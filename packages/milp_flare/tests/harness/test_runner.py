"""Unit tests for the compute backends (runners) — no network/daemon needed.

`DockerRunner` arg construction is exercised by inspecting the assembled
`docker run` command; its `run` is exercised with `subprocess.Popen`
monkeypatched. `ModalRunner` network behavior is covered by `modal`-marked
tests elsewhere; here we only check its static config surface, the
`RUNNERS` registry, and the no-network streaming/cancel primitives.
"""

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from typing import Any

from milp_flare.harness.runner import (
    RUNNERS,
    AuthSpec,
    DockerRunner,
    ModalRunner,
)
from milp_flare.harness.runner import docker as docker_module
from milp_flare.harness.runner.modal import ModalAgentRun


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


def test_docker_cmd_labels_with_run_id(tmp_path: Path, monkeypatch: Any) -> None:
    """A FLARE_RUN_ID in the env tags the container with a flare-run label."""
    monkeypatch.setenv("FLARE_RUN_ID", "run-123")
    cmd = DockerRunner()._build_docker_cmd(tmp_path, AuthSpec(env=[], home_dirs=[]))
    assert "--label" in cmd
    assert "flare-run=run-123" in cmd


def test_docker_cmd_includes_unique_name(tmp_path: Path) -> None:
    """A supplied name becomes a unique `--name` for per-run cancel."""
    cmd = DockerRunner()._build_docker_cmd(
        tmp_path, AuthSpec(env=[], home_dirs=[]), name="flare-abc123"
    )
    assert "--name" in cmd
    assert "flare-abc123" in cmd


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


def test_registry_keys_match_names() -> None:
    """Each RUNNERS key matches its class's `name`."""
    assert {k: cls.name for k, cls in RUNNERS.items()} == {
        "docker": "docker",
        "modal": "modal",
    }


# --- DockerRunner streaming + cancel (no daemon) --------------------------


class _FakePopen:
    """Minimal Popen stand-in: a fixed stdout line iterator that can EOF."""

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        self.stdout = iter(["line1\n", "line2\n"])
        self.waited = False

    def wait(self) -> int:
        self.waited = True
        return 0


def test_docker_run_streams_lines_and_sets_duration(
    tmp_path: Path, monkeypatch: Any
) -> None:
    """`run` yields a handle whose iteration streams the container's stdout,
    creates the stderr file, and sets duration_s on exit."""
    wd = tmp_path / "wd"
    wd.mkdir()
    monkeypatch.setattr(docker_module.subprocess, "Popen", _FakePopen)
    kills: list[list[str]] = []
    monkeypatch.setattr(
        docker_module.subprocess, "run", lambda cmd, **kw: kills.append(cmd)
    )

    lines: list[str] = []
    with DockerRunner().run(wd, AuthSpec(env=[], home_dirs=[])) as agent:
        for line in agent.stdout:
            lines.append(line)

    assert lines == ["line1", "line2"]
    assert agent.duration_s >= 0.0
    assert (wd / "docker_stderr.txt").exists()
    # Teardown always issues an idempotent `docker kill` to ensure the
    # container is stopped (a no-op when it already exited).
    assert any(cmd[:2] == ["docker", "kill"] for cmd in kills)


def test_docker_cancel_kills_container_by_name(
    tmp_path: Path, monkeypatch: Any
) -> None:
    """`AgentRun.cancel()` issues `docker kill <unique-name>`."""
    wd = tmp_path / "wd"
    wd.mkdir()
    monkeypatch.setattr(docker_module.subprocess, "Popen", _FakePopen)
    kills: list[list[str]] = []
    monkeypatch.setattr(
        docker_module.subprocess, "run", lambda cmd, **kw: kills.append(cmd)
    )

    with DockerRunner().run(wd, AuthSpec(env=[], home_dirs=[])) as agent:
        agent.cancel()

    # The kill targets a single unique container name (flare-<hex>).
    killed_names = [cmd[2] for cmd in kills if cmd[:2] == ["docker", "kill"]]
    assert killed_names
    assert all(name.startswith("flare-") for name in killed_names)


# --- ModalRunner primitives (no network) ----------------------------------


def test_modal_agent_run_streams_and_cancels() -> None:
    """ModalAgentRun decodes str/bytes stdout lines and forwards cancel()."""
    proc = SimpleNamespace(stdout=iter(["a\n", b"b\n"]))
    killed: list[bool] = []
    agent = ModalAgentRun(proc, lambda: killed.append(True))
    assert list(agent.stdout) == ["a", "b"]
    agent.cancel()
    assert killed == [True]


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


def test_modal_kill_agent_tolerates_gone_sandbox() -> None:
    """A Sandbox reaped out from under us doesn't crash the cancel path."""

    def _exec(*args: str, **kwargs: Any) -> None:
        raise RuntimeError("Sandbox already shut down")

    sb = SimpleNamespace(exec=_exec)
    ModalRunner()._kill_agent(sb)  # must not raise


def test_modal_pull_wd_tolerates_gone_sandbox(tmp_path: Path) -> None:
    """If the Sandbox vanished mid-cancel, _pull_wd logs and returns quietly."""

    def _exec(*args: str, **kwargs: Any) -> None:
        raise RuntimeError("Sandbox already shut down")

    sb = SimpleNamespace(exec=_exec)
    ModalRunner()._pull_wd(sb, tmp_path)  # must not raise
