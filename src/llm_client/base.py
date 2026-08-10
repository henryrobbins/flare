import random
import time
from abc import ABC, abstractmethod
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any, TypeVar

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


@dataclass(frozen=True)
class ModelPrice:
    """A model's USD price per million tokens.

    `cached_input` is None when the provider publishes no cached rate, in
    which case cached tokens are billed at the full `input` rate.
    """

    input: float
    output: float
    cached_input: float | None = None


# Cost per million tokens. Used to compute cost_usd for direct API calls.
# Update when model pricing changes.
# https://platform.claude.com/docs/en/about-claude/pricing
# https://developers.openai.com/api/docs/pricing
# https://api-docs.deepseek.com/quick_start/pricing
_COST_PER_MTOK: dict[str, ModelPrice] = {
    # Anthropic cache reads are 0.1x input; cache writes (1.25x input) are not
    # modeled, so runs that write a lot of cache are priced slightly low.
    "claude-fable-5": ModelPrice(10.0, 50.0, 1.0),
    "claude-opus-5": ModelPrice(5.0, 25.0, 0.50),
    "claude-opus-4-8": ModelPrice(5.0, 25.0, 0.50),
    "claude-opus-4-7": ModelPrice(5.0, 25.0, 0.50),
    "claude-opus-4-6": ModelPrice(5.0, 25.0, 0.50),
    # Introductory pricing through 2026-08-31; $3/$15 from 2026-09-01.
    "claude-sonnet-5": ModelPrice(2.0, 10.0, 0.20),
    "claude-sonnet-4-6": ModelPrice(3.0, 15.0, 0.30),
    "claude-sonnet-4-5": ModelPrice(3.0, 15.0, 0.30),
    "claude-haiku-4-5": ModelPrice(1.0, 5.0, 0.10),
    "gpt-5.6-sol": ModelPrice(5.0, 30.0, 0.50),
    "gpt-5.6-terra": ModelPrice(2.0, 12.0, 0.20),
    "gpt-5.5": ModelPrice(5.0, 30.0, 0.50),
    "gpt-5.4": ModelPrice(2.5, 15.0, 0.25),
    "gpt-5.4-mini": ModelPrice(0.75, 4.5, 0.075),
    "gpt-5.4-nano": ModelPrice(0.20, 1.25, 0.02),
    # Legacy OpenAI models, no longer on the pricing page above — kept at their
    # last known input/output rates, with no cached rate to cite.
    "gpt-4.1": ModelPrice(2.0, 8.0),
    "gpt-4o": ModelPrice(2.5, 10.0),
    "gpt-4o-mini": ModelPrice(0.15, 0.60),
    "deepseek-v4-pro": ModelPrice(0.435, 0.87, 0.003625),
    "deepseek-v4-flash": ModelPrice(0.14, 0.28, 0.0028),
}


def compute_cost_usd(
    model: str,
    input_tokens: int,
    output_tokens: int,
    cached_input_tokens: int = 0,
) -> float | None:
    """Return estimated cost in USD, or None if the model isn't in the pricing table.

    `cached_input_tokens` is the cache-hit subset of `input_tokens`, billed at
    the model's cached rate. If unreported, the whole input is billed as
    uncached, an upper bound.
    """
    price = _COST_PER_MTOK.get(model)
    if price is None:
        return None
    cached_rate = price.input if price.cached_input is None else price.cached_input
    uncached_tokens = input_tokens - cached_input_tokens
    return (
        uncached_tokens * price.input
        + cached_input_tokens * cached_rate
        + output_tokens * price.output
    ) / 1_000_000


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
    def from_dict(cls, d: dict[str, Any]) -> "LLMConfig":
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
        self, system: str, user: str, schema: dict[str, Any]
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        """Return (parsed_json, usage); usage has input_tokens and output_tokens."""
        pass

    def complete_json(
        self, system: str, user: str, schema: dict[str, Any]
    ) -> dict[str, Any]:
        result, _ = self.complete_json_with_usage(system, user, schema)
        return result
