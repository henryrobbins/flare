from pathlib import Path
from typing import Any

from formulation_bench import Formulation
from milp_flare import FLARE, FormulationInput, Harness
from milp_flare.flare import FLARERun

from src.verify.base import (
    ReformulationResult,
    ReformulationRun,
    ReformulationVerifier,
)


class FLAREVerifierRun(ReformulationRun):
    """In-flight FLARE run, cancellable from another thread.

    A thin adapter over :class:`milp_flare.flare.FLARERun`. The underlying run
    has already started (the agent is live) by the time this handle exists, so
    :meth:`cancel` simply forwards to the live :class:`~milp_flare.AgentRun`
    (``docker kill`` / ``pkill`` inside the Sandbox) with no flag, lock, or
    callback: the cancel-before-start race is gone because provisioning happens
    in :meth:`FLAREVerifier.start`, not in :meth:`result`. A canceled run keeps
    its partial output on either backend.
    """

    def __init__(self, run: FLARERun, output_path: Path, name: str) -> None:
        self._run = run
        self._output_path = output_path
        self._name = name

    def cancel(self) -> None:
        self._run.cancel()

    def result(self) -> ReformulationResult:
        r = self._run.result()
        return ReformulationResult(
            is_reformulation=r.is_reformulation,
            method=self._name,
            artifacts_dir=self._output_path,
            duration_s=r.duration_s,
            cost_usd=r.cost_usd,
            metadata=r.metadata,
        )


class FLAREVerifier(ReformulationVerifier):
    """Adapts `milp_flare.FLARE` to `ReformulationVerifier` API."""

    def __init__(self, harness: Harness) -> None:
        self._inner = FLARE(harness=harness)

    @property
    def name(self) -> str:
        return "flare"

    def get_config_dict(self) -> dict[str, Any]:
        return self._inner.get_config_dict()

    def start(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> FLAREVerifierRun:
        a_in = FormulationInput(
            formulation_md=a.render_markdown(), solve_py=a.gen_solve_py()
        )
        b_in = FormulationInput(
            formulation_md=b.render_markdown(), solve_py=b.gen_solve_py()
        )
        run = self._inner.start(a_in, b_in, output_path)
        return FLAREVerifierRun(run, output_path, self.name)
