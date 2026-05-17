import dataclasses
import json
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from milp_flare.assets import LEAN_DIR
from milp_flare.harness import Harness
from milp_flare.prompts import render_agent_prompt


@dataclass(frozen=True)
class FormulationInput:
    """Per-formulation inputs handed to the FLARE agent.

    ``formulation_md`` is written to ``<label>/formulation.md`` and
    ``solve_py`` to ``<label>/solve.py`` inside the agent working
    directory.
    """

    formulation_md: str
    solve_py: str


@dataclass
class FLAREResult:
    is_reformulation: bool
    duration_s: float | None = None
    cost_usd: float | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


class FLARE:
    def __init__(self, harness: Harness) -> None:
        self.harness = harness

    @property
    def name(self) -> str:
        return "flare"

    def method_config(self) -> dict[str, Any]:
        return self.harness.method_config()

    def verify(
        self,
        a: FormulationInput,
        b: FormulationInput,
        output_path: Path,
    ) -> FLAREResult:
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

        return FLAREResult(
            is_reformulation=meta["is_reformulation"],
            duration_s=meta.get("duration_s"),
            cost_usd=meta.get("cost_usd"),
            metadata=meta,
        )

    def _setup_wd(
        self,
        wd: Path,
        a: FormulationInput,
        b: FormulationInput,
    ) -> None:
        """Populate the agent working directory with all necessary files."""

        wd.mkdir(parents=True, exist_ok=True)

        # Setup Lean environment configuration
        self._setup_lake(wd)

        # Populate problem files for Formulation A and B
        for label, inp in [("A", a), ("B", b)]:
            form_dir = wd / label
            form_dir.mkdir(exist_ok=True)
            (form_dir / "formulation.md").write_text(inp.formulation_md)
            (form_dir / "solve.py").write_text(inp.solve_py)
            (form_dir / "Formulation.lean").write_text("")

        # Create empty Reformulation.lean
        (wd / "Reformulation.lean").write_text("")

        # Write the agent prompt
        # For Docker harnesses, this allows agent scripts to access the prompt
        # in the container (see milp_flare/assets/scripts/*.sh).
        (wd / "prompt.txt").write_text(render_agent_prompt())

        # Do any harness-specific configuration (e.g., agent.sh, MCP config, skills).
        self.harness.configure_wd(wd)

    def _setup_lake(self, wd: Path) -> None:
        """Setup minimal Lake environment so the agent can compile Lean files."""
        for src in LEAN_DIR.iterdir():
            shutil.copy2(src, wd / src.name)

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
