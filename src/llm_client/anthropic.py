import json

from .base import LLMClient, LLMConfig, with_retry


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
        message = with_retry(
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
        message = with_retry(
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
