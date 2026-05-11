from src.verify.flare.harness.base import Harness, HarnessRunResult
from src.verify.flare.harness.claude_code import ClaudeCodeHarness
from src.verify.flare.harness.codex import CodexHarness
from src.verify.flare.harness.opencode import OpenCodeHarness

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
    "HarnessRunResult",
    "OpenCodeHarness",
]
