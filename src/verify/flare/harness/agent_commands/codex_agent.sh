#!/usr/bin/env bash
# Docker is the isolation boundary; `--sandbox danger-full-access` drops
# codex's own sandbox (which blocks lake from finding its toolchain). Codex
# doesn't auto-discover .mcp.json, so the lean-lsp MCP server is declared
# inline via -c overrides.
codex exec --json --skip-git-repo-check \
    --sandbox danger-full-access \
    --model '<<MODEL>>' \
    -c 'mcp_servers.lean-lsp.command="uvx"' \
    -c 'mcp_servers.lean-lsp.args=["lean-lsp-mcp"]' \
    -c 'model_reasoning_effort="<<EFFORT>>"' \
    "$PROMPT" \
    > /workspace/wd/agent_output.jsonl
