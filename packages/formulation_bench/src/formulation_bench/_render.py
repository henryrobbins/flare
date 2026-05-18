"""Markdown rendering for :class:`Formulation`."""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from jinja2 import Environment, FileSystemLoader

if TYPE_CHECKING:
    from .formulation import Formulation

_env = Environment(
    loader=FileSystemLoader(Path(__file__).parent / "templates"),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)


def render_markdown(formulation: Formulation, include_implicit: bool = True) -> str:
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
