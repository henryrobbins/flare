import json
from pathlib import Path

from .problem import Problem


class Dataset:
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).resolve()
        raw = json.loads((self.root / "dataset.json").read_text())
        self.problems: dict[int, Problem] = {
            pid: Problem(self.root / "problems" / str(pid))
            for pid in raw["problems"]
        }

    def __repr__(self) -> str:
        return f"Dataset(root={self.root!r}, problems={list(self.problems.keys())})"
