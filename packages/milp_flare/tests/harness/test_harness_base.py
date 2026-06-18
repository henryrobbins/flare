"""Unit tests for `milp_flare.harness.base` — compute-independent logic.

These cover the *agent* concern owned by `Harness`: delegating to its
injected `Runner`, parsing the agent stream, and estimating cost. A fake
`Runner` stands in for the compute backend so no Docker daemon or image is
involved. The Docker compute backend itself is covered by `test_runner.py`.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest

from milp_flare.harness.base import Harness, HarnessRunResult
from milp_flare.harness.runner import AuthSpec, DockerRunner, Runner, RunnerRun


class _FakeRun(RunnerRun):
    """RunnerRun stand-in recording cancels and returning a fixed duration."""

    def __init__(self, cancels: list[bool]) -> None:
        self._cancels = cancels

    def cancel(self) -> None:
        self._cancels.append(True)

    def wait(self) -> float:
        return 0.0


class _FakeRunner(Runner):
    """Runner stand-in: runs `on_launch` at start, never touches Docker."""

    name = "fake"
    home = "/home/agent"

    def __init__(self, on_launch: Any) -> None:
        self._on_launch = on_launch
        self.cancels: list[bool] = []
        self.last_auth: AuthSpec | None = None

    @property
    def image(self) -> str:
        return "fake-image:latest"

    def start(self, wd: Path, auth: AuthSpec) -> _FakeRun:
        self.last_auth = auth
        self._on_launch(wd, auth)
        return _FakeRun(self.cancels)


class _StubHarness(Harness):
    """Minimal concrete Harness for exercising `run` without a real backend."""

    name = "stub"

    #: parsed-stream result; override per-instance to drive a specific path.
    parsed: dict[str, Any] = {
        "stop_reason": "end_turn",
        "input_tokens": 1000,
        "output_tokens": 200,
        "cost_usd": 0.5,
    }

    def auth_spec(self) -> AuthSpec:
        return AuthSpec(env=["STUB"], home_dirs=[])

    def _agent_command(self) -> str:
        return "echo stub"

    def _parse_lines(self, lines: list[str]) -> dict[str, Any]:
        return dict(self.parsed)


# ---------------------------------------------------------------------------
# Harness.run / start — exercised with a fake Runner
# ---------------------------------------------------------------------------


def test_run_parses_stream(tmp_path: Path) -> None:
    """`run` delegates to the runner and parses the JSONL it leaves behind."""
    wd = tmp_path / "wd"
    wd.mkdir()

    def _launch(launch_wd: Path, auth: AuthSpec) -> None:
        (launch_wd / "agent_output.jsonl").write_text("synthetic agent output\n")

    harness = _StubHarness(model="claude-opus-4-7", runner=_FakeRunner(_launch))
    result = harness.run(wd)

    assert isinstance(result, HarnessRunResult)
    assert result.stop_reason == "end_turn"
    assert result.input_tokens == 1000
    assert result.output_tokens == 200
    assert result.cost_usd == 0.5
    assert result.duration_s >= 0.0


def test_run_fills_cost_from_tokens_when_unset(tmp_path: Path) -> None:
    """When the parsed stream has no `cost_usd`, it is estimated from tokens."""
    wd = tmp_path / "wd"
    wd.mkdir()

    def _launch(launch_wd: Path, auth: AuthSpec) -> None:
        (launch_wd / "agent_output.jsonl").write_text("x\n")

    harness = _StubHarness(model="claude-opus-4-7", runner=_FakeRunner(_launch))
    harness.parsed = {
        "stop_reason": "end_turn",
        "input_tokens": 1_000_000,
        "output_tokens": 1_000_000,
        "cost_usd": None,
    }
    result = harness.run(wd)
    # claude-opus-4-7 is priced at (5.0, 25.0) per Mtok -> 5 + 25 = 30.0
    assert result.cost_usd == pytest.approx(30.0)


def test_run_handles_missing_agent_output(tmp_path: Path) -> None:
    """A missing `agent_output.jsonl` yields zeroed defaults, not a crash."""
    wd = tmp_path / "wd"
    wd.mkdir()
    harness = _StubHarness(
        model="claude-opus-4-7", runner=_FakeRunner(lambda w, a: None)
    )
    result = harness.run(wd)
    assert result.stop_reason is None
    assert result.input_tokens == 0
    assert result.output_tokens == 0
    # compute_cost_usd("claude-opus-4-7", 0, 0) == 0.0
    assert result.cost_usd == 0.0


def test_start_passes_auth_spec_and_cancel_delegates(tmp_path: Path) -> None:
    """`start` hands the harness's auth_spec to the runner; cancel delegates."""
    wd = tmp_path / "wd"
    wd.mkdir()
    runner = _FakeRunner(lambda w, a: None)
    harness = _StubHarness(model="claude-opus-4-7", runner=runner)

    run = harness.start(wd)
    assert runner.last_auth == AuthSpec(env=["STUB"], home_dirs=[])

    run.cancel()
    assert runner.cancels == [True]


def test_defaults_to_docker_runner() -> None:
    """A harness with no explicit runner uses a DockerRunner."""
    harness = _StubHarness(model="claude-opus-4-7")
    assert isinstance(harness.runner, DockerRunner)


def test_config_dict_reports_compute_and_image() -> None:
    """get_config_dict surfaces the runner's compute name and image."""
    runner = _FakeRunner(lambda w, a: None)
    cfg = _StubHarness(model="claude-opus-4-7", runner=runner).get_config_dict()
    assert cfg["compute"] == "fake"
    assert cfg["image"] == "fake-image:latest"
    assert cfg["harness"] == "stub"


# ---------------------------------------------------------------------------
# configure_wd — base working-directory setup
# ---------------------------------------------------------------------------


def test_configure_wd_requires_existing_dir(tmp_path: Path) -> None:
    """configure_wd raises if the working directory was never created."""
    harness = _StubHarness(model="claude-opus-4-7")
    with pytest.raises(RuntimeError, match="hasn't been created"):
        harness.configure_wd(tmp_path / "missing")


def test_configure_wd_writes_agent_script(tmp_path: Path) -> None:
    """The base configure_wd writes `agent.sh` with the agent command."""
    harness = _StubHarness(model="claude-opus-4-7")
    harness.configure_wd(tmp_path)
    assert (tmp_path / "agent.sh").read_text() == harness._agent_command()
