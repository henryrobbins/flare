from __future__ import annotations

import os
import subprocess
import time
import uuid
from collections.abc import Iterator
from pathlib import Path
from typing import IO, ClassVar

from milp_flare.harness.runner.base import IMAGE, AgentRun, AuthSpec, Runner


class DockerAgentRun(AgentRun):
    """Live handle for a single in-flight Docker agent run.

    Parameters
    ----------
    popen : subprocess.Popen[str]
        The Popen handle for the ``docker run`` running container process.
    name : str
        The unique container name for this run, used to target cancellation.
    stderr_f : IO[bytes]
        The file where the container's stderr is being redirected.
    start : float
        The wall-clock time when the container was launched, for duration tracking.
    """

    def __init__(
        self,
        popen: subprocess.Popen[str],
        name: str,
        stderr_f: IO[bytes],
        start: float,
    ) -> None:
        super().__init__(start)
        self._popen = popen
        self._name = name
        self._stderr_f = stderr_f

    @property
    def stdout(self) -> Iterator[str]:
        assert self._popen.stdout is not None
        for line in self._popen.stdout:
            yield line.rstrip("\n")

    def cancel(self) -> None:
        # The agent working directory is bind-mounted into the container, so all
        # partial artifacts are already on the host. Just kill the container.
        subprocess.run(
            ["docker", "kill", self._name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def _teardown(self) -> None:
        super()._teardown()
        # Killing the Docker container kills the process and the stdout pipe
        # which should release the wait() below.
        self._popen.wait()
        self._stderr_f.close()


class DockerRunner(Runner):
    """Run the agent in a local Docker container.

    Parameters
    ----------
    image : str, default :const:`IMAGE`
        The Docker image tag to run. Built via ``milp-flare build-docker-image``;
        see :doc:`/installation`.
    """

    name: ClassVar[str] = "docker"
    home: ClassVar[str] = "/home/agent"

    def __init__(self, image: str = IMAGE) -> None:
        self._image = image

    @property
    def image(self) -> str:
        return self._image

    def start(self, wd: Path, auth: AuthSpec) -> AgentRun:
        # A unique per-run name lets cancel() stop just this container.
        name = f"flare-{uuid.uuid4().hex[:12]}"
        start = time.time()
        # Redirect stderr straight to a file so the undrained pipe can't deadlock
        # the run; stdout stays a pipe we stream line by line. The handle owns
        # the file and closes it on teardown.
        stderr_f = open(wd / "docker_stderr.txt", "wb")
        try:
            popen = subprocess.Popen(
                self._build_docker_cmd(wd, auth, name=name),
                stdout=subprocess.PIPE,
                stderr=stderr_f,
                text=True,
                # Without start_new_session, Ctrl+C in the terminal sends SIGINT
                # to both the driver and the agent container, which can cause the
                # container to terminate prematurely. start_new_session=True
                # detaches the subprocess from the terminal's process group.
                start_new_session=True,
            )
        except BaseException:
            stderr_f.close()
            raise
        return DockerAgentRun(popen, name, stderr_f, start)

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
