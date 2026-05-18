"""The :class:`Formulation` class: one MILP formulation of a problem."""

from __future__ import annotations

import copy
import json
import subprocess
from pathlib import Path
from typing import TYPE_CHECKING, Any

from .codegen import generate
from .models import (
    Assumption,
    Constraint,
    Definition,
    Objective,
    Parameter,
    ParameterType,
    Variable,
    VariableType,
)

if TYPE_CHECKING:
    from .problem import Problem


class Formulation:
    """A single MILP formulation of a :class:`Problem`.

    A ``Formulation`` corresponds to one
    ``problems/pN/formulations/x/`` directory. It loads ``formulation.json``
    eagerly into typed fields. The on-disk JSON is also kept in
    :attr:`_raw` so that new formulations can be derived via
    :meth:`with_constraint` without re-reading from disk.

    Parameters
    ----------
    path : str or pathlib.Path
        Path to the formulation directory.
    problem : Problem
        The parent problem this formulation belongs to.

    Attributes
    ----------
    path : pathlib.Path
        Resolved absolute path to the formulation directory.
    valid : bool
        Whether this formulation is a valid formulation of its parent
        problem (i.e. its feasible set and objective match the intended
        problem). Invalid formulations are kept in the dataset as labelled
        negative examples.
    parameters : dict[str, Parameter]
        Parameters consumed by this formulation. May differ from the parent
        problem's parameters (e.g. derived constants).
    definitions : dict[str, Definition]
        Optional named derived quantities computed from parameters before
        variables are declared. Emitted into the generated ``solve.py`` in
        declaration order.
    assumptions : list[Assumption]
        Parameter assumptions (explicit or implicit).
    variables : dict[str, Variable]
        Decision variables, keyed by name.
    constraints : list[Constraint]
        Constraints on the decision variables (explicit and implicit).
    objective : Objective
        Objective function.
    imports : list[str]
        Extra Python ``import`` statements emitted in the generated
        ``solve.py``.
    metadata : dict[str, Any]
        Free-form metadata from ``formulation.json``.

    Examples
    --------
    >>> from formulation_bench import Dataset
    >>> ds = Dataset("dataset")          # doctest: +SKIP
    >>> f = ds.problems[1].formulations["a"]   # doctest: +SKIP
    >>> f.valid                                # doctest: +SKIP
    True
    >>> sorted(f.variables)                    # doctest: +SKIP
    ['x', 'y']
    >>> print(f.gurobipy_code[:80])            # doctest: +SKIP
    import json
    import gurobipy as gp
    from gurobipy import GRB, quicksum
    ...
    """

    def __init__(self, path: str | Path, problem: Problem) -> None:
        self.path = Path(path).resolve()
        self._problem: Problem = problem
        raw = json.loads((self.path / "formulation.json").read_text())
        self._raw = raw
        self._load_from_raw(raw)

    @property
    def problem(self) -> Problem:
        """The parent :class:`Problem`."""
        return self._problem

    def _load_from_raw(self, raw: dict[str, Any]) -> None:
        self.valid: bool = raw["valid"]
        self.parameters: dict[str, Parameter] = {
            k: Parameter(
                description=v["description"],
                type=ParameterType(v.get("type", "continuous")),
                shape=v["shape"],
            )
            for k, v in raw["parameters"].items()
        }
        self.definitions: dict[str, Definition] = {
            k: Definition(
                description=v["description"],
                code=v["code"],
                formulation=v["formulation"],
            )
            for k, v in raw.get("definitions", {}).items()
        }
        self.assumptions: list[Assumption] = [
            Assumption(
                description=a["description"],
                formulation=a["formulation"],
                explicit=a["explicit"],
                code=a["code"],
            )
            for a in raw.get("assumptions", [])
        ]
        self.variables: dict[str, Variable] = {
            k: Variable(
                description=v["description"],
                type=VariableType(v["type"]),
                shape=v.get("shape", []),
                indices=v.get("indices"),
            )
            for k, v in raw["variables"].items()
        }
        self.constraints: list[Constraint] = [
            Constraint(
                description=c["description"],
                formulation=c["formulation"],
                explicit=c["explicit"],
                code=c["code"],
            )
            for c in raw["constraints"]
        ]
        self.objective: Objective = Objective(
            description=raw["objective"]["description"],
            formulation=raw["objective"]["formulation"],
            code=raw["objective"]["code"],
        )
        self.imports: list[str] = list(raw.get("imports", []))
        self.metadata: dict[str, Any] = raw.get("metadata", {})

    @classmethod
    def from_raw(cls, raw: dict[str, Any], path: Path, problem: Problem) -> Formulation:
        """Construct a :class:`Formulation` from an in-memory dict.

        Useful for building a formulation programmatically (e.g. when
        deriving a new formulation by adding a constraint) without writing
        anything to disk.

        Parameters
        ----------
        raw : dict
            The ``formulation.json`` payload as a dict.
        path : pathlib.Path
            A path to associate with the new formulation. The path need not
            exist on disk, but :meth:`gen_params` and :meth:`solve` require
            it to point at a directory containing ``gen_params.py`` /
            ``solve.py``.
        problem : Problem
            The parent problem.

        Returns
        -------
        Formulation
        """
        obj = cls.__new__(cls)
        obj.path = Path(path)
        obj._problem = problem
        obj._raw = raw
        obj._load_from_raw(raw)
        return obj

    def with_constraint(self, constraint: Constraint) -> Formulation:
        """Return a new :class:`Formulation` with one extra constraint appended.

        The original formulation is not modified. Useful for building cutting
        planes or hypothesis constraints on top of an existing formulation.

        Parameters
        ----------
        constraint : Constraint

        Returns
        -------
        Formulation

        Examples
        --------
        >>> f = ds.problems[6].formulations["a"]               # doctest: +SKIP
        >>> from formulation_bench import Constraint
        >>> cut = Constraint(                                  # doctest: +SKIP
        ...     description="symmetry-breaking cut",
        ...     formulation=r"x_0 \\leq x_1",
        ...     explicit=False,
        ...     code={"gurobipy": "model.addConstr(x[0] <= x[1])"},
        ... )
        >>> f2 = f.with_constraint(cut)                        # doctest: +SKIP
        >>> len(f2.constraints) == len(f.constraints) + 1      # doctest: +SKIP
        True
        """
        new_raw = copy.deepcopy(self._raw)
        new_raw["constraints"].append(
            {
                "description": constraint.description,
                "formulation": constraint.formulation,
                "explicit": constraint.explicit,
                "code": constraint.code,
            }
        )
        return Formulation.from_raw(new_raw, self.path, self._problem)

    @property
    def gurobipy_code(self) -> str:
        """The full ``solve.py`` source for this formulation, as a string.

        Deterministically generated from ``formulation.json`` by
        :func:`formulation_bench.codegen.generate`.
        Equivalent to the contents of ``solve.py`` on disk.

        Examples
        --------
        >>> f = ds.problems[1].formulations["a"]   # doctest: +SKIP
        >>> "model.optimize()" in f.gurobipy_code  # doctest: +SKIP
        True
        """
        return generate(self._raw)

    def gen_params(
        self,
        input_path: str | Path | None = None,
        output_path: str | Path | None = None,
    ) -> None:
        """Run this formulation's ``gen_params.py`` script.

        The script reads the parent problem's instance data and writes a
        ``parameters.json`` payload that ``solve.py`` can consume.

        Parameters
        ----------
        input_path : str or pathlib.Path, optional
            Path to a ``data.json`` file. Defaults to the parent problem's
            ``data.json``.
        output_path : str or pathlib.Path, optional
            Path to write the generated parameters. Defaults to
            ``<formulation>/parameters.json``.
        """
        script = self.path / "gen_params.py"
        needs_data = 'add_argument("data"' in script.read_text()
        if needs_data and input_path is None:
            input_path = self.path.parent.parent / "data.json"
        if output_path is None:
            output_path = self.path / "parameters.json"
        cmd = ["python", str(script)]
        if needs_data:
            cmd.append(str(input_path))
        cmd.append(str(output_path))
        subprocess.run(cmd, check=True)

    def solve(
        self,
        input_path: str | Path | None = None,
        output_path: str | Path | None = None,
    ) -> None:
        """Run this formulation's ``solve.py`` via Gurobi.

        Parameters
        ----------
        input_path : str or pathlib.Path, optional
            Path to ``parameters.json``. Defaults to
            ``<formulation>/parameters.json``.
        output_path : str or pathlib.Path, optional
            Path to write ``solution.json``. Defaults to
            ``<formulation>/solution.json``.

        Examples
        --------
        Generate the parameters file, solve, and read back the objective::

            >>> f = ds.problems[1].formulations["a"]   # doctest: +SKIP
            >>> f.gen_params()                         # doctest: +SKIP
            >>> f.solve()                              # doctest: +SKIP
            >>> import json
            >>> json.load(open(f.path / "solution.json"))["objective"]  # doctest: +SKIP
            42.0
        """
        if input_path is None:
            input_path = self.path / "parameters.json"
        if output_path is None:
            output_path = self.path / "solution.json"
        subprocess.run(
            ["python", str(self.path / "solve.py"), str(input_path), str(output_path)],
            check=True,
        )

    def __repr__(self) -> str:
        return f"Formulation(path={self.path!r}, valid={self.valid})"
