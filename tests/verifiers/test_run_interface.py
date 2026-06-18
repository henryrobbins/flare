"""Unit tests for the run-handle interface in `src.verify.base`.

Covers the `start()` primitive, the `verify()` convenience built on it, and the
`SynchronousVerifier` helper that wraps a blocking `_verify` in a non-cancellable
`_SyncRun`.
"""

from __future__ import annotations

from pathlib import Path

from formulation_bench import Formulation

from src.verify.base import (
    ReformulationResult,
    ReformulationRun,
    ReformulationVerifier,
    SynchronousVerifier,
)


def _result(name: str) -> ReformulationResult:
    return ReformulationResult(
        is_reformulation=True, method=name, artifacts_dir=Path(".")
    )


class _RecordingRun(ReformulationRun):
    def __init__(self, name: str, log: list[str]) -> None:
        self._name = name
        self._log = log

    def cancel(self) -> None:
        self._log.append("cancel")

    def result(self) -> ReformulationResult:
        self._log.append("result")
        return _result(self._name)


class _HandleVerifier(ReformulationVerifier):
    def __init__(self) -> None:
        self.log: list[str] = []

    @property
    def name(self) -> str:
        return "handle"

    def get_config_dict(self) -> dict:
        return {}

    def start(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationRun:
        self.log.append("start")
        return _RecordingRun(self.name, self.log)


class _SyncStub(SynchronousVerifier):
    def __init__(self) -> None:
        self.calls = 0

    @property
    def name(self) -> str:
        return "sync"

    def get_config_dict(self) -> dict:
        return {}

    def _verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        self.calls += 1
        return _result(self.name)


def test_verify_delegates_to_start_then_result() -> None:
    """The default verify() starts a run and awaits it (in that order)."""
    v = _HandleVerifier()
    result = v.verify(None, None, Path("."))  # type: ignore[arg-type]
    assert result.method == "handle"
    assert v.log == ["start", "result"]


def test_synchronous_verifier_is_lazy_and_noncancellable() -> None:
    """SynchronousVerifier.start() defers _verify to result(); cancel is a no-op."""
    v = _SyncStub()
    run = v.start(None, None, Path("."))  # type: ignore[arg-type]
    assert v.calls == 0  # nothing computed until result()
    run.cancel()  # no-op, must not raise or trigger work
    assert v.calls == 0
    result = run.result()
    assert v.calls == 1
    assert result.method == "sync"


def test_synchronous_verifier_verify_runs_once() -> None:
    """The inherited verify() convenience runs _verify exactly once."""
    v = _SyncStub()
    v.verify(None, None, Path("."))  # type: ignore[arg-type]
    assert v.calls == 1
