"""Compute backends (runners) for executing the FLARE agent container."""

from __future__ import annotations

from milp_flare.harness.runner.base import IMAGE, AgentRun, AuthSpec, Runner
from milp_flare.harness.runner.docker import DockerRunner
from milp_flare.harness.runner.modal import ModalRunner

RUNNERS: dict[str, type[Runner]] = {
    "docker": DockerRunner,
    "modal": ModalRunner,
}


__all__ = [
    "IMAGE",
    "RUNNERS",
    "AgentRun",
    "AuthSpec",
    "DockerRunner",
    "ModalRunner",
    "Runner",
]
