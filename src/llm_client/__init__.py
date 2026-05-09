from .anthropic import AnthropicClient
from .base import LLMClient, LLMConfig, compute_cost_usd
from .deepseek import DeepSeekClient
from .openai import OpenAIClient

__all__ = [
    "AnthropicClient",
    "DeepSeekClient",
    "LLMClient",
    "LLMConfig",
    "OpenAIClient",
    "compute_cost_usd",
    "make_client",
]


def make_client(spec: dict) -> LLMClient:
    """Build an LLMClient from a dict spec.

    `provider` (one of "anthropic", "openai", "deepseek") may be set
    explicitly; otherwise it's inferred from the model name prefix.
    All other keys are forwarded to LLMConfig.
    """
    spec = dict(spec)
    provider = spec.pop("provider", None)
    config = LLMConfig.from_dict(spec)
    if provider is None:
        if config.model.startswith("claude"):
            provider = "anthropic"
        elif config.model.startswith("deepseek"):
            provider = "deepseek"
        else:
            provider = "openai"
    if provider == "anthropic":
        return AnthropicClient(config)
    if provider == "openai":
        return OpenAIClient(config)
    if provider == "deepseek":
        return DeepSeekClient(config)
    raise ValueError(f"unknown provider: {provider!r}")
