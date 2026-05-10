import random
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Callable, TypeVar

T = TypeVar("T")

# HTTP status codes worth retrying on (transient server / rate limit issues).
# 400 in case prompt is accidentally flagged as potentially violating the usage policy
_RETRYABLE_STATUS = {408, 425, 429, 500, 502, 503, 504, 529, 400}


def with_retry(fn: Callable[[], T], max_attempts: int = 4) -> T:
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
    # Per-response output cap. `None` means "no explicit cap" — each client
    # falls back to the model's native max (Anthropic requires the field on
    # the wire, so it substitutes a high sentinel; OpenAI/DeepSeek omit it).
    max_tokens: int | None = None
    temperature: float | None = None
    reasoning: bool = False
    # Effort level passed to the provider when reasoning is enabled. Accepted
    # values are provider/model-dependent: OpenAI Responses API takes
    # "minimal" | "low" | "medium" | "high" | "xhigh"; Anthropic adaptive
    # thinking takes "low" | "medium" | "high" | "xhigh" | "max"; DeepSeek
    # v4-pro takes "high" | "max".
    reasoning_effort: str | None = None

    @classmethod
    def from_dict(cls, d: dict) -> "LLMConfig":
        return cls(**d)


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
