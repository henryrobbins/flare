from abc import ABC, abstractmethod


class LLMClient(ABC):
    @abstractmethod
    def complete(self, system: str, user: str) -> str: ...


class AnthropicClient(LLMClient):
    def __init__(self, model: str = "claude-sonnet-4-6") -> None:
        import anthropic

        self._client = anthropic.Anthropic()
        self.model = model

    def complete(self, system: str, user: str) -> str:
        message = self._client.messages.create(
            model=self.model,
            max_tokens=1024,
            system=system,
            messages=[{"role": "user", "content": user}],
        )
        return message.content[0].text


class OpenAIClient(LLMClient):
    def __init__(self, model: str = "gpt-4o") -> None:
        import openai

        self._client = openai.OpenAI()
        self.model = model

    def complete(self, system: str, user: str) -> str:
        response = self._client.chat.completions.create(
            model=self.model,
            temperature=0,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        )
        return response.choices[0].message.content or ""
