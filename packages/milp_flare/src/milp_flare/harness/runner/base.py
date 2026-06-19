from __future__ import annotations

import time
from abc import ABC, abstractmethod
from collections.abc import Iterator
from contextlib import AbstractContextManager
from dataclasses import dataclass
from pathlib import Path
from types import TracebackType
from typing import ClassVar

#: The default name of the Docker image containing the agent environment. This
#: image is expected to be built prior to running FLARE. See :doc:`/installation`.
IMAGE = "flare-agent:latest"


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
    """Handle for a running agent, returned by :meth:`Runner.start`.

    The handle owns the lifecycle of an active agent run. The caller is
    responsible for iterating :attr:`stdout` to retrieve agent output until
    the run ends (if :attr:`stdout` is not drained, the buffer will fill and
    block the agent). Use :meth:`close` to stop the agent, capture any partial
    artifacts, and release the compute. Additionally, :meth:`cancel` offers a
    thread-safe way to stop the agent without waiting for completion.

    Attributes
    ----------
    stdout : Iterator[str]
        Iterator yielding the agent's ``stdout`` lines until the process exits
        (EOF).
    duration_s : float
        Wall-clock duration of the run, in seconds. ``0.0`` until :meth:`close`
        runs and sets it.

    Returns
    -------
    AgentRun
        Handle to the in-flight run.
    """

    duration_s: float = 0.0
    _start: float | None = None
    _closed: bool = False

    def __init__(self, start: float | None = None) -> None:
        if start is not None:
            self._start = start

    @property
    @abstractmethod
    def stdout(self) -> Iterator[str]: ...

    @abstractmethod
    def cancel(self) -> None:
        """Stop the agent process.

        This does not capture partial artifacts or release compute. It solely
        stops the agent process and makes the :attr:`stdout` iteration end.
        This allows for thread-safe cancellation. Any consumer thread can detect
        cancellation by the end of the stream.
        """
        ...

    def _teardown(self) -> None:
        """Stop the agent, capture partial artifacts, and release the compute."""
        self.cancel()

    def close(self) -> None:
        """Stop the agent, capture partial artifacts, and release the compute."""
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
    """Launch the FLARE agent container for a populated working directory.

    Attributes
    ----------
    name : str
        Compute backend identifier (e.g. ``"docker"``).
    home : str
        Absolute path of the container ``HOME`` for this backend.
    image : str
        Image identifier for this runner.
    """

    name: ClassVar[str]
    home: ClassVar[str]

    @property
    @abstractmethod
    def image(self) -> str: ...

    @abstractmethod
    def start(self, wd: Path, auth: AuthSpec) -> AgentRun:
        """Launch the agent with the given working directory and credentials.

        Parameters
        ----------
        wd : pathlib.Path
            The populated agent working directory.
        auth : AuthSpec
            Credential-forwarding spec from the harness.

        Returns
        -------
        AgentRun
            Handle to the in-flight run.
        """
        ...
