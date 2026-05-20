FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ripgrep is a recommended install for lean_local_search in the lean-lsp-mcp
# See https://github.com/oOo0oOo/lean-lsp-mcp#4-install-ripgrep-optional-but-recommended
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        build-essential \
        python3 \
        python3-pip \
        pipx \
        ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Node 20 + agent CLIs (Claude Code, Codex, OpenCode)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g @anthropic-ai/claude-code @openai/codex opencode-ai \
 && rm -rf /var/lib/apt/lists/*

# Non-root user (Claude Code refuses root).
RUN useradd -m -s /bin/bash agent
USER agent
WORKDIR /home/agent

# elan + Lean toolchain. `--default-toolchain none` lets the lean-toolchain
# file we copy below pin the version on first `lake` invocation.
RUN curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf \
        | sh -s -- -y --default-toolchain none --no-modify-path
ENV PATH="/home/agent/.elan/bin:/home/agent/.local/bin:${PATH}"

# lean-lsp MCP server (matches the `uvx lean-lsp-mcp` invocation in .mcp.json).
# https://github.com/oOo0oOo/lean-lsp-mcp
RUN pipx install lean-lsp-mcp \
 && pipx install uv

WORKDIR /workspace

# Configure Lake project skeleton in the image. Build context is the
# milp_flare package's `assets/` directory (parent of `lean/` and
# `docker/`), so the image builds purely from files bundled in the
# installed package.
COPY --chown=agent:agent lean/ /workspace/

# Pre-fetch mathlib oleans for the pinned toolchain
RUN lake exe cache get

# Pre-build Common so its olean is warm in /workspace/.lake/build/
# The agent working directory is bind mounted to /workspace/wd and then
# /workspace/wd/.lake is symlinked to /workspace/.lake so the agent has a
# pre-built lake build without polluting the host with build artifacts
RUN lake build Common

# Entrypoint sources the harness-rendered agent.sh, then runs the
# post-hoc lake compile check and writes result.json + compile_log.txt
# back through the bind mount.
COPY --chown=agent:agent docker/entrypoint.sh /usr/local/bin/run-agent
USER root
RUN chmod +x /usr/local/bin/run-agent
USER agent

ENTRYPOINT ["/usr/local/bin/run-agent"]
