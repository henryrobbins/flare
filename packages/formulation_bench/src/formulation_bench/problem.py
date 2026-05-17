"""The :class:`Problem` class: a single MILP problem and its formulations."""

import json
from functools import cached_property
from pathlib import Path

from .formulation import Formulation
from .models import Parameter, ParameterType, Solution


class Problem:
    """A single problem in the FormulationBench dataset.

    A ``Problem`` corresponds to one ``problems/pN/`` directory. It loads the
    parameter schema from ``problem.json`` eagerly; the natural-language
    description, the concrete instance data, the reference solution, and the
    set of formulations are loaded lazily on first access.

    Parameters
    ----------
    path : str or pathlib.Path
        Path to a ``problems/pN/`` directory containing at least
        ``problem.json``.

    Attributes
    ----------
    path : pathlib.Path
        Resolved absolute path to the problem directory.
    name : str
        Human-readable problem name (e.g. ``"Traveling Salesman Problem"``).
    parameters : dict[str, Parameter]
        Schema of the problem's parameters, keyed by parameter name.
    metadata : dict[str, object]
        Free-form metadata from ``problem.json``, typically including
        ``{"source": "..."}``.

    Examples
    --------
    >>> from formulation_bench import Dataset
    >>> ds = Dataset("dataset")          # doctest: +SKIP
    >>> p12 = ds.problems[12]            # doctest: +SKIP
    >>> p12.name                         # doctest: +SKIP
    'Traveling Salesman Problem (TSP)'
    >>> sorted(p12.formulations)[:3]     # doctest: +SKIP
    ['a', 'b', 'c']
    >>> p12.solution.objective           # doctest: +SKIP
    42.0
    """

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path).resolve()
        raw = json.loads((self.path / "problem.json").read_text())

        self.name: str = raw["name"]
        self.parameters: dict[str, Parameter] = {
            k: Parameter(
                description=v["description"],
                type=ParameterType(v.get("type", "continuous")),
                shape=v["shape"],
            )
            for k, v in raw["parameters"].items()
        }
        self.metadata: dict[str, object] = raw.get("metadata", {})

    @cached_property
    def description(self) -> str:
        """Natural-language description from ``description.md``."""
        return (self.path / "description.md").read_text()

    @cached_property
    def data(self) -> dict[str, object] | None:
        """Concrete parameter values from ``data.json``, or ``None`` if absent.

        This is the instance used to verify that all valid formulations of
        the problem produce the same optimal objective.
        """
        data_file = self.path / "data.json"
        return json.loads(data_file.read_text()) if data_file.exists() else None

    @cached_property
    def formulations(self) -> dict[str, Formulation]:
        """Mapping from formulation id (``"a"``, ``"b"``, ...) to :class:`Formulation`.

        Examples
        --------
        >>> p = ds.problems[1]                       # doctest: +SKIP
        >>> [f for f, F in p.formulations.items()    # doctest: +SKIP
        ...  if F.valid]
        ['a', 'b', 'c', 'd']
        """
        formulations_dir = self.path / "formulations"
        if not formulations_dir.exists():
            return {}
        result = {}
        for d in sorted(formulations_dir.iterdir()):
            if d.is_dir():
                f = Formulation(d, self)
                result[d.name] = f
        return result

    @cached_property
    def solution(self) -> Solution | None:
        """Reference optimal :class:`Solution` from ``solution.json``.

        Returns ``None`` if ``solution.json`` is absent.
        """
        solution_file = self.path / "solution.json"
        if not solution_file.exists():
            return None
        raw = json.loads(solution_file.read_text())
        return Solution(variables=raw["variables"], objective=raw["objective"])

    def __repr__(self) -> str:
        return f"Problem(path={self.path!r})"
