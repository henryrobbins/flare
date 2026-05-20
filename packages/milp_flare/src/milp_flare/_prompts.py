from jinja2 import Environment, FileSystemLoader

from milp_flare._assets import PROMPTS_DIR

_env = Environment(
    loader=FileSystemLoader(PROMPTS_DIR),
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)


def render_flare_agent_prompt() -> str:
    """Render the FLARE agent prompt.

    Renders the Jinja2 template at
    ``milp_flare/assets/prompts/flare_agent.j2``. The rendered prompt
    instructs the in-container coding agent on the working directory
    layout, workflow, and rules. See :doc:`/prompts` for the template.

    Returns
    -------
    prompt : str
        The rendered FLARE agent prompt.
    """
    return _env.get_template("flare_agent.j2").render()


def render_flare_nl_prompt(formulation_a: str, formulation_b: str) -> str:
    """Render the FLARE-NL user prompt.

    Renders the Jinja2 template at
    ``milp_flare/assets/prompts/flare_nl.j2`` with the two pre-rendered
    formulations interpolated in. See :doc:`/prompts` for the template
    and :func:`milp_flare.flare_nl.flare_nl_prompt` for the higher-level
    helper that pairs this with the system message.

    Parameters
    ----------
    formulation_a : str
        Pre-rendered description of formulation A.
    formulation_b : str
        Pre-rendered description of formulation B.

    Returns
    -------
    prompt : str
        The rendered FLARE-NL user prompt.
    """
    return _env.get_template("flare_nl.j2").render(
        formulation_a=formulation_a,
        formulation_b=formulation_b,
    )
