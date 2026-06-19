"""Modal compute backend for the FLARE agent container.

Runs the agent in a `Modal <https://modal.com>`_ Sandbox created from a
pre-built named image (see ``milp-flare build-modal-image``). ``modal`` is an
optional dependency, imported lazily so the package installs and the local
Docker backend works without it.
"""

from __future__ import annotations

import io
import logging
import os
import tarfile
import tempfile
import time
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import TYPE_CHECKING, Any, ClassVar

from milp_flare.harness.runner.base import AgentRun, AuthSpec, Runner

log = logging.getLogger(__name__)

if TYPE_CHECKING:
    import modal

#: Working directory inside the Sandbox (mirrors the Docker bind-mount target).
REMOTE_WD = "/workspace/wd"


def _require_modal() -> Any:
    """Import ``modal`` lazily, with an actionable error if it is missing."""
    try:
        import modal
    except ModuleNotFoundError as exc:  # pragma: no cover - exercised via message
        raise RuntimeError(
            "the modal compute backend requires the `modal` package; "
            "install it with `pip install milp-flare[modal]`"
        ) from exc
    return modal


def _tar_dir(src: Path) -> bytes:
    """Tar the contents of ``src`` (arcname='.') into an in-memory gzip blob."""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tf:
        tf.add(str(src), arcname=".")
    return buf.getvalue()


class ModalAgentRun(AgentRun):
    """Live handle over a Sandbox exec's ``stdout``.

    Iterating :attr:`stdout` drains the ``run-agent`` exec's output line by line
    (the agent stream) until the process exits. :meth:`cancel` ``pkill``\\ s the agent
    *inside* the still-alive Sandbox, so the post-run artifact pull (done by the
    enclosing :meth:`ModalRunner.run` context exit) can still capture partial
    output before the Sandbox is terminated.
    """

    def __init__(self, proc: Any, cancel_fn: Callable[[], None]) -> None:
        self._proc = proc
        self._cancel_fn = cancel_fn

    @property
    def stdout(self) -> Iterator[str]:
        for line in self._proc.stdout:
            if isinstance(line, bytes):
                line = line.decode("utf-8", errors="replace")
            yield line.rstrip("\n")

    def cancel(self) -> None:
        self._cancel_fn()


class ModalRunner(Runner):
    """Run the agent in a Modal Sandbox from a pre-built named image.

    The image bakes ``run-agent`` at ``/usr/local/bin/run-agent`` but **not**
    as its ``ENTRYPOINT`` (a Sandbox runs the entrypoint at creation time,
    before the working directory is populated). The runner instead creates an
    **idle**, command-less Sandbox: with no main process to exit, the Sandbox
    stays in the *Started* state on its own until ``timeout`` or
    ``terminate()`` — which is what keeps it execable for the steps below.

    The runner pushes ``wd`` in via the filesystem API, execs ``run-agent``, and
    streams the exec's ``stdout`` back as a :class:`ModalAgentRun`. When the
    stream ends (or the caller cancels), the context exit pulls the artifacts
    back out via the filesystem API and terminates the Sandbox. An ``sb.exec``
    child finishing does not end the Sandbox, so the artifact pull runs against
    the still-live (idle) Sandbox.

    Agent output is **not** mirrored to the Modal dashboard Logs view (only a
    main process's stdout reaches the dashboard, and there is no main process
    here — an exec'd process's output goes to the client only). Consumers read
    the agent's output from the streamed ``stdout`` instead.

    Parameters
    ----------
    image : str, default ``"flare-agent"``
        The Modal named image to launch (built via ``milp-flare
        build-modal-image``).
    app : str, default ``"flare"``
        The Modal app the Sandbox is associated with.
    cpu : float, default ``4.0``
        Requested CPU cores (a guaranteed floor; the Sandbox may burst higher).
    memory : int, default ``4096``
        Requested memory in MiB.
    timeout : int, default ``1800``
        Hard cap on Sandbox lifetime, in seconds.
    """

    name: ClassVar[str] = "modal"
    home: ClassVar[str] = "/root"

    def __init__(
        self,
        image: str = "flare-agent",
        app: str = "flare",
        cpu: float = 4.0,
        memory: int = 4096,
        timeout: int = 1800,
    ) -> None:
        self._image = image
        self.app = app
        self.cpu = cpu
        self.memory = memory
        self.timeout = timeout

    @property
    def image(self) -> str:
        return self._image

    @contextmanager
    def run(self, wd: Path, auth: AuthSpec) -> Iterator[AgentRun]:
        modal = _require_modal()

        app = modal.App.lookup(self.app, create_if_missing=True)
        image = modal.Image.from_name(self._image)
        # IS_SANDBOX=1 lets Claude's bypassPermissions mode run as root (Modal
        # ignores the image's USER and runs everything as root).
        secret_dict = {name: os.environ[name] for name in auth.env}
        secret_dict["IS_SANDBOX"] = "1"
        secret = modal.Secret.from_dict(secret_dict)

        # Create an idle, command-less Sandbox. With no main process to exit, it
        # stays *Started* until terminate()/timeout, which keeps it execable for
        # the run-agent exec below and the tar exec in _pull_wd afterward. (An
        # sb.exec child finishing does not end the Sandbox; only the main process
        # exiting does — and there is none.) _push_wd creates REMOTE_WD.
        sb = modal.Sandbox.create(
            app=app,
            image=image,
            secrets=[secret],
            cpu=self.cpu,
            memory=self.memory,
            timeout=self.timeout,
        )

        start = time.time()
        try:
            # Tag with the FLARE run ID first thing, so a batch-level reaper
            # (experiments' kill_run_sandboxes) can find and terminate this
            # Sandbox by tag even if the worker dies before its own teardown.
            run_id = os.environ.get("FLARE_RUN_ID")
            if run_id:
                sb.set_tags({"flare-run": run_id})

            self._push_wd(sb, wd, auth)

            # Run the baked entrypoint (agent.sh + post-hoc compile) via exec.
            # The idle Sandbox stays *Started* across the exec, so it remains
            # execable for _pull_wd afterward. No PTY: agent.sh writes stream-json
            # to stdout, which a PTY would corrupt.
            #
            # Redirect run-agent's stdin from /dev/null. Modal's exec leaves
            # stdin an open pipe with no EOF, so the agent CLIs block reading
            # it — claude waits 3s then proceeds, but codex/opencode hang
            # indefinitely until the Sandbox times out. `docker run` (no -i)
            # gives stdin immediate EOF, which is why the Docker backend never
            # hit this. Redirect stderr to a file in wd so only stdout streams
            # (no second pipe to drain) and the stderr is pulled back as an
            # artifact for diagnostics.
            proc = sb.exec(
                "bash",
                "-c",
                "exec /usr/local/bin/run-agent "
                f"< /dev/null 2> {REMOTE_WD}/modal_stderr.txt",
                workdir=REMOTE_WD,
            )
            agent = ModalAgentRun(proc, lambda: self._kill_agent(sb))
            try:
                yield agent
            finally:
                # Ensure the agent is stopped (a no-op if it already exited),
                # then pull whatever artifacts exist off the still-live Sandbox.
                agent.cancel()
                proc.wait()
                self._pull_wd(sb, wd)
                agent.duration_s = time.time() - start
        finally:
            # Tear down the Sandbox. Tolerate it being already gone (an external
            # batch reaper may have terminated it) so cleanup never masks the
            # original control flow.
            try:
                sb.terminate()
            except Exception:
                log.debug("terminate: Sandbox already gone")
            try:
                sb.detach()
            except Exception:
                log.debug("detach: Sandbox already gone")

    def _kill_agent(self, sb: modal.Sandbox) -> None:
        """Stop the agent process inside the Sandbox, leaving the Sandbox alive.

        ``ContainerProcess`` has no per-exec kill, so the running ``run-agent``
        (and its agent.sh child) is terminated with ``pkill`` (from ``procps``,
        baked into the image). The Sandbox itself stays *Started* so the
        post-loop ``_pull_wd`` can still capture partial artifacts; the
        ``finally: sb.terminate()`` in :meth:`run` nukes any lingering
        grandchild afterward. Idempotent and safe to re-issue.

        Best-effort: if the Sandbox is already gone (e.g. an external batch
        reaper terminated it, or a prior call already killed it), the exec
        raises and we simply treat the agent as already stopped.
        """
        try:
            sb.exec("pkill", "-TERM", "-f", "run-agent").wait()
        except Exception:
            log.debug("kill_agent: Sandbox unavailable; treating agent as stopped")

    def _push_wd(self, sb: modal.Sandbox, wd: Path, auth: AuthSpec) -> None:
        """Copy the populated ``wd`` (and any auth home dirs) into the Sandbox."""
        with tempfile.NamedTemporaryFile(suffix=".tar.gz") as tmp:
            tmp.write(_tar_dir(wd))
            tmp.flush()
            sb.filesystem.copy_from_local(tmp.name, "/tmp/wd.tar.gz")
        sb.exec(
            "bash",
            "-c",
            f"mkdir -p {REMOTE_WD} && tar -xzf /tmp/wd.tar.gz -C {REMOTE_WD}",
        ).wait()

        # Push host config dirs (e.g. ~/.codex) under the Sandbox's HOME so the
        # agent CLI finds its credentials at the expected path.
        for host_dir, dest in auth.home_dirs:
            remote = f"{self.home}/{dest}"
            with tempfile.NamedTemporaryFile(suffix=".tar.gz") as tmp:
                tmp.write(_tar_dir(host_dir))
                tmp.flush()
                sb.filesystem.copy_from_local(tmp.name, "/tmp/home_dir.tar.gz")
            sb.exec(
                "bash",
                "-c",
                f"mkdir -p {remote} && tar -xzf /tmp/home_dir.tar.gz -C {remote}",
            ).wait()

    def _pull_wd(self, sb: modal.Sandbox, wd: Path) -> None:
        """Tar the Sandbox ``wd`` back out and extract it over the host ``wd``.

        Best-effort: if the Sandbox has already been torn down (e.g. an external
        batch reaper terminated it during a cancel), the exec/copy raises; we log
        and return rather than crash the worker, keeping whatever artifacts had
        already been written.
        """
        # Exclude the big image-baked .lake symlink target.
        try:
            sb.exec(
                "bash",
                "-c",
                f"tar -czf /tmp/out.tar.gz -C {REMOTE_WD} --exclude=./.lake .",
            ).wait()
            with tempfile.NamedTemporaryFile(suffix=".tar.gz") as tmp:
                sb.filesystem.copy_to_local("/tmp/out.tar.gz", tmp.name)
                with tarfile.open(tmp.name, mode="r:gz") as tf:
                    tf.extractall(wd)
        except Exception:
            log.warning("pull_wd: failed to pull artifacts (Sandbox unavailable)")
