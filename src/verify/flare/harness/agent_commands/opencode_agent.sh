#!/usr/bin/env bash
opencode run --dir /workspace/wd --format json \
    --model '<<PROVIDER>>/<<MODEL>>' \
    "$PROMPT" \
    > /workspace/wd/agent_output.jsonl
