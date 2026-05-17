from dataclasses import dataclass

from milp_flare.prompts import render_flare_nl_prompt

FLARE_NL_SYSTEM = (
    "You are an expert in mathematical optimization problems. "
    "You decide if one given MILP formulation is a reformulation of another."
)


@dataclass(frozen=True)
class FLARENLPrompt:
    system: str
    user: str


def flare_nl_prompt(formulation_a: str, formulation_b: str) -> FLARENLPrompt:
    """Build the FLARE-NL system + user prompt.

    ``formulation_a`` and ``formulation_b`` are pre-rendered formulation
    descriptions (e.g., JSON or markdown); the caller controls how
    formulations are serialized.
    """
    return FLARENLPrompt(
        system=FLARE_NL_SYSTEM,
        user=render_flare_nl_prompt(formulation_a, formulation_b),
    )
