"""Unit tests for the compute backends (runners) — no network/daemon needed.

`DockerRunner` arg construction is exercised by inspecting the assembled
`docker run` command; its `run` is exercised with `subprocess.run`
monkeypatched. `ModalRunner` network behavior is covered by `modal`-marked
tests elsewhere; here we only check its static config surface and the
registry/`make_runner` selection.
"""

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest

from milp_flare.harness.runner import (
    RUNNERS,
    AuthSpec,
    DockerRunner,
    ModalRunner,
    Runner,
    make_runner,
)
from milp_flare.harness.runner import docker as docker_module


def test_docker_cmd_includes_mount_and_image(tmp_path: Path) -> None:
    """The base command bind-mounts wd and ends with the image."""
    runner = DockerRunner()
    cmd = runner._build_docker_cmd(tmp_path, AuthSpec(env=[], home_dirs=[]))
    assert cmd[:2] == ["docker", "run"]
    assert "--rm" in cmd
    assert f"{tmp_path.resolve()}:/workspace/wd" in cmd
    assert cmd[-1] == "flare-agent:latest"


def test_docker_cmd_forwards_env_and_home_dirs(tmp_path: Path) -> None:
    """`auth.env` becomes `-e NAME`; `auth.home_dirs` becomes `-v host:HOME/dest`."""
    runner = DockerRunner()
    auth = AuthSpec(env=["TOKEN"], home_dirs=[(tmp_path / ".codex", ".codex")])
    cmd = runner._build_docker_cmd(tmp_path, auth)
    assert "-e" in cmd and "TOKEN" in cmd
    assert f"{tmp_path / '.codex'}:/home/agent/.codex" in cmd


def test_docker_cmd_labels_with_run_id(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A FLARE_RUN_ID in the env tags the container with a flare-run label."""
    monkeypatch.setenv("FLARE_RUN_ID", "run-123")
    cmd = DockerRunner()._build_docker_cmd(tmp_path, AuthSpec(env=[], home_dirs=[]))
    assert "--label" in cmd
    assert "flare-run=run-123" in cmd


def test_docker_run_writes_stderr(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """`DockerRunner.run` invokes docker and persists any stderr."""
    wd = tmp_path / "wd"
    wd.mkdir()

    def _fake_run(cmd: list[str], **kwargs: Any) -> SimpleNamespace:
        assert cmd[0] == "docker"
        return SimpleNamespace(stderr="boom\n")

    monkeypatch.setattr(docker_module.subprocess, "run", _fake_run)
    duration = DockerRunner().run(wd, AuthSpec(env=[], home_dirs=[]))
    assert duration >= 0.0
    assert (wd / "docker_stderr.txt").read_text() == "boom\n"


def test_docker_run_skips_stderr_when_empty(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """No stderr file is written when the docker subprocess produced none."""
    wd = tmp_path / "wd"
    wd.mkdir()
    monkeypatch.setattr(
        docker_module.subprocess,
        "run",
        lambda cmd, **kw: SimpleNamespace(stderr=""),
    )
    DockerRunner().run(wd, AuthSpec(env=[], home_dirs=[]))
    assert not (wd / "docker_stderr.txt").exists()


def test_docker_runner_config_surface() -> None:
    """DockerRunner advertises its name, container HOME, and image."""
    runner = DockerRunner(image="custom:tag")
    assert runner.name == "docker"
    assert runner.home == "/home/agent"
    assert runner.image == "custom:tag"


def test_modal_runner_config_surface() -> None:
    """ModalRunner advertises its name, container HOME, and image (no network)."""
    runner = ModalRunner(image="flare-agent")
    assert runner.name == "modal"
    assert runner.home == "/root"
    assert runner.image == "flare-agent"


def test_make_runner_selects_backend() -> None:
    """`make_runner` instantiates the right class and forwards config."""
    assert isinstance(make_runner("docker"), DockerRunner)
    assert isinstance(make_runner("modal", {"cpu": 8.0}), ModalRunner)
    assert make_runner("docker", {"image": "x:1"}).image == "x:1"


def test_make_runner_rejects_unknown() -> None:
    """An unknown backend name is a clear error."""
    with pytest.raises(ValueError, match="unknown compute backend"):
        make_runner("nope")


def test_registry_keys_match_names() -> None:
    """Each RUNNERS key matches its class's `name`."""
    assert {k: cls.name for k, cls in RUNNERS.items()} == {
        "docker": "docker",
        "modal": "modal",
    }


# --- _supervise: backend-agnostic tick loop -------------------------------


class _FakeRunner(Runner):
    """Minimal Runner exposing `_supervise` over an in-memory fake process."""

    name = "fake"
    home = "/root"

    @property
    def image(self) -> str:
        return "fake"

    def run(self, wd: Path, auth: AuthSpec, **kwargs: Any) -> float:  # pragma: no cover
        return 0.0


def test_supervise_streams_growing_snapshots_then_final(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """on_output fires each tick with growing content, plus a final snapshot."""
    from milp_flare.harness.runner import base as base_module

    monkeypatch.setattr(base_module.time, "sleep", lambda _s: None)

    # Process "runs" for 3 ticks; output grows by one line per read.
    ticks = {"running": 3, "lines": 0}

    def is_running() -> bool:
        if ticks["running"] > 0:
            ticks["running"] -= 1
            return True
        return False

    def read_output() -> str:
        ticks["lines"] += 1
        return "x\n" * ticks["lines"]

    snapshots: list[str] = []
    _FakeRunner()._supervise(
        is_running=is_running,
        read_output=read_output,
        terminate=lambda: None,
        on_output=snapshots.append,
        should_cancel=None,
        poll_interval=0.0,
    )

    # Snapshots are monotonically growing and a final one fires after exit:
    # 3 in-loop ticks + 1 final snapshot = 4 reads.
    assert len(snapshots) == 4
    assert all(len(b) >= len(a) for a, b in zip(snapshots, snapshots[1:], strict=False))


def test_supervise_cancel_calls_terminate_and_returns(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Flipping should_cancel true calls terminate and ends the loop promptly."""
    from milp_flare.harness.runner import base as base_module

    monkeypatch.setattr(base_module.time, "sleep", lambda _s: None)

    terminated = {"running": True, "calls": 0}

    def is_running() -> bool:
        return terminated["running"]

    def terminate() -> None:
        terminated["calls"] += 1
        terminated["running"] = False  # process exits after being killed

    _FakeRunner()._supervise(
        is_running=is_running,
        read_output=lambda: "",
        terminate=terminate,
        on_output=None,
        should_cancel=lambda: True,
        poll_interval=0.0,
    )
    assert terminated["calls"] >= 1
    assert terminated["running"] is False


def test_supervise_guards_hook_exceptions(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A throwing on_output / should_cancel never aborts the run."""
    from milp_flare.harness.runner import base as base_module

    monkeypatch.setattr(base_module.time, "sleep", lambda _s: None)

    ticks = {"n": 2}

    def is_running() -> bool:
        if ticks["n"] > 0:
            ticks["n"] -= 1
            return True
        return False

    def boom_output(_s: str) -> None:
        raise RuntimeError("sink failed")

    def boom_cancel() -> bool:
        raise RuntimeError("cancel failed")

    # Should complete without propagating either exception.
    _FakeRunner()._supervise(
        is_running=is_running,
        read_output=lambda: "data",
        terminate=lambda: None,
        on_output=boom_output,
        should_cancel=boom_cancel,
        poll_interval=0.0,
    )


# --- DockerRunner supervised path -----------------------------------------


def test_docker_run_supervised_streams_and_returns(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """With a hook, DockerRunner uses Popen + _supervise and streams the file."""
    wd = tmp_path / "wd"
    wd.mkdir()
    jsonl = wd / "agent_output.jsonl"
    jsonl.write_text("line1\n")

    class _FakePopen:
        def __init__(self, *args: Any, **kwargs: Any) -> None:
            self._polls = 0

        def poll(self) -> int | None:
            # Append more output, then exit on the 3rd poll.
            self._polls += 1
            jsonl.write_text("line1\nline2\n" * self._polls)
            return None if self._polls < 3 else 0

        def wait(self) -> int:
            return 0

    monkeypatch.setattr(docker_module.subprocess, "Popen", _FakePopen)
    monkeypatch.setattr(docker_module.time, "sleep", lambda _s: None)

    snapshots: list[str] = []
    duration = DockerRunner().run(
        wd,
        AuthSpec(env=[], home_dirs=[]),
        on_output=snapshots.append,
        poll_interval=0.0,
    )
    assert duration >= 0.0
    assert snapshots  # at least one live snapshot fired
    assert "line2" in snapshots[-1]


def test_docker_cmd_includes_unique_name(tmp_path: Path) -> None:
    """A supplied name becomes a unique `--name` for per-run cancel."""
    cmd = DockerRunner()._build_docker_cmd(
        tmp_path, AuthSpec(env=[], home_dirs=[]), name="flare-abc123"
    )
    assert "--name" in cmd
    assert "flare-abc123" in cmd


# --- ModalRunner supervision primitives (no network) ----------------------


def test_modal_read_remote_output_returns_contents() -> None:
    """`_read_remote_output` reads the remote file via the filesystem API."""
    sb = SimpleNamespace(filesystem=SimpleNamespace(read_text=lambda path: "snap\n"))
    assert ModalRunner()._read_remote_output(sb) == "snap\n"


def test_modal_read_remote_output_missing_file_is_empty() -> None:
    """A not-yet-created output file yields an empty snapshot, not an error."""

    def _read_text(path: str) -> str:
        raise FileNotFoundError(path)

    sb = SimpleNamespace(filesystem=SimpleNamespace(read_text=_read_text))
    assert ModalRunner()._read_remote_output(sb) == ""


def test_modal_kill_agent_pkills_run_agent() -> None:
    """`_kill_agent` issues a pkill against run-agent and waits on it."""
    calls: list[tuple[str, ...]] = []

    class _Proc:
        def wait(self) -> int:
            return 0

    def _exec(*args: str, **kwargs: Any) -> _Proc:
        calls.append(args)
        return _Proc()

    sb = SimpleNamespace(exec=_exec)
    ModalRunner()._kill_agent(sb)
    assert calls == [("pkill", "-TERM", "-f", "run-agent")]
