#!/usr/bin/env bash
opencode run --dir /workspace --format json \
    --model '<<PROVIDER>>/<<MODEL>>' \
    "$PROMPT" \
    > /workspace/agent_output.jsonl
