import dataclasses
import json
import re
import shutil
import subprocess
import time
from pathlib import Path

from formulation_bench import Formulation

from src.prompts import render_formulation
from src.verify.base import ReformulationResult, ReformulationVerifier
from src.verify.flare.harness import Harness
from src.verify.flare.prompts import render_agent_prompt

_HERE = Path(__file__).parent
_LAKEFILE: str = (_HERE / "lakefile.toml").read_text()


def setup_lean_project(wd: Path, repo_root: Path) -> None:
    """Provision `wd` with the FLARE Lean project skeleton.

    Drops `lean-toolchain`, `Common.lean`, `lake-manifest.json`, the FLARE
    `lakefile.toml`, and a symlinked `.lake/packages` (sharing the repo's
    pre-downloaded mathlib). Pre-builds `Common.olean` host-side so that
    `.lake/build/` exists before the sandbox starts (the sandbox forbids
    creating it but permits writes inside) and lean-lsp diagnostics on
    freshly-written files come back populated.

    Extracted from `FLAREVerifier._setup_wd` so integration tests can reuse
    the real provisioning logic.
    """
    wd.mkdir(parents=True, exist_ok=True)

    shutil.copy2(repo_root / "lean-toolchain", wd / "lean-toolchain")
    shutil.copy2(repo_root / "Common.lean", wd / "Common.lean")
    shutil.copy2(repo_root / "lake-manifest.json", wd / "lake-manifest.json")
    (wd / "lakefile.toml").write_text(_LAKEFILE)

    # Share the repo's pre-built Mathlib oleans instead of downloading a
    # fresh copy per pair. Each wd still gets its own .lake/build/ for
    # A/B/Reformulation modules, so parallel runs don't conflict.
    wd_lake = wd / ".lake"
    wd_lake.mkdir(parents=True, exist_ok=True)
    (wd_lake / "packages").symlink_to(
        (repo_root / ".lake" / "packages").resolve()
    )

    # Pre-build Common host-side. This must happen here (not later, e.g.
    # delegated to the agent) because the harness sandbox forbids *creating*
    # `.lake/build/` but permits writes *inside* it. If the directory does
    # not exist before the sandbox starts, the agent's first `lake build`
    # fails with "operation not permitted" on `.lake/build`. Pre-building
    # also means lean-lsp diagnostics on freshly-written files (which
    # `import Common`) return real results on the first call.
    subprocess.run(
        ["lake", "build", "Common"],
        cwd=wd,
        check=True,
        capture_output=True,
        text=True,
        timeout=180,
    )


class FLAREVerifier(ReformulationVerifier):
    def __init__(self, repo_root: Path, harness: Harness | None = None) -> None:
        # `harness` is optional so that callers that only need ._evaluate
        # (e.g., scripts/reeval_flare.py) can construct a verifier without
        # configuring a CLI harness.
        self.repo_root = repo_root
        self.harness = harness

    @property
    def name(self) -> str:
        return "flare"

    def method_config(self) -> dict:
        if self.harness is None:
            return {}
        return self.harness.method_config()

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        if self.harness is None:
            raise RuntimeError("FLAREVerifier.verify requires a Harness")

        artifacts_dir = output_path
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        (artifacts_dir / "config.json").write_text(
            json.dumps(self.method_config(), indent=2)
        )

        wd = artifacts_dir / "wd"
        self._setup_wd(wd, a, b)
        self.harness.configure_wd(wd, self.repo_root)

        prompt = render_agent_prompt()
        (artifacts_dir / "prompt.txt").write_text(prompt)

        jsonl_path = artifacts_dir / "agent_output.jsonl"
        print(f"  [flare] monitor: tail -f {jsonl_path}")

        run_result = self.harness.run(prompt, wd, jsonl_path)

        meta = self._evaluate(wd)
        meta.update(dataclasses.asdict(run_result))

        (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))

        # Copy generated Lean outputs alongside other artifacts for inspection.
        for rel in ["A/Formulation.lean", "B/Formulation.lean", "Reformulation.lean"]:
            src = wd / rel
            if src.exists() and src.stat().st_size > 0:
                dst = artifacts_dir / Path(rel).name
                shutil.copy2(src, dst)

        return ReformulationResult(
            is_reformulation=meta["is_reformulation"],
            method=self.name,
            artifacts_dir=artifacts_dir,
            duration_s=meta.get("duration_s"),
            cost_usd=meta.get("cost_usd"),
            metadata=meta,
        )

    def _setup_wd(self, wd: Path, a: Formulation, b: Formulation) -> None:
        setup_lean_project(wd, self.repo_root)

        for label, form in [("A", a), ("B", b)]:
            form_dir = wd / label
            form_dir.mkdir(exist_ok=True)
            (form_dir / "formulation.md").write_text(render_formulation(form))
            solve_src = form.path / "solve.py"
            if solve_src.exists():
                shutil.copy2(solve_src, form_dir / "solve.py")
            (form_dir / "Formulation.lean").write_text("")

        (wd / "Reformulation.lean").write_text("")

    def _evaluate(self, wd: Path) -> dict:
        form_a_lean = wd / "A" / "Formulation.lean"
        form_b_lean = wd / "B" / "Formulation.lean"
        reform_file = wd / "Reformulation.lean"

        reform_content = reform_file.read_text().strip() if reform_file.exists() else ""

        # Normalize the first meaningful line: strip Lean comment markers so
        # "-- NOT REFORMULATION: ..." is detected the same as "NOT REFORMULATION: ...".
        first_line = next(
            (l.strip() for l in reform_content.splitlines() if l.strip()), ""
        )
        normalized = re.sub(r"^-+\s*", "", first_line).upper()

        base = {
            "form_a_written": form_a_lean.exists() and form_a_lean.stat().st_size > 0,
            "form_b_written": form_b_lean.exists() and form_b_lean.stat().st_size > 0,
            "form_a_compiled": None,
            "form_b_compiled": None,
            "proof_compiled": None,
            "milp_reform_found": None,
            "sorry_free": None,
        }

        if normalized.startswith("NOT REFORMULATION"):
            return {
                "is_reformulation": False,
                "agent_decision": "not_reformulation",
                "agent_reason": reform_content,
                **base,
            }

        if normalized.startswith("MCP_UNAVAILABLE"):
            return {
                "is_reformulation": False,
                "agent_decision": "mcp_unavailable",
                "agent_reason": reform_content,
                **base,
            }

        form_a_written = base["form_a_written"]
        form_b_written = base["form_b_written"]
        proof_written = bool(reform_content)

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
                _lean_compiles_with_output(wd, reform_file, log, "Reformulation.lean")
                if proof_written
                else (False, "")
            )
            # MILPReformulation presence: require a 'def _ : MILPReformulation' in the file.
            milp_reform_found = bool(
                re.search(r"\bdef\s+\w+\s*:\s*MILPReformulation\b", reform_content)
            )
            # Lean emits "warning: 'X' uses sorry" when sorry is present.
            # Only meaningful when the file compiled and the def was found.
            sorry_free = (
                "uses `sorry`" not in proof_output
                if (proof_compiled and milp_reform_found)
                else False
            )
            log.write(
                f"=== sorry check ===\nmilp_reform_found: {milp_reform_found}\n"
                f"sorry_free: {sorry_free}\n\n"
            )

        is_reformulation = (
            form_a_compiled
            and form_b_compiled
            and proof_compiled
            and milp_reform_found
            and sorry_free
        )

        return {
            "is_reformulation": is_reformulation,
            "agent_decision": "reformulation" if is_reformulation else "failed",
            "form_a_written": form_a_written,
            "form_b_written": form_b_written,
            "form_a_compiled": form_a_compiled,
            "form_b_compiled": form_b_compiled,
            "proof_compiled": proof_compiled,
            "milp_reform_found": milp_reform_found,
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
