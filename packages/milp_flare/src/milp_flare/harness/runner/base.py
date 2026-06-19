from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import Iterator
from contextlib import AbstractContextManager
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


class AgentRun(ABC):
    """Live handle to a running agent, yielded by :meth:`Runner.run`.

    The handle is the single streaming primitive shared by every backend:

    - **Iterate** :attr:`stdout` to consume the agent's output line by line as
      it is produced (the agent CLIs emit ``stream-json``). Iteration ends when
      the agent process exits (EOF).
    - **Call** :meth:`cancel` (from any thread) to stop the agent mid-flight.
      Iteration then ends promptly, and whatever partial artifacts exist are
      still captured when the enclosing :meth:`Runner.run` context exits.

    Attributes
    ----------
    duration_s : float
        Wall-clock duration of the run, in seconds. ``0.0`` until the enclosing
        :meth:`Runner.run` context manager exits and sets it.
    """

    duration_s: float = 0.0

    @property
    @abstractmethod
    def stdout(self) -> Iterator[str]:
        """Yield the agent's ``stdout`` lines (``stream-json``) as produced."""
        ...

    @abstractmethod
    def cancel(self) -> None:
        """Stop the agent process. Idempotent and thread-safe.

        Stopping the agent makes the consumer's iteration end (EOF). Partial
        artifacts are still synced back into ``wd`` by the enclosing
        :meth:`Runner.run` context exit, so a canceled run looks like a short
        normal run with whatever output the agent had produced.
        """
        ...


class Runner(ABC):
    """Execute the FLARE agent container for a populated working directory.

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
    def run(self, wd: Path, auth: AuthSpec) -> AbstractContextManager[AgentRun]:
        """Populate ``wd`` into the container, start the agent, and stream it.

        Returns a context manager yielding a live :class:`AgentRun`. The caller
        iterates the handle for the agent's ``stdout`` and may
        :meth:`~AgentRun.cancel` it. When the context exits, the runner stops
        the agent if it is still running, syncs the container's working
        directory back into ``wd`` (the agent's Lean files, ``result.json``,
        ``compile_log.txt``), sets :attr:`AgentRun.duration_s`, and tears down
        the compute.

        Note that ``agent_output.jsonl`` is *not* produced by the container; the
        caller rebuilds it on the host from the streamed ``stdout`` lines.

        Parameters
        ----------
        wd : pathlib.Path
            The populated agent working directory (``agent.sh``, ``prompt.txt``,
            skills, MCP config, Lake skeleton).
        auth : AuthSpec
            Credential-forwarding spec from the harness.
        """
        ...
