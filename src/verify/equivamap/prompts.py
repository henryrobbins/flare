import json
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from milp_eq_tools import Formulation

from src.verify.prompts import RenderedPrompt, problem_info


def constraints_involving(var_name: str, constraints: list[dict]) -> list[dict]:
    return [c for c in constraints if var_name in c["formulation"]]

VARIABLE_MAPPING_SCHEMA: dict = json.loads(
    (Path(__file__).parent / "variable_mapping_schema.json").read_text()
)

VARIABLE_MAPPING_SYSTEM = "You are an expert in optimization problems and variable mappings."

_env = Environment(
    loader=FileSystemLoader(Path(__file__).parent),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)
_env.globals["constraints_involving"] = constraints_involving


def render_variable_mapping(var_name: str, a: Formulation, b: Formulation) -> RenderedPrompt:
    info_a = problem_info(a)
    info_b = problem_info(b)
    tmpl = _env.get_template("variable_mapping.j2")
    user = tmpl.render(var_name=var_name, info_a=info_a, info_b=info_b)
    return RenderedPrompt(system=VARIABLE_MAPPING_SYSTEM, user=user)
