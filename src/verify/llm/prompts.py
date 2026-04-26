import json
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from milp_eq_tools import Formulation

from src.verify.prompts import RenderedPrompt, problem_info

EQUIVALENCE_SYSTEM = (
    "You are an expert in mathematical optimization problems. "
    "You decide if two given formulations represent the same problem."
)

_env = Environment(
    loader=FileSystemLoader(Path(__file__).parent),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)


def render_equivalence(a: Formulation, b: Formulation) -> RenderedPrompt:
    info_a = problem_info(a)
    info_b = problem_info(b)
    tmpl = _env.get_template("equivalence.j2")
    user = tmpl.render(
        info_a_json=json.dumps(info_a, indent=2),
        info_b_json=json.dumps(info_b, indent=2),
    )
    return RenderedPrompt(system=EQUIVALENCE_SYSTEM, user=user)
