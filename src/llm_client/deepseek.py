from typing import Any

from .base import (
    LLMClient,
    LLMConfig,
    TruncatedResponseError,
    schema_instructions,
    with_json_retry,
    with_retry,
)


class DeepSeekClient(LLMClient):
    """DeepSeek client using the OpenAI-compatible Chat Completions endpoint.

    DeepSeek doesn't expose a Responses API and doesn't support
    response_format type "json_schema" — only "json_object".
    """

    def __init__(self, config: LLMConfig) -> None:
        import os

        import openai

        self._client = openai.OpenAI(
            base_url=config.base_url or "https://api.deepseek.com",
            api_key=os.environ[config.api_key_env or "DEEPSEEK_API_KEY"],
        )
        self._config = config

    @property
    def config(self) -> LLMConfig:
        return self._config

    def _build_kwargs(self) -> dict[str, Any]:
        kwargs: dict[str, Any] = {"model": self._config.model}
        if self._config.max_tokens is not None:
            kwargs["max_tokens"] = self._config.max_tokens
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
        response = with_retry(
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
        self, system: str, user: str, schema: dict[str, Any]
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        # json_object mode requires the word "json" in the prompt and benefits
        # from a schema example to guide output shape.
        system_with_schema = schema_instructions(system, schema)
        return with_json_retry(
            lambda: self._complete_json_once(system_with_schema, user), schema
        )

    def _complete_json_once(self, system: str, user: str) -> tuple[str, dict[str, Any]]:
        response = with_retry(
            lambda: self._client.chat.completions.create(
                **self._build_kwargs(),
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                response_format={"type": "json_object"},
            )
        )
        if response.choices[0].finish_reason == "length":
            message = response.choices[0].message
            raise TruncatedResponseError(
                f"DeepSeek response truncated (finish_reason=length, "
                f"max_tokens={self._config.max_tokens})",
                message.content or getattr(message, "reasoning_content", "") or "",
            )
        usage_obj = response.usage
        details = (
            getattr(usage_obj, "completion_tokens_details", None) if usage_obj else None
        )
        usage = {
            "input_tokens": usage_obj.prompt_tokens if usage_obj else 0,
            "output_tokens": usage_obj.completion_tokens if usage_obj else 0,
            "reasoning_tokens": getattr(details, "reasoning_tokens", 0) or 0,
        }
        return response.choices[0].message.content or "{}", usage
