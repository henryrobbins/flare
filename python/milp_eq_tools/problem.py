import json
from functools import cached_property
from pathlib import Path

from .formulation import Formulation
from .models import Parameter


class Problem:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path).resolve()
        raw = json.loads((self.path / "problem.json").read_text())

        self.parameters: dict[str, Parameter] = {
            k: Parameter(description=v["description"], shape=v["shape"])
            for k, v in raw["parameters"].items()
        }
        self.metadata: dict[str, object] = raw.get("metadata", {})

    @cached_property
    def description(self) -> str:
        return (self.path / "description.md").read_text()

    @cached_property
    def data(self) -> dict[str, object] | None:
        data_file = self.path / "data.json"
        return json.loads(data_file.read_text()) if data_file.exists() else None

    @cached_property
    def formulations(self) -> dict[str, Formulation]:
        formulations_dir = self.path / "formulations"
        if not formulations_dir.exists():
            return {}
        return {
            d.name: Formulation(d)
            for d in sorted(formulations_dir.iterdir())
            if d.is_dir()
        }

    def __repr__(self) -> str:
        return f"Problem(path={self.path!r})"
