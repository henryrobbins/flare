import json
from functools import cached_property
from pathlib import Path

from .formulation import Formulation
from .models import Parameter, Solution


class Problem:
    """A problem in the FormulationBench dataset.

    A problem is an optimization problem (e.g., TSP, CWLP) that admits one or
    more MILP formulations. Each problem is identified by a unique integer ID.
    Problems are often referred to by ``pN.F`` where ``N`` is the problem ID and
    ``F`` is a formulation ID (e.g., ``p12.a``).

    Parameters
    ----------
    path : str or pathlib.Path
        Path to the directory containing this problem. See
        :ref:`problem-directory` for the expected directory structure.

    Attributes
    ----------
    path : pathlib.Path
        Resolved absolute path to the problem directory.
    name : str
        Human-readable problem name.
    parameters : dict[str, Parameter]
        Problem data parameters keyed by their names.
    description : str
        Natural-language description of the problem.
    formulations : dict[str, Formulation]
        MILP formulations associated with this problem, keyed by their
        formulation ID (e.g., ``"a"``, ``"b"``, etc.). This may include
        formulations that are unfaithful or otherwise invalid; use the ``valid``
        attribute of :class:`Formulation` to filter.
    data : dict[str, object] or None
        A single concrete instance of problem data.
    solution : Solution or None
        Optimal solution to the provided instance data, if available.
    metadata : dict[str, object]
        Free-form metadata about the problem. Typically includes a ``source``
        field with details about the origin of the problem and a ``notes``
        field with additional commentary.

    Examples
    --------

    Examine problem :doc:`/problems/p12`::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> p12 = ds.problems[12]
        >>> p12.name
        'Traveling Salesman Problem (TSP)'
        >>> p12.description
        'The Traveling Salesman Problem (TSP) aims to find the shortest cycle ...'

    Get the list of valid/invalid formulations::

        >>> [f_id for f_id, f in p12.formulations.items() if f.valid]
        ['a', 'b', 'c', 'g', 'h', 'i']
        >>> [f_id for f_id, f in p12.formulations.items() if not f.valid]
        ['d', 'e', 'f']

    Access the problem data and solution, if available::

        >>> p12.data is not None
        True
        >>> p12.solution is not None
        True
        >>> p12.data["n"]
        16
        >>> p12.solution.objective
        6859
    """

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path).resolve()
        raw = json.loads((self.path / "problem.json").read_text())

        self.name: str = raw["name"]
        self.parameters: dict[str, Parameter] = {
            k: Parameter.from_dict(v) for k, v in raw["parameters"].items()
        }
        self.metadata: dict[str, object] = raw.get("metadata", {})

    @cached_property
    def description(self) -> str:
        return (self.path / "description.md").read_text()

    @cached_property
    def data(self) -> dict[str, object] | None:
        data_file = self.path / "data.json"
        return json.loads(data_file.read_text()) if data_file.exists() else None

    @cached_property
    def formulations(self) -> dict[str, Formulation]:
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
        solution_file = self.path / "solution.json"
        if not solution_file.exists():
            return None
        raw = json.loads(solution_file.read_text())
        return Solution(variables=raw["variables"], objective=raw["objective"])

    def __repr__(self) -> str:
        return f"Problem(path={self.path!r})"
