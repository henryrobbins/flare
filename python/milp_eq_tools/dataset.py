import json
from functools import cached_property
from pathlib import Path

from .pair import Pair
from .problem import Problem


class Dataset:
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).resolve()
        raw = json.loads((self.root / "dataset.json").read_text())
        self.problems: dict[int, Problem] = {
            pid: Problem(self.root / "problems" / f"p{pid}")
            for pid in raw["problems"]
        }

    @cached_property
    def pairs(self) -> list[Pair]:
        return self._load_pairs()

    def _load_pairs(self) -> list[Pair]:
        pairs_file = self.root / "pairs.json"
        if not pairs_file.exists():
            return []
        raw = json.loads(pairs_file.read_text())
        return [
            Pair(
                a=self.problems[entry["a"]["problem"]].formulations[entry["a"]["formulation"]],
                b=self.problems[entry["b"]["problem"]].formulations[entry["b"]["formulation"]],
                reformulation=entry["reformulation"],
            )
            for entry in raw
        ]

    def __repr__(self) -> str:
        return f"Dataset(root={self.root!r}, problems={list(self.problems.keys())})"
