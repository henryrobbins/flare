import json
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from milp_eq_tools import Formulation

from src.prompts import RenderedPrompt
from src.verify.equivaproof.equivaproof import render_formulation

SYSTEM = (
    "You are an expert in mathematical optimization problems. "
    "You decide if two given MILP formulations are equivalent."
)

EQUIVALENCE_SCHEMA: dict = json.loads(
    (Path(__file__).parent / "equivalence_schema.json").read_text()
)

_env = Environment(
    loader=FileSystemLoader(Path(__file__).parent),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)


def render_equivalence(a: Formulation, b: Formulation) -> RenderedPrompt:
    tmpl = _env.get_template("equivalence.j2")
    user = tmpl.render(
        problem_a=json.dumps(render_formulation(a), indent=2),
        problem_b=json.dumps(render_formulation(b), indent=2),
    )
    return RenderedPrompt(system=SYSTEM, user=user)
