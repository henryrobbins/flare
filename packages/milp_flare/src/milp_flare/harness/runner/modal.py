from __future__ import annotations

import io
import logging
import os
import tarfile
import tempfile
import time
from collections.abc import Iterator
from pathlib import Path
from typing import TYPE_CHECKING, ClassVar

from milp_flare.harness.runner.base import IMAGE, AgentRun, AuthSpec, Runner

log = logging.getLogger(__name__)

if TYPE_CHECKING:
    import modal
    from modal import Sandbox
    from modal.container_process import ContainerProcess

#: Working directory inside the Sandbox.
REMOTE_WD = "/workspace/wd"


def _require_modal() -> None:
    """Validate that ``modal`` is importable, with an actionable error if not."""
    try:
        import modal  # noqa: F401
    except ModuleNotFoundError as exc:  # pragma: no cover
        raise RuntimeError(
            "the modal compute backend requires the `modal` package; "
            "install it with `pip install milp-flare[modal]`"
        ) from exc


def _tar_dir(src: Path) -> bytes:
    """Tar the contents of ``src`` into an in-memory gzip blob."""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tf:
        tf.add(str(src), arcname=".")
    return buf.getvalue()


class ModalAgentRun(AgentRun):
    """Live handle for a single in-flight Modal Sandbox agent run.

    Parameters
    ----------
    proc : ContainerProcess[str]
        The ContainerProcess handle for the running agent exec.
    sb : Sandbox
        The Sandbox the agent is running in.
    wd : pathlib.Path
        The host working directory where agent artifacts are synced to.
    runner : ModalRunner
        The parent runner.
    start : float
        The wall-clock time when the agent was launched, for duration tracking.
    """

    def __init__(
        self,
        proc: ContainerProcess[str],
        sb: Sandbox,
        wd: Path,
        runner: ModalRunner,
        start: float,
    ) -> None:
        super().__init__(start)
        self._proc = proc
        self._sb = sb
        self._wd = wd
        self._runner = runner

    @property
    def stdout(self) -> Iterator[str]:
        for line in self._proc.stdout:
            yield line.rstrip("\n")

    def cancel(self) -> None:
        # Stop the agent process in the Sandbox, leaving the Sandbox alive
        # so that partial artifacts can be pulled first.
        self._runner._kill_agent(self._sb)

    def _teardown(self) -> None:
        super()._teardown()
        # Killing the agent process kills the stdout pipe which should release
        # the wait() below.
        self._proc.wait()
        # Pull partial artifacts before terminating the Sandbox.
        self._runner._pull_wd(self._sb, self._wd)
        self._runner._terminate(self._sb)


class ModalRunner(Runner):
    """Run the agent in a Modal Sandbox.

    Note that the agent process runs via a :meth:`Sandbox.exec` to allow for
    pushing and pulling the working directory via the filesystem API before and
    after the run, respectively. The logs on the Modal dashboard will not show
    any agent output because only a main process's stdout is captured.

    Parameters
    ----------
    image : str, default :const:`IMAGE`
        The Modal named image to launch. Built via ``milp-flare build-modal-image``;
        see :doc:`/installation`.
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
        image: str = IMAGE,
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

    def start(self, wd: Path, auth: AuthSpec) -> AgentRun:
        _require_modal()
        import modal

        app = modal.App.lookup(self.app, create_if_missing=True)
        image = modal.Image.from_name(self._image)

        # Create a Modal Secret from the AuthSpec environment variables.
        secret_dict: dict[str, str | None] = {
            name: os.environ[name] for name in auth.env
        }
        # IS_SANDBOX=1 lets Claude's bypassPermissions mode run as root (Modal
        # ignores the image's USER and runs everything as root).
        secret_dict["IS_SANDBOX"] = "1"
        # Pin Lean's thread pool to the reserved core count to ensure Lean
        # doesn't oversubscribe causing thrashing from thread count exceeding
        # the available core capacity.
        secret_dict["LEAN_NUM_THREADS"] = str(max(1, int(self.cpu)))
        secret = modal.Secret.from_dict(secret_dict)

        # Create an idle Sandbox with no main process. We must push the working
        # directory before start the agent with exec.
        sb = modal.Sandbox.create(
            app=app,
            image=image,
            secrets=[secret],
            cpu=self.cpu,
            memory=self.memory,
            timeout=self.timeout,
        )

        try:
            # Tag with the FLARE run ID for easy identification.
            run_id = os.environ.get("FLARE_RUN_ID")
            if run_id:
                sb.set_tags({"flare-run": run_id})

            # Push the agent working directory
            self._push_wd(sb, wd, auth)

            # Warm the Lean build cache before the agent starts. Modal lazily
            # pages image layers in on first read, so the first `lake build`
            # inside the Sandbox pays a large cold-read penalty.
            # This requires setting up the .lake symlink inside the Sandbox.
            sb.exec(
                "bash",
                "-c",
                f"ln -sfn /workspace/.lake {REMOTE_WD}/.lake && lake build",
                workdir=REMOTE_WD,
            ).wait()

            # Start the agent-duration clock after push + warmup
            start = time.time()

            # Redirect run-agent's stdin from /dev/null. Modal's exec leaves
            # stdin an open pipe with no EOF, so the agent CLIs block reading
            # it — claude waits 3s then proceeds, but codex/opencode hang
            # indefinitely until the Sandbox times out.
            proc = sb.exec(
                "bash",
                "-c",
                "exec /usr/local/bin/run-agent "
                "< /dev/null "  # redirect stdin from /dev/null
                f"2> {REMOTE_WD}/modal_stderr.txt",  # redirect stderr to a file
                workdir=REMOTE_WD,
            )
        except BaseException:
            # Provisioning failed after the Sandbox was created; release it
            # before propagating so a failed start never leaks compute.
            self._terminate(sb)
            raise
        return ModalAgentRun(proc, sb, wd, self, start)

    def _terminate(self, sb: modal.Sandbox) -> None:
        """Tear down the Sandbox."""
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

        The Sandbox has no per-exec kill, so the running ``run-agent`` is
        terminated with ``pkill``.
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
        """Tar the Sandbox ``wd`` back out and extract it over the host ``wd``."""
        try:
            # Exclude the big image-baked .lake symlink target.
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
