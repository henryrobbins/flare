"""Compute-backend abstraction for executing the FLARE agent container.

A :class:`Runner` owns the *compute* concern: given a populated agent working
directory, execute the agent container (sourcing ``agent.sh`` and running the
post-hoc Lean compile) and return the wall-clock duration. This is orthogonal
to the *agent* concern owned by :class:`~milp_flare.harness.base.Harness`
(which CLI to launch, how to parse its output). A harness holds a runner and
delegates execution to it, so the same parsing/cost logic works on any backend.

Two implementations ship with the package:

- :class:`~milp_flare.harness.runner.docker.DockerRunner` — local Docker
  container (the default; behaves exactly as FLARE always has).
- :class:`~milp_flare.harness.runner.modal.ModalRunner` — a
  `Modal <https://modal.com>`_ Sandbox from a pre-built named image.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import ClassVar


@dataclass(frozen=True)
class AuthSpec:
    """Compute-agnostic description of how to forward agent credentials.

    A harness builds an :class:`AuthSpec` describing what the agent CLI needs;
    each runner knows how to satisfy it for its own backend (Docker ``-e`` /
    ``-v`` flags, a Modal secret / file push, etc.).

    Attributes
    ----------
    env : list[str]
        Host environment-variable names to forward into the container. The
        harness has already validated that any required names are present.
    home_dirs : list[tuple[pathlib.Path, str]]
        Host directories to make available under the container's ``$HOME``, as
        ``(host_dir, dest_basename)`` pairs (e.g. ``(~/.codex, ".codex")``).
        The runner knows its own container ``HOME``, so the same spec works for
        Docker (``/home/agent``) and Modal (``/root``).
    """

    env: list[str]
    home_dirs: list[tuple[Path, str]]


class Runner(ABC):
    """Execute the FLARE agent container for a populated working directory.

    Attributes
    ----------
    name : str
        Compute backend identifier (``"docker"`` | ``"modal"``); surfaced in
        the run config as ``config["compute"]``.
    home : str
        Absolute path of the container ``HOME`` for this backend
        (``"/home/agent"`` for Docker, ``"/root"`` for Modal); used to place
        :attr:`AuthSpec.home_dirs`.
    """

    name: ClassVar[str]
    home: ClassVar[str]

    @property
    @abstractmethod
    def image(self) -> str:
        """Image identifier for this runner (for run-config reporting)."""
        ...

    @abstractmethod
    def run(self, wd: Path, auth: AuthSpec) -> float:
        """Execute the agent in ``wd``; return wall-clock duration in seconds.

        Writes the same artifacts the image entrypoint always writes
        (``agent_output.jsonl``, ``result.json``, ``compile_log.txt``, and the
        agent's Lean files) back into ``wd``.

        Parameters
        ----------
        wd : pathlib.Path
            The populated agent working directory (``agent.sh``, ``prompt.txt``,
            skills, MCP config, Lake skeleton).
        auth : AuthSpec
            Credential-forwarding spec from the harness.

        Returns
        -------
        float
            Measured wall-clock duration of the agent run, in seconds.
        """
        ...
