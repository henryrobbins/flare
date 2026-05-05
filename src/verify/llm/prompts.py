import json
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from milp_eq_tools import Formulation

from src.prompts import RenderedPrompt
from src.verify.equivaproof.equivaproof import render_formulation

SYSTEM = (
    "You are an expert in mathematical optimization problems. "
    "You decide if one given MILP formulation is a reformulation of another."
)

REFORMULATION_SCHEMA: dict = json.loads(
    (Path(__file__).parent / "reformulation_schema.json").read_text()
)

_env = Environment(
    loader=FileSystemLoader(Path(__file__).parent),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)


def render_reformulation(
    a: Formulation,
    b: Formulation,
    template: str = "reformulation.j2",
    include_implicit: bool = True,
) -> RenderedPrompt:
    tmpl = _env.get_template(template)
    user = tmpl.render(
        problem_a=json.dumps(render_formulation(a, include_implicit), indent=2),
        problem_b=json.dumps(render_formulation(b, include_implicit), indent=2),
    )
    return RenderedPrompt(system=SYSTEM, user=user)
