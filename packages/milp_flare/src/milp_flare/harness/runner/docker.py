"""Local-Docker compute backend for the FLARE agent container."""

from __future__ import annotations

import os
import subprocess
import time
import uuid
from collections.abc import Iterator
from pathlib import Path
from typing import IO, ClassVar

from milp_flare.harness.runner.base import AgentRun, AuthSpec, Runner

#: The default name of the Docker image containing the agent environment. This
#: image is expected to be built prior to running FLARE. See :doc:`/installation`.
IMAGE = "flare-agent:latest"


class DockerAgentRun(AgentRun):
    """Live handle over a ``docker run`` container's ``stdout``.

    The container is launched with a unique ``--name`` so :meth:`cancel` can
    stop just this run (``docker kill <name>``) without touching other
    containers in the same batch. The agent's working directory is bind-mounted,
    so the container's writes (Lean files, ``result.json``, ``compile_log.txt``)
    are already visible on the host — there is nothing to pull back.
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
        # The bind mount means the container's stdout pipe is the live agent
        # stream; yield it line by line until the container exits (EOF).
        assert self._popen.stdout is not None
        for line in self._popen.stdout:
            yield line.rstrip("\n")

    def cancel(self) -> None:
        # Kill the container by name (the durable address), not the Popen
        # client. Idempotent and safe to re-issue from any thread; ignore
        # failures (e.g. already exited). The agent's partial Lean files are
        # already on the host via the bind mount.
        subprocess.run(
            ["docker", "kill", self._name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def _teardown(self) -> None:
        # Ensure the container is stopped (a no-op if it already exited), reap
        # it, and close the stderr sink. The bind mount means artifacts are
        # already on the host, so there is nothing to pull back.
        self.cancel()
        self._popen.wait()
        self._stderr_f.close()


class DockerRunner(Runner):
    """Run the agent in a local Docker container.

    Bind-mounts the agent working directory into the container at
    ``/workspace/wd`` and relies on the image's ``ENTRYPOINT`` (``run-agent``)
    to source ``agent.sh`` and run the post-hoc Lean compile. The agent CLI
    writes its ``stream-json`` event log to ``stdout``, which :meth:`run`
    exposes as the live :class:`DockerAgentRun` stream; the caller rebuilds
    ``agent_output.jsonl`` on the host from it.

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

    def start(self, wd: Path, auth: AuthSpec) -> AgentRun:
        # A unique per-run name lets cancel() stop just this container.
        container = f"flare-{uuid.uuid4().hex[:12]}"
        start = time.time()
        # Redirect stderr straight to a file so the undrained pipe can't deadlock
        # the run; stdout stays a pipe we stream line by line. The handle owns
        # the file and closes it on teardown.
        stderr_f = open(wd / "docker_stderr.txt", "wb")
        try:
            popen = subprocess.Popen(
                self._build_docker_cmd(wd, auth, name=container),
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
        return DockerAgentRun(popen, container, stderr_f, start)

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
