from dataclasses import dataclass


@dataclass(frozen=True)
class FormulationInput:
    """Per-formulation inputs handed to the FLARE agent.

    ``formulation_md`` is written to ``<label>/formulation.md`` and
    ``solve_py`` to ``<label>/solve.py`` inside the agent working
    directory.
    """

    formulation_md: str
    solve_py: str
