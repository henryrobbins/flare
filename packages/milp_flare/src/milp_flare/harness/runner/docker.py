"""Local-Docker compute backend for the FLARE agent container."""

from __future__ import annotations

import os
import subprocess
import time
import uuid
from collections.abc import Callable
from pathlib import Path
from typing import ClassVar

from milp_flare.harness.runner.base import AuthSpec, Runner

#: The default name of the Docker image containing the agent environment. This
#: image is expected to be built prior to running FLARE. See :doc:`/installation`.
IMAGE = "flare-agent:latest"


class DockerRunner(Runner):
    """Run the agent in a local Docker container.

    Bind-mounts the agent working directory into the container at
    ``/workspace/wd`` and relies on the image's ``ENTRYPOINT`` (``run-agent``)
    to source ``agent.sh`` and run the post-hoc Lean compile. This is the
    default backend and preserves FLARE's historical behavior.

    When :meth:`run` is given an ``on_output`` / ``should_cancel`` hook it
    switches from a blocking ``subprocess.run`` to ``subprocess.Popen`` driven
    by the shared :meth:`~milp_flare.harness.runner.base.Runner._supervise` tick
    loop: the container gets a unique ``--name`` so a single run can be canceled
    with ``docker kill`` (independent of the batch ``flare-run`` label), and the
    live ``agent_output.jsonl`` snapshot is read straight off the bind mount.
    With no hook supplied the original blocking path runs verbatim.

    Parameters
    ----------
    image : str, default ``"flare-agent:latest"``
        The Docker image tag to run.
    """

    name: ClassVar[str] = "docker"
    home: ClassVar[str] = "/home/agent"

    def __init__(self, image: str = IMAGE) -> None:
        self._image = image

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
        # No-hooks fast path: identical blocking behavior to before, no ticking.
        if on_output is None and should_cancel is None:
            start = time.time()
            proc = subprocess.run(
                self._build_docker_cmd(wd, auth),
                capture_output=True,
                text=True,
                # Without start_new_session, Ctrl+C in the terminal sends SIGINT
                # to both the driver and the agent container, which can cause the
                # container to terminate prematurely. start_new_session=True
                # detaches the subprocess from the terminal's process group.
                start_new_session=True,
            )
            duration = time.time() - start
            if proc.stderr:
                (wd / "docker_stderr.txt").write_text(proc.stderr)
            return duration

        # Supervised path: a unique container --name enables per-run cancel
        # (`docker kill <name>`), and stdout/stderr are redirected straight to
        # files so the undrained pipes can't deadlock during the run.
        container = f"flare-{uuid.uuid4().hex[:12]}"
        jsonl_path = wd / "agent_output.jsonl"

        def read_output() -> str:
            # The bind mount means the host sees the container's writes live.
            try:
                return jsonl_path.read_text()
            except FileNotFoundError:
                return ""

        def terminate() -> None:
            # Kill the container by name (not the Popen client). Idempotent and
            # safe to re-issue; ignore failures (e.g. already exited).
            subprocess.run(
                ["docker", "kill", container],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

        start = time.time()

        # If a cancel is already pending, don't launch the container at all.
        # (Docker's setup window is tiny — Popen returns at once and the
        # container is named immediately — so the supervise loop's first tick
        # otherwise catches everything; this just avoids a needless launch.)
        if should_cancel is not None:
            try:
                if should_cancel():
                    return time.time() - start
            except Exception:
                pass

        with open(wd / "docker_stderr.txt", "wb") as stderr_f:
            popen = subprocess.Popen(
                self._build_docker_cmd(wd, auth, name=container),
                stdout=subprocess.DEVNULL,
                stderr=stderr_f,
                start_new_session=True,
            )
            self._supervise(
                is_running=lambda: popen.poll() is None,
                read_output=read_output,
                terminate=terminate,
                on_output=on_output,
                should_cancel=should_cancel,
                poll_interval=poll_interval,
            )
            popen.wait()
        return time.time() - start

    def _build_docker_cmd(
        self, wd: Path, auth: AuthSpec, name: str | None = None
    ) -> list[str]:
        """Assemble the full ``docker run`` command from an :class:`AuthSpec`."""
        cmd = ["docker", "run"]
        # Automatically remove the container when it exits
        cmd += ["--rm"]
        # A unique per-run name enables per-run cancel (`docker kill <name>`)
        # without affecting other containers in the same batch.
        if name:
            cmd += ["--name", name]
        # Bind mount the agent's working directory to /workspace/wd in the container
        cmd += ["-v", f"{wd.resolve()}:/workspace/wd"]
        # Label the container with the FLARE run ID (if present)
        run_id = os.environ.get("FLARE_RUN_ID")
        if run_id:
            cmd += ["--label", f"flare-run={run_id}"]
        # Forward agent credentials (env vars and host config dirs).
        for name in auth.env:
            cmd += ["-e", name]
        for host_dir, dest in auth.home_dirs:
            # Mount rw so e.g. codex can refresh its access token mid-session.
            cmd += ["-v", f"{host_dir}:{self.home}/{dest}"]
        # Finally, specify the image to run
        cmd += [self._image]
        return cmd
