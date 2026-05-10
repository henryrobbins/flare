"""Agent-harness abstraction used by FLAREVerifier.

A `Harness` knows how to (a) drop its config + skills + MCP wiring into a
working directory and (b) invoke its CLI on a prompt, streaming raw output
to a JSONL file and returning a few normalized run-level metrics.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path


@dataclass
class HarnessRunResult:
    duration_s: float
    cost_usd: float | None
    input_tokens: int
    output_tokens: int
    stop_reason: str | None


class Harness(ABC):
    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def method_config(self) -> dict: ...

    @abstractmethod
    def configure_wd(self, wd: Path, repo_root: Path) -> None: ...

    @abstractmethod
    def run(self, prompt: str, wd: Path, jsonl_path: Path) -> HarnessRunResult: ...
