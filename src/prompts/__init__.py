import json
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

EQUIVALENCE_SYSTEM = (
    "You are an expert in mathematical optimization. "
    "Decide if two formulations represent equivalent optimization problems."
)

VARIABLE_MAPPING_SYSTEM = (
    "You are an expert in mathematical optimization and variable mapping. "
    "Your task is to find mappings between variables in two equivalent optimization formulations."
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


def _constraints_involving(var_name: str, constraints: list[dict]) -> list[dict]:
    return [c for c in constraints if var_name in c["formulation"]]


def render_equivalence(a: Formulation, b: Formulation) -> RenderedPrompt:
    info_a = problem_info(a)
    info_b = problem_info(b)
    tmpl = _env.get_template("equivalence.j2")
    user = tmpl.render(
        info_a_json=json.dumps(info_a, indent=2),
        info_b_json=json.dumps(info_b, indent=2),
    )
    return RenderedPrompt(system=EQUIVALENCE_SYSTEM, user=user)


def render_variable_mapping(var_name: str, a: Formulation, b: Formulation) -> RenderedPrompt:
    info_a = problem_info(a)
    info_b = problem_info(b)

    var_desc = info_a["variables"][var_name]["description"]
    constraints_a = _constraints_involving(var_name, info_a["constraints"])
    in_objective_a = var_name in info_a["objective"]["formulation"]

    b_variables = [
        {
            "name": b_name,
            "description": b_var["description"],
            "constraints": _constraints_involving(b_name, info_b["constraints"]),
            "in_objective": b_name in info_b["objective"]["formulation"],
        }
        for b_name, b_var in info_b["variables"].items()
    ]

    mapping_json_example = (
        "{\n"
        f'  "{var_name}": [\n'
        '    {"constant": <number>, "variable": "<b_var_name>"},\n'
        "    ...\n"
        "  ]\n"
        "}"
    )
    no_mapping_example = (
        "{\n"
        f'  "{var_name}": [{{"constant": "none", "variable": "none"}}]\n'
        "}"
    )

    tmpl = _env.get_template("variable_mapping.j2")
    user = tmpl.render(
        var_name=var_name,
        var_desc=var_desc,
        constraints_a=constraints_a,
        in_objective_a=in_objective_a,
        b_variables=b_variables,
        mapping_json_example=mapping_json_example,
        no_mapping_example=no_mapping_example,
    )
    return RenderedPrompt(system=VARIABLE_MAPPING_SYSTEM, user=user)
