import json
from pathlib import Path
from typing import Any

from formulation_bench import Formulation
from jinja2 import Environment, FileSystemLoader
from milp_flare.flare_nl import FLARE_NL_SYSTEM, flare_nl_prompt

from src.prompt import RenderedPrompt

REFORMULATION_SCHEMA: dict[str, Any] = json.loads(
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
    template: str = "flare_nl",
    include_implicit: bool = True,
) -> RenderedPrompt:
    formulation_a = json.dumps(a.render_markdown(include_implicit), indent=2)
    formulation_b = json.dumps(b.render_markdown(include_implicit), indent=2)

    if template == "flare_nl":
        p = flare_nl_prompt(formulation_a, formulation_b)
        return RenderedPrompt(system=p.system, user=p.user)

    user = _env.get_template(template).render(
        problem_a=formulation_a,
        problem_b=formulation_b,
    )
    return RenderedPrompt(system=FLARE_NL_SYSTEM, user=user)
