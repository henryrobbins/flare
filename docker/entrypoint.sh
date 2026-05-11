#!/usr/bin/env bash
# Runs the harness-rendered agent.sh + post-hoc compile check inside the
# container. The harness bind-mounts pair_dir/wd at /workspace/wd, so
# everything the agent needs (agent.sh, prompt.txt, configs, A/, B/,
# Reformulation.lean, lake skeleton) and everything we write back
# (agent_output.jsonl, result.json, compile_log.txt) lives at that one
# path.
#
# /workspace/.lake is image-baked (mathlib + Common.olean) and lives
# outside the bind mount. We symlink it into /workspace/wd/.lake so the
# agent's lake project (rooted at /workspace/wd) finds the build tree.
# The symlink itself appears on host as a dangling pointer to
# /workspace/.lake — that's intentional; the multi-GB build artifacts
# stay in the container's writable layer and get discarded with --rm.

set -uo pipefail

WD=/workspace/wd
AGENT_SH=$WD/agent.sh
COMPILE_LOG=$WD/compile_log.txt
RESULT=$WD/result.json

if [[ ! -f $AGENT_SH ]]; then
    echo "entrypoint: missing $AGENT_SH" >&2
    exit 2
fi
if [[ ! -f $WD/prompt.txt ]]; then
    echo "entrypoint: missing $WD/prompt.txt" >&2
    exit 2
fi

ln -sfn /workspace/.lake "$WD/.lake"

cd "$WD"
export PROMPT="$(cat "$WD/prompt.txt")"
bash "$AGENT_SH"
AGENT_EXIT=$?

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
