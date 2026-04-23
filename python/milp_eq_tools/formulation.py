import json
import subprocess
from pathlib import Path

from .models import Assumption, Constraint, Objective, Parameter, Variable, VariableType


class Formulation:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path).resolve()
        raw = json.loads((self.path / "formulation.json").read_text())

        self.valid: bool = raw["valid"]
        self.parameters: dict[str, Parameter] = {
            k: Parameter(description=v["description"], shape=v["shape"])
            for k, v in raw["parameters"].items()
        }
        self.assumptions: list[Assumption] = [
            Assumption(
                description=a["description"],
                formulation=a["formulation"],
                explicit=a["explicit"],
                code=a["code"],
            )
            for a in raw.get("assumptions", [])
        ]
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
                explicit=c["explicit"],
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

    def gen_params(
        self,
        input_path: str | Path | None = None,
        output_path: str | Path | None = None,
    ) -> None:
        """Run gen_params.py. Defaults: input=parent problem data.json, output=this formulation directory."""
        script = self.path / "gen_params.py"
        needs_data = 'add_argument("data"' in script.read_text()
        if needs_data and input_path is None:
            input_path = self.path.parent.parent / "data.json"
        if output_path is None:
            output_path = self.path / "parameters.json"
        cmd = ["python", str(script)]
        if needs_data:
            cmd.append(str(input_path))
        cmd.append(str(output_path))
        subprocess.run(cmd, check=True)

    def solve(
        self,
        input_path: str | Path | None = None,
        output_path: str | Path | None = None,
    ) -> None:
        """Run solve.py. Defaults: input=parameters.json in this formulation directory, output=this formulation directory."""
        if input_path is None:
            input_path = self.path / "parameters.json"
        if output_path is None:
            output_path = self.path / "solution.json"
        subprocess.run(
            ["python", str(self.path / "solve.py"), str(input_path), str(output_path)],
            check=True,
        )

    def __repr__(self) -> str:
        return f"Formulation(path={self.path!r}, valid={self.valid})"
