from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path

from milp_eq_tools import Formulation


@dataclass
class CheckResult:
    is_equivalent: bool
    method: str
    artifacts_dir: Path
    metadata: dict = field(default_factory=dict)


class EquivalenceVerifier(ABC):
    def __init__(self, runs_dir: Path) -> None:
        self.runs_dir = runs_dir

    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def check(self, a: Formulation, b: Formulation, pair_id: str) -> CheckResult: ...
