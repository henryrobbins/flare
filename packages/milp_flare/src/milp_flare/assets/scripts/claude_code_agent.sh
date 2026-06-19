#!/usr/bin/env bash

# $PROMPT is set by the container entrypoint: milp_flare/assets/docker/entrypoint.sh
# bypassPermissions skips all permission prompts (safe in container)
# .mcp.json configures MCP servers and --strict-mcp-config restricts to those servers
# <<MODEL>> and <<EFFORT>> are templated by src/verify/flare/harness/claude_code.py
# The event stream goes to stdout; the runner streams it and persists it as
# agent_output.jsonl on the host.
#
# https://code.claude.com/docs/en/permissions
# https://code.claude.com/docs/en/cli-reference

claude -p "$PROMPT" \
    --output-format stream-json --verbose \
    --permission-mode bypassPermissions \
    --mcp-config .mcp.json --strict-mcp-config \
    --model '<<MODEL>>' --effort '<<EFFORT>>'
