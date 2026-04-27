import json
from abc import ABC, abstractmethod
from dataclasses import dataclass


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
    def complete_json(self, system: str, user: str, schema: dict) -> dict:
        pass


class AnthropicClient(LLMClient):
    _DEFAULT_CONFIG = LLMConfig(model="claude-sonnet-4-6")

    def __init__(self, config: LLMConfig = _DEFAULT_CONFIG) -> None:
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

    def complete_json(self, system: str, user: str, schema: dict) -> dict:
        message = self._client.messages.create(
            **self._build_kwargs(),
            system=system,
            messages=[{"role": "user", "content": user}],
            output_config={"format": {"type": "json_schema", "schema": schema}},
        )
        return json.loads(next(b.text for b in message.content if b.type == "text"))


class OpenAIClient(LLMClient):
    _DEFAULT_CONFIG = LLMConfig(model="gpt-4o", temperature=0.0)

    def __init__(self, config: LLMConfig = _DEFAULT_CONFIG) -> None:
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

    def complete_json(self, system: str, user: str, schema: dict) -> dict:
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
        return json.loads(response.choices[0].message.content or "{}")
