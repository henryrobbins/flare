import json

from .base import LLMClient, LLMConfig, with_retry


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
        else:
            kwargs["reasoning"] = {"effort": "none"}
            if self._config.temperature is not None:
                kwargs["temperature"] = self._config.temperature
        return kwargs

    def complete(self, system: str, user: str) -> str:
        response = with_retry(
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
        response = with_retry(
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
