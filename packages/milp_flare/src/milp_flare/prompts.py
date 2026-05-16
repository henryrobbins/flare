from jinja2 import Environment, FileSystemLoader

from milp_flare.assets import PROMPTS_DIR

_env = Environment(
    loader=FileSystemLoader(PROMPTS_DIR),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)


def render_agent_prompt() -> str:
    return _env.get_template("agent_prompt.j2").render()
