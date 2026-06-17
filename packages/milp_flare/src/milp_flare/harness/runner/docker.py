"""Local-Docker compute backend for the FLARE agent container."""

from __future__ import annotations

import os
import subprocess
import time
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

    def run(self, wd: Path, auth: AuthSpec) -> float:
        start = time.time()
        proc = subprocess.run(
            self._build_docker_cmd(wd, auth),
            capture_output=True,
            text=True,
            # Without start_new_session, Ctrl+C in the terminal sends SIGINT to both
            # the driver and the agent container, which can cause the container to
            # terminate prematurely. start_new_session=True detaches the subprocess
            # from the terminal's process group.
            start_new_session=True,
        )
        duration = time.time() - start

        if proc.stderr:
            (wd / "docker_stderr.txt").write_text(proc.stderr)

        return duration

    def _build_docker_cmd(self, wd: Path, auth: AuthSpec) -> list[str]:
        """Assemble the full ``docker run`` command from an :class:`AuthSpec`."""
        cmd = ["docker", "run"]
        # Automatically remove the container when it exits
        cmd += ["--rm"]
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
