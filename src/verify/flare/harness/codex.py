"""OpenAI Codex CLI agent harness (https://developers.openai.com/codex/).

Runs `codex exec --json` against a per-pair working directory with a
project-local `.codex/config.toml` that pins the model, restricts writes
to `wd`, disables network, and registers the lean-lsp MCP server. Skills
are copied into `wd/.agents/skills/` (Codex's discovery path).

Sandboxing here is weaker than Claude Code's read denylist — Codex's
`sandbox_mode = "workspace-write"` only constrains writes (to
`writable_roots`) and network. Reads outside `wd` are not blocked (see
openai/codex#2847; the new `[permissions]` profile system in 0.130 is
not yet stable enough to rely on). This matches the trust model
accepted for OpenCodeHarness.

Auth: forces the cached ChatGPT subscription login (`~/.codex/auth.json`)
so usage bills against the ChatGPT plan rather than API credits, mirroring
the Claude Code harness's `ANTHROPIC_API_KEY` strip. We do this two ways:
1) `forced_login_method = "chatgpt"` in the per-wd `config.toml`, and
2) stripping `OPENAI_API_KEY` / `CODEX_API_KEY` from the subprocess env so
   Codex can't fall through to API-key auth even if the config knob fails.

Models are configured via the same `LLMConfig` used by other verifiers
(see `src/llm_client/base.py`). When `cfg.reasoning` is true, the
`reasoning_effort` is passed through verbatim as `model_reasoning_effort`.
"""

import json
import os
import shutil
import subprocess
import time
from pathlib import Path

from src.llm_client import LLMConfig
from src.verify.flare.harness.base import Harness, HarnessRunResult

_HERE = Path(__file__).parent
_CONFIG_TEMPLATE: str = (_HERE / "templates" / "codex_config.toml").read_text()


def _render_config_toml(wd: Path, cfg: LLMConfig) -> str:
    # Codex disallows `model_provider` in project-local config (it warns and
    # ignores), so we only emit `model` plus the reasoning effort; provider
    # selection has to happen via user-level ~/.codex/config.toml or a CLI
    # --config override.
    effort_line = (
        f'model_reasoning_effort = "{cfg.reasoning_effort}"'
        if cfg.reasoning and cfg.reasoning_effort
        else ""
    )
    return (
        _CONFIG_TEMPLATE.replace("<<WD_ABS>>", str(wd.resolve()))
        .replace("<<MODEL>>", cfg.model)
        .replace("<<EFFORT_LINE>>", effort_line)
    )


class CodexHarness(Harness):
    def __init__(self, config: LLMConfig, provider: str | None = None) -> None:
        self.config = config
        # Codex's `model_provider` defaults to "openai"; user can override.
        self.provider = provider or "openai"

    @property
    def name(self) -> str:
        return "codex"

    def method_config(self) -> dict:
        return {
            "harness": self.name,
            "provider": self.provider,
            "model": self.config.model,
            "max_tokens": self.config.max_tokens,
            "temperature": self.config.temperature,
            "reasoning": self.config.reasoning,
            "reasoning_effort": self.config.reasoning_effort,
        }

    def configure_wd(self, wd: Path, repo_root: Path) -> None:
        # Codex looks for skills in .agents/skills/, not .claude/skills/.
        agents_dst = wd / ".agents" / "skills"
        skills_src = repo_root / ".claude" / "skills"
        if skills_src.exists():
            shutil.copytree(skills_src, agents_dst, dirs_exist_ok=True)

        codex_dir = wd / ".codex"
        codex_dir.mkdir(parents=True, exist_ok=True)
        (codex_dir / "config.toml").write_text(
            _render_config_toml(wd, self.config)
        )

    def run(self, prompt: str, wd: Path, jsonl_path: Path) -> HarnessRunResult:
        # Don't pass --ignore-user-config: despite the name, Codex applies it
        # to ALL config.toml files including the project-local one we just
        # wrote into wd/.codex/, so MCP servers + sandbox_mode get dropped.
        # User-level ~/.codex/config.toml leaking in is fine — our project
        # config overrides model and the auth env-strip handles the rest.
        # `--sandbox workspace-write` is repeated on the CLI as
        # belt-and-suspenders against the agent perceiving a read-only env.
        cmd = [
            "codex",
            "exec",
            "--json",
            "--skip-git-repo-check",
            "--sandbox",
            "workspace-write",
            prompt,
        ]

        # Force ChatGPT-subscription auth: without these env vars Codex falls
        # back to the cached ChatGPT login (~/.codex/auth.json), so usage
        # bills against the subscription rather than API credits. Mirrors
        # the ClaudeCodeHarness ANTHROPIC_API_KEY strip.
        subprocess_env = {
            k: v
            for k, v in os.environ.items()
            if k not in ("OPENAI_API_KEY", "CODEX_API_KEY")
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
            jsonl_path.with_name("codex_stderr.txt").write_text(stderr)

        parsed = _parse_stream(stdout_lines)
        return HarnessRunResult(duration_s=round(duration, 1), **parsed)


def _parse_stream(lines: list[str]) -> dict:
    """Parse `codex exec --json` stream output.

    Codex emits JSON Lines events including `thread.started`,
    `turn.completed`, and `item.completed`. Token usage and stop reason
    live on `turn.completed`. We sum per-turn token counts and take the
    last turn's stop reason. Codex doesn't surface a USD spend per turn,
    so `cost_usd` stays None.

    Field names are picked defensively because the exact schema isn't
    fully nailed down in the public docs — we try `usage.input_tokens` /
    `inputTokens` / `prompt_tokens` and the corresponding output forms.
    """
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
        it = (
            usage.get("input_tokens")
            or usage.get("inputTokens")
            or usage.get("prompt_tokens")
            or 0
        )
        ot = (
            usage.get("output_tokens")
            or usage.get("outputTokens")
            or usage.get("completion_tokens")
            or 0
        )
        if isinstance(it, int):
            input_tokens += it
        if isinstance(ot, int):
            output_tokens += ot

        sr = event.get("stop_reason") or event.get("finish_reason")
        if isinstance(sr, str):
            stop_reason = sr

    return {
        "stop_reason": stop_reason,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cost_usd": None,
    }
