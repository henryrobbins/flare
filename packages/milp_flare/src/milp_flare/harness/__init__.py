from milp_flare.harness.base import Harness, HarnessRun, HarnessRunResult
from milp_flare.harness.claude_code import ClaudeCodeHarness
from milp_flare.harness.codex import CodexHarness
from milp_flare.harness.opencode import OpenCodeHarness
from milp_flare.harness.runner import (
    RUNNERS,
    AuthSpec,
    DockerRunner,
    Runner,
    make_runner,
)

HARNESSES: dict[str, type[Harness]] = {
    "claude_code": ClaudeCodeHarness,
    "codex": CodexHarness,
    "opencode": OpenCodeHarness,
}

__all__ = [
    "HARNESSES",
    "RUNNERS",
    "AuthSpec",
    "ClaudeCodeHarness",
    "CodexHarness",
    "DockerRunner",
    "Harness",
    "HarnessRun",
    "HarnessRunResult",
    "OpenCodeHarness",
    "Runner",
    "make_runner",
]
