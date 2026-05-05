from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path

from milp_eq_tools import Formulation


@dataclass
class ReformulationResult:
    is_reformulation: bool
    method: str
    artifacts_dir: Path
    duration_s: float | None = None
    cost_usd: float | None = None
    metadata: dict = field(default_factory=dict)


class ReformulationVerifier(ABC):
    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def method_config(self) -> dict: ...

    @abstractmethod
    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult: ...
