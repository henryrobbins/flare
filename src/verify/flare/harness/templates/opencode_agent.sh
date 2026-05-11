#!/usr/bin/env bash
set -uo pipefail
cd /workspace
PROMPT="$(cat /workspace/out/prompt.txt)"
opencode run --dir /workspace --format json \
    --model '<<PROVIDER>>/<<MODEL>>' \
    "$PROMPT" \
    > /workspace/out/agent_output.jsonl
