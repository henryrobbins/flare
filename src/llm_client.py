import json
from abc import ABC, abstractmethod
from dataclasses import dataclass

# Cost per million tokens (input, output). Used to compute cost_usd for direct
# API calls. Update when model pricing changes.
# https://platform.claude.com/docs/en/about-claude/pricing
# https://developers.openai.com/api/docs/pricing
_COST_PER_MTOK: dict[str, tuple[float, float]] = {
    "claude-opus-4-7": (5.0, 25.0),
    "claude-sonnet-4-6": (3.0, 15.0),
    "claude-haiku-4-5": (1, 5.0),
    "gpt-4.1": (2.0, 8.0),
    "gpt-4o": (2.5, 10.0),
    "gpt-4o-mini": (0.15, 0.60),
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
    max_tokens: int = 1024
    temperature: float | None = None
    reasoning: bool = False
    reasoning_tokens: int | None = None


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
        message = self._client.messages.create(
            **self._build_kwargs(),
            system=system,
            messages=[{"role": "user", "content": user}],
        )
        return next(b.text for b in message.content if b.type == "text")

    def complete_json_with_usage(
        self, system: str, user: str, schema: dict
    ) -> tuple[dict, dict]:
        message = self._client.messages.create(
            **self._build_kwargs(),
            system=system,
            messages=[{"role": "user", "content": user}],
            output_config={"format": {"type": "json_schema", "schema": schema}},
        )
        parsed = json.loads(next(b.text for b in message.content if b.type == "text"))
        usage = {
            "input_tokens": message.usage.input_tokens,
            "output_tokens": message.usage.output_tokens,
        }
        return parsed, usage


class OpenAIClient(LLMClient):
    def __init__(self, config: LLMConfig) -> None:
        import openai

        self._client = openai.OpenAI()
        self._config = config

    @property
    def config(self) -> LLMConfig:
        return self._config

    def _build_kwargs(self) -> dict:
        kwargs: dict = {"model": self._config.model}
        if self._config.temperature is not None:
            kwargs["temperature"] = self._config.temperature
        return kwargs

    def complete(self, system: str, user: str) -> str:
        response = self._client.chat.completions.create(
            **self._build_kwargs(),
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        )
        return response.choices[0].message.content or ""

    def complete_json_with_usage(
        self, system: str, user: str, schema: dict
    ) -> tuple[dict, dict]:
        response = self._client.chat.completions.create(
            **self._build_kwargs(),
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            response_format={
                "type": "json_schema",
                "json_schema": {"name": "response", "schema": schema},
            },
        )
        parsed = json.loads(response.choices[0].message.content or "{}")
        usage_obj = response.usage
        usage = {
            "input_tokens": usage_obj.prompt_tokens if usage_obj else 0,
            "output_tokens": usage_obj.completion_tokens if usage_obj else 0,
        }
        return parsed, usage
