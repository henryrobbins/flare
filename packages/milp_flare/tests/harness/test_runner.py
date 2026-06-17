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
