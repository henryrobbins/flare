"""Compute backends (runners) for executing the FLARE agent container."""

from __future__ import annotations

from milp_flare.harness.runner.base import AuthSpec, Runner, RunnerRun
from milp_flare.harness.runner.docker import DockerRun, DockerRunner

RUNNERS: dict[str, type[Runner]] = {
    "docker": DockerRunner,
}


__all__ = [
    "RUNNERS",
    "AuthSpec",
    "DockerRun",
    "DockerRunner",
    "Runner",
    "RunnerRun",
]
