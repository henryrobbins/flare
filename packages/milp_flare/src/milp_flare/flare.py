import dataclasses
import json
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from milp_flare._assets import LEAN_DIR
from milp_flare._prompts import render_flare_agent_prompt
from milp_flare.harness import Harness

#: Axioms permitted in a verified reformulation proof. All of Mathlib is built on
#: these three; a proof depending on anything else is not trusted by FLARE.
STANDARD_AXIOMS = frozenset({"propext", "Classical.choice", "Quot.sound"})


@dataclass(frozen=True)
class FormulationInput:
    """Formulation input for the FLARE agent.

    Attributes
    ----------
    formulation_md : str
        Markdown description of the formulation. Typically produced by
        ``Formulation.render_markdown()`` from :fb:`/api/formulation.html`.
    solve_py : str
        Python solver script with Gurobi implementation of the formulation.
        :class:`FLARE` does not execute this script; it is only used as an additional
        reference for the agent. Typically produced by ``Formulation.gen_solve_py()``
        from :fb:`/api/formulation.html`.

    Examples
    --------

    Construct a ``FormulationInput`` from formulation ``p1.a`` from
    :fb:`/problems/p1.html`::

        >>> from formulation_bench import Dataset
        >>> from milp_flare import FormulationInput
        >>> ds = Dataset.load()
        >>> a = ds.problems[1].formulations["a"]
        >>> inp = FormulationInput(a.render_markdown(), a.gen_solve_py())

        >>> print(inp.formulation_md)
        # Amusement Park Ticket Machines
        <BLANKLINE>
        ## Problem Description
        <BLANKLINE>
        An amusement park is installing cash-based machines and card-only machines...

        >>> print(inp.solve_py)
        import json
        from gurobipy import Model, GRB
        import argparse
        <BLANKLINE>
        <BLANKLINE>
        def main(params_path: str, solution_path: str) -> None:
        ...
    """

    formulation_md: str
    solve_py: str


@dataclass
class FLAREResult:
    """Result from FLARE.

    Attributes
    ----------
    is_reformulation : bool
        Final verdict. True if all sub-checks pass: both ``Formulation.lean``
        files compile, ``Reformulation.lean`` compiles and contains a
        ``def : MILPReformulation``, and the proof is ``sorry``-free using
        only the :data:`STANDARD_AXIOMS`.
    duration_s : float, optional
        Wall-clock duration of the agent run, in seconds.
    cost_usd : float, optional
        Estimated USD cost of the agent run. ``None`` when the harness
        does not report cost.
    metadata : dict[str, Any]
        Per-check breakdown and harness run metadata: ``form_a_written``,
        ``form_a_compiled``, ``form_b_written``, ``form_b_compiled``,
        ``proof_compiled``, ``milp_reform_found``, ``sorry_free``,
        ``no_new_axioms``, ``axioms``, ``agent_decision``, and token counts.
    """

    is_reformulation: bool
    duration_s: float | None = None
    cost_usd: float | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


class FLARE:
    """Agentic MILP reformulation verifier.

    FLARE (Formulation-Level Automated Reformulation Evaluation) uses an LLM-based
    agent and the Lean proof assistant to verify MILP reformulations according to
    the :fb:`/definitions.html` definition of reformulation. See the
    :paper:`/` for more details.

    Parameters
    ----------
    harness : Harness
        The agent harness to use for auto-formalization and proof synthesis.
        See :ref:`agent-harnesses` for the available harnesses.

    Attributes
    ----------
    harness : Harness
        The configured agent harness.

    Examples
    --------

    Use FLARE to verify if formulation ``b`` of problem ``p1`` from
    :fb:`/problems/p1.html` is a reformulation of formulation ``a`` (also see
    :doc:`/user_guide/run_flare`):

    .. code-block:: python

        from pathlib import Path
        from formulation_bench import Dataset
        from milp_flare import FLARE, FormulationInput
        from milp_flare.harness import ClaudeCodeHarness

        ds = Dataset.load()
        a = ds.problems[1].formulations["a"]
        b = ds.problems[1].formulations["b"]

        harness = ClaudeCodeHarness(model="claude-opus-4-7")
        flare = FLARE(harness=harness)
        result = flare.verify(
            FormulationInput(a.render_markdown(), a.gen_solve_py()),
            FormulationInput(b.render_markdown(), b.gen_solve_py()),
            output_path=Path("runs/p1_a_b"),
        )
    """

    def __init__(self, harness: Harness) -> None:
        self.harness = harness

    def get_config_dict(self) -> dict[str, Any]:
        """Return a dictionary with the FLARE configuration.

        Returns
        -------
        config : dict[str, Any]
            Harness, image, model, and reasoning configuration. Forwarded
            directly from :meth:`Harness.get_config_dict`.
        """
        return self.harness.get_config_dict()

    def verify(
        self,
        a: FormulationInput,
        b: FormulationInput,
        output_path: Path,
    ) -> FLAREResult:
        """Run FLARE on a pair of MILP formulations.

        Run FLARE to determine if formulation ``b`` is a reformulation of
        formulation ``a`` according to the :fb:`/definitions.html`
        definition of reformulation. This method creates the agent working
        directory (see below), triggers the agent, and evaluates the
        agent output. Finally, it populates ``output_path`` with:

        - The agent working directory (``wd/``)
        - The FLARE configuration (``config.json``)
        - The result dictionary (``result.json``)

        The agent working directory contains descriptions of each formulation,
        the agent prompt ``prompt.txt`` (see :doc:`/prompts`), and the necessary
        Lake environment files.

        .. code-block::

            wd/
            ├── A/
            │   ├── formulation.md
            │   ├── solve.py
            │   └── Formulation.lean   # written by agent
            ├── B/
            │   ├── formulation.md
            │   ├── solve.py
            │   └── Formulation.lean   # written by agent
            ├── Reformulation.lean     # written by agent
            ├── prompt.txt
            ├── Common.lean
            ├── lake-manifest.json
            ├── lakefile.toml
            └── lean-toolchain

        Parameters
        ----------
        a : FormulationInput
            Inputs for formulation A.
        b : FormulationInput
            Inputs for formulation B (the candidate reformulation of A).
        output_path : pathlib.Path
            Directory to populate with run artifacts.

        Returns
        -------
        result : FLAREResult
            The verdict, duration, cost, and per-check metadata.

        Examples
        --------

        Run FLARE on formulations ``a`` and ``b`` and inspect the result:

        .. code-block:: python

            flare = FLARE(harness=harness)
            result = flare.verify(a, b, output_path=Path("runs/a_b"))
            result.is_reformulation
            True
            result.metadata["form_a_written"]
            True
            result.cost_usd
            1.49
            result.duration_s
            322

        See :doc:`/user_guide/run_flare` for more example usage.
        """
        # Create the artifacts directory at the output path and write config
        artifacts_dir = output_path
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        (artifacts_dir / "config.json").write_text(
            json.dumps(self.get_config_dict(), indent=2)
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
        (wd / "prompt.txt").write_text(render_flare_agent_prompt())

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
                "no_new_axioms": None,
                "axioms": None,
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

        # Check the reformulation proof's axiom dependencies
        no_new_axioms, axioms = self._check_axioms(compile_log)
        no_new_axioms = (
            no_new_axioms if (proof_compiled and milp_reform_found) else False
        )

        is_reformulation = (
            form_a_compiled
            and form_b_compiled
            and proof_compiled
            and milp_reform_found
            and sorry_free
            and no_new_axioms
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
            "no_new_axioms": no_new_axioms,
            "axioms": axioms,
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

    def _check_axioms(self, compile_log: str) -> tuple[bool, list[str]]:
        """Parse ``#print axioms`` output and check it against the allowlist."""
        match = re.search(r"depends on axioms: \[([^\]]*)\]", compile_log)
        if match is None:
            if "does not depend on any axioms" in compile_log:
                return True, []
            return False, []
        axioms = [a.strip() for a in match.group(1).split(",") if a.strip()]
        no_new_axioms = all(a in STANDARD_AXIOMS for a in axioms)
        return no_new_axioms, axioms
