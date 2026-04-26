from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from milp_eq_tools import Formulation

_env = Environment(
    loader=FileSystemLoader(Path(__file__).parent),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)


def render_agent_prompt() -> str:
    return _env.get_template("agent_prompt.j2").render()


def render_formulation_description(form: Formulation, problem_description: str) -> str:
    tmpl = _env.get_template("formulation_description.md.j2")
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
