#!/usr/bin/env bash

# $PROMPT is set by the container entrypoint: milp_flare/assets/docker/entrypoint.sh
# Use `opencode run` to run the agent in non-interactive mode
# `opencode.json` configures model provider and MCP server: src/verify/flare/harness/opencode.py
# <<PROVIDER>> and <<MODEL>> are templated by src/verify/flare/harness/opencode.py
# The event stream goes to stdout

# --auto auto-approves every permission (safe in the container). Without it a
# prompt is auto-*rejected* and opencode tears the session down mid-turn.
#
# https://opencode.ai/docs/cli/#run-1

opencode run --dir /workspace/wd --format json --auto \
    --model '<<PROVIDER>>/<<MODEL>>' \
    "$PROMPT"
