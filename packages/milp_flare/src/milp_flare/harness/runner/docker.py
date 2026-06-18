"""Local-Docker compute backend for the FLARE agent container."""

from __future__ import annotations

import os
import subprocess
import time
import uuid
from pathlib import Path
from typing import IO, ClassVar

from milp_flare.harness.runner.base import AuthSpec, Runner, RunnerRun

#: The default name of the Docker image containing the agent environment. This
#: image is expected to be built prior to running FLARE. See :doc:`/installation`.
IMAGE = "flare-agent:latest"


class DockerRun(RunnerRun):
    """Handle for a single in-flight Docker agent run.

    Owns the launched ``docker run`` subprocess and its uniquely named
    container. Cancellation kills the container by name (``docker kill``), which
    is independent of the batch-level ``flare-run`` label backstop.
    """

    def __init__(
        self,
        proc: subprocess.Popen[bytes],
        name: str,
        stderr_file: IO[bytes],
        start_time: float,
    ) -> None:
        self._proc = proc
        self._container = name
        self._stderr_file = stderr_file
        self._start_time = start_time

    def cancel(self) -> None:
        """Stop the run by killing its container; idempotent and thread-safe."""
        subprocess.run(
            ["docker", "kill", self._container],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def wait(self) -> float:
        """Block until the container exits; return wall-clock duration in seconds."""
        self._proc.wait()
        self._stderr_file.close()
        return time.time() - self._start_time


class DockerRunner(Runner):
    """Run the agent in a local Docker container.

    Bind-mounts the agent working directory into the container at
    ``/workspace/wd`` and relies on the image's ``ENTRYPOINT`` to source
    ``agent.sh`` and run the post-hoc Lean compile. This is the default backend
    and preserves FLARE's historical behavior. Each run gets a unique container
    ``--name`` so it can be canceled with ``docker kill`` independently of other
    containers in the same batch.

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

    def start(self, wd: Path, auth: AuthSpec) -> DockerRun:
        name = f"flare-{uuid.uuid4().hex[:12]}"
        stderr_file = open(wd / "docker_stderr.txt", "wb")
        start = time.time()
        proc = subprocess.Popen(
            self._build_docker_cmd(wd, auth, name=name),
            stdout=subprocess.DEVNULL,
            stderr=stderr_file,
            # Without start_new_session, Ctrl+C in the terminal sends SIGINT to
            # both the driver and the agent container, which can cause the
            # container to terminate prematurely. start_new_session=True detaches
            # the subprocess from the terminal's process group.
            start_new_session=True,
        )
        return DockerRun(
            proc=proc, name=name, stderr_file=stderr_file, start_time=start
        )

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
        # Label the container with the FLARE run ID (if present) as a batch-wide
        # cancellation backstop.
        run_id = os.environ.get("FLARE_RUN_ID")
        if run_id:
            cmd += ["--label", f"flare-run={run_id}"]
        # Forward agent credentials (env vars and host config dirs).
        for env_name in auth.env:
            cmd += ["-e", env_name]
        for host_dir, dest in auth.home_dirs:
            # Mount rw so e.g. codex can refresh its access token mid-session.
            cmd += ["-v", f"{host_dir}:{self.home}/{dest}"]
        # Finally, specify the image to run
        cmd += [self._image]
        return cmd
