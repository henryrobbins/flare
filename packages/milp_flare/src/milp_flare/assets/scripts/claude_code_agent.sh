#!/usr/bin/env bash

# $PROMPT is set by the container entrypoint: milp_flare/assets/docker/entrypoint.sh
# bypassPermissions skips all permission prompts (safe in container)
# .mcp.json configures MCP servers and --strict-mcp-config restricts to those servers
# <<MODEL>> and <<EFFORT>> are templated by src/verify/flare/harness/claude_code.py
# Write logs to the agent working directory inside the container: /workspace/wd
#
# https://code.claude.com/docs/en/permissions
# https://code.claude.com/docs/en/cli-reference

claude -p "$PROMPT" \
    --output-format stream-json --verbose \
    --permission-mode bypassPermissions \
    --mcp-config .mcp.json --strict-mcp-config \
    --model '<<MODEL>>' --effort '<<EFFORT>>' \
    > /workspace/wd/agent_output.jsonl
