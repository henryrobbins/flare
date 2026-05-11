# FLARE agent image. Runs Claude Code, Codex, or OpenCode against a
# bind-mounted pair dir. The lake project skeleton (lakefile.toml,
# Common.lean, lean-toolchain, lake-manifest.json, .lake/) lives in the
# image at /workspace/. The harness bind-mounts the host pair_dir/wd at
# /workspace, which overlays the four small skeleton files (they are
# also copied into pair_dir/wd by FLAREVerifier._setup_wd from the repo,
# so the bind mount doesn't shadow them away to nothing). The big .lake/
# build tree is shadowed by a named volume seeded from this image so it
# never lands on the host.
#
# Build:
#   docker build -t flare-agent:latest .
#
# Run (driven by src/verify/flare/harness/base.py):
#   docker run --rm \
#       -v ${pair_dir}/wd:/workspace \
#       -v flare-lake:/workspace/.lake \
#       -e CLAUDE_CODE_OAUTH_TOKEN \           # (claude_code)
#       -v ~/.codex:/home/agent/.codex \       # (codex)
#       flare-agent:latest

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
# These four files are also copied into pair_dir/wd at runtime by the
# harness, because the bind mount on /workspace would otherwise hide
# them. The image-side copies exist so the build steps below can run.
COPY --chown=agent:agent lean-toolchain        /workspace/lean-toolchain
COPY --chown=agent:agent lake-manifest.json    /workspace/lake-manifest.json
COPY --chown=agent:agent Common.lean           /workspace/Common.lean
COPY --chown=agent:agent docker/lakefile.toml  /workspace/lakefile.toml

# Pre-fetch mathlib oleans for the pinned toolchain (~3-5 min download
# vs. 30-45 min compile). Cached as its own layer. Populates
# /workspace/.lake, which the harness mounts a named volume over so
# Docker seeds the volume from this layer on first use.
RUN lake exe cache get

# Pre-build Common so its olean is warm in /workspace/.lake/build/.
RUN lake build Common

# Entrypoint sources the harness-rendered agent.sh, then runs the
# post-hoc lake compile check and writes result.json + compile_log.txt
# back through the bind mount.
COPY --chown=agent:agent docker/entrypoint.sh /usr/local/bin/run-agent
USER root
RUN chmod +x /usr/local/bin/run-agent
USER agent

ENTRYPOINT ["/usr/local/bin/run-agent"]
