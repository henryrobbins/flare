import json
from typing import Any

from .base import LLMClient, LLMConfig, with_retry


class AnthropicClient(LLMClient):
    def __init__(self, config: LLMConfig) -> None:
        import anthropic

        self._client = anthropic.Anthropic()
        self._config = config

    @property
    def config(self) -> LLMConfig:
        return self._config

    def _build_kwargs(self) -> dict[str, Any]:
        # Anthropic requires `max_tokens` on the wire. When the config leaves
        # it unset, pass the Claude 4.x family output cap so we don't impose
        # a low artificial limit.
        kwargs: dict[str, Any] = {
            "model": self._config.model,
            "max_tokens": self._config.max_tokens or 64000,
        }
        if self._config.reasoning:
            # Adaptive thinking: Claude decides when/how much to think, guided
            # by `effort`. Required on Opus 4.7; recommended on 4.6 / Sonnet 4.6.
            # `display: summarized` opts in to thinking text in the response
            # (Opus 4.7 defaults to "omitted").
            kwargs["thinking"] = {"type": "adaptive", "display": "summarized"}
            effort = self._config.reasoning_effort or "high"
            kwargs["output_config"] = {"effort": effort}
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
        text: str = next(b.text for b in message.content if b.type == "text")
        return text

    def complete_json_with_usage(
        self, system: str, user: str, schema: dict[str, Any]
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        kwargs = self._build_kwargs()
        # Merge with any output_config set by _build_kwargs (e.g. adaptive
        # thinking effort) — both share the same field on the API.
        output_config = kwargs.pop("output_config", {})
        output_config["format"] = {"type": "json_schema", "schema": schema}
        message = with_retry(
            lambda: self._client.messages.create(
                **kwargs,
                system=system,
                messages=[{"role": "user", "content": user}],
                output_config=output_config,
            )
        )
        if message.stop_reason == "max_tokens":
            raise RuntimeError(
                f"Anthropic response truncated (max_tokens={self._config.max_tokens})"
            )
        parsed = json.loads(next(b.text for b in message.content if b.type == "text"))
        # Anthropic bills the full unsummarized thinking via output_tokens but
        # exposes no breakdown. When thinking is on, estimate visible text
        # tokens (~4 chars/token) and attribute the remainder to thinking.
        # Skip the estimate entirely when reasoning is off — JSON output is
        # denser than 4 chars/token and would yield a phantom remainder.
        if self._config.reasoning:
            visible_chars = sum(
                len(getattr(b, "text", "") or "")
                for b in message.content
                if b.type == "text"
            )
            reasoning_tokens = max(message.usage.output_tokens - visible_chars // 4, 0)
        else:
            reasoning_tokens = 0
        usage = {
            "input_tokens": message.usage.input_tokens,
            "output_tokens": message.usage.output_tokens,
            "reasoning_tokens": reasoning_tokens,
        }
        return parsed, usage
