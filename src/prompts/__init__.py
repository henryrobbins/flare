from dataclasses import dataclass
from typing import Any

from formulation_bench import Formulation


@dataclass
class RenderedPrompt:
    system: str
    user: str


def problem_info(f: Formulation) -> dict[str, Any]:
    return {
        "variables": {
            name: {"description": var.description, "type": var.type.value}
            for name, var in f.variables.items()
        },
        "constraints": [
            {
                "description": c.description,
                "formulation": c.formulation,
                "code": c.code.get("gurobipy", ""),
            }
            for c in f.constraints
            if c.explicit
        ],
        "objective": {
            "description": f.objective.description,
            "formulation": f.objective.formulation,
            "code": f.objective.code.get("gurobipy", ""),
        },
    }
