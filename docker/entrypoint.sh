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
# .lake/mathlib, lean-toolchain). Per-pair files (.claude/, .agents/,
# opencode.json, .mcp.json, prompt.txt, …) arrive via the bind mount at
# /workspace/out — each harness writes only what its CLI needs. Below we
# symlink everything that landed in /workspace/out into /workspace/ so the
# agent's cwd sees those files at their conventional names. A/, B/, and
# Reformulation.lean are NOT bridged this way: they're bind-mounted
# directly at /workspace/{A,B,Reformulation.lean} because claude_code's
# Write tool refuses to follow symlinks.
shopt -s dotglob nullglob
for path in "$OUT"/*; do
    name=$(basename "$path")
    [[ -e /workspace/$name && ! -L /workspace/$name ]] && continue
    ln -sfn "out/$name" "/workspace/$name"
done
shopt -u dotglob nullglob

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
