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
import threading
import time
from collections.abc import Callable
from pathlib import Path
from typing import TYPE_CHECKING, Any, ClassVar

from milp_flare.harness.runner.base import AuthSpec, Runner

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


class ModalRunner(Runner):
    """Run the agent in a Modal Sandbox from a pre-built named image.

    The image bakes ``run-agent`` at ``/usr/local/bin/run-agent`` but **not**
    as its ``ENTRYPOINT`` (a Sandbox runs the entrypoint at creation time,
    before the working directory is populated). The runner instead creates an
    **idle**, command-less Sandbox: with no main process to exit, the Sandbox
    stays in the *Started* state on its own until ``timeout`` or
    ``terminate()`` — which is what keeps it execable for the steps below.

    The runner then pushes ``wd`` in via the filesystem API, runs ``run-agent``
    via ``sb.exec``, pulls the artifacts back out via the filesystem API, and
    terminates the Sandbox. An ``sb.exec`` child finishing does not end the
    Sandbox, so the artifact pull runs against the still-live (idle) Sandbox.

    Agent output is **not** mirrored to the Modal dashboard Logs view (only a
    main process's stdout reaches the dashboard, and there is no main process
    here — an exec'd process's output goes to the client only). Consumers read
    the agent's output from ``agent_output.jsonl`` in ``wd`` instead.

    When :meth:`run` is given an ``on_output`` / ``should_cancel`` hook, the
    exec's pipes are drained in a background thread (which also signals
    completion) while the main thread runs the shared
    :meth:`~milp_flare.harness.runner.base.Runner._supervise` tick loop: live
    snapshots are read from ``agent_output.jsonl`` via the filesystem API, and
    cancellation kills ``run-agent`` (via ``pkill``) *inside* the still-alive
    Sandbox so
    the post-run artifact pull can still capture partial output before the
    Sandbox is terminated. With no hook supplied the run simply blocks until the
    drain thread reports completion.

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

    def run(
        self,
        wd: Path,
        auth: AuthSpec,
        *,
        on_output: Callable[[str], None] | None = None,
        should_cancel: Callable[[], bool] | None = None,
        poll_interval: float = 2.0,
    ) -> float:
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
            # Sandbox by tag even if we are canceled mid-setup, before the
            # supervise loop starts polling should_cancel.
            run_id = os.environ.get("FLARE_RUN_ID")
            if run_id:
                sb.set_tags({"flare-run": run_id})

            def _canceled() -> bool:
                # Treat a hook error as "do not cancel" (mirrors _supervise).
                try:
                    return bool(should_cancel and should_cancel())
                except Exception:
                    log.exception("should_cancel hook failed; treating as no-cancel")
                    return False

            # Cancel checkpoints bracket the long, blocking setup calls
            # (Sandbox.create above, _push_wd below) that run before the
            # supervise loop can poll should_cancel. On cancel we return early;
            # the `finally` terminates the Sandbox, so a Ctrl+C during setup no
            # longer leaks a live Sandbox billing until `timeout`.
            if _canceled():
                return time.time() - start

            self._push_wd(sb, wd, auth)

            if _canceled():
                return time.time() - start

            # Run the baked entrypoint (agent.sh + post-hoc compile) via exec.
            # The idle Sandbox stays *Started* across the exec, so it remains
            # execable for _pull_wd afterward. No PTY: agent.sh writes stream-json
            # to agent_output.jsonl, which a PTY would corrupt.
            #
            # Redirect run-agent's stdin from /dev/null. Modal's exec leaves
            # stdin an open pipe with no EOF, so the agent CLIs block reading
            # it — claude waits 3s then proceeds, but codex/opencode hang
            # indefinitely until the Sandbox times out. `docker run` (no -i)
            # gives stdin immediate EOF, which is why the Docker backend never
            # hit this.
            proc = sb.exec(
                "bash",
                "-c",
                "exec /usr/local/bin/run-agent < /dev/null",
                workdir=REMOTE_WD,
            )

            if on_output is None and should_cancel is None:
                # No-hooks fast path: drain the exec's pipes and block inline
                # (verbatim historical behavior, no supervision thread). Draining
                # is required — if the buffer fills the agent blocks and
                # proc.wait() hangs. Persist stderr for diagnostics.
                for _ in proc.stdout:
                    pass
                stderr = proc.stderr.read()
                proc.wait()
            else:
                # Supervised path: drain the exec's pipes in a background thread
                # (which also signals completion via `done`) so the main thread
                # can run the shared tick loop concurrently.
                done = threading.Event()
                captured: dict[str, str] = {}

                def _drain() -> None:
                    try:
                        for _ in proc.stdout:
                            pass
                        captured["stderr"] = proc.stderr.read()
                        proc.wait()
                    finally:
                        done.set()

                drain = threading.Thread(target=_drain, daemon=True)
                drain.start()
                self._supervise(
                    is_running=lambda: not done.is_set(),
                    read_output=lambda: self._read_remote_output(sb),
                    # Kill the agent process *inside* the sandbox, leaving the
                    # sandbox alive so _pull_wd can still capture partial
                    # artifacts. ContainerProcess has no per-exec kill, and
                    # sb.terminate() here would destroy the sandbox before the
                    # pull. Killing run-agent makes the drain thread's
                    # proc.wait() return, so the loop exits and cancel looks
                    # exactly like normal completion.
                    terminate=lambda: self._kill_agent(sb),
                    on_output=on_output,
                    should_cancel=should_cancel,
                    poll_interval=poll_interval,
                )
                drain.join()
                stderr = captured.get("stderr", "")

            if stderr:
                (wd / "modal_stderr.txt").write_text(stderr)

            self._pull_wd(sb, wd)
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

        return time.time() - start

    def _read_remote_output(self, sb: modal.Sandbox) -> str:
        """Return the current ``agent_output.jsonl`` from the Sandbox, or ``""``.

        Reads via the filesystem API; the file may not exist yet early in a run
        (and a transient read against the live Sandbox may fail), in which case
        an empty snapshot is returned — the next tick self-heals.
        """
        try:
            return sb.filesystem.read_text(f"{REMOTE_WD}/agent_output.jsonl")
        except Exception:
            return ""

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
