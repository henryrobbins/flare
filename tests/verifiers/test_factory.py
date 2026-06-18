"""Tests for `src.verify.factory` compute-backend selection."""

from __future__ import annotations

import pytest
from milp_flare.harness import DockerRunner

from src.verify.factory import _build_harness


def _flare_spec(**extra: object) -> dict[str, object]:
    return {"harness": "claude_code", "client": {"model": "claude-opus-4-7"}, **extra}


def test_flare_defaults_to_docker() -> None:
    """A flare spec with no `compute` key uses a DockerRunner."""
    harness = _build_harness(_flare_spec())
    assert isinstance(harness.runner, DockerRunner)


def test_flare_explicit_docker_with_config() -> None:
    """An explicit `compute: docker` honors a `docker:` config block."""
    harness = _build_harness(_flare_spec(compute="docker", docker={"image": "x:y"}))
    assert isinstance(harness.runner, DockerRunner)
    assert harness.runner.image == "x:y"


def test_flare_unknown_compute_raises() -> None:
    """An unregistered compute backend (e.g. modal) raises a clear error."""
    with pytest.raises(ValueError, match="unknown compute backend"):
        _build_harness(_flare_spec(compute="modal"))
