"""Unit tests for `milp_flare.harness.base` — Docker-independent logic.

`test_docker.py` spins up real containers and is otherwise the only thing
exercising the harness layer. This module covers `Harness.start`/`run`'s
post-processing and the base `configure_wd`, with `subprocess.Popen`
monkeypatched so no Docker daemon or image is involved.
"""

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from typing import IO, Any

import pytest

from milp_flare.harness import base as harness_base
from milp_flare.harness.base import Harness, HarnessRunResult


def _fake_popen_factory(on_launch: Any) -> Any:
    """Build a `subprocess.Popen` stand-in.

    `on_launch(cmd, stderr_file)` runs at launch time to simulate the container
    (write `agent_output.jsonl`, emit stderr). The returned object exposes the
    minimal `wait()` the run handle needs.
    """

    def _popen(
        cmd: list[str],
        stdout: Any = None,
        stderr: IO[bytes] | None = None,
        **kwargs: Any,
    ) -> SimpleNamespace:
        on_launch(cmd, stderr)
        return SimpleNamespace(wait=lambda: 0)

    return _popen


class _StubHarness(Harness):
    """Minimal concrete Harness for exercising `run` without Docker.

    ``_parse_lines`` returns ``self.parsed`` so individual tests can control
    the parsed-stream result; the abstract Docker hooks return trivial values
    since ``subprocess.run`` is monkeypatched away.
    """

    name = "stub"

    #: parsed-stream result; override per-instance to drive a specific path.
    parsed: dict[str, Any] = {
        "stop_reason": "end_turn",
        "input_tokens": 1000,
        "output_tokens": 200,
        "cost_usd": 0.5,
    }

    def _agent_docker_args(self) -> list[str]:
        return ["-e", "STUB"]

    def _agent_command(self) -> str:
        return "echo stub"

    def _parse_lines(self, lines: list[str]) -> dict[str, Any]:
        return dict(self.parsed)


# ---------------------------------------------------------------------------
# Harness.run — exercised without Docker
# ---------------------------------------------------------------------------


def test_run_parses_stream_and_writes_stderr(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """`run` builds a `docker` command, parses the JSONL, and saves stderr."""
    wd = tmp_path / "wd"
    wd.mkdir()
    harness = _StubHarness(model="claude-opus-4-7")

    def _launch(cmd: list[str], stderr: IO[bytes] | None) -> None:
        assert cmd[0] == "docker"
        (wd / "agent_output.jsonl").write_text("synthetic agent output\n")
        assert stderr is not None
        stderr.write(b"boom\n")

    monkeypatch.setattr(harness_base.subprocess, "Popen", _fake_popen_factory(_launch))

    result = harness.run(wd)

    assert isinstance(result, HarnessRunResult)
    assert result.stop_reason == "end_turn"
    assert result.input_tokens == 1000
    assert result.output_tokens == 200
    assert result.cost_usd == 0.5
    assert result.duration_s >= 0.0
    # stderr is persisted next to the agent output, namespaced by harness name
    assert (wd / "stub_stderr.txt").read_text() == "boom\n"


def test_run_skips_stderr_file_when_empty(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """No stderr file is written when the subprocess produced no stderr."""
    wd = tmp_path / "wd"
    wd.mkdir()
    harness = _StubHarness(model="claude-opus-4-7")

    def _launch(cmd: list[str], stderr: IO[bytes] | None) -> None:
        (wd / "agent_output.jsonl").write_text("x\n")

    monkeypatch.setattr(harness_base.subprocess, "Popen", _fake_popen_factory(_launch))
    harness.run(wd)
    assert not (wd / "stub_stderr.txt").exists()


def test_run_fills_cost_from_tokens_when_unset(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """When the parsed stream has no `cost_usd`, it is estimated from tokens."""
    wd = tmp_path / "wd"
    wd.mkdir()
    harness = _StubHarness(model="claude-opus-4-7")
    harness.parsed = {
        "stop_reason": "end_turn",
        "input_tokens": 1_000_000,
        "output_tokens": 1_000_000,
        "cost_usd": None,
    }

    def _launch(cmd: list[str], stderr: IO[bytes] | None) -> None:
        (wd / "agent_output.jsonl").write_text("x\n")

    monkeypatch.setattr(harness_base.subprocess, "Popen", _fake_popen_factory(_launch))
    result = harness.run(wd)
    # claude-opus-4-7 is priced at (5.0, 25.0) per Mtok -> 5 + 25 = 30.0
    assert result.cost_usd == pytest.approx(30.0)


def test_run_handles_missing_agent_output(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A missing `agent_output.jsonl` yields zeroed defaults, not a crash."""
    wd = tmp_path / "wd"
    wd.mkdir()
    harness = _StubHarness(model="claude-opus-4-7")

    def _launch(cmd: list[str], stderr: IO[bytes] | None) -> None:
        # The agent produced no output file at all.
        return

    monkeypatch.setattr(harness_base.subprocess, "Popen", _fake_popen_factory(_launch))
    result = harness.run(wd)
    assert result.stop_reason is None
    assert result.input_tokens == 0
    assert result.output_tokens == 0
    # compute_cost_usd("claude-opus-4-7", 0, 0) == 0.0
    assert result.cost_usd == 0.0


def test_start_assigns_unique_name_and_cancel_kills_it(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """`start` names the container uniquely; `cancel` docker-kills that name."""
    wd = tmp_path / "wd"
    wd.mkdir()
    harness = _StubHarness(model="claude-opus-4-7")

    captured: dict[str, list[str]] = {}

    def _launch(cmd: list[str], stderr: IO[bytes] | None) -> None:
        captured["cmd"] = cmd
        (wd / "agent_output.jsonl").write_text("x\n")

    monkeypatch.setattr(harness_base.subprocess, "Popen", _fake_popen_factory(_launch))

    kills: list[list[str]] = []

    def _fake_kill(cmd: list[str], **kwargs: Any) -> SimpleNamespace:
        kills.append(cmd)
        return SimpleNamespace()

    monkeypatch.setattr(harness_base.subprocess, "run", _fake_kill)

    run = harness.start(wd)

    assert "--name" in captured["cmd"]
    name = captured["cmd"][captured["cmd"].index("--name") + 1]
    assert name.startswith("flare-")

    run.cancel()
    assert kills == [["docker", "kill", name]]

    # result() still completes after a cancel (the kill makes the proc exit).
    assert isinstance(run.result(), HarnessRunResult)


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
