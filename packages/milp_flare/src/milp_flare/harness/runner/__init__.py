"""Compute backends (runners) for executing the FLARE agent container."""

from __future__ import annotations

from milp_flare.harness.runner.base import AuthSpec, Runner
from milp_flare.harness.runner.docker import DockerRunner
from milp_flare.harness.runner.modal import ModalRunner

#: Registry of compute backends by ``Runner.name``. Mirrors ``HARNESSES``.
RUNNERS: dict[str, type[Runner]] = {
    "docker": DockerRunner,
    "modal": ModalRunner,
}


__all__ = [
    "RUNNERS",
    "AuthSpec",
    "DockerRunner",
    "ModalRunner",
    "Runner",
]
