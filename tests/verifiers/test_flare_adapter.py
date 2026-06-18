"""Unit tests for the FLAREVerifier run-handle adapter (src.verify.flare).

The full FLARE pipeline is exercised in packages/milp_flare/tests; here we only
check that FLAREVerifierRun forwards cancellation to the inner milp_flare handle
and adapts FLAREResult -> ReformulationResult.
"""

from __future__ import annotations

from pathlib import Path

from milp_flare import FLAREResult

from src.verify.flare import FLAREVerifierRun


class _FakeFLARERun:
    def __init__(self) -> None:
        self.cancelled = False

    def cancel(self) -> None:
        self.cancelled = True

    def result(self) -> FLAREResult:
        return FLAREResult(
            is_reformulation=True,
            duration_s=1.5,
            cost_usd=2.0,
            metadata={"input_tokens": 5},
        )


def test_run_forwards_cancel_to_inner() -> None:
    inner = _FakeFLARERun()
    run = FLAREVerifierRun(inner, Path("/tmp/x"), "flare")  # type: ignore[arg-type]
    run.cancel()
    assert inner.cancelled is True


def test_run_adapts_result_fields() -> None:
    inner = _FakeFLARERun()
    run = FLAREVerifierRun(inner, Path("/tmp/x"), "flare")  # type: ignore[arg-type]
    r = run.result()
    assert r.is_reformulation is True
    assert r.method == "flare"
    assert r.artifacts_dir == Path("/tmp/x")
    assert r.duration_s == 1.5
    assert r.cost_usd == 2.0
    assert r.metadata["input_tokens"] == 5
