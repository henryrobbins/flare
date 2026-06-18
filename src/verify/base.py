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
    """Handle for a single in-flight verification.

    A :meth:`ReformulationVerifier.start` call returns one of these immediately,
    giving the caller a 1-1 handle on that run: :meth:`cancel` stops it (and
    tears down any compute it owns), and :meth:`result` blocks until it finishes
    and returns the :class:`ReformulationResult`. ``cancel`` is safe to call from
    another thread while ``result`` is blocking, and is idempotent.
    """

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

        Returns promptly with a :class:`ReformulationRun` the caller can cancel
        or await. This is the primitive every verifier implements; :meth:`verify`
        is the blocking convenience built on top of it.
        """
        ...

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        """Blocking convenience: start the run and wait for its result."""
        return self.start(a, b, output_path).result()


class _SyncRun(ReformulationRun):
    """A non-cancellable run whose result is computed lazily on :meth:`result`.

    Used by :class:`SynchronousVerifier` to wrap a single blocking call in the
    :class:`ReformulationRun` protocol; there is no in-flight compute to stop, so
    :meth:`cancel` is a no-op.
    """

    def __init__(self, compute: Callable[[], ReformulationResult]) -> None:
        self._compute = compute

    def cancel(self) -> None:
        pass

    def result(self) -> ReformulationResult:
        return self._compute()


class SynchronousVerifier(ReformulationVerifier):
    """Base for verifiers whose work is a single, non-cancellable blocking call.

    Subclasses implement :meth:`_verify` (the old ``verify`` body); they inherit
    a :meth:`start` that wraps it in a :class:`_SyncRun` so they satisfy the
    handle-based interface without owning any cancellable compute.
    """

    @abstractmethod
    def _verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult: ...

    def start(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationRun:
        return _SyncRun(lambda: self._verify(a, b, output_path))
