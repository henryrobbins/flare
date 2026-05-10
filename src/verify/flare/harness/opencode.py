"""OpenCode (https://opencode.ai/) agent harness.

Permissions in OpenCode subsume the filesystem-sandbox role of Claude Code's
sandbox config: setting `external_directory: deny` plus path-pattern allow
lists on `read`/`edit`/`glob`/`grep` confines the agent to the working
directory without an OS-level sandbox. We mirror the Claude Code behavior of
denying everything by default and explicitly allowlisting the commands FLARE
needs (`lake env lean`, `lake build`, basic file viewers).

Models are configured via the same `LLMConfig` used by other verifiers (see
`src/llm_client/base.py`). The harness translates the LLMConfig into the
nested `provider.<id>.models.<id>.options` block that OpenCode expects:

  - Anthropic (claude-*): `thinking: { type: enabled, budgetTokens: N }`
  - OpenAI (gpt-*):       `reasoningEffort: <low|medium|high|xhigh>`
  - DeepSeek (deepseek-*): `reasoningEffort: <high|max>`
  - Google (gemini-*):    `reasoningEffort: <low|medium|high>`

See https://opencode.ai/docs/models/ for the exact schema.
"""

import copy
import json
import shutil
import subprocess
import time
from pathlib import Path

from src.llm_client import LLMConfig
from src.verify.flare.harness.base import Harness, HarnessRunResult

_HERE = Path(__file__).parent
_OPENCODE_TEMPLATE: dict = json.loads(
    (_HERE / "templates" / "opencode.json").read_text()
)

# Effort -> budgetTokens mapping for Anthropic adaptive thinking. OpenCode
# expects a concrete token budget rather than a symbolic effort, so we
# translate using the same buckets the rest of the codebase already exposes.
_ANTHROPIC_BUDGET_TOKENS = {
    "low": 4000,
    "medium": 8000,
    "high": 16000,
    "xhigh": 32000,
    "max": 64000,
}


def _infer_provider(model: str) -> str:
    if model.startswith("claude"):
        return "anthropic"
    if model.startswith("deepseek"):
        return "deepseek"
    if model.startswith("gemini"):
        return "google"
    return "openai"


def _model_options(provider: str, cfg: LLMConfig) -> dict:
    """Translate an LLMConfig into the OpenCode `options` block for a model."""
    options: dict = {}
    if cfg.temperature is not None:
        options["temperature"] = cfg.temperature
    if cfg.max_tokens:
        options["maxTokens"] = cfg.max_tokens

    if cfg.reasoning:
        if provider == "anthropic":
            budget = _ANTHROPIC_BUDGET_TOKENS.get(cfg.reasoning_effort or "medium")
            if budget is None:
                raise ValueError(
                    f"unknown anthropic reasoning_effort {cfg.reasoning_effort!r};"
                    f" expected one of {sorted(_ANTHROPIC_BUDGET_TOKENS)}"
                )
            options["thinking"] = {"type": "enabled", "budgetTokens": budget}
        else:
            # OpenAI / DeepSeek / Google all accept `reasoningEffort` per the
            # OpenCode docs. Pass the user's symbolic effort straight through.
            if cfg.reasoning_effort:
                options["reasoningEffort"] = cfg.reasoning_effort

    return options


def _config_for(wd: Path, provider: str, cfg: LLMConfig) -> dict:
    """Render the opencode.json template for a specific working directory."""
    out = copy.deepcopy(_OPENCODE_TEMPLATE)
    wd_abs = str(wd.resolve())

    def substitute(node):
        if isinstance(node, dict):
            return {substitute(k): substitute(v) for k, v in node.items()}
        if isinstance(node, list):
            return [substitute(x) for x in node]
        if isinstance(node, str):
            return node.replace("<<WD_ABS>>", wd_abs)
        return node

    out = substitute(out)

    options = _model_options(provider, cfg)
    if options:
        out.setdefault("provider", {}).setdefault(provider, {}).setdefault(
            "models", {}
        )[cfg.model] = {"options": options}

    return out


class OpenCodeHarness(Harness):
    def __init__(self, config: LLMConfig, provider: str | None = None) -> None:
        self.config = config
        self.provider = provider or _infer_provider(config.model)
        # `provider/model_id` is what OpenCode's --model flag expects.
        self.model_id = f"{self.provider}/{config.model}"

    @property
    def name(self) -> str:
        return "opencode"

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
        # OpenCode discovers skills directly from .claude/skills/ — no rename
        # needed. We reuse the same skill tree the Claude Code harness uses.
        claude_dst = wd / ".claude"
        claude_dst.mkdir(exist_ok=True)
        skills_src = repo_root / ".claude" / "skills"
        if skills_src.exists():
            shutil.copytree(skills_src, claude_dst / "skills", dirs_exist_ok=True)

        cfg = _config_for(wd, self.provider, self.config)
        (wd / "opencode.json").write_text(json.dumps(cfg, indent=2))

    def run(self, prompt: str, wd: Path, jsonl_path: Path) -> HarnessRunResult:
        cmd = [
            "opencode",
            "run",
            "--format",
            "json",
            "--model",
            self.model_id,
            prompt,
        ]

        start = time.time()
        stdout_lines: list[str] = []

        with jsonl_path.open("w") as jsonl_f:
            with subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=wd,
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
            jsonl_path.with_name("opencode_stderr.txt").write_text(stderr)

        parsed = _parse_stream(stdout_lines)
        return HarnessRunResult(duration_s=round(duration, 1), **parsed)


def _parse_stream(lines: list[str]) -> dict:
    """Best-effort parse of `opencode run --format json` stream output.

    OpenCode's event schema is not as load-bearing here as Claude's `result`
    event — we accumulate token counts across any object that exposes them
    and pick up `total_cost_usd` / `stop_reason` from whichever event carries
    them. Missing fields fall back to 0 / None.
    """
    input_tokens = 0
    output_tokens = 0
    stop_reason: str | None = None
    cost_usd: float | None = None

    def harvest(obj):
        nonlocal input_tokens, output_tokens, stop_reason, cost_usd
        if not isinstance(obj, dict):
            return
        usage = obj.get("usage")
        if isinstance(usage, dict):
            it = usage.get("input_tokens") or usage.get("inputTokens")
            ot = usage.get("output_tokens") or usage.get("outputTokens")
            if isinstance(it, int):
                input_tokens = max(input_tokens, it)
            if isinstance(ot, int):
                output_tokens = max(output_tokens, ot)
        for k in ("total_cost_usd", "totalCostUsd", "cost", "cost_usd"):
            v = obj.get(k)
            if isinstance(v, (int, float)):
                cost_usd = float(v)
                break
        for k in ("stop_reason", "stopReason", "finish_reason", "finishReason"):
            v = obj.get(k)
            if isinstance(v, str):
                stop_reason = v
                break
        for v in obj.values():
            if isinstance(v, (dict, list)):
                walk(v)

    def walk(node):
        if isinstance(node, dict):
            harvest(node)
        elif isinstance(node, list):
            for x in node:
                walk(x)

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        walk(obj)

    return {
        "stop_reason": stop_reason,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cost_usd": cost_usd,
    }
