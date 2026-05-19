from dataclasses import dataclass

from milp_flare.prompts import render_flare_nl_prompt

FLARE_NL_SYSTEM = (
    "You are an expert in mathematical optimization problems. "
    "You decide if one given MILP formulation is a reformulation of another."
)


@dataclass(frozen=True)
class FLARENLPrompt:
    """A single-turn FLARE-NL prompt.

    Pair of strings produced by :func:`flare_nl_prompt` to be sent to a
    chat-completion API. FLARE-NL is the natural-language judge baseline
    that asks an LLM directly whether one formulation is a reformulation
    of another, without any Lean machinery.

    Attributes
    ----------
    system : str
        System message describing the judge's role.
    user : str
        User message containing the two rendered formulations and the
        instructions for the judge.
    """

    system: str
    user: str


def flare_nl_prompt(formulation_a: str, formulation_b: str) -> FLARENLPrompt:
    """Build the FLARE-NL system + user prompt.

    Parameters
    ----------
    formulation_a : str
        Pre-rendered description of formulation A (e.g., Markdown or JSON).
        The caller controls how formulations are serialized.
    formulation_b : str
        Pre-rendered description of formulation B (the candidate
        reformulation of A).

    Returns
    -------
    prompt : FLARENLPrompt
        The system and user messages to send to the judge LLM.

    Examples
    --------
    Build a FLARE-NL prompt from two FormulationBench formulations::

        >>> from formulation_bench import Dataset
        >>> from milp_flare import flare_nl_prompt

        >>> ds = Dataset.load()
        >>> a = ds.problems[1].formulations["a"]
        >>> b = ds.problems[1].formulations["b"]

        >>> prompt = flare_nl_prompt(a.render_markdown(), b.render_markdown())
        >>> prompt.system.startswith("You are an expert")
        True
    """
    return FLARENLPrompt(
        system=FLARE_NL_SYSTEM,
        user=render_flare_nl_prompt(formulation_a, formulation_b),
    )
