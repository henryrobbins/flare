"""Claude Code agent harness."""

import copy
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

from src.llm_client import LLMConfig
from src.verify.flare.harness.base import Harness, HarnessRunResult

_HERE = Path(__file__).parent
_SETTINGS_TEMPLATE: dict = json.loads(
    (_HERE / "templates" / "claude_settings.json").read_text()
)

# We use a combination of sandboxing and permissions to restrict the agent
# to only read/write files within its working directory (wd). See the current
# documentation for details:
#
# https://code.claude.com/docs/en/sandboxing
# https://code.claude.com/docs/en/permissions
#
# Sandboxing only applies to the Bash tool. We only apply restrictions to
# the filesystem. We deny read/write to both ~/ (home directory) and the
# repo root. We then allow read/write specifically to the wd. In the sandbox
# configuration, the allow list overrides the deny list. Lastly, we must
# explicitly disable `allowUnsandboxedCommands` to prevent bypassing.
#
# To prevent read/write for other tools (e.g., Read, Write), we must use
# the permissions setting. We run claude with `--permission-mode dontAsk` so
# that it doesn't prompt and auto-denies anything outside permissions.allow.
# We manually specify all allowed commands in `settings.json`. This is a
# comprehensive and sufficient list for the required task.


def _settings_for(wd: Path, repo_root: Path) -> dict:
    settings = copy.deepcopy(_SETTINGS_TEMPLATE)
    wd_abs = str(wd.resolve())
    repo_abs = str(repo_root.resolve())
    # `wd/.lake/packages` is symlinked to `repo_root/.lake/packages` so the
    # wd shares prebuilt mathlib oleans. The symlink resolves outside wd to
    # a path under repo_abs, so without an explicit allow lake's URL-check
    # reads (e.g. mathlib's `.git/config`) fail under denyRead and lake
    # then tries to reclone, which then fails on denyWrite — neither path
    # finishes a build. Allowing the resolved package path lets
    # `Bash(lake build:*)` actually work for the agent.
    pkgs_abs = str((repo_root / ".lake" / "packages").resolve())
    fs = settings["sandbox"]["filesystem"]
    fs["denyRead"].append(repo_abs)
    fs["denyWrite"].append(repo_abs)
    fs["allowRead"].append(wd_abs)
    fs["allowRead"].append(pkgs_abs)
    fs["allowWrite"].append(wd_abs)
    return settings


class ClaudeCodeHarness(Harness):
    def __init__(self, config: LLMConfig) -> None:
        self.config = config
        self.model = config.model
        self.effort = config.reasoning_effort or "medium"

    @property
    def name(self) -> str:
        return "claude_code"

    def method_config(self) -> dict:
        return {"harness": self.name, "model": self.model, "effort": self.effort}

    def configure_wd(self, wd: Path, repo_root: Path) -> None:
        # Claude Code auto-discovers .mcp.json at the working directory root.
        shutil.copy2(repo_root / ".mcp.json", wd / ".mcp.json")

        claude_dst = wd / ".claude"
        claude_dst.mkdir(exist_ok=True)
        skills_src = repo_root / ".claude" / "skills"
        if skills_src.exists():
            shutil.copytree(skills_src, claude_dst / "skills", dirs_exist_ok=True)
        settings = _settings_for(wd, repo_root)
        (claude_dst / "settings.json").write_text(json.dumps(settings, indent=2))

    def run(self, prompt: str, wd: Path, jsonl_path: Path) -> HarnessRunResult:
        settings_path = wd / ".claude" / "settings.json"
        cmd = [
            "claude",
            "-p",
            prompt,
            "--output-format",
            "stream-json",
            "--verbose",
            "--permission-mode",
            "dontAsk",  # auto-deny anything not in permissions.allow
            "--settings",
            str(settings_path.resolve()),
            "--model",
            self.model,
            "--effort",
            self.effort,
        ]
        # Strip ANTHROPIC_API_KEY so claude uses the Claude.ai plan (OAuth
        # session) rather than API credits, with automatic extra-usage overage.
        subprocess_env = {
            k: v for k, v in os.environ.items() if k != "ANTHROPIC_API_KEY"
        }

        start = time.time()
        stdout_lines: list[str] = []

        with jsonl_path.open("w") as jsonl_f:
            with subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=wd,
                env=subprocess_env,
            ) as proc:
                assert proc.stdout is not None
                for line in proc.stdout:
                    jsonl_f.write(line)
                    jsonl_f.flush()
                    stdout_lines.append(line)
                stderr = proc.stderr.read() if proc.stderr else ""
                proc.wait()

        duration = time.time() - start

        if stderr:
            jsonl_path.with_name("claude_stderr.txt").write_text(stderr)

        parsed = _parse_stream(stdout_lines)
        return HarnessRunResult(duration_s=round(duration, 1), **parsed)


def _parse_stream(lines: list[str]) -> dict:
    input_tokens = 0
    output_tokens = 0
    stop_reason = None
    cost_usd = None

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        if obj.get("type") == "result":
            stop_reason = obj.get("stop_reason")
            cost_usd = obj.get("total_cost_usd")
            usage = obj.get("usage", {})
            input_tokens = usage.get("input_tokens", input_tokens)
            output_tokens = usage.get("output_tokens", output_tokens)

    return {
        "stop_reason": stop_reason,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cost_usd": cost_usd,
    }
