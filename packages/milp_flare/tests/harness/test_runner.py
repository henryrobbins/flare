"""Unit tests for the compute-backend layer (`milp_flare.harness.runner`).

These exercise `DockerRunner`'s command assembly and `DockerRun`'s lifecycle
with `subprocess` monkeypatched, plus the `RUNNERS` registry.
No Docker daemon or image is involved; real container behavior is covered by
`test_docker.py`.
"""

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from typing import IO, Any

import pytest

from milp_flare.harness.runner import (
    RUNNERS,
    AuthSpec,
    DockerRunner,
    Runner,
)
from milp_flare.harness.runner import docker as docker_module


def _fake_popen_factory(on_launch: Any) -> Any:
    """Build a `subprocess.Popen` stand-in.

    `on_launch(cmd, stderr_file)` runs at launch time to simulate the
    container (write `agent_output.jsonl`, emit stderr). The returned object
    exposes the minimal `wait()` the run handle needs.
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


# ---------------------------------------------------------------------------
# DockerRunner._build_docker_cmd
# ---------------------------------------------------------------------------


def test_docker_cmd_includes_mount_and_image(tmp_path: Path) -> None:
    runner = DockerRunner(image="custom-image:tag")
    cmd = runner._build_docker_cmd(tmp_path, AuthSpec(env=[], home_dirs=[]))
    assert cmd[:2] == ["docker", "run"]
    assert "--rm" in cmd
    assert "-v" in cmd and f"{tmp_path.resolve()}:/workspace/wd" in cmd
    assert cmd[-1] == "custom-image:tag"


def test_docker_cmd_forwards_env_and_home_dirs(tmp_path: Path) -> None:
    auth = AuthSpec(env=["FOO", "BAR"], home_dirs=[(tmp_path, ".codex")])
    cmd = DockerRunner()._build_docker_cmd(tmp_path, auth, name="flare-x")
    assert "--name" in cmd and "flare-x" in cmd
    # env vars forwarded by name
    assert cmd.count("-e") == 2
    assert "FOO" in cmd and "BAR" in cmd
    # home dir mounted under the container HOME, rw
    assert f"{tmp_path}:/home/agent/.codex" in cmd


def test_docker_cmd_labels_with_run_id(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("FLARE_RUN_ID", "20260618-run")
    cmd = DockerRunner()._build_docker_cmd(tmp_path, AuthSpec(env=[], home_dirs=[]))
    assert "--label" in cmd and "flare-run=20260618-run" in cmd


def test_docker_cmd_omits_label_without_run_id(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("FLARE_RUN_ID", raising=False)
    cmd = DockerRunner()._build_docker_cmd(tmp_path, AuthSpec(env=[], home_dirs=[]))
    assert "--label" not in cmd


# ---------------------------------------------------------------------------
# DockerRunner.start / DockerRun
# ---------------------------------------------------------------------------


def test_start_assigns_unique_name_and_writes_stderr(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """`start` names the container uniquely and persists container stderr."""
    captured: dict[str, list[str]] = {}

    def _launch(cmd: list[str], stderr: IO[bytes] | None) -> None:
        captured["cmd"] = cmd
        assert stderr is not None
        stderr.write(b"boom\n")

    monkeypatch.setattr(docker_module.subprocess, "Popen", _fake_popen_factory(_launch))

    run = DockerRunner().start(tmp_path, AuthSpec(env=[], home_dirs=[]))
    duration = run.wait()

    name = captured["cmd"][captured["cmd"].index("--name") + 1]
    assert name.startswith("flare-")
    assert duration >= 0.0
    assert (tmp_path / "docker_stderr.txt").read_text() == "boom\n"


def test_cancel_kills_named_container(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """`DockerRun.cancel` issues `docker kill <name>` for its container."""
    captured: dict[str, list[str]] = {}

    def _launch(cmd: list[str], stderr: IO[bytes] | None) -> None:
        captured["cmd"] = cmd

    monkeypatch.setattr(docker_module.subprocess, "Popen", _fake_popen_factory(_launch))

    kills: list[list[str]] = []

    def _fake_run(cmd: list[str], **kwargs: Any) -> SimpleNamespace:
        kills.append(cmd)
        return SimpleNamespace()

    monkeypatch.setattr(docker_module.subprocess, "run", _fake_run)

    run = DockerRunner().start(tmp_path, AuthSpec(env=[], home_dirs=[]))
    name = captured["cmd"][captured["cmd"].index("--name") + 1]
    run.cancel()
    assert kills == [["docker", "kill", name]]


def test_docker_runner_config_surface() -> None:
    runner = DockerRunner()
    assert runner.name == "docker"
    assert runner.home == "/home/agent"
    assert runner.image == "flare-agent:latest"


# ---------------------------------------------------------------------------
# RUNNERS registry
# ---------------------------------------------------------------------------


def test_registry_keys_match_names() -> None:
    for key, cls in RUNNERS.items():
        assert issubclass(cls, Runner)
        assert cls.name == key
