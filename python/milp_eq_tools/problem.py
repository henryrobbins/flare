import json
from functools import cached_property
from pathlib import Path

from .formulation import Formulation
from .models import Parameter, ParameterType, Solution


class Problem:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path).resolve()
        raw = json.loads((self.path / "problem.json").read_text())

        self.name: str = raw["name"]
        self.parameters: dict[str, Parameter] = {
            k: Parameter(
                description=v["description"],
                type=ParameterType(v.get("type", "continuous")),
                shape=v["shape"],
            )
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
        result = {}
        for d in sorted(formulations_dir.iterdir()):
            if d.is_dir():
                f = Formulation(d, self)
                result[d.name] = f
        return result

    @cached_property
    def solution(self) -> Solution | None:
        solution_file = self.path / "solution.json"
        if not solution_file.exists():
            return None
        raw = json.loads(solution_file.read_text())
        return Solution(variables=raw["variables"], objective=raw["objective"])

    def __repr__(self) -> str:
        return f"Problem(path={self.path!r})"
