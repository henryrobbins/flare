"""Docker-based agent harness.

Spins up a container per pair and dispatches one of claude_code | codex |
opencode via the image's entrypoint. The container is the isolation boundary:
the host pair_dir is bind-mounted at /workspace/out, the agent works inside
/workspace/out/wd, and lake's build artifacts land in /workspace/.lake/
(image overlay, ephemeral). The entrypoint also runs the post-hoc
`lake env lean` compile inside the container and writes result.json back
through the bind mount.

Image is built from the repo root Dockerfile. See AGENTS.md for setup.
"""

import json
import os
import shutil
import subprocess
import time
from pathlib import Path

from src.llm_client import LLMConfig, compute_cost_usd
from src.verify.flare.harness.base import Harness, HarnessRunResult

_HERE = Path(__file__).parent
_SETTINGS_TEMPLATE: str = (_HERE / "templates" / "claude_settings.json").read_text()

_VALID_CLIS = ("claude_code", "codex", "opencode")


def _infer_provider(model: str) -> str:
    if model.startswith("claude"):
        return "anthropic"
    if model.startswith("deepseek"):
        return "deepseek"
    if model.startswith("gemini"):
        return "google"
    return "openai"


class DockerHarness(Harness):
    def __init__(
        self,
        cli: str,
        config: LLMConfig,
        provider: str | None = None,
        image: str = "flare-agent:latest",
    ) -> None:
        if cli not in _VALID_CLIS:
            raise ValueError(f"unknown cli {cli!r}; expected one of {_VALID_CLIS}")
        self.cli = cli
        self.config = config
        self.model = config.model
        self.effort = config.reasoning_effort or "medium"
        self.provider = provider or _infer_provider(config.model)
        self.image = image

    @property
    def name(self) -> str:
        return f"docker_{self.cli}"

    def method_config(self) -> dict:
        return {
            "harness": self.name,
            "cli": self.cli,
            "image": self.image,
            "provider": self.provider,
            "model": self.model,
            "effort": self.effort,
            "max_tokens": self.config.max_tokens,
            "temperature": self.config.temperature,
            "reasoning": self.config.reasoning,
            "reasoning_effort": self.config.reasoning_effort,
        }

    def configure_wd(self, wd: Path, repo_root: Path) -> None:
        # Agent configuration (.claude/, .mcp.json, opencode.json) lives at
        # pair_dir, one level above `wd`, so the host's pair_dir/wd contains
        # ONLY the agent's source files (A/, B/, Reformulation.lean).
        # Image-side symlinks at /workspace/{.claude,.mcp.json,opencode.json}
        # bring them into the agent's cwd.
        pair_dir = wd.parent
        pair_dir.mkdir(parents=True, exist_ok=True)
        wd.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo_root / ".mcp.json", pair_dir / ".mcp.json")
        claude_dir = pair_dir / ".claude"
        claude_dir.mkdir(exist_ok=True)
        skills_src = repo_root / ".claude" / "skills"
        if skills_src.exists():
            shutil.copytree(skills_src, claude_dir / "skills", dirs_exist_ok=True)
        (claude_dir / "settings.json").write_text(_SETTINGS_TEMPLATE)
        if self.cli == "opencode":
            (pair_dir / "opencode.json").write_text(
                json.dumps(self._opencode_config(), indent=2)
            )

    def _opencode_config(self) -> dict:
        """Minimal opencode.json: register the model + lean-lsp MCP server.

        Permissions are intentionally absent — the container is the sandbox
        boundary.
        """
        options: dict = {}
        if self.config.temperature is not None:
            options["temperature"] = self.config.temperature
        if self.config.reasoning:
            if self.provider == "anthropic":
                options["thinking"] = {"type": "adaptive"}
                if self.config.reasoning_effort:
                    options["output_config"] = {
                        "effort": self.config.reasoning_effort
                    }
            elif self.config.reasoning_effort:
                options["reasoningEffort"] = self.config.reasoning_effort
        return {
            "$schema": "https://opencode.ai/config.json",
            "provider": {
                self.provider: {"models": {self.model: {"options": options}}}
            },
            "mcp": {
                "lean-lsp": {
                    "type": "local",
                    "command": ["uvx", "lean-lsp-mcp"],
                    "enabled": True,
                }
            },
        }

    def run(self, prompt: str, wd: Path, jsonl_path: Path) -> HarnessRunResult:
        # The entrypoint reads prompt.txt and writes outputs (jsonl, result.json,
        # compile_log) into /workspace/out. The verifier has already written
        # prompt.txt to pair_dir, so we just bind-mount pair_dir and dispatch.
        pair_dir = wd.parent
        cmd = [
            "docker", "run", "--rm",
            "-v", f"{pair_dir.resolve()}:/workspace/out",
        ]
        cmd += self._credential_args()
        cmd += [
            self.image,
            "--cli", self.cli,
            "--model", self.model,
            "--effort", self.effort,
            "--provider", self.provider,
        ]

        start = time.time()
        # The entrypoint streams agent stdout to /workspace/out/agent_output.jsonl,
        # which is jsonl_path on the host (via the bind mount). We just need to
        # wait for the container and capture stderr for debugging.
        proc = subprocess.run(cmd, capture_output=True, text=True)
        duration = time.time() - start

        if proc.stderr:
            jsonl_path.with_name(f"{self.cli}_stderr.txt").write_text(proc.stderr)

        parsed = self._parse_stream(jsonl_path)
        # Codex doesn't surface per-turn USD; fill from token totals.
        if parsed.get("cost_usd") is None:
            parsed["cost_usd"] = compute_cost_usd(
                self.model, parsed["input_tokens"], parsed["output_tokens"]
            )
        return HarnessRunResult(duration_s=round(duration, 1), **parsed)

    def _credential_args(self) -> list[str]:
        if self.cli == "claude_code":
            # OAuth token from `claude setup-token`, exported in .env.
            return ["-e", "CLAUDE_CODE_OAUTH_TOKEN"]
        if self.cli == "codex":
            # Bill against the ChatGPT subscription by mounting the host's
            # cached OAuth login (~/.codex/auth.json). Mount rw because
            # codex refreshes its access token mid-session; :ro breaks
            # startup with "failed to initialize in-process app-server
            # client". OPENAI_API_KEY / CODEX_API_KEY are deliberately
            # NOT passed through so codex can't fall through to API-key
            # auth and bill against credits.
            codex_dir = Path.home() / ".codex"
            if not codex_dir.exists():
                raise RuntimeError(
                    "codex harness requires ~/.codex from `codex login`"
                )
            return ["-v", f"{codex_dir}:/home/agent/.codex"]
        if self.cli == "opencode":
            # Pass through provider API keys that OpenCode reads from env.
            args = []
            for key in ("ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GOOGLE_API_KEY",
                        "DEEPSEEK_API_KEY"):
                if key in os.environ:
                    args += ["-e", key]
            return args
        return []

    def _parse_stream(self, jsonl_path: Path) -> dict:
        if not jsonl_path.exists():
            return {"stop_reason": None, "input_tokens": 0, "output_tokens": 0,
                    "cost_usd": None}
        lines = jsonl_path.read_text().splitlines()
        if self.cli == "claude_code":
            return _parse_claude_code(lines)
        if self.cli == "codex":
            return _parse_codex(lines)
        if self.cli == "opencode":
            return _parse_opencode(lines)
        raise AssertionError(f"unreachable: {self.cli}")


def _parse_claude_code(lines: list[str]) -> dict:
    """Parse `claude -p --output-format stream-json` output.

    Tokens, stop_reason, and total_cost_usd live on the final `result` event.
    """
    input_tokens = 0
    output_tokens = 0
    stop_reason: str | None = None
    cost_usd: float | None = None

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

    return {"stop_reason": stop_reason, "input_tokens": input_tokens,
            "output_tokens": output_tokens, "cost_usd": cost_usd}


def _parse_codex(lines: list[str]) -> dict:
    """Parse `codex exec --json` output: per-turn usage on `turn.completed`."""
    input_tokens = 0
    output_tokens = 0
    stop_reason: str | None = None

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") != "turn.completed":
            continue
        usage = event.get("usage") or {}
        it = (usage.get("input_tokens") or usage.get("inputTokens")
              or usage.get("prompt_tokens") or 0)
        ot = (usage.get("output_tokens") or usage.get("outputTokens")
              or usage.get("completion_tokens") or 0)
        if isinstance(it, int):
            input_tokens += it
        if isinstance(ot, int):
            output_tokens += ot
        sr = event.get("stop_reason") or event.get("finish_reason")
        if isinstance(sr, str):
            stop_reason = sr

    return {"stop_reason": stop_reason, "input_tokens": input_tokens,
            "output_tokens": output_tokens, "cost_usd": None}


def _parse_opencode(lines: list[str]) -> dict:
    """Parse `opencode run --format json` output: per-step deltas on step_finish.

    `tokens.input` is uncached input; cached prompt tokens appear in
    `tokens.cache.{write,read}` and are folded into input_tokens.
    """
    input_tokens = 0
    output_tokens = 0
    cost_usd: float | None = None
    stop_reason: str | None = None

    def _as_int(x) -> int:
        return x if isinstance(x, int) else 0

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") != "step_finish":
            continue
        part = event.get("part") or {}
        tokens = part.get("tokens") or {}
        cache = tokens.get("cache") or {}
        input_tokens += (_as_int(tokens.get("input"))
                         + _as_int(cache.get("write"))
                         + _as_int(cache.get("read")))
        output_tokens += _as_int(tokens.get("output"))
        c = part.get("cost")
        if isinstance(c, (int, float)):
            cost_usd = (cost_usd or 0.0) + float(c)
        r = part.get("reason")
        if isinstance(r, str):
            stop_reason = r

    return {"stop_reason": stop_reason, "input_tokens": input_tokens,
            "output_tokens": output_tokens, "cost_usd": cost_usd}
