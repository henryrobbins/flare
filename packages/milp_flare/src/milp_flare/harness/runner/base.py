from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import ClassVar


@dataclass(frozen=True)
class AuthSpec:
    """Compute-agnostic description for forwarding agent credentials.

    Attributes
    ----------
    env : list[str]
        Host environment-variable names to forward into the container.
    home_dirs : list[tuple[pathlib.Path, str]]
        Host directories to make available under the container's ``$HOME``, as
        ``(host_dir, dest_basename)`` pairs (e.g. ``(~/.codex, ".codex")``).
    """

    env: list[str]
    home_dirs: list[tuple[Path, str]]


class RunnerRun(ABC):
    """Handle for a single in-flight agent run on a compute backend."""

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
        Compute backend identifier (e.g. ``"docker"``).
    home : str
        Absolute path of the container ``HOME`` for this backend.
    """

    name: ClassVar[str]
    home: ClassVar[str]

    @property
    @abstractmethod
    def image(self) -> str:
        """Image identifier for this runner."""
        ...

    @abstractmethod
    def start(self, wd: Path, auth: AuthSpec) -> RunnerRun:
        """Launch the agent with the given working directory and return a run handle.

        The agent harness is responsible for populating the working directory
        with any harness-specific files.

        Parameters
        ----------
        wd : pathlib.Path
            The populated agent working directory.
        auth : AuthSpec
            Credential-forwarding spec from the harness.

        Returns
        -------
        RunnerRun
            Handle to the in-flight run.
        """
        ...
