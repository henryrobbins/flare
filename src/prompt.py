from dataclasses import dataclass


@dataclass
class RenderedPrompt:
    system: str
    user: str
