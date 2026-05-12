import json
from typing import Any

from .base import LLMClient, LLMConfig, with_retry


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
            response = with_retry(
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
