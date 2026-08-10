from dataclasses import dataclass

from milp_flare._prompts import render_flare_nl_prompt

#: System prompt describing the FLARE-NL judge's role.
FLARE_NL_SYSTEM = (
    "You are an expert in mathematical optimization problems. "
    "You decide if one given MILP formulation is a reformulation of another."
)


@dataclass(frozen=True)
class FLARENLPrompt:
    """Return type of :func:`flare_nl_prompt` with system and user messages.

    Attributes
    ----------
    system : str
        System message describing the judge's role. Set to :data:`FLARE_NL_SYSTEM`.
    user : str
        User message containing the two formulations and instructions for the judge.
    """

    system: str
    user: str


def flare_nl_prompt(
    formulation_a: str, formulation_b: str, parameter_map: str
) -> FLARENLPrompt:
    """Build the FLARE-NL prompt from two MILP formulations and a parameter map.

    FLARE-NL is a natural language judge for :class:`FLARE` that prompts an LLM
    to decided if one formulation is a reformulation of another according to
    the :fb:`/definitions.html` definition of reformulation. See
    :doc:`/prompts` for the full prompt. See the :paper:`/` for more details.

    Parameters
    ----------
    formulation_a : str
        Markdown description of formulation A. Typically produced by
        ``Formulation.render_markdown()`` from :fb:`/api/formulation.html`.
    formulation_b : str
        Markdown description of formulation B. Typically produced by
        ``Formulation.render_markdown()`` from :fb:`/api/formulation.html`.
    parameter_map : str
        Markdown description of the parameter mapping from A's parameters to
        B's. Typically produced by
        ``Reformulation.parameter_map.render_markdown()`` from
        :fb:`/api/reformulation.html`. The judge is asked to decide whether B
        is a reformulation of A under this mapping specifically.

    Returns
    -------
    prompt : FLARENLPrompt
        The system and user messages to send to the judge LLM.

    Examples
    --------
    Use FLARE-NL to verify if formulation ``b`` of problem ``p1`` from
    :fb:`/problems/p1.html` is a reformulation of formulation ``a``::

        >>> from formulation_bench import Dataset
        >>> from milp_flare import flare_nl_prompt

        >>> ds = Dataset.load()
        >>> pair = ds.reformulations[0]  # p1.a -> p1.b

        >>> prompt = flare_nl_prompt(
        ...     pair.a.render_markdown(),
        ...     pair.b.render_markdown(),
        ...     pair.parameter_map.render_markdown(),
        ... )
        >>> print(prompt.user)
        You are given the following two Mixed-Integer Linear Programming (MILP)...
        <BLANKLINE>
        ## Formulations
        ...
        <BLANKLINE>
        ## Parameter Mapping
        ...
        <BLANKLINE>
        ## Instructions
        <BLANKLINE>
        - Decide whether B is a reformulation of A under *this* parameter mapping...
        - Do NOT make any assumptions about the formulation ...
        - When uncertain, state that formulation B is *not* a reformulation of A.
        - Provide a short summary of your conclusion ...
        <BLANKLINE>
    """
    return FLARENLPrompt(
        system=FLARE_NL_SYSTEM,
        user=render_flare_nl_prompt(formulation_a, formulation_b, parameter_map),
    )
