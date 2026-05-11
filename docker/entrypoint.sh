#!/usr/bin/env bash
# Runs one agent + compile check inside the container. Reads the prompt
# from /workspace/out/prompt.txt, writes outputs back to /workspace/out/
# (which the harness has bind-mounted to the pair dir on the host).

set -uo pipefail

CLI=""
MODEL=""
EFFORT=""
PROVIDER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cli)      CLI="$2";      shift 2 ;;
        --model)    MODEL="$2";    shift 2 ;;
        --effort)   EFFORT="$2";   shift 2 ;;
        --provider) PROVIDER="$2"; shift 2 ;;
        *) echo "entrypoint: unknown arg $1" >&2; exit 2 ;;
    esac
done

OUT=/workspace/out
WD=$OUT/wd
PROMPT_FILE=$OUT/prompt.txt
JSONL=$OUT/agent_output.jsonl
COMPILE_LOG=$OUT/compile_log.txt
RESULT=$OUT/result.json

if [[ ! -f $PROMPT_FILE ]]; then
    echo "entrypoint: missing $PROMPT_FILE" >&2
    exit 2
fi

PROMPT="$(cat "$PROMPT_FILE")"

# The agent runs at /workspace, which is image-baked (lakefile, Common,
# .lake/mathlib, lean-toolchain). Per-pair source files (A/, B/,
# Reformulation.lean) and agent config (.claude/, .mcp.json) are reached
# via image-side symlinks at /workspace/{A,B,Reformulation.lean,.claude,
# .mcp.json} that resolve into the bind-mounted host pair_dir. So the lake
# skeleton never appears on the host, and the host's pair_dir/wd contains
# only the agent's source files.
cd /workspace

AGENT_EXIT=0
case "$CLI" in
    claude_code)
        claude -p "$PROMPT" \
            --output-format stream-json --verbose \
            --permission-mode dontAsk \
            --settings .claude/settings.json \
            --model "$MODEL" --effort "$EFFORT" \
            > "$JSONL"
        AGENT_EXIT=$?
        ;;
    codex)
        # The Docker container is the isolation boundary; drop codex's own
        # sandbox (which blocks lake from finding its toolchain via some
        # restriction even in workspace-write mode). Register the lean-lsp
        # MCP server inline since codex does not auto-discover .mcp.json.
        codex exec --json --skip-git-repo-check \
            --sandbox danger-full-access \
            -c 'mcp_servers.lean-lsp.command="uvx"' \
            -c 'mcp_servers.lean-lsp.args=["lean-lsp-mcp"]' \
            -c 'model_reasoning_effort="'"$EFFORT"'"' \
            "$PROMPT" \
            > "$JSONL"
        AGENT_EXIT=$?
        ;;
    opencode)
        opencode run --dir /workspace --format json \
            --model "${PROVIDER}/${MODEL}" "$PROMPT" \
            > "$JSONL"
        AGENT_EXIT=$?
        ;;
    *)
        echo "entrypoint: unknown --cli '$CLI' (expected claude_code|codex|opencode)" >&2
        exit 2
        ;;
esac

: > "$COMPILE_LOG"

run_compile() {
    local file="$1"
    echo "=== $file ===" >> "$COMPILE_LOG"
    lake env lean "$file" >> "$COMPILE_LOG" 2>&1
    local rc=$?
    echo "=== exit: $rc ===" >> "$COMPILE_LOG"
    return $rc
}

run_compile A/Formulation.lean; FORM_A_EXIT=$?
run_compile B/Formulation.lean; FORM_B_EXIT=$?
run_compile Reformulation.lean; COMPILE_EXIT=$?

cat > "$RESULT" <<EOF
{"agent_exit": $AGENT_EXIT, "form_a_compile_exit": $FORM_A_EXIT, "form_b_compile_exit": $FORM_B_EXIT, "compile_exit": $COMPILE_EXIT}
EOF

exit $COMPILE_EXIT
