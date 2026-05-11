# FLARE agent image. Runs Claude Code, Codex, or OpenCode against a
# bind-mounted pair dir. The lake project skeleton (lakefile.toml,
# Common.lean, lean-toolchain, lake-manifest.json, .lake/) lives in the
# image at /workspace/; the harness bind-mounts the host pair dir at
# /workspace/out/, and the agent works under /workspace/out/wd/.
#
# Build:
#   docker build -t flare-agent:latest .
#
# Run (driven by src/verify/flare/harness/docker.py):
#   docker run --rm \
#       -v ${pair_dir}:/workspace/out \
#       -e CLAUDE_CODE_OAUTH_TOKEN \           # (claude_code)
#       -v ~/.codex:/home/agent/.codex:ro \    # (codex)
#       flare-agent:latest \
#       --cli claude_code --model claude-opus-4-7 --effort medium

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        build-essential \
        python3 \
        python3-pip \
        pipx \
    && rm -rf /var/lib/apt/lists/*

# Node 20 + the three agent CLIs (all distributed via npm).
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g @anthropic-ai/claude-code @openai/codex opencode-ai \
 && rm -rf /var/lib/apt/lists/*

# Non-root user (Claude Code refuses root; Codex/OpenCode are happy as
# either, and a regular user matches local-dev posture).
RUN useradd -m -s /bin/bash agent
USER agent
WORKDIR /home/agent

# elan + Lean toolchain. `--default-toolchain none` lets the lean-toolchain
# file we copy below pin the version on first `lake` invocation.
RUN curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf \
        | sh -s -- -y --default-toolchain none --no-modify-path
ENV PATH="/home/agent/.elan/bin:/home/agent/.local/bin:${PATH}"

# lean-lsp MCP server (matches the `uvx lean-lsp-mcp` invocation in .mcp.json).
RUN pipx install lean-lsp-mcp \
 && pipx install uv

WORKDIR /workspace

# Lake project skeleton. Split into the slow layers (cache get + build
# Common) so per-experiment changes to the entrypoint don't bust them.
COPY --chown=agent:agent lean-toolchain        /workspace/lean-toolchain
COPY --chown=agent:agent lake-manifest.json    /workspace/lake-manifest.json
COPY --chown=agent:agent Common.lean           /workspace/Common.lean
COPY --chown=agent:agent docker/lakefile.toml  /workspace/lakefile.toml

# Pre-fetch mathlib oleans for the pinned toolchain (~3-5 min download
# vs. 30-45 min compile). Cached as its own layer.
RUN lake exe cache get

# Pre-build Common so its olean is warm in /workspace/.lake/build/.
RUN lake build Common

# Image-side symlinks bridge the agent's cwd (/workspace) to per-pair files
# that arrive via the bind mount at /workspace/out. Targets are dangling at
# image build time and resolve at runtime once the bind mount is present.
# Lake commands run from /workspace and resolve A/B/Reformulation through
# the symlinks; the host's pair_dir/wd therefore contains only the agent's
# source files (no lake skeleton clutter).
RUN ln -s out/wd/A               /workspace/A \
 && ln -s out/wd/B               /workspace/B \
 && ln -s out/wd/Reformulation.lean /workspace/Reformulation.lean \
 && ln -s out/.claude            /workspace/.claude \
 && ln -s out/.mcp.json          /workspace/.mcp.json \
 && ln -s out/opencode.json      /workspace/opencode.json \
 && ln -s out/prompt.txt         /workspace/prompt.txt

# Entrypoint dispatches based on --cli {claude_code|codex|opencode},
# runs the agent, runs the post-hoc lake compile check, writes result.json.
COPY --chown=agent:agent docker/entrypoint.sh /usr/local/bin/run-agent
USER root
RUN chmod +x /usr/local/bin/run-agent
USER agent

ENTRYPOINT ["/usr/local/bin/run-agent"]
