from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class FLAREResult:
    is_reformulation: bool
    method: str
    artifacts_dir: Path
    duration_s: float | None = None
    cost_usd: float | None = None
    metadata: dict[str, Any] = field(default_factory=dict)
