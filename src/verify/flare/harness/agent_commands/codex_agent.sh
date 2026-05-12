#!/usr/bin/env bash

# $PROMPT is set by the container entrypoint: docker/entrypoint.sh
# Use `codex exec` to run the agent in non-interactive mode
# danger-full-access sandbox gives broad permissions (safe in container)
# Supply model using dedicated flag and template with src/verify/flare/harness/codex.py
# Supply effort using -c override and template with src/verify/flare/harness/codex.py
# Provide MCP configuration via -c overrides since codex doesn't auto-discover .mcp.json
# Write logs to the agent working directory inside the container: /workspace/wd
#
# https://developers.openai.com/codex/cli/reference
# https://developers.openai.com/codex/noninteractive#permissions-and-safety
# https://developers.openai.com/codex/config-advanced#one-off-overrides-from-the-cli

codex exec --json --skip-git-repo-check \
    --sandbox danger-full-access \
    --model '<<MODEL>>' \
    -c 'mcp_servers.lean-lsp.command="uvx"' \
    -c 'mcp_servers.lean-lsp.args=["lean-lsp-mcp"]' \
    -c 'model_reasoning_effort="<<EFFORT>>"' \
    "$PROMPT" \
    > /workspace/wd/agent_output.jsonl
