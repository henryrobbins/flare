from milp_flare.harness.base import Harness, HarnessRunResult
from milp_flare.harness.claude_code import ClaudeCodeHarness
from milp_flare.harness.codex import CodexHarness
from milp_flare.harness.config import HarnessConfig, compute_cost_usd
from milp_flare.harness.opencode import OpenCodeHarness

HARNESSES: dict[str, type[Harness]] = {
    "claude_code": ClaudeCodeHarness,
    "codex": CodexHarness,
    "opencode": OpenCodeHarness,
}

__all__ = [
    "HARNESSES",
    "ClaudeCodeHarness",
    "CodexHarness",
    "Harness",
    "HarnessConfig",
    "HarnessRunResult",
    "OpenCodeHarness",
    "compute_cost_usd",
]
