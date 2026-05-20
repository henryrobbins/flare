from __future__ import annotations

import copy
import json
import subprocess
from pathlib import Path
from typing import TYPE_CHECKING, Any

from ._codegen import generate
from ._render import render_markdown as _render_markdown
from .models import (
    Assumption,
    Constraint,
    Definition,
    Objective,
    Parameter,
    Variable,
)

if TYPE_CHECKING:
    from .problem import Problem


class Formulation:
    """A MILP formulation for an optimization problem.

    Parameters
    ----------
    path : str or pathlib.Path
        Path to the directory containing this formulation. See
        :ref:`formulation-level-files` for the expected directory structure.
    problem : Problem
        The parent optimization problem this formulation belongs to.

    Attributes
    ----------
    path : pathlib.Path
        Resolved absolute path to the formulation directory.
    problem : Problem
        The parent optimization problem this formulation belongs to.
    valid : bool
        Whether this formulation is a faithful reformulation of the parent problem.
    parameters : dict[str, Parameter]
        The parametrization of this formulation. Note this may differ from the
        parent problem's parameters which define the general problem data.
    definitions : dict[str, Definition]
        Optional named derived quantities computed from parameters before
        variables are declared. Useful for defining sets, constants, etc... that
        are referenced in multiple places in the formulation.
    assumptions : list[Assumption]
        Assumptions on the problem parameters.
    variables : dict[str, Variable]
        Decision variables, keyed by name.
    constraints : list[Constraint]
        Constraints on the decision variables.
    objective : Objective
        Objective function.
    imports : list[str]
        :meth:`gen_solve_py` generates a Python script with an implementation of
        this formulation in Gurobi. By default, the import block includes ``json``,
        ``gurobipy``, and ``argpase``. If the formulation requires additional imports
        (e.g., ``import networkx as nx``), they are included here.
    lean_formulation_path : pathlib.Path
        Path to a Lean file (``Formulation.lean``) containing a formal specification
        of this formulation. See :doc:`/lean/formulation` for details on how a
        MILP formulation is represented in Lean.
    metadata : dict[str, Any]
        Free-form metadata about the formulation. Typically includes a ``source``
        field with details about the origin of the formulation and a ``notes``
        field with additional commentary.

    Examples
    --------

    Load formulation ``a`` of :doc:`/problems/p12`::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> f = ds.problems[12].formulations["a"]
        >>> f.problem.name
        'Traveling Salesman Problem (TSP)'

    Check if the formulation is valid::

        >>> f.valid
        True

    Get the formulation's parameters and assumptions::

        >>> f.parameters
        {'n': Parameter(...), 'c': Parameter(...)}
        >>> f.assumptions
        []

    Get the first constraint of the formulation::

        >>> f.constraints[0]
        Constraint(description='Each city has exactly one outgoing arc ...)

    Get the formulation's objective function::

        >>> f.objective
        Objective(description='Minimize the total travel cost ...)

    Get the path to the Lean specification of this formulation::

        >>> f.lean_formulation_path
        PosixPath('.../dataset/problems/p12/formulations/a/Formulation.lean')
    """

    def __init__(self, path: str | Path, problem: Problem) -> None:
        self.path = Path(path).resolve()
        self._problem: Problem = problem
        raw = json.loads((self.path / "formulation.json").read_text())
        self.valid: bool = raw["valid"]
        self.parameters: dict[str, Parameter] = {
            k: Parameter.from_dict(v) for k, v in raw["parameters"].items()
        }
        self.definitions: dict[str, Definition] = {
            k: Definition.from_dict(v) for k, v in raw.get("definitions", {}).items()
        }
        self.assumptions: list[Assumption] = [
            Assumption.from_dict(a) for a in raw.get("assumptions", [])
        ]
        self.variables: dict[str, Variable] = {
            k: Variable.from_dict(v) for k, v in raw["variables"].items()
        }
        self.constraints: list[Constraint] = [
            Constraint.from_dict(c) for c in raw["constraints"]
        ]
        self.objective: Objective = Objective.from_dict(raw["objective"])
        self.imports: list[str] = list(raw.get("imports", []))
        self.metadata: dict[str, Any] = raw.get("metadata", {})

    @property
    def problem(self) -> Problem:
        return self._problem

    @property
    def lean_formulation_path(self) -> Path:
        return self.path / "Formulation.lean"

    def with_constraint(self, constraint: Constraint) -> Formulation:
        r"""Return a new :class:`Formulation` with one extra constraint appended.

        The original formulation is not modified. Useful for creating formulations
        from cutting planes or fixing variable values.

        Parameters
        ----------
        constraint : Constraint
            The constraint to be added to the formulation.

        Returns
        -------
        formulation : Formulation
            A new formulation with the added constraint.

        Examples
        --------

        Add a cutting plane to the MTZ TSP formulation of :doc:`/problems/p12`
        that prevents two-city subtours::

            >>> from formulation_bench import Dataset
            >>> ds = Dataset("dataset")
            >>> f = ds.problems[12].formulations["a"]  # MTZ formulation of TSP
            >>> c = Constraint(
            ...     description="No 2-city subtours",
            ...     formulation=r"x_{1,2} + x_{2,1} \leq 1",
            ...     explicit=False,
            ...     code={"gurobipy": "model.addConstr(x[1,2] + x[2,1] <= 1)"}
            ... )
            >>> new_f = f.with_constraint(c)
            >>> new_f.constraints[-1]
            Constraint(description='No 2-city subtours', ...)

        """
        new = copy.copy(self)
        new.constraints = self.constraints + [constraint]
        return new

    def gen_solve_py(self) -> str:
        """Generate a Python script with a Gurobi implementation of this formulation.

        The script is generated from the ``gurobipy`` code snippets in the ``code``
        attribute of every formulation component (parameters, definitions,
        assumptions, variables, constraints, and objective). Additional :attr:`imports`
        are also included at the top of the script.

        The resulting script expects ``--params`` and ``--solution`` command-line
        arguments for paths to the input parameters and output solution, respectively.

        Examples
        --------

        Generate the solve script for :doc:`/problems/p12`::

            >>> from formulation_bench import Dataset
            >>> ds = Dataset("dataset")
            >>> f = ds.problems[12].formulations["a"]  # MTZ formulation of TSP
            >>> script = f.gen_solve_py()
            >>> print(script)
            import json
            import gurobipy as gp
            from gurobipy import GRB
            import argparse
            ...
            if __name__ == "__main__":
                parser = argparse.ArgumentParser()
                parser.add_argument("params", help="Path to parameters.json")
                parser.add_argument("solution", help="Path to write solution.json")
                ...

        """
        return generate(self)

    def render_markdown(self, include_implicit: bool = True) -> str:
        r"""Render this formulation in Markdown.

        The output is produced by rendering the following Jinja template. The
        ``assumptions`` and ``constraints`` passed to this template are filtered
        according to ``include_implicit`` flag.

        .. literalinclude:: ../../src/formulation_bench/templates/formulation.j2
           :language: jinja

        Parameters
        ----------
        include_implicit : bool, default True
            If False, omit assumptions and constraints with ``explicit=False``.

        Returns
        -------
        markdown : str
            The rendered Markdown string.

        Examples
        --------

        Render a formulation of :doc:`/problems/p12` without implicit constraints::

            >>> from formulation_bench import Dataset
            >>> ds = Dataset("dataset")
            >>> f = ds.problems[12].formulations["a"]  # MTZ formulation of TSP
            >>> md = f.render_markdown(include_implicit=False)
            >>> print(md)
            # Traveling Salesman Problem (TSP)
            <BLANKLINE>
            ## Problem Description
            <BLANKLINE>
            The Traveling Salesman Problem (TSP) aims to find the shortest cycle in a graph that visits every node exactly once.
            ...
            ## Formulation
            <BLANKLINE>
            ### Parameters
            <BLANKLINE>
            - **n** (type: integer, shape: `[]`): Number of cities
            - **c** (type: continuous, shape: `['n', 'n']`): Travel cost from city i to city j
            ...
            ### Variables
            <BLANKLINE>
            - **x** (type: binary, shape: `['n', 'n']`): 1 if the tour goes directly from city i to city j, 0 otherwise
            - **u** (type: continuous, shape: `['n']`): MTZ position of city i in the tour
            <BLANKLINE>
            ### Constraints
            <BLANKLINE>
            - Each city has exactly one outgoing arc in the tour.
            $$\sum_{j \in V,\, j \neq i} x_{ij} = 1 \quad \forall i \in V$$
            - Each city has exactly one incoming arc in the tour.
            $$\sum_{i \in V,\, i \neq j} x_{ij} = 1 \quad \forall j \in V$$
            - MTZ subtour elimination constraint.
            $$u_i - u_j + n \cdot x_{ij} \leq n - 1 \quad \forall i, j \in V \setminus \{0\},\; i \neq j$$
            - Depot position is fixed to 1 to anchor the tour ordering.
            $$u_0 = 1$$
            - Lower bound on MTZ position: each non-depot city's position is at least 2.
            $$u_i \geq 2 \quad \forall i \in V \setminus \{0\}$$
            - Upper bound on MTZ position: each non-depot city's position is at most n.
            $$u_i \leq n \quad \forall i \in V \setminus \{0\}$$
            <BLANKLINE>
            ### Objective
            <BLANKLINE>
            Minimize the total travel cost of the Hamiltonian cycle.
            $$\min \sum_{i \in V} \sum_{j \in V,\, j \neq i} c_{ij} \cdot x_{ij}$$
            <BLANKLINE>

        """  # noqa: E501
        return _render_markdown(self, include_implicit=include_implicit)

    def run_gen_params(
        self,
        input_path: str | Path | None = None,
        output_path: str | Path | None = None,
    ) -> None:
        """Run this formulation's ``gen_params.py`` script.

        Each formulation includes a ``gen_params.py`` script that transforms
        problem-level instance data into the specific parameter values used by
        the formulation. Note the solver script generated by :meth:`gen_solve_py`
        expects these formulation-specific parameters.

        Parameters
        ----------
        input_path : str or pathlib.Path, optional
            Path to a ``data.json`` file containing the problem instance data.
            Defaults to the parent problem's ``data.json``.
        output_path : str or pathlib.Path, optional
            Path to write the generated parameters. Defaults to
            ``parameters.json`` in this formulation's directory.

        Examples
        --------

        Run the parameter generation script for formulation ``b`` of
        :doc:`/problems/p1`::

            >>> import json
            >>> from formulation_bench import Dataset
            >>> ds = Dataset("dataset")
            >>> f = ds.problems[1].formulations["b"]

            >>> # Inspect the raw problem instance data
            >>> data = json.load(open(f.problem.path / "data.json", "r"))
            >>> data["CashMachineProcessingRate"]
            20

            >>> # Run the parameter generation script and inspect
            >>> f.run_gen_params()
            >>> params = json.load(open(f.path / "parameters.json", "r"))
            >>> params["A"]  # The variable name for "CashMachineProcessingRate"
            20

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

    def __repr__(self) -> str:
        return f"Formulation(path={self.path!r}, valid={self.valid})"
