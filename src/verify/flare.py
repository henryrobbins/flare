from pathlib import Path
from typing import Any

from formulation_bench import Formulation
from milp_flare import FLARE, FLARERun, FormulationInput, Harness

from src.verify.base import (
    ReformulationResult,
    ReformulationRun,
    ReformulationVerifier,
)


class FLAREVerifierRun(ReformulationRun):
    """Run handle adapting a :class:`milp_flare.FLARERun` to the verifier API."""

    def __init__(self, inner: FLARERun, output_path: Path, name: str) -> None:
        self._inner = inner
        self._output_path = output_path
        self._name = name

    def cancel(self) -> None:
        self._inner.cancel()

    def result(self) -> ReformulationResult:
        r = self._inner.result()
        return ReformulationResult(
            is_reformulation=r.is_reformulation,
            method=self._name,
            artifacts_dir=self._output_path,
            duration_s=r.duration_s,
            cost_usd=r.cost_usd,
            metadata=r.metadata,
        )


class FLAREVerifier(ReformulationVerifier):
    """Adapter exposing the milp_flare verifier as a ReformulationVerifier."""

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
        inner = self._inner.start(a_in, b_in, output_path)
        return FLAREVerifierRun(inner, output_path, self.name)
