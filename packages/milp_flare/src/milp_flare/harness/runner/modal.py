"""Modal compute backend for the FLARE agent container.

Runs the agent in a `Modal <https://modal.com>`_ Sandbox created from a
pre-built named image (see ``milp-flare build-modal-image``). ``modal`` is an
optional dependency, imported lazily so the package installs and the local
Docker backend works without it.
"""

from __future__ import annotations

import io
import os
import tarfile
import tempfile
import threading
import time
from pathlib import Path
from typing import TYPE_CHECKING, Any, ClassVar

from milp_flare.harness.runner.base import AuthSpec, Runner

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
    before the working directory is populated). Instead the runner sets the
    Sandbox's CMD to ``tail -F agent_output.jsonl``. That main process serves
    two purposes: it streams the agent's output to the Modal dashboard Logs
    view (only the main process's stdout reaches the dashboard — an exec'd
    process's output goes to the client only), and, by never exiting, it keeps
    the Sandbox in the *Started* state. The latter matters because the agent
    runs via ``sb.exec`` and the artifacts are tarred back out via another
    ``sb.exec``: once the main process exits the Sandbox is *Finished* and no
    further commands can run. The runner pushes ``wd`` in, runs ``run-agent``
    via ``exec``, pulls the artifacts, then terminates the Sandbox.

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

    def run(self, wd: Path, auth: AuthSpec) -> float:
        modal = _require_modal()

        app = modal.App.lookup(self.app, create_if_missing=True)
        image = modal.Image.from_name(self._image)
        # IS_SANDBOX=1 lets Claude's bypassPermissions mode run as root (Modal
        # ignores the image's USER and runs everything as root).
        secret_dict = {name: os.environ[name] for name in auth.env}
        secret_dict["IS_SANDBOX"] = "1"
        secret = modal.Secret.from_dict(secret_dict)

        # The Sandbox's MAIN process is `tail -F agent_output.jsonl`. Only the
        # main process's stdout reaches the Modal dashboard Logs view (an exec'd
        # process's output streams to the client only), so tailing the agent's
        # stream-json file onto it is what surfaces the agent's output there.
        # Because `tail -F` never exits, it also keeps the Sandbox *Started* so
        # the run-agent exec below — and the tar exec in _pull_wd afterward —
        # can run: once the main process exits the Sandbox is *Finished* and any
        # further sb.exec raises NotFoundError. `tail -F` (capital) follows by
        # name, tolerating the file being created/truncated after launch.
        agent_log = f"{REMOTE_WD}/agent_output.jsonl"
        sb = modal.Sandbox.create(
            "bash",
            "-c",
            f"mkdir -p {REMOTE_WD} && touch {agent_log} && "
            f"exec tail -n +1 -F {agent_log}",
            app=app,
            image=image,
            secrets=[secret],
            cpu=self.cpu,
            memory=self.memory,
            timeout=self.timeout,
        )

        # Drain the main process's stdout in the background so the client-side
        # buffer can't grow unbounded over a long run (the tailed stream-json
        # can be many MB). Dashboard capture is server-side and independent of
        # this drain; the thread ends when terminate() closes the stream.
        def _drain_dashboard_stream() -> None:
            try:
                for _ in sb.stdout:
                    pass
            except Exception:
                pass

        drain = threading.Thread(target=_drain_dashboard_stream, daemon=True)
        drain.start()

        start = time.time()
        try:
            # Tag with the FLARE run ID (parity with the docker --label).
            run_id = os.environ.get("FLARE_RUN_ID")
            if run_id:
                sb.set_tags({"flare-run": run_id})

            self._push_wd(sb, wd, auth)

            # Run the baked entrypoint (agent.sh + post-hoc compile) via exec so
            # the `tail -F` main process stays alive and the Sandbox remains
            # execable for _pull_wd. No PTY: agent.sh writes stream-json to
            # agent_output.jsonl, which a PTY would corrupt.
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
            # Drain the agent exec's own pipes — mostly empty (agent.sh writes
            # the stream to the file, not stdout), but if the buffer fills the
            # agent blocks and proc.wait() hangs. Persist stderr for diagnostics
            # (parity with DockerRunner).
            for _ in proc.stdout:
                pass
            stderr = proc.stderr.read()
            proc.wait()
            if stderr:
                (wd / "modal_stderr.txt").write_text(stderr)

            self._pull_wd(sb, wd)
        finally:
            sb.terminate()
            sb.detach()

        return time.time() - start

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
