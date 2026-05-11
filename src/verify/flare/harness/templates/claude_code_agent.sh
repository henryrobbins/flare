#!/usr/bin/env bash
claude -p "$PROMPT" \
    --output-format stream-json --verbose \
    --permission-mode dontAsk \
    --settings .claude/settings.json \
    --model '<<MODEL>>' --effort '<<EFFORT>>' \
    > /workspace/out/agent_output.jsonl
