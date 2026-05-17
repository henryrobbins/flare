from jinja2 import Environment, FileSystemLoader

from milp_flare.assets import PROMPTS_DIR

_env = Environment(
    loader=FileSystemLoader(PROMPTS_DIR),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)


def render_flare_agent_prompt() -> str:
    return _env.get_template("flare_agent.j2").render()


def render_flare_nl_prompt(formulation_a: str, formulation_b: str) -> str:
    return _env.get_template("flare_nl.j2").render(
        formulation_a=formulation_a,
        formulation_b=formulation_b,
    )
