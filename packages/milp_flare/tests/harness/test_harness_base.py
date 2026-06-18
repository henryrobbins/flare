"""Unit tests for `milp_flare.harness.base` — compute-independent logic.

`test_docker.py` spins up real containers and is otherwise the only thing
exercising the harness layer. This module covers `Harness.run`'s
post-processing and the base `configure_wd` using a stub `Runner` that
writes a synthetic `agent_output.jsonl` instead of executing any container.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest

from milp_flare.harness.base import Harness, HarnessRunResult
from milp_flare.harness.runner import AuthSpec, Runner


class _StubRunner(Runner):
    """Runner that writes a caller-supplied `agent_output.jsonl` and returns 0.

    ``output`` is the text to drop into ``wd/agent_output.jsonl`` (``None``
    leaves the file absent, simulating an agent that produced nothing). The
    last :class:`AuthSpec` it received is recorded on ``last_auth``.
    """

    name = "stub"
    home = "/stub"

    def __init__(self, output: str | None = "x\n") -> None:
        self.output = output
        self.last_auth: AuthSpec | None = None

    @property
    def image(self) -> str:
        return "stub-image"

    def run(self, wd: Path, auth: AuthSpec, **kwargs: Any) -> float:
        self.last_auth = auth
        if self.output is not None:
            (wd / "agent_output.jsonl").write_text(self.output)
        return 0.0


class _StubHarness(Harness):
    """Minimal concrete Harness for exercising `run` without a real backend.

    ``_parse_lines`` returns ``self.parsed`` so individual tests can control
    the parsed-stream result.
    """

    name = "stub"

    #: parsed-stream result; override per-instance to drive a specific path.
    parsed: dict[str, Any] = {
        "stop_reason": "end_turn",
        "input_tokens": 1000,
        "output_tokens": 200,
        "cost_usd": 0.5,
    }

    def _agent_command(self) -> str:
        return "echo stub"

    def _parse_lines(self, lines: list[str]) -> dict[str, Any]:
        return dict(self.parsed)


# ---------------------------------------------------------------------------
# Harness.run — exercised against a stub runner
# ---------------------------------------------------------------------------


def test_run_delegates_to_runner_and_parses_stream(tmp_path: Path) -> None:
    """`run` delegates to the runner, then parses the produced JSONL."""
    wd = tmp_path / "wd"
    wd.mkdir()
    runner = _StubRunner(output="synthetic agent output\n")
    harness = _StubHarness(model="claude-opus-4-7", runner=runner)

    result = harness.run(wd)

    assert isinstance(result, HarnessRunResult)
    assert result.stop_reason == "end_turn"
    assert result.input_tokens == 1000
    assert result.output_tokens == 200
    assert result.cost_usd == 0.5
    assert result.duration_s >= 0.0
    # The runner received the harness's (default empty) auth spec.
    assert runner.last_auth == AuthSpec(env=[], home_dirs=[])


def test_run_fills_cost_from_tokens_when_unset(tmp_path: Path) -> None:
    """When the parsed stream has no `cost_usd`, it is estimated from tokens."""
    wd = tmp_path / "wd"
    wd.mkdir()
    harness = _StubHarness(model="claude-opus-4-7", runner=_StubRunner())
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
    harness = _StubHarness(model="claude-opus-4-7", runner=_StubRunner(output=None))

    result = harness.run(wd)
    assert result.stop_reason is None
    assert result.input_tokens == 0
    assert result.output_tokens == 0
    # compute_cost_usd("claude-opus-4-7", 0, 0) == 0.0
    assert result.cost_usd == 0.0


def test_run_defaults_to_docker_runner() -> None:
    """A harness constructed without a runner uses the local Docker backend."""
    from milp_flare.harness.runner import DockerRunner

    harness = _StubHarness(model="claude-opus-4-7")
    assert isinstance(harness.runner, DockerRunner)
    assert harness.get_config_dict()["compute"] == "docker"


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
