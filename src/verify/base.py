from abc import ABC, abstractmethod
from collections.abc import Callable
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


class ReformulationRun(ABC):
    """Handle for a single in-flight verification."""

    @abstractmethod
    def cancel(self) -> None:
        """Request cancellation of this run; idempotent and thread-safe."""
        ...

    @abstractmethod
    def result(self) -> ReformulationResult:
        """Block until the run completes and return its result."""
        ...


class ReformulationVerifier(ABC):
    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def get_config_dict(self) -> dict[str, Any]: ...

    @abstractmethod
    def start(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationRun:
        """Start verifying whether ``b`` reformulates ``a`` and return a handle.

        Returns a :class:`ReformulationRun` the caller can cancel or await.
        :meth:`verify` offers blocking convenience.
        """
        ...

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        """Start the run and wait for its result."""
        return self.start(a, b, output_path).result()


class _SyncRun(ReformulationRun):
    """A non-cancellable run whose result is computed lazily on :meth:`result`."""

    def __init__(self, compute: Callable[[], ReformulationResult]) -> None:
        self._compute = compute

    def cancel(self) -> None:
        pass

    def result(self) -> ReformulationResult:
        return self._compute()


class SynchronousVerifier(ReformulationVerifier):
    """Base for verifiers whose work is a single, non-cancellable blocking call."""

    @abstractmethod
    def _verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult: ...

    def start(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationRun:
        return _SyncRun(lambda: self._verify(a, b, output_path))
