from dataclasses import dataclass
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from milp_eq_tools import Formulation

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
            {"description": c.description, "formulation": c.formulation}
            for c in f.constraints
            if c.explicit
        ],
        "objective": {
            "description": f.objective.description,
            "formulation": f.objective.formulation,
        },
    }


def render_formulation(form: Formulation, problem_description: str) -> str:
    tmpl = _env.get_template("formulation.j2")
    return tmpl.render(
        formulation_id=form.path.name,
        problem_description=problem_description,
        parameters=form.parameters,
        variables=form.variables,
        definitions=form.definitions,
        assumptions=form.assumptions,
        constraints=form.constraints,
        objective=form.objective,
    )
