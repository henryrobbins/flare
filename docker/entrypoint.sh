#!/usr/bin/env bash
# Runs the harness-rendered agent.sh + post-hoc compile check inside the
# container. The harness writes /workspace/out/agent.sh from the host before
# invoking us, so this entrypoint is CLI-agnostic: it just sources the agent
# script and then runs `lake env lean` on A/B/Reformulation. Outputs land in
# /workspace/out/ (bind-mounted to the pair dir on the host).

set -uo pipefail

OUT=/workspace/out
AGENT_SH=$OUT/agent.sh
COMPILE_LOG=$OUT/compile_log.txt
RESULT=$OUT/result.json

if [[ ! -f $AGENT_SH ]]; then
    echo "entrypoint: missing $AGENT_SH" >&2
    exit 2
fi
if [[ ! -f $OUT/prompt.txt ]]; then
    echo "entrypoint: missing $OUT/prompt.txt" >&2
    exit 2
fi

# The agent runs at /workspace, which is image-baked (lakefile, Common,
# .lake/mathlib, lean-toolchain). Per-pair source files (A/, B/,
# Reformulation.lean) and agent config (.claude/, .mcp.json) are reached
# via image-side symlinks at /workspace/{A,B,Reformulation.lean,.claude,
# .mcp.json} that resolve into the bind-mounted host pair_dir. So the lake
# skeleton never appears on the host, and the host's pair_dir/wd contains
# only the agent's source files. The cwd and PROMPT carry over to agent.sh.
cd /workspace
export PROMPT="$(cat "$OUT/prompt.txt")"
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
