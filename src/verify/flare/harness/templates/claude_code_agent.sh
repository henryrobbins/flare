#!/usr/bin/env bash
set -uo pipefail
cd /workspace
PROMPT="$(cat /workspace/out/prompt.txt)"
claude -p "$PROMPT" \
    --output-format stream-json --verbose \
    --permission-mode dontAsk \
    --settings .claude/settings.json \
    --model '<<MODEL>>' --effort '<<EFFORT>>' \
    > /workspace/out/agent_output.jsonl
