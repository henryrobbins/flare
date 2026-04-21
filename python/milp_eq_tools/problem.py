import json
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

    @property
    def description(self) -> str:
        if not hasattr(self, "_description"):
            self._description = (self.path / "description.md").read_text()
        return self._description

    @property
    def data(self) -> dict[str, object] | None:
        if not hasattr(self, "_data"):
            data_file = self.path / "data.json"
            self._data = json.loads(data_file.read_text()) if data_file.exists() else None
        return self._data

    @property
    def formulations(self) -> dict[str, Formulation]:
        if not hasattr(self, "_formulations"):
            formulations_dir = self.path / "formulations"
            if formulations_dir.exists():
                self._formulations = {
                    d.name: Formulation(d)
                    for d in sorted(formulations_dir.iterdir())
                    if d.is_dir()
                }
            else:
                self._formulations = {}
        return self._formulations

    def __repr__(self) -> str:
        return f"Problem(path={self.path!r})"
