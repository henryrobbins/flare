import json
import shutil
import subprocess
import time
from pathlib import Path

from milp_eq_tools import Formulation

from .checker import CheckResult, EquivalenceChecker
from .prompts import render_formulation_description

# Settings written into each wd/.claude/ to restrict the agent to the
# working directory and avoid it reading ground-truth files from the repo.
_STAGING_SETTINGS = {
    "env": {
        "CLAUDE_CODE_THINKING_BUDGET": "10000",
    },
    "permissions": {
        "allow": [
            "mcp__lean-lsp__*",
            "Bash(lake env lean:*)",
            "Bash(lake build:*)",
        ],
    },
    "enableAllProjectMcpServers": True,
    "enabledMcpjsonServers": ["lean-lsp"],
}

# Lakefile for the isolated working directory — A/ and B/ hold the two
# formulations; Equivalence.lean lives at the root.
_STAGING_LAKEFILE = """\
name = "bench"
version = "0.1.0"

[[require]]
name = "mathlib"
git = "https://github.com/leanprover-community/mathlib4"
rev = "v4.28.0"

[[lean_lib]]
name = "Common"

[[lean_lib]]
name = "A"
srcDir = "."
globs = ["A.+"]

[[lean_lib]]
name = "B"
srcDir = "."
globs = ["B.+"]
"""

_AGENT_PROMPT_TEMPLATE = """\
You are a Lean 4 expert working on MILP formalization. Your task:

1. Read the formulation descriptions and solver scripts for two formulations of the same problem.
2. Generate a Lean 4 `Formulation.lean` file for each formulation following the lean-milp-formulation skill at `.claude/skills/lean-milp-formulation/`.
3. Determine whether the two formulations are mathematically equivalent.
4. If equivalent: generate a compiled `MILPEquiv` proof following the lean-milp-equivalence skill at `.claude/skills/lean-milp-equivalence/`. Write it to the output path.
5. If not equivalent: write `NOT EQUIVALENT: <brief reason>` to the output path and stop.

Formulation A description: A/formulation.md
Formulation A solver: A/solve.py
Formulation A output: A/Formulation.lean

Formulation B description: B/formulation.md
Formulation B solver: B/solve.py
Formulation B output: B/Formulation.lean

Equivalence proof output: Equivalence.lean

Important:
- Only read files that exist in this working directory. Do not navigate outside it.
- The Lean project root is the current directory. Use `import A.Formulation` and `import B.Formulation`.
- Use the lean-lsp MCP tools to check compilation as you work.
- Generate both Formulation.lean files before attempting the equivalence proof.
"""


class ClaudeCodeChecker(EquivalenceChecker):
    def __init__(self, runs_dir: Path, repo_root: Path) -> None:
        super().__init__(runs_dir)
        self.repo_root = repo_root

    @property
    def name(self) -> str:
        return "claude_code"

    def check(self, a: Formulation, b: Formulation, pair_id: str) -> CheckResult:
        artifacts_dir = self.runs_dir / "pairs" / pair_id / self.name
        artifacts_dir.mkdir(parents=True, exist_ok=True)

        # wd lives inside the timestamped run dir so all artifacts are co-located.
        wd = artifacts_dir / "wd"
        self._setup_wd(wd, a, b)

        (artifacts_dir / "prompt.txt").write_text(_AGENT_PROMPT_TEMPLATE)

        jsonl_path = artifacts_dir / "claude_output.jsonl"
        print(f"  [claude_code] {pair_id} → monitor: tail -f {jsonl_path}")

        stream_metrics = self._run_claude(_AGENT_PROMPT_TEMPLATE, wd, jsonl_path)

        meta = self._evaluate(wd)
        meta.update(stream_metrics)

        (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))

        # Copy generated Lean outputs alongside other artifacts for inspection.
        for rel in ["A/Formulation.lean", "B/Formulation.lean", "Equivalence.lean"]:
            src = wd / rel
            if src.exists() and src.stat().st_size > 0:
                dst = artifacts_dir / Path(rel).name
                shutil.copy2(src, dst)

        return CheckResult(
            is_equivalent=meta["is_equivalent"],
            method=self.name,
            artifacts_dir=artifacts_dir,
            metadata=meta,
        )

    def _setup_wd(self, wd: Path, a: Formulation, b: Formulation) -> None:
        wd.mkdir(parents=True, exist_ok=True)

        shutil.copy2(self.repo_root / "lean-toolchain", wd / "lean-toolchain")
        shutil.copy2(self.repo_root / "Common.lean", wd / "Common.lean")
        (wd / "lakefile.toml").write_text(_STAGING_LAKEFILE)

        # Copy agents/skills but use restricted settings; omit milp-reviewer.
        claude_dst = wd / ".claude"
        shutil.copytree(self.repo_root / ".claude", claude_dst, dirs_exist_ok=True)
        reviewer = claude_dst / "agents" / "milp-reviewer.md"
        if reviewer.exists():
            reviewer.unlink()
        (claude_dst / "settings.local.json").write_text(
            json.dumps(_STAGING_SETTINGS, indent=4)
        )

        problem_id = a.path.parent.parent.name
        prob_src = self.repo_root / "dataset" / "problems" / problem_id
        problem_desc = (prob_src / "description.md").read_text()

        for label, form in [("A", a), ("B", b)]:
            form_dir = wd / label
            form_dir.mkdir(exist_ok=True)
            (form_dir / "formulation.md").write_text(
                render_formulation_description(form, problem_desc)
            )
            solve_src = form.path / "solve.py"
            if solve_src.exists():
                shutil.copy2(solve_src, form_dir / "solve.py")
            (form_dir / "Formulation.lean").write_text("")

        (wd / "Equivalence.lean").write_text("")

        # Share the repo's pre-built Mathlib oleans instead of downloading a
        # fresh copy per pair. Each wd still gets its own .lake/build/ for
        # A/B/Equivalence modules, so parallel runs don't conflict.
        wd_lake = wd / ".lake"
        wd_lake.mkdir(parents=True, exist_ok=True)
        (wd_lake / "packages").symlink_to(self.repo_root / ".lake" / "packages")

    def _run_claude(self, prompt: str, wd: Path, jsonl_path: Path) -> dict:
        cmd = [
            "claude",
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--permission-mode", "bypassPermissions",
        ]
        start = time.time()
        stdout_lines: list[str] = []

        with jsonl_path.open("w") as jsonl_f:
            with subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=wd,
            ) as proc:
                assert proc.stdout is not None
                for line in proc.stdout:
                    jsonl_f.write(line)
                    jsonl_f.flush()
                    stdout_lines.append(line)
                stderr = proc.stderr.read() if proc.stderr else ""
                proc.wait()

        duration = time.time() - start

        if stderr:
            jsonl_path.with_name("claude_stderr.txt").write_text(stderr)

        return {"duration_s": round(duration, 1), **_parse_stream(stdout_lines)}

    def _evaluate(self, wd: Path) -> dict:
        form_a_lean = wd / "A" / "Formulation.lean"
        form_b_lean = wd / "B" / "Formulation.lean"
        equiv_file = wd / "Equivalence.lean"

        equiv_content = equiv_file.read_text().strip() if equiv_file.exists() else ""

        if equiv_content.upper().startswith("NOT EQUIVALENT"):
            return {
                "is_equivalent": False,
                "agent_decision": "not_equivalent",
                "agent_reason": equiv_content,
                "form_a_written": form_a_lean.exists() and form_a_lean.stat().st_size > 0,
                "form_b_written": form_b_lean.exists() and form_b_lean.stat().st_size > 0,
                "form_a_compiled": None,
                "form_b_compiled": None,
                "proof_compiled": None,
                "has_sorry": None,
            }

        form_a_written = form_a_lean.exists() and form_a_lean.stat().st_size > 0
        form_b_written = form_b_lean.exists() and form_b_lean.stat().st_size > 0
        proof_written = bool(equiv_content)

        form_a_compiled = _lean_compiles(wd, form_a_lean) if form_a_written else False
        form_b_compiled = _lean_compiles(wd, form_b_lean) if form_b_written else False
        proof_compiled = _lean_compiles(wd, equiv_file) if proof_written else False
        has_sorry = "sorry" in equiv_content if proof_written else None

        is_equivalent = proof_compiled and not has_sorry

        return {
            "is_equivalent": is_equivalent,
            "agent_decision": "equivalent" if is_equivalent else "failed",
            "form_a_written": form_a_written,
            "form_b_written": form_b_written,
            "form_a_compiled": form_a_compiled,
            "form_b_compiled": form_b_compiled,
            "proof_compiled": proof_compiled,
            "has_sorry": has_sorry,
        }


def _lean_compiles(cwd: Path, lean_file: Path) -> bool:
    try:
        result = subprocess.run(
            ["lake", "env", "lean", str(lean_file)],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=300,
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def _parse_stream(lines: list[str]) -> dict:
    input_tokens = 0
    output_tokens = 0
    stop_reason = None
    cost_usd = None

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        if obj.get("type") == "result":
            stop_reason = obj.get("stop_reason")
            cost_usd = obj.get("total_cost_usd")
            usage = obj.get("usage", {})
            input_tokens = usage.get("input_tokens", input_tokens)
            output_tokens = usage.get("output_tokens", output_tokens)

    return {
        "stop_reason": stop_reason,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cost_usd": cost_usd,
    }
