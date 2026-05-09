import json
import random
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Callable, TypeVar

T = TypeVar("T")

# HTTP status codes worth retrying on (transient server / rate limit issues).
# 400 in case prompt is accidentally flagged as potentially violating the usage policy
_RETRYABLE_STATUS = {408, 425, 429, 500, 502, 503, 504, 529, 400}


def _with_retry(fn: Callable[[], T], max_attempts: int = 4) -> T:
    """Run fn() with exponential backoff on transient API errors."""
    last_exc: Exception | None = None
    for attempt in range(max_attempts):
        try:
            return fn()
        except Exception as e:
            status = getattr(e, "status_code", None)
            cls_name = type(e).__name__
            transient = status in _RETRYABLE_STATUS or any(
                k in cls_name
                for k in ("Connection", "Timeout", "RateLimit", "InternalServer")
            )
            if not transient or attempt == max_attempts - 1:
                raise
            sleep = (2**attempt) + random.uniform(0, 0.5)
            time.sleep(sleep)
            last_exc = e
    assert last_exc is not None
    raise last_exc


# Cost per million tokens (input, output). Used to compute cost_usd for direct
# API calls. Update when model pricing changes.
# https://platform.claude.com/docs/en/about-claude/pricing
# https://developers.openai.com/api/docs/pricing
_COST_PER_MTOK: dict[str, tuple[float, float]] = {
    "claude-opus-4-7": (5.0, 25.0),
    "claude-opus-4-6": (5.0, 25.0),
    "claude-sonnet-4-6": (3.0, 15.0),
    "claude-sonnet-4-5": (3.0, 15.0),
    "claude-haiku-4-5": (1, 5.0),
    "gpt-4.1": (2.0, 8.0),
    "gpt-4o": (2.5, 10.0),
    "gpt-4o-mini": (0.15, 0.60),
    "gpt-5.5": (5.0, 30.0),
    "gpt-5.4": (2.5, 15.0),
    "gpt-5.4-mini": (0.75, 4.5),
    "gpt-5.4-nano": (0.20, 1.25),
    "deepseek-v4-pro": (1.74, 3.48),
    "deepseek-v4-flash": (0.14, 0.28),
}


def compute_cost_usd(model: str, input_tokens: int, output_tokens: int) -> float | None:
    """Return estimated cost in USD, or None if the model isn't in the pricing table."""
    entry = _COST_PER_MTOK.get(model)
    if entry is None:
        return None
    input_price, output_price = entry
    return (input_tokens * input_price + output_tokens * output_price) / 1_000_000


@dataclass
class LLMConfig:
    model: str
    max_tokens: int = 2048
    temperature: float | None = None
    reasoning: bool = False
    # Anthropic: thinking budget in tokens.
    reasoning_tokens: int | None = None
    # OpenAI Responses API: "minimal" | "low" | "medium" | "high" | "xhigh"
    # (model-dependent). Defaults to "medium" when reasoning is enabled.
    reasoning_effort: str | None = None

    @classmethod
    def from_dict(cls, d: dict) -> "LLMConfig":
        return cls(**d)


def make_client(spec: dict) -> "LLMClient":
    """Build an LLMClient from a dict spec.

    `provider` (one of "anthropic", "openai", "deepseek") may be set
    explicitly; otherwise it's inferred from the model name prefix.
    All other keys are forwarded to LLMConfig.
    """
    spec = dict(spec)
    provider = spec.pop("provider", None)
    config = LLMConfig.from_dict(spec)
    if provider is None:
        if config.model.startswith("claude"):
            provider = "anthropic"
        elif config.model.startswith("deepseek"):
            provider = "deepseek"
        else:
            provider = "openai"
    if provider == "anthropic":
        return AnthropicClient(config)
    if provider == "openai":
        return OpenAIClient(config)
    if provider == "deepseek":
        return DeepSeekClient(config)
    raise ValueError(f"unknown provider: {provider!r}")


class LLMClient(ABC):
    @property
    @abstractmethod
    def config(self) -> LLMConfig:
        pass

    @abstractmethod
    def complete(self, system: str, user: str) -> str:
        pass

    @abstractmethod
    def complete_json_with_usage(
        self, system: str, user: str, schema: dict
    ) -> tuple[dict, dict]:
        """Returns (parsed_json, usage) where usage has input_tokens and output_tokens."""
        pass

    def complete_json(self, system: str, user: str, schema: dict) -> dict:
        result, _ = self.complete_json_with_usage(system, user, schema)
        return result


class AnthropicClient(LLMClient):
    def __init__(self, config: LLMConfig) -> None:
        import anthropic

        self._client = anthropic.Anthropic()
        self._config = config

    @property
    def config(self) -> LLMConfig:
        return self._config

    def _build_kwargs(self) -> dict:
        kwargs: dict = {
            "model": self._config.model,
            "max_tokens": self._config.max_tokens,
        }
        if self._config.reasoning:
            budget = self._config.reasoning_tokens or self._config.max_tokens // 2
            kwargs["thinking"] = {"type": "enabled", "budget_tokens": budget}
        elif self._config.temperature is not None:
            kwargs["temperature"] = self._config.temperature
        return kwargs

    def complete(self, system: str, user: str) -> str:
        message = _with_retry(
            lambda: self._client.messages.create(
                **self._build_kwargs(),
                system=system,
                messages=[{"role": "user", "content": user}],
            )
        )
        return next(b.text for b in message.content if b.type == "text")

    def complete_json_with_usage(
        self, system: str, user: str, schema: dict
    ) -> tuple[dict, dict]:
        message = _with_retry(
            lambda: self._client.messages.create(
                **self._build_kwargs(),
                system=system,
                messages=[{"role": "user", "content": user}],
                output_config={"format": {"type": "json_schema", "schema": schema}},
            )
        )
        if message.stop_reason == "max_tokens":
            raise RuntimeError(
                f"Anthropic response truncated (max_tokens={self._config.max_tokens})"
            )
        parsed = json.loads(next(b.text for b in message.content if b.type == "text"))
        # Anthropic's Usage object doesn't break out thinking tokens; estimate
        # from the raw text length of thinking content blocks (~4 chars/token).
        thinking_chars = sum(
            len(getattr(b, "thinking", "") or "")
            for b in message.content
            if b.type == "thinking"
        )
        usage = {
            "input_tokens": message.usage.input_tokens,
            "output_tokens": message.usage.output_tokens,
            "reasoning_tokens": thinking_chars // 4 if thinking_chars else 0,
        }
        return parsed, usage


class OpenAIClient(LLMClient):
    """OpenAI client using the Responses API (preferred for GPT-5 family)."""

    def __init__(self, config: LLMConfig) -> None:
        import openai

        self._client = openai.OpenAI()
        self._config = config

    @property
    def config(self) -> LLMConfig:
        return self._config

    def _build_kwargs(self) -> dict:
        kwargs: dict = {
            "model": self._config.model,
            "max_output_tokens": self._config.max_tokens,
        }
        if self._config.reasoning:
            effort = self._config.reasoning_effort or "medium"
            kwargs["reasoning"] = {"effort": effort}
        elif self._config.temperature is not None:
            kwargs["temperature"] = self._config.temperature
        return kwargs

    def complete(self, system: str, user: str) -> str:
        response = _with_retry(
            lambda: self._client.responses.create(
                **self._build_kwargs(),
                instructions=system,
                input=user,
            )
        )
        return response.output_text

    def complete_json_with_usage(
        self, system: str, user: str, schema: dict
    ) -> tuple[dict, dict]:
        response = _with_retry(
            lambda: self._client.responses.create(
                **self._build_kwargs(),
                instructions=system,
                input=user,
                text={
                    "format": {
                        "type": "json_schema",
                        "name": "response",
                        "schema": schema,
                    }
                },
            )
        )
        if getattr(response, "status", None) == "incomplete":
            reason = getattr(
                getattr(response, "incomplete_details", None), "reason", "unknown"
            )
            raise RuntimeError(
                f"OpenAI response incomplete (reason={reason}, "
                f"max_output_tokens={self._config.max_tokens})"
            )
        parsed = json.loads(response.output_text or "{}")
        details = (
            getattr(response.usage, "output_tokens_details", None)
            if response.usage
            else None
        )
        reasoning_tokens = getattr(details, "reasoning_tokens", 0) or 0
        usage = {
            "input_tokens": response.usage.input_tokens if response.usage else 0,
            "output_tokens": response.usage.output_tokens if response.usage else 0,
            "reasoning_tokens": reasoning_tokens,
        }
        return parsed, usage


class DeepSeekClient(LLMClient):
    """DeepSeek client using the OpenAI-compatible Chat Completions endpoint.

    DeepSeek doesn't expose a Responses API and doesn't support
    response_format type "json_schema" — only "json_object".
    """

    def __init__(self, config: LLMConfig) -> None:
        import os

        import openai

        self._client = openai.OpenAI(
            base_url="https://api.deepseek.com",
            api_key=os.environ["DEEPSEEK_API_KEY"],
        )
        self._config = config

    @property
    def config(self) -> LLMConfig:
        return self._config

    def _build_kwargs(self) -> dict:
        kwargs: dict = {
            "model": self._config.model,
            "max_tokens": self._config.max_tokens,
        }
        if self._config.reasoning:
            # DeepSeek v4-pro supports "high" (default) or "max".
            kwargs["reasoning_effort"] = self._config.reasoning_effort or "high"
            kwargs["extra_body"] = {"thinking": {"type": "enabled"}}
        else:
            # Explicitly disable to override v4-pro's enabled-by-default thinking.
            kwargs["extra_body"] = {"thinking": {"type": "disabled"}}
        if self._config.temperature is not None:
            kwargs["temperature"] = self._config.temperature
        return kwargs

    def complete(self, system: str, user: str) -> str:
        response = _with_retry(
            lambda: self._client.chat.completions.create(
                **self._build_kwargs(),
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
            )
        )
        return response.choices[0].message.content or ""

    def complete_json_with_usage(
        self, system: str, user: str, schema: dict
    ) -> tuple[dict, dict]:
        # json_object mode requires the word "json" in the prompt and benefits
        # from a schema example to guide output shape.
        system_with_schema = (
            f"{system}\n\nRespond with a JSON object matching this schema:\n"
            f"{json.dumps(schema)}\n"
            "Output only the JSON object — no markdown fences, no prose."
        )
        required_keys = set(
            schema.get("required") or schema.get("properties", {}).keys()
        )

        last_err: Exception | None = None
        for attempt in range(3):
            response = _with_retry(
                lambda: self._client.chat.completions.create(
                    **self._build_kwargs(),
                    messages=[
                        {"role": "system", "content": system_with_schema},
                        {"role": "user", "content": user},
                    ],
                    response_format={"type": "json_object"},
                )
            )
            finish_reason = response.choices[0].finish_reason
            if finish_reason == "length":
                raise RuntimeError(
                    f"DeepSeek response truncated (finish_reason=length, "
                    f"max_tokens={self._config.max_tokens})"
                )
            content = response.choices[0].message.content or "{}"
            try:
                parsed = json.loads(_strip_to_json(content))
                missing = required_keys - parsed.keys()
                if missing:
                    raise ValueError(f"missing required keys: {sorted(missing)}")
                break
            except (json.JSONDecodeError, ValueError) as e:
                last_err = e
                continue
        else:
            raise RuntimeError(
                f"DeepSeek returned invalid JSON after 3 attempts: {last_err}"
            )

        usage_obj = response.usage
        details = (
            getattr(usage_obj, "completion_tokens_details", None) if usage_obj else None
        )
        reasoning_tokens = getattr(details, "reasoning_tokens", 0) or 0
        usage = {
            "input_tokens": usage_obj.prompt_tokens if usage_obj else 0,
            "output_tokens": usage_obj.completion_tokens if usage_obj else 0,
            "reasoning_tokens": reasoning_tokens,
        }
        return parsed, usage


def _strip_to_json(s: str) -> str:
    """Strip markdown fences and any prose around a JSON object."""
    s = s.strip()
    # Strip ```json ... ``` or ``` ... ``` fences.
    if s.startswith("```"):
        s = s.split("\n", 1)[1] if "\n" in s else s[3:]
        if s.endswith("```"):
            s = s[:-3]
        s = s.strip()
    # Take the first {...} block if there's leading/trailing prose.
    start = s.find("{")
    end = s.rfind("}")
    if start != -1 and end != -1 and end > start:
        s = s[start : end + 1]
    return s
