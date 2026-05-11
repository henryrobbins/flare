#!/usr/bin/env bash
opencode run --dir /workspace --format json \
    --model '<<PROVIDER>>/<<MODEL>>' \
    "$PROMPT" \
    > /workspace/out/agent_output.jsonl
