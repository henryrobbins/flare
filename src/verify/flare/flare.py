import dataclasses
import json
import re
import shutil
from pathlib import Path
from typing import Any

from formulation_bench import Formulation

from src.prompts import render_formulation
from src.verify.base import ReformulationResult, ReformulationVerifier
from src.verify.flare.harness import Harness
from src.verify.flare.prompts import render_agent_prompt


class FLAREVerifier(ReformulationVerifier):
    def __init__(self, repo_root: Path, harness: Harness) -> None:
        self.repo_root = repo_root
        self.harness = harness

    @property
    def name(self) -> str:
        return "flare"

    def method_config(self) -> dict[str, Any]:
        return self.harness.method_config()

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        # Create the artifacts directory at the output path and write config
        artifacts_dir = output_path
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        (artifacts_dir / "config.json").write_text(
            json.dumps(self.method_config(), indent=2)
        )

        # Setup the agent's working directory
        wd = artifacts_dir / "wd"
        self._setup_wd(wd, a, b)

        # Run the agent harness
        run_result = self.harness.run(wd)

        # Evaluate the agent's output to obtain final result and write metadata
        meta = self._evaluate(wd)
        meta.update(dataclasses.asdict(run_result))
        (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))

        return ReformulationResult(
            is_reformulation=meta["is_reformulation"],
            method=self.name,
            artifacts_dir=artifacts_dir,
            duration_s=meta.get("duration_s"),
            cost_usd=meta.get("cost_usd"),
            metadata=meta,
        )

    def _setup_wd(self, wd: Path, a: Formulation, b: Formulation) -> None:
        """Populate the agent working directory with all necessary files."""

        wd.mkdir(parents=True, exist_ok=True)

        # Setup Lean environment configuration
        self._setup_lake(wd)

        # Populate problem files for Formulation A and B
        for label, form in [("A", a), ("B", b)]:
            form_dir = wd / label
            form_dir.mkdir(exist_ok=True)
            (form_dir / "formulation.md").write_text(render_formulation(form))
            (form_dir / "solve.py").write_text(form.gurobipy_code)
            (form_dir / "Formulation.lean").write_text("")

        # Create empty Reformulation.lean
        (wd / "Reformulation.lean").write_text("")

        # Write the agent prompt
        # For Docker harnesses, this allows agent scripts to access the prompt
        # in the container (see src/verify/flare/harness/agent_commands/*.sh).
        (wd / "prompt.txt").write_text(render_agent_prompt())

        # Do any harness-specific configuration (e.g., agent.sh, MCP config, skills).
        self.harness.configure_wd(wd, self.repo_root)

    def _setup_lake(self, wd: Path) -> None:
        """Setup minimal Lake environment so the agent can compile Lean files."""
        shutil.copy2(self.repo_root / "docker" / "lakefile.toml", wd / "lakefile.toml")
        shutil.copy2(self.repo_root / "lean-toolchain", wd / "lean-toolchain")
        shutil.copy2(self.repo_root / "lake-manifest.json", wd / "lake-manifest.json")
        shutil.copy2(self.repo_root / "Common.lean", wd / "Common.lean")

    def _evaluate(self, wd: Path) -> dict[str, Any]:
        """Evaluate the agent's output to determine if the reformulation is correct."""

        # Expected agent output files
        form_a_lean = wd / "A" / "Formulation.lean"
        form_b_lean = wd / "B" / "Formulation.lean"
        reform_file = wd / "Reformulation.lean"

        # Check if the agent wrote the expected files
        form_a_written = form_a_lean.exists() and form_a_lean.stat().st_size > 0
        form_b_written = form_b_lean.exists() and form_b_lean.stat().st_size > 0
        reform_content = reform_file.read_text().strip() if reform_file.exists() else ""
        proof_written = bool(reform_content)

        # Check for agent self-reported non-reformulation decisions
        decision = self._check_agent_decision(reform_content)
        if decision is not None:
            return {
                "is_reformulation": False,
                "agent_decision": decision,
                "agent_reason": reform_content,
                "form_a_written": form_a_written,
                "form_b_written": form_b_written,
                "form_a_compiled": None,
                "form_b_compiled": None,
                "proof_compiled": None,
                "milp_reform_found": None,
                "sorry_free": None,
            }

        # Load the agent's compile results and log
        result_path = wd / "result.json"
        compile_log_path = wd / "compile_log.txt"
        entry_result: dict[str, Any] = {}
        if result_path.exists():
            try:
                entry_result = json.loads(result_path.read_text())
            except json.JSONDecodeError:
                entry_result = {}
        compile_log = compile_log_path.read_text() if compile_log_path.exists() else ""

        # Generate compilation status for each file
        form_a_compiled = (
            form_a_written and entry_result.get("form_a_compile_exit") == 0
        )
        form_b_compiled = (
            form_b_written and entry_result.get("form_b_compile_exit") == 0
        )
        proof_compiled = proof_written and entry_result.get("compile_exit") == 0

        # Check if Reformulation.lean contains a MILPReformulation def
        milp_reform_found = bool(
            re.search(r"\bdef\s+\w+\s*:\s*MILPReformulation\b", reform_content)
        )

        # Check if `sorry` is used in the reformulation proof
        sorry_free = (
            "uses `sorry`" not in compile_log
            if (proof_compiled and milp_reform_found)
            else False
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

    def _check_agent_decision(self, reform_content: str) -> str | None:
        """Check for agent self-reported non-reformulation decisions"""
        first_line = next(
            (line.strip() for line in reform_content.splitlines() if line.strip()),
            "",
        )
        normalized = re.sub(r"^-+\s*", "", first_line).upper()
        if normalized.startswith("NOT REFORMULATION"):
            return "not_reformulation"
        if normalized.startswith("MCP_UNAVAILABLE"):
            return "mcp_unavailable"
        return None
