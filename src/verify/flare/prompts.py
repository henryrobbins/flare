from pathlib import Path

from jinja2 import Environment, FileSystemLoader

_env = Environment(
    loader=FileSystemLoader(Path(__file__).parent),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)


def render_agent_prompt() -> str:
    return _env.get_template("agent_prompt.j2").render()
