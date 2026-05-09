from __future__ import annotations

import copy
import json
import subprocess
from pathlib import Path
from typing import TYPE_CHECKING

from .codegen import generate
from .models import (
    Assumption,
    Constraint,
    Definition,
    Objective,
    Parameter,
    ParameterType,
    Variable,
    VariableType,
)

if TYPE_CHECKING:
    from .problem import Problem


class Formulation:
    def __init__(self, path: str | Path, problem: Problem) -> None:
        self.path = Path(path).resolve()
        self._problem: Problem = problem
        raw = json.loads((self.path / "formulation.json").read_text())
        self._raw = raw
        self._load_from_raw(raw)

    @property
    def problem(self) -> Problem:
        return self._problem

    def _load_from_raw(self, raw: dict) -> None:
        self.valid: bool = raw["valid"]
        self.parameters: dict[str, Parameter] = {
            k: Parameter(
                description=v["description"],
                type=ParameterType(v.get("type", "continuous")),
                shape=v["shape"],
            )
            for k, v in raw["parameters"].items()
        }
        self.definitions: dict[str, Definition] = {
            k: Definition(
                description=v["description"],
                code=v["code"],
                formulation=v["formulation"],
            )
            for k, v in raw.get("definitions", {}).items()
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
                shape=v.get("shape", []),
                indices=v.get("indices"),
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
        self.imports: list[str] = list(raw.get("imports", []))
        self.metadata: dict[str, object] = raw.get("metadata", {})

    @classmethod
    def from_raw(cls, raw: dict, path: Path, problem: Problem) -> Formulation:
        """Construct a Formulation directly from a raw dict without reading from disk."""
        obj = cls.__new__(cls)
        obj.path = Path(path)
        obj._problem = problem
        obj._raw = raw
        obj._load_from_raw(raw)
        return obj

    def with_constraint(self, constraint: Constraint) -> Formulation:
        """Return a new Formulation with one additional constraint appended."""
        new_raw = copy.deepcopy(self._raw)
        new_raw["constraints"].append({
            "description": constraint.description,
            "formulation": constraint.formulation,
            "explicit": constraint.explicit,
            "code": constraint.code,
        })
        return Formulation.from_raw(new_raw, self.path, self._problem)

    @property
    def gurobipy_code(self) -> str:
        """Return complete gurobipy solve.py source for this formulation."""
        return generate(self._raw)

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
