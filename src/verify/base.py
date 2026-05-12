from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from formulation_bench import Formulation


@dataclass
class ReformulationResult:
    is_reformulation: bool
    method: str
    artifacts_dir: Path
    duration_s: float | None = None
    cost_usd: float | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


class ReformulationVerifier(ABC):
    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def method_config(self) -> dict[str, Any]: ...

    @abstractmethod
    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult: ...
