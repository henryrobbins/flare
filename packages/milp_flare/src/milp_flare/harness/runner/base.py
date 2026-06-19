from __future__ import annotations

import logging
import time
from abc import ABC, abstractmethod
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import ClassVar

log = logging.getLogger(__name__)


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
    def run(
        self,
        wd: Path,
        auth: AuthSpec,
        *,
        on_output: Callable[[str], None] | None = None,
        should_cancel: Callable[[], bool] | None = None,
        poll_interval: float = 2.0,
    ) -> float:
        """Execute the agent in ``wd``; return wall-clock duration in seconds.

        Writes the same artifacts the image entrypoint always writes
        (``agent_output.jsonl``, ``result.json``, ``compile_log.txt``, and the
        agent's Lean files) back into ``wd``.

        Two optional callback hooks let an external consumer observe the agent's
        output **live** and **cancel** the run mid-flight. With neither supplied,
        ``run`` behaves exactly as it always has — a single blocking call with no
        polling overhead.

        Parameters
        ----------
        wd : pathlib.Path
            The populated agent working directory (``agent.sh``, ``prompt.txt``,
            skills, MCP config, Lake skeleton).
        auth : AuthSpec
            Credential-forwarding spec from the harness.
        on_output : Callable[[str], None], optional
            Called roughly every ``poll_interval`` seconds with the **full**
            current contents of ``agent_output.jsonl`` (a complete snapshot, not
            a delta). Consumers parse the whole file each call and must be
            idempotent; a skipped snapshot self-heals on the next tick. A final
            snapshot fires once after the agent finishes. Hook errors are logged
            and swallowed so a failing sink never aborts the run.
        should_cancel : Callable[[], bool], optional
            Polled once per tick. Returning ``True`` makes the runner stop the
            agent compute, capture whatever partial artifacts exist, and return
            promptly. The caller owns the cancel decision, so the runner does not
            signal "this was a cancellation" back — a canceled run looks like a
            short normal run. A hook error is treated as "do not cancel this
            tick."
        poll_interval : float, default ``2.0``
            Seconds between supervision ticks. Only relevant when at least one
            hook is supplied.

        Returns
        -------
        float
            Measured wall-clock duration of the agent run, in seconds.
        """
        ...

    def _supervise(
        self,
        *,
        is_running: Callable[[], bool],
        read_output: Callable[[], str],
        terminate: Callable[[], None],
        on_output: Callable[[str], None] | None,
        should_cancel: Callable[[], bool] | None,
        poll_interval: float,
    ) -> None:
        """Drive the shared output/cancel tick loop for a running agent.

        Backends supply three primitives — ``is_running`` (has the agent
        compute exited?), ``read_output`` (full current ``agent_output.jsonl``
        contents, ``""`` if absent) and ``terminate`` (stop the agent compute;
        idempotent and safe to re-issue) — and this method handles the common
        cadence, final-flush, and hook error-guarding so the two backends stay
        in lockstep. Returns once the agent compute has exited.
        """
        canceled = False
        while is_running():
            time.sleep(poll_interval)
            if on_output:
                try:
                    on_output(read_output())
                except Exception:
                    log.exception("on_output hook failed; continuing")
            if canceled:
                # Re-issue until the process actually exits.
                terminate()
            elif should_cancel:
                try:
                    if should_cancel():
                        canceled = True
                        terminate()
                except Exception:
                    log.exception("should_cancel hook failed; treating as no-cancel")
        if on_output:  # final snapshot after the agent has exited
            try:
                on_output(read_output())
            except Exception:
                log.exception("final on_output hook failed")
