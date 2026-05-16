from pathlib import Path
from typing import Any

from formulation_bench import Formulation
from milp_flare import FLAREVerifier as _FLAREVerifier
from milp_flare import Harness

from src.prompts import render_formulation
from src.verify.base import ReformulationResult, ReformulationVerifier


class FLAREVerifier(ReformulationVerifier):
    """Adapter exposing the milp_flare verifier as a ReformulationVerifier."""

    def __init__(self, harness: Harness) -> None:
        self._inner = _FLAREVerifier(harness=harness)

    @property
    def name(self) -> str:
        return self._inner.name

    def method_config(self) -> dict[str, Any]:
        return self._inner.method_config()

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        formulation_md = {"A": render_formulation(a), "B": render_formulation(b)}
        r = self._inner.verify(a, b, formulation_md, output_path)
        return ReformulationResult(
            is_reformulation=r.is_reformulation,
            method=r.method,
            artifacts_dir=r.artifacts_dir,
            duration_s=r.duration_s,
            cost_usd=r.cost_usd,
            metadata=r.metadata,
        )
