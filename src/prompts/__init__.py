from dataclasses import dataclass
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from formulation_bench import Formulation

_env = Environment(
    loader=FileSystemLoader(Path(__file__).parent),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)


@dataclass
class RenderedPrompt:
    system: str
    user: str


def problem_info(f: Formulation) -> dict:
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


def render_formulation(formulation: Formulation, include_implicit: bool = True) -> str:
    assumptions = formulation.assumptions
    constraints = formulation.constraints
    if not include_implicit:
        assumptions = [a for a in assumptions if a.explicit]
        constraints = [c for c in constraints if c.explicit]

    tmpl = _env.get_template("formulation.j2")
    return tmpl.render(
        problem_name=formulation.problem.name,
        problem_description=formulation.problem.description,
        parameters=formulation.parameters,
        variables=formulation.variables,
        definitions=formulation.definitions,
        assumptions=assumptions,
        constraints=constraints,
        objective=formulation.objective,
    )
