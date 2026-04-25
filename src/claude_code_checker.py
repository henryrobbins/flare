import json
import os
import re
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
- You MUST use the lean-lsp MCP tools (mcp__lean-lsp__*) to check compilation as you work. Before doing anything else, verify the lean-lsp MCP server is available by calling `mcp__lean-lsp__lean_diagnostic_messages` on `Common.lean`. If that call fails (e.g., "Failed to start Lean language server" or the tool is unavailable), STOP IMMEDIATELY: write `MCP_UNAVAILABLE: <error>` to Equivalence.lean and exit. Do not fall back to `lake env lean` or `lake build`.
- Generate both Formulation.lean files before attempting the equivalence proof.
- After writing `A/Formulation.lean` and `B/Formulation.lean`, validate each with `mcp__lean-lsp__lean_diagnostic_messages`, then run `Bash(lake build A.Formulation B.Formulation)` ONCE to materialize their oleans. Without this, `lean_diagnostic_messages` on `Equivalence.lean` will return `success:false` with empty items because its imports cannot be elaborated. After the build, use `lean_diagnostic_messages` on `Equivalence.lean` for all subsequent proof iteration.
- Interpret `lean_diagnostic_messages` carefully: `success:true, items:[]` means the file compiles cleanly. `success:false, items:[]` typically means imports aren't built yet — build them, don't assume the file is broken. Real errors come back as `items` with severity/message fields.
- Confirm the final equivalence proof with `mcp__lean-lsp__lean_verify` on the `MILPEquiv` definition. The returned axioms must NOT contain `sorryAx` — if it does, the proof has a stub and you must finish it.
"""


class ClaudeCodeChecker(EquivalenceChecker):
    def __init__(self, runs_dir: Path, repo_root: Path, model: str = "claude-sonnet-4-6") -> None:
        super().__init__(runs_dir)
        self.repo_root = repo_root
        self.model = model

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
        shutil.copy2(self.repo_root / ".mcp.json", wd / ".mcp.json")
        shutil.copy2(self.repo_root / "lake-manifest.json", wd / "lake-manifest.json")
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
        (wd_lake / "packages").symlink_to((self.repo_root / ".lake" / "packages").resolve())

        # Pre-build Common.olean so the agent's first lean-lsp diagnostic call
        # on a freshly-written Formulation.lean (which imports Common) returns
        # real diagnostics instead of an opaque `success:false`.
        subprocess.run(
            ["lake", "build", "Common"],
            cwd=wd,
            check=True,
            capture_output=True,
            text=True,
            timeout=180,
        )

    def _run_claude(self, prompt: str, wd: Path, jsonl_path: Path) -> dict:
        cmd = [
            "claude",
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--permission-mode", "bypassPermissions",
        ]
        cmd += ["--model", self.model]
        start = time.time()
        stdout_lines: list[str] = []

        # Strip ANTHROPIC_API_KEY so claude uses the Claude.ai plan (OAuth
        # session) rather than API credits, with automatic extra-usage overage.
        subprocess_env = {k: v for k, v in os.environ.items() if k != "ANTHROPIC_API_KEY"}

        with jsonl_path.open("w") as jsonl_f:
            with subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=wd,
                env=subprocess_env,
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

        # Normalize the first meaningful line: strip Lean comment markers so
        # "-- NOT EQUIVALENT: ..." is detected the same as "NOT EQUIVALENT: ...".
        first_line = next((l.strip() for l in equiv_content.splitlines() if l.strip()), "")
        normalized = re.sub(r"^-+\s*", "", first_line).upper()

        base = {
            "form_a_written": form_a_lean.exists() and form_a_lean.stat().st_size > 0,
            "form_b_written": form_b_lean.exists() and form_b_lean.stat().st_size > 0,
            "form_a_compiled": None,
            "form_b_compiled": None,
            "proof_compiled": None,
            "milp_equiv_found": None,
            "sorry_free": None,
        }

        if normalized.startswith("NOT EQUIVALENT"):
            return {"is_equivalent": False, "agent_decision": "not_equivalent",
                    "agent_reason": equiv_content, **base}

        if normalized.startswith("MCP_UNAVAILABLE"):
            return {"is_equivalent": False, "agent_decision": "mcp_unavailable",
                    "agent_reason": equiv_content, **base}

        form_a_written = base["form_a_written"]
        form_b_written = base["form_b_written"]
        proof_written = bool(equiv_content)

        compile_log_path = wd.parent / "compile_log.txt"
        with compile_log_path.open("w") as log:
            form_a_compiled = (
                _lean_compiles(wd, form_a_lean, log, "A/Formulation.lean")
                if form_a_written else False
            )
            form_b_compiled = (
                _lean_compiles(wd, form_b_lean, log, "B/Formulation.lean")
                if form_b_written else False
            )
            proof_compiled, proof_output = (
                _lean_compiles_with_output(wd, equiv_file, log, "Equivalence.lean")
                if proof_written else (False, "")
            )
            # MILPEquiv presence: require a 'def _ : MILPEquiv' in the file.
            milp_equiv_found = bool(re.search(r"\bdef\s+\w+\s*:\s*MILPEquiv\b", equiv_content))
            # Lean emits "warning: 'X' uses sorry" when sorry is present.
            # Only meaningful when the file compiled and the def was found.
            sorry_free = (
                "uses sorry" not in proof_output
                if (proof_compiled and milp_equiv_found) else False
            )
            log.write(f"=== sorry check ===\nmilp_equiv_found: {milp_equiv_found}\n"
                      f"sorry_free: {sorry_free}\n\n")

        is_equivalent = (
            form_a_compiled and form_b_compiled
            and proof_compiled and milp_equiv_found and sorry_free
        )

        return {
            "is_equivalent": is_equivalent,
            "agent_decision": "equivalent" if is_equivalent else "failed",
            "form_a_written": form_a_written,
            "form_b_written": form_b_written,
            "form_a_compiled": form_a_compiled,
            "form_b_compiled": form_b_compiled,
            "proof_compiled": proof_compiled,
            "milp_equiv_found": milp_equiv_found,
            "sorry_free": sorry_free,
        }

def _lean_compiles(cwd: Path, lean_file: Path, log, label: str) -> bool:
    compiled, _ = _lean_compiles_with_output(cwd, lean_file, log, label)
    return compiled


def _lean_compiles_with_output(cwd: Path, lean_file: Path, log, label: str) -> tuple[bool, str]:
    start = time.time()
    cwd_abs = cwd.resolve()
    lean_file_abs = lean_file.resolve()
    log.write(f"=== {label} ===\n")
    log.write(f"cmd: lake env lean {lean_file_abs}\n")
    log.write(f"cwd: {cwd_abs}\n")
    try:
        result = subprocess.run(
            ["lake", "env", "lean", str(lean_file_abs)],
            cwd=cwd_abs,
            capture_output=True,
            text=True,
            timeout=300,
        )
        duration = time.time() - start
        log.write(f"returncode: {result.returncode}\n")
        log.write(f"duration_s: {duration:.1f}\n")
        if result.stdout:
            log.write(f"--- stdout ---\n{result.stdout}\n")
        if result.stderr:
            log.write(f"--- stderr ---\n{result.stderr}\n")
        combined = result.stdout + result.stderr
        log.write("\n")
        log.flush()
        return result.returncode == 0, combined
    except subprocess.TimeoutExpired as e:
        duration = time.time() - start
        log.write(f"TIMEOUT after {duration:.1f}s (limit 300s)\n")
        partial = ""
        if e.stdout:
            s = e.stdout.decode(errors='replace') if isinstance(e.stdout, bytes) else e.stdout
            log.write(f"--- partial stdout ---\n{s}\n"); partial += s
        if e.stderr:
            s = e.stderr.decode(errors='replace') if isinstance(e.stderr, bytes) else e.stderr
            log.write(f"--- partial stderr ---\n{s}\n"); partial += s
        log.write("\n")
        log.flush()
        return False, partial
    except FileNotFoundError as e:
        log.write(f"FileNotFoundError: {e}\n\n")
        log.flush()
        return False, ""


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
