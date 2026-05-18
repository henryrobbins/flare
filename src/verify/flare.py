from pathlib import Path
from typing import Any

from formulation_bench import Formulation
from milp_flare import FLARE, FormulationInput, Harness

from src.verify.base import ReformulationResult, ReformulationVerifier


class FLAREVerifier(ReformulationVerifier):
    """Adapter exposing the milp_flare verifier as a ReformulationVerifier."""

    def __init__(self, harness: Harness) -> None:
        self._inner = FLARE(harness=harness)

    @property
    def name(self) -> str:
        return self._inner.name

    def method_config(self) -> dict[str, Any]:
        return self._inner.method_config()

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        a_in = FormulationInput(
            formulation_md=a.render_markdown(), solve_py=a.gurobipy_code
        )
        b_in = FormulationInput(
            formulation_md=b.render_markdown(), solve_py=b.gurobipy_code
        )
        r = self._inner.verify(a_in, b_in, output_path)
        return ReformulationResult(
            is_reformulation=r.is_reformulation,
            method=self.name,
            artifacts_dir=output_path,
            duration_s=r.duration_s,
            cost_usd=r.cost_usd,
            metadata=r.metadata,
        )
