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

  - Anthropic (claude-*): `thinking: {type: adaptive}` plus
                          `output_config: {effort: <effort>}` (newer Claude
                          models reject the legacy `type: enabled` +
                          `budgetTokens` form)
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
    # Intentionally NOT forwarding cfg.max_tokens. LLMConfig.max_tokens is a
    # per-response cap aimed at single-shot LLM clients; under an agent
    # harness, the same cap throttles every turn, and with reasoning on a
    # small value (e.g. the LLMConfig default 2048) gets eaten by thinking
    # tokens before the model emits its tool call — the response truncates
    # mid-stream, no step_finish lands, and the run stalls. Let OpenCode
    # apply the model's native output limit instead.

    if cfg.reasoning:
        if provider == "anthropic":
            # Newer Claude models (Opus 4.7, etc.) reject the legacy
            # `thinking.type: enabled` + `budgetTokens` form; they require
            # adaptive thinking with `output_config.effort` instead. See
            # https://github.com/anomalyco/opencode/issues/22863.
            options["thinking"] = {"type": "adaptive"}
            if cfg.reasoning_effort:
                options["output_config"] = {"effort": cfg.reasoning_effort}
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
        # `--dir` pins OpenCode to the isolated wd. Without it OpenCode walks
        # upward from cwd to the enclosing git worktree root and operates
        # there, so the agent ends up looking at the FLARE monorepo instead
        # of the per-pair wd.
        cmd = [
            "opencode",
            "run",
            "--dir",
            str(wd.resolve()),
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
    """Parse `opencode run --format json` stream output.

    OpenCode emits one JSON event per line. The events that carry usage
    metrics are `step_finish` parts with the shape::

        {"type": "step_finish",
         "part": {"reason": "...",
                  "tokens": {"input": N, "output": M, "reasoning": R,
                             "total": T, "cache": {"read": ..., "write": ...}},
                  "cost": <usd>}}

    `tokens.input` / `tokens.output` are per-step deltas and `cost` is the
    per-step spend. Note that `tokens.input` is *uncached* input only;
    cached prompt tokens appear under `tokens.cache.{write,read}`. We fold
    all three into `input_tokens` so the total matches what Anthropic
    actually billed for prompt tokens. We take the last step's `reason` as
    the run-level stop_reason. Missing fields fall back to 0 / None.
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
        input_tokens += (
            _as_int(tokens.get("input"))
            + _as_int(cache.get("write"))
            + _as_int(cache.get("read"))
        )
        output_tokens += _as_int(tokens.get("output"))

        c = part.get("cost")
        if isinstance(c, (int, float)):
            cost_usd = (cost_usd or 0.0) + float(c)

        r = part.get("reason")
        if isinstance(r, str):
            stop_reason = r

    return {
        "stop_reason": stop_reason,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cost_usd": cost_usd,
    }
