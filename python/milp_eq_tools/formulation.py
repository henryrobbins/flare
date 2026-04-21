import json
import subprocess
from pathlib import Path

from .models import Constraint, Objective, Parameter, Variable, VariableType


class Formulation:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path).resolve()
        raw = json.loads((self.path / "formulation.json").read_text())

        self.valid: bool = raw["valid"]
        self.parameters: dict[str, Parameter] = {
            k: Parameter(description=v["description"], shape=v["shape"])
            for k, v in raw["parameters"].items()
        }
        self.variables: dict[str, Variable] = {
            k: Variable(
                description=v["description"],
                type=VariableType(v["type"]),
                shape=v["shape"],
            )
            for k, v in raw["variables"].items()
        }
        self.constraints: list[Constraint] = [
            Constraint(
                description=c["description"],
                formulation=c["formulation"],
                code=c["code"],
            )
            for c in raw["constraints"]
        ]
        self.objective: Objective = Objective(
            description=raw["objective"]["description"],
            formulation=raw["objective"]["formulation"],
            code=raw["objective"]["code"],
        )
        self.metadata: dict[str, object] = raw.get("metadata", {})

    @property
    def description(self) -> str:
        if not hasattr(self, "_description"):
            self._description = (self.path / "description.md").read_text()
        return self._description

    def gen_params(
        self,
        input_path: str | Path | None = None,
        output_path: str | Path | None = None,
    ) -> None:
        """Run gen_params.py. Defaults: input=parent problem data.json, output=this formulation directory."""
        if input_path is None:
            input_path = self.path.parent.parent.parent / "data.json"
        if output_path is None:
            output_path = self.path / "parameters.json"
        subprocess.run(
            ["python", str(self.path / "gen_params.py"), str(input_path), str(output_path)],
            check=True,
        )

    def solve(
        self,
        input_path: str | Path | None = None,
        output_path: str | Path | None = None,
    ) -> None:
        """Run solve.py. Defaults: input=parameters.json in this formulation directory, output=this formulation directory."""
        if input_path is None:
            input_path = self.path / "parameters.json"
        if output_path is None:
            output_path = self.path
        subprocess.run(
            ["python", str(self.path / "solve.py"), str(input_path), str(output_path)],
            check=True,
        )

    def __repr__(self) -> str:
        return f"Formulation(path={self.path!r}, valid={self.valid})"
