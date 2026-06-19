"""Tests for `src.verify.factory` — verifier construction from dict specs.

Focused on the FLARE `compute:` selection added for the Modal backend; the
other verifier types are covered behaviorally in `test_verifiers.py`.
"""

from __future__ import annotations

from milp_flare.harness.runner import DockerRunner, ModalRunner

from src.verify.factory import build_verifier
from src.verify.flare import FLAREVerifier


def _harness(spec: dict) -> object:
    verifier = build_verifier(spec)
    assert isinstance(verifier, FLAREVerifier)
    return verifier._inner.harness


def test_flare_defaults_to_docker() -> None:
    """A flare spec without `compute` runs on the local Docker backend."""
    harness = _harness(
        {"type": "flare", "harness": "claude_code", "client": {"model": "m"}}
    )
    assert isinstance(harness.runner, DockerRunner)
    assert harness.get_config_dict()["compute"] == "docker"


def test_flare_selects_modal_with_config() -> None:
    """`compute: modal` plus a `modal:` block builds a configured ModalRunner."""
    harness = _harness(
        {
            "type": "flare",
            "harness": "claude_code",
            "compute": "modal",
            "modal": {"cpu": 8.0, "memory": 8192, "app": "myapp", "image": "img"},
            "client": {"model": "m"},
        }
    )
    runner = harness.runner
    assert isinstance(runner, ModalRunner)
    assert runner.cpu == 8.0
    assert runner.memory == 8192
    assert runner.app == "myapp"
    assert runner.image == "img"
    assert harness.get_config_dict()["compute"] == "modal"


def test_flare_modal_without_config_uses_defaults() -> None:
    """`compute: modal` with no `modal:` block uses ModalRunner defaults."""
    harness = _harness(
        {
            "type": "flare",
            "harness": "claude_code",
            "compute": "modal",
            "client": {"model": "m"},
        }
    )
    assert isinstance(harness.runner, ModalRunner)
    assert harness.runner.image == "flare-agent:latest"
