#!/usr/bin/env bash
claude -p "$PROMPT" \
    --output-format stream-json --verbose \
    --permission-mode bypassPermissions \
    --mcp-config .mcp.json --strict-mcp-config \
    --model '<<MODEL>>' --effort '<<EFFORT>>' \
    > /workspace/wd/agent_output.jsonl
