import copy
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

from milp_eq_tools import Formulation

from src.prompts import render_formulation
from src.verify.base import EquivalenceResult, EquivalenceVerifier
from src.verify.equivaproof.prompts import render_agent_prompt

_HERE = Path(__file__).parent
_LAKEFILE: str = (_HERE / "lakefile.toml").read_text()
_CLAUDE_CODE_SETTINGS_TEMPLATE: dict = json.loads((_HERE / "settings.json").read_text())

# We use a combination of sandboxing and permissions to restrict the agent
# to only read/write files within its working directory (wd). See the current
# documentation for details:
#
# https://code.claude.com/docs/en/sandboxing
# https://code.claude.com/docs/en/permissions
#
# Sandboxing only applies to the Bash tool. We only apply restrictions to
# the filesystem. We deny read/write to both ~/ (home directory) and the
# repo root. We then allow read/write specifically to the wd. In the sandbox
# configuration, the allow list overrides the deny list. Lastly, we must
# explicitly disable `allowUnsandboxedCommands` to prevent bypassing.
#
# To prevent read/write for other tools (e.g., Read, Write), we must use
# the permissions setting. We run claude with `--permission-mode dontAsk` so
# that it doesn't prompt and auto-denies anything outside permissions.allow.
# We manually specify all allowed commands in `settings.json`. This is a
# comprehensive and sufficient list for the required task.


def _claude_code_settings(wd: Path, repo_root: Path) -> dict:
    settings = copy.deepcopy(_CLAUDE_CODE_SETTINGS_TEMPLATE)
    wd_abs = str(wd.resolve())
    repo_abs = str(repo_root.resolve())
    fs = settings["sandbox"]["filesystem"]
    # Dynamically update filesystem permissions with repo and wd paths
    fs["denyRead"].append(repo_abs)
    fs["denyWrite"].append(repo_abs)
    fs["allowRead"].append(wd_abs)
    fs["allowWrite"].append(wd_abs)
    return settings


class EquivaProofVerifier(EquivalenceVerifier):
    def __init__(self, repo_root: Path, model: str) -> None:
        self.repo_root = repo_root
        self.model = model

    @property
    def name(self) -> str:
        return "equivaproof"

    def method_config(self) -> dict:
        return {"model": self.model}

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> EquivalenceResult:
        artifacts_dir = output_path
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        (artifacts_dir / "config.json").write_text(
            json.dumps(self.method_config(), indent=2)
        )

        wd = artifacts_dir / "wd"
        self._setup_wd(wd, a, b)

        prompt = render_agent_prompt()
        (artifacts_dir / "prompt.txt").write_text(prompt)

        jsonl_path = artifacts_dir / "claude_output.jsonl"
        print(f"  [equivaproof] monitor: tail -f {jsonl_path}")

        stream_metrics = self._run_claude(prompt, wd, jsonl_path)

        meta = self._evaluate(wd)
        meta.update(stream_metrics)

        (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))

        # Copy generated Lean outputs alongside other artifacts for inspection.
        for rel in ["A/Formulation.lean", "B/Formulation.lean", "Equivalence.lean"]:
            src = wd / rel
            if src.exists() and src.stat().st_size > 0:
                dst = artifacts_dir / Path(rel).name
                shutil.copy2(src, dst)

        return EquivalenceResult(
            is_equivalent=meta["is_equivalent"],
            method=self.name,
            artifacts_dir=artifacts_dir,
            duration_s=meta.get("duration_s"),
            cost_usd=meta.get("cost_usd"),
            metadata=meta,
        )

    def _setup_wd(self, wd: Path, a: Formulation, b: Formulation) -> None:
        wd.mkdir(parents=True, exist_ok=True)

        shutil.copy2(self.repo_root / "lean-toolchain", wd / "lean-toolchain")
        shutil.copy2(self.repo_root / "Common.lean", wd / "Common.lean")
        shutil.copy2(self.repo_root / ".mcp.json", wd / ".mcp.json")
        shutil.copy2(self.repo_root / "lake-manifest.json", wd / "lake-manifest.json")
        (wd / "lakefile.toml").write_text(_LAKEFILE)

        # Copy skills and write settings
        claude_dst = wd / ".claude"
        claude_dst.mkdir(exist_ok=True)
        skills_src = self.repo_root / ".claude" / "skills"
        if skills_src.exists():
            shutil.copytree(skills_src, claude_dst / "skills", dirs_exist_ok=True)
        settings = _claude_code_settings(wd, self.repo_root)
        (claude_dst / "settings.json").write_text(json.dumps(settings, indent=2))

        for label, form in [("A", a), ("B", b)]:
            form_dir = wd / label
            form_dir.mkdir(exist_ok=True)
            (form_dir / "formulation.md").write_text(render_formulation(form))
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
        (wd_lake / "packages").symlink_to(
            (self.repo_root / ".lake" / "packages").resolve()
        )

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
        settings_path = wd / ".claude" / "settings.json"
        cmd = [
            "claude",
            "-p",
            prompt,
            "--output-format",
            "stream-json",
            "--verbose",
            "--permission-mode",
            "dontAsk",  # auto-deny anything not in permissions.allow
            "--settings",
            str(settings_path.resolve()),
        ]
        cmd += ["--model", self.model]
        start = time.time()
        stdout_lines: list[str] = []

        # Strip ANTHROPIC_API_KEY so claude uses the Claude.ai plan (OAuth
        # session) rather than API credits, with automatic extra-usage overage.
        subprocess_env = {
            k: v for k, v in os.environ.items() if k != "ANTHROPIC_API_KEY"
        }

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
        first_line = next(
            (l.strip() for l in equiv_content.splitlines() if l.strip()), ""
        )
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
            return {
                "is_equivalent": False,
                "agent_decision": "not_equivalent",
                "agent_reason": equiv_content,
                **base,
            }

        if normalized.startswith("MCP_UNAVAILABLE"):
            return {
                "is_equivalent": False,
                "agent_decision": "mcp_unavailable",
                "agent_reason": equiv_content,
                **base,
            }

        form_a_written = base["form_a_written"]
        form_b_written = base["form_b_written"]
        proof_written = bool(equiv_content)

        compile_log_path = wd.parent / "compile_log.txt"
        with compile_log_path.open("w") as log:
            form_a_compiled = (
                _lean_compiles(wd, form_a_lean, log, "A/Formulation.lean")
                if form_a_written
                else False
            )
            form_b_compiled = (
                _lean_compiles(wd, form_b_lean, log, "B/Formulation.lean")
                if form_b_written
                else False
            )
            proof_compiled, proof_output = (
                _lean_compiles_with_output(wd, equiv_file, log, "Equivalence.lean")
                if proof_written
                else (False, "")
            )
            # MILPReformulation presence: require a 'def _ : MILPReformulation' in the file.
            milp_equiv_found = bool(
                re.search(r"\bdef\s+\w+\s*:\s*MILPReformulation\b", equiv_content)
            )
            # Lean emits "warning: 'X' uses sorry" when sorry is present.
            # Only meaningful when the file compiled and the def was found.
            sorry_free = (
                "uses `sorry`" not in proof_output
                if (proof_compiled and milp_equiv_found)
                else False
            )
            log.write(
                f"=== sorry check ===\nmilp_equiv_found: {milp_equiv_found}\n"
                f"sorry_free: {sorry_free}\n\n"
            )

        is_equivalent = (
            form_a_compiled
            and form_b_compiled
            and proof_compiled
            and milp_equiv_found
            and sorry_free
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


def _lean_compiles_with_output(
    cwd: Path, lean_file: Path, log, label: str
) -> tuple[bool, str]:
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
            s = (
                e.stdout.decode(errors="replace")
                if isinstance(e.stdout, bytes)
                else e.stdout
            )
            log.write(f"--- partial stdout ---\n{s}\n")
            partial += s
        if e.stderr:
            s = (
                e.stderr.decode(errors="replace")
                if isinstance(e.stderr, bytes)
                else e.stderr
            )
            log.write(f"--- partial stderr ---\n{s}\n")
            partial += s
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
