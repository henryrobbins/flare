import json
import os
from typing import Any

from .base import (
    LLMClient,
    LLMConfig,
    schema_instructions,
    with_json_retry,
    with_retry,
)


class AnthropicClient(LLMClient):
    def __init__(self, config: LLMConfig) -> None:
        import anthropic

        kwargs: dict[str, Any] = {}
        if config.base_url is not None:
            kwargs["base_url"] = config.base_url
        if config.api_key_env is not None:
            kwargs["api_key"] = os.environ[config.api_key_env]
        self._client = anthropic.Anthropic(**kwargs)
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

    def _usage(self, message: Any) -> dict[str, Any]:
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
        return {
            "input_tokens": message.usage.input_tokens,
            "output_tokens": message.usage.output_tokens,
            "reasoning_tokens": reasoning_tokens,
        }

    def _create(self, system: str, user: str, **extra: Any) -> Any:
        return with_retry(
            lambda: self._client.messages.create(
                system=system,
                messages=[{"role": "user", "content": user}],
                **extra,
            )
        )

    def complete(self, system: str, user: str) -> str:
        message = self._create(system, user, **self._build_kwargs())
        return _text(message)

    def complete_json_with_usage(
        self, system: str, user: str, schema: dict[str, Any]
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        if self._config.json_mode == "prompt":
            return with_json_retry(
                lambda: self._complete_text_json(
                    schema_instructions(system, schema), user
                ),
                schema,
            )

        kwargs = self._build_kwargs()
        # Merge with any output_config set by _build_kwargs (e.g. adaptive
        # thinking effort) — both share the same field on the API.
        output_config = kwargs.pop("output_config", {})
        output_config["format"] = {"type": "json_schema", "schema": schema}
        message = self._create(system, user, **kwargs, output_config=output_config)
        self._check_truncated(message)
        return json.loads(_text(message)), self._usage(message)

    def _complete_text_json(self, system: str, user: str) -> tuple[str, dict[str, Any]]:
        """One unenforced-JSON attempt; parsing and retries are the caller's."""
        message = self._create(system, user, **self._build_kwargs())
        self._check_truncated(message)
        return _text(message), self._usage(message)

    def _check_truncated(self, message: Any) -> None:
        if message.stop_reason == "max_tokens":
            raise RuntimeError(
                f"Anthropic response truncated (max_tokens={self._config.max_tokens})"
            )


def _text(message: Any) -> str:
    text: str = next(b.text for b in message.content if b.type == "text")
    return text
