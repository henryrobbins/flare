"""Compute-backend abstraction for executing the FLARE agent container.

A :class:`Runner` owns the *compute* concern: given a populated agent working
directory, launch the agent container (sourcing ``agent.sh`` and running the
post-hoc Lean compile) and return a :class:`RunnerRun` handle the caller can
cancel or wait on. This is orthogonal to the *agent* concern owned by
:class:`~milp_flare.harness.base.Harness` (which CLI to launch, how to parse
its output). A harness holds a runner and delegates execution to it, so the
same parsing/cost logic works on any backend.

One implementation ships with the package today:

- :class:`~milp_flare.harness.runner.docker.DockerRunner` — local Docker
  container (the default; behaves exactly as FLARE always has).
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
    ``-v`` flags, a remote secret / file push, etc.).

    Attributes
    ----------
    env : list[str]
        Host environment-variable names to forward into the container. The
        harness has already validated that any required names are present.
    home_dirs : list[tuple[pathlib.Path, str]]
        Host directories to make available under the container's ``$HOME``, as
        ``(host_dir, dest_basename)`` pairs (e.g. ``(~/.codex, ".codex")``).
        The runner knows its own container ``HOME``, so the same spec works
        across backends.
    """

    env: list[str]
    home_dirs: list[tuple[Path, str]]


class RunnerRun(ABC):
    """Handle for a single in-flight agent run on a compute backend.

    A runner returns one of these from :meth:`Runner.start`. The agent layer
    (:class:`~milp_flare.harness.base.HarnessRun`) wraps it, forwarding
    cancellation and waiting on completion before parsing the agent output.
    """

    @abstractmethod
    def cancel(self) -> None:
        """Stop the run; idempotent and thread-safe."""
        ...

    @abstractmethod
    def wait(self) -> float:
        """Block until the compute exits; return wall-clock duration in seconds."""
        ...


class Runner(ABC):
    """Launch the FLARE agent container for a populated working directory.

    Attributes
    ----------
    name : str
        Compute backend identifier (e.g. ``"docker"``); surfaced in the run
        config as ``config["compute"]``.
    home : str
        Absolute path of the container ``HOME`` for this backend
        (``"/home/agent"`` for Docker); used to place
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
    def start(self, wd: Path, auth: AuthSpec) -> RunnerRun:
        """Launch the agent in ``wd`` and return a run handle.

        The launched container writes the artifacts the image entrypoint always
        writes (``agent_output.jsonl``, ``result.json``, ``compile_log.txt``,
        and the agent's Lean files) back into ``wd``.

        Parameters
        ----------
        wd : pathlib.Path
            The populated agent working directory (``agent.sh``, ``prompt.txt``,
            skills, MCP config, Lake skeleton).
        auth : AuthSpec
            Credential-forwarding spec from the harness.

        Returns
        -------
        RunnerRun
            Handle to the in-flight run; the caller awaits or cancels it.
        """
        ...
