from __future__ import annotations

import time
from abc import ABC, abstractmethod
from collections.abc import Iterator
from contextlib import AbstractContextManager
from dataclasses import dataclass
from pathlib import Path
from types import TracebackType
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


class AgentRun(AbstractContextManager["AgentRun"]):
    """Durable handle to a running agent, returned by :meth:`Runner.start`.

    The handle is the single primitive shared by every backend, and it owns the
    run's lifecycle end to end:

    - **Iterate** :attr:`stdout` to consume the agent's output line by line as
      it is produced (the agent CLIs emit ``stream-json``). Iteration ends when
      the agent process exits (EOF).
    - **Call** :meth:`cancel` (from any thread) to stop the agent mid-flight.
      ``cancel`` only ever touches the backend's *durable address* (the
      container name / Sandbox), never the streaming process object, so it is
      safe to call concurrently with an in-progress :attr:`stdout` iteration.
      Iteration then ends promptly (EOF).
    - **Call** :meth:`close` (or use the handle as a ``with`` block) to tear the
      run down: stop the agent if still running, capture whatever partial
      artifacts exist into ``wd``, release the compute, and set
      :attr:`duration_s`. Idempotent — call it exactly once from the consuming
      thread; ``cancel`` does *not* close.

    Because the handle owns teardown, an external owner can hold it, stream it
    on one thread, and :meth:`cancel` it from another with no callback wiring:
    the handle already exists the moment :meth:`Runner.start` returns.

    Attributes
    ----------
    duration_s : float
        Wall-clock duration of the run, in seconds. ``0.0`` until :meth:`close`
        runs and sets it.
    """

    duration_s: float = 0.0
    _start: float | None = None
    _closed: bool = False

    def __init__(self, start: float | None = None) -> None:
        if start is not None:
            self._start = start

    @property
    @abstractmethod
    def stdout(self) -> Iterator[str]:
        """Yield the agent's ``stdout`` lines (``stream-json``) as produced."""
        ...

    @abstractmethod
    def cancel(self) -> None:
        """Stop the agent process. Idempotent and thread-safe.

        Implemented purely against the backend's durable address (e.g.
        ``docker kill <name>`` / ``pkill`` inside the Sandbox), so it never
        depends on the streaming process object and may be called from any
        thread. Stopping the agent makes the consumer's :attr:`stdout`
        iteration end (EOF); the partial artifacts are captured later by
        :meth:`close`.
        """
        ...

    def _teardown(self) -> None:
        """Stop the agent, capture partial artifacts, and release the compute.

        Backend-specific; the default is a no-op (used by in-memory test
        doubles). Called at most once, by :meth:`close`.
        """

    def close(self) -> None:
        """Idempotent teardown. Stops the agent, captures artifacts, sets
        :attr:`duration_s`. Safe to call more than once; only the first runs."""
        if self._closed:
            return
        self._closed = True
        try:
            self._teardown()
        finally:
            if self._start is not None:
                self.duration_s = time.time() - self._start

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        tb: TracebackType | None,
    ) -> None:
        self.close()


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
    def start(self, wd: Path, auth: AuthSpec) -> AgentRun:
        """Provision the compute, populate ``wd``, start the agent, and return
        a live :class:`AgentRun` handle.

        The handle owns the run's durable address and full lifecycle: the caller
        iterates :attr:`AgentRun.stdout`, may :meth:`~AgentRun.cancel` it from
        any thread, and must :meth:`~AgentRun.close` it once (directly or via a
        ``with`` block) to capture artifacts, set :attr:`AgentRun.duration_s`,
        and release the compute.

        On a provisioning failure (after the compute is created), the runner
        releases the compute before re-raising, so a failed ``start`` never
        leaks a container/Sandbox.

        Parameters
        ----------
        wd : pathlib.Path
            The populated agent working directory (``agent.sh``, ``prompt.txt``,
            skills, MCP config, Lake skeleton).
        auth : AuthSpec
            Credential-forwarding spec from the harness.

        Notes
        -----
        The returned handle is itself a context manager, so for scoped use that
        wants a guaranteed :meth:`~AgentRun.close` on exit, write
        ``with runner.start(wd, auth) as agent: ...``.
        """
        ...
