"""Compute backends (runners) for executing the FLARE agent container."""

from __future__ import annotations

from typing import Any

from milp_flare.harness.runner.base import AuthSpec, Runner
from milp_flare.harness.runner.docker import DockerRunner
from milp_flare.harness.runner.modal import ModalRunner

#: Registry of compute backends by ``Runner.name``. Mirrors ``HARNESSES``.
RUNNERS: dict[str, type[Runner]] = {
    "docker": DockerRunner,
    "modal": ModalRunner,
}


def make_runner(name: str, cfg: dict[str, Any] | None = None) -> Runner:
    """Instantiate a compute backend by name.

    Parameters
    ----------
    name : str
        A key of :data:`RUNNERS` (``"docker"`` or ``"modal"``).
    cfg : dict[str, Any], optional
        Keyword arguments forwarded to the runner constructor.

    Returns
    -------
    Runner
        The constructed runner.

    Raises
    ------
    ValueError
        If ``name`` is not a known compute backend.
    """
    cls = RUNNERS.get(name)
    if cls is None:
        raise ValueError(f"unknown compute backend: {name!r}")
    return cls(**(cfg or {}))


__all__ = [
    "RUNNERS",
    "AuthSpec",
    "DockerRunner",
    "ModalRunner",
    "Runner",
    "make_runner",
]
