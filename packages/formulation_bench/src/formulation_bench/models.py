"""Typed records for components of a formulation.

These dataclasses mirror the JSON schema defined in :doc:`/schema`.
"""

from dataclasses import dataclass
from enum import Enum
from typing import Any


@dataclass(frozen=True)
class Parameter:
    """MILP formulation parameter.

    Attributes
    ----------
    description : str
        Human-readable description of the parameter.
    type : ParameterType
        Numeric type of a parameter (continuous, integer, or binary).
    shape : list[int | str]
        Index structure. ``[]`` is a scalar; a string entry names a scalar
        parameter that drives the dimension's range; a string of the form
        ``"X[Y]"`` denotes a ragged dimension. See the dataset
        documentation for the full notation.

    Examples
    --------

    Examine the ``CashMachineProcessingRate`` of formulation ``a`` for problem
    :doc:`/problems/p1`::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> p1 = ds.problems[1]
        >>> p = p1.formulations["a"].parameters["CashMachineProcessingRate"]
        >>> p.description
        'Processing rate of a cash-based machine in people per hour'
        >>> p.type
        <ParameterType.continuous: 'continuous'>
        >>> p.shape
        []

    Examine the shape of the cost matrix ``c`` in :doc:`/problems/p12`. The
    ``n`` dimension is driven by the scalar parameter ``n`` (number of cities)::

        >>> p12 = ds.problems[12]
        >>> p = p12.formulations["a"].parameters["c"]
        >>> p.description
        'Travel cost from city i to city j'
        >>> p.type
        <ParameterType.continuous: 'continuous'>
        >>> p.shape
        ['n', 'n']

    Examine the shape of the startup lag parameter in :doc:`/problems/p11`. The
    ``n_G`` dimension is driven by the scalar parameter ``n_G`` (number of
    generators), and the ``n_S[n_G]`` dimension is ragged, driven by the array
    parameter ``n_S`` (number of startup categories for each generator) which is
    indexed by the ``n_G`` dimension::

        >>> p = ds.problems[11].formulations["a"].parameters["ell"]
        >>> p.description
        'Startup lag for each startup category of each generator'
        >>> p.type
        <ParameterType.integer: 'integer'>
        >>> p.shape
        ['n_G', 'n_S[n_G]']
    """

    description: str
    type: "ParameterType"
    shape: list[int | str]

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Parameter":
        return cls(
            description=d["description"],
            type=ParameterType(d.get("type", "continuous")),
            shape=d["shape"],
        )


@dataclass(frozen=True)
class Variable:
    """MILP formulation decision variable.

    Attributes
    ----------
    description : str
        Human-readable description of the variable.
    type : VariableType
        Variable domain (continuous, integer, or binary).
    shape : list[int | str]
        Index structure, using the same notation as :class:`Parameter`.
        Mutually exclusive with ``indices``.
    indices : str or None, optional
        Python expression (a generator or comprehension) producing the
        explicit set of index keys passed to ``model.addVars``. Use this
        when the variable is indexed over an irregular set rather than a
        rectangular product of dimensions. When ``indices`` is set,
        ``shape`` may still be present (typically with ``|X|`` cardinality
        notation) to document the conceptual size.

    Examples
    --------

    A scalar variable (empty ``shape``) from formulation ``a`` of
    :doc:`/problems/p1`::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> v = ds.problems[1].formulations["a"].variables["NumCashMachines"]
        >>> v.description
        'The number of cash-based machines'
        >>> v.type
        <VariableType.integer: 'integer'>
        >>> v.shape
        []
        >>> v.indices is None
        True

    A one-dimensional variable in formulation ``a`` of :doc:`/problems/p2`. The
    ``NumExperiments`` dimension is driven by the scalar parameter of the same
    name::

        >>> v = ds.problems[2].formulations["a"].variables["ConductExperiment"]
        >>> v.type
        <VariableType.integer: 'integer'>
        >>> v.shape
        ['NumExperiments']

    A ragged variable in formulation ``a`` of :doc:`/problems/p11`. The middle
    dimension ``n_S[n_G]`` is ragged: for each generator ``g`` it ranges over
    ``n_S[g]`` startup categories::

        >>> v = ds.problems[11].formulations["a"].variables["d_su"]
        >>> v.type
        <VariableType.binary: 'binary'>
        >>> v.shape
        ['n_G', 'n_S[n_G]', 'T']

    A variable indexed by an irregular set in formulation ``a`` of
    :doc:`/problems/p7`. The ``shape`` uses ``|I|`` cardinality notation to
    document the conceptual size, while ``indices`` gives the explicit
    expression passed to ``model.addVars``::

        >>> I = ds.problems[7].formulations["a"].definitions["I"]
        >>> I.description
        'Set of column interval pairs (a, b) with a <= b'
        >>> v = ds.problems[7].formulations["a"].variables["x"]
        >>> v.shape
        ['N', '|I|']
        >>> v.indices
        '(i, a, b) for i in R for (a, b) in I'
    """

    description: str
    type: "VariableType"
    shape: list[int | str]
    indices: str | None = None

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Variable":
        return cls(
            description=d["description"],
            type=VariableType(d["type"]),
            shape=d.get("shape", []),
            indices=d.get("indices"),
        )


class VariableType(str, Enum):
    """Domain of a decision :class:`Variable`."""

    continuous = "continuous"
    integer = "integer"
    binary = "binary"


class ParameterType(str, Enum):
    """Numeric type of a :class:`Parameter`."""

    continuous = "continuous"
    integer = "integer"
    binary = "binary"


@dataclass(frozen=True)
class Definition:
    """A named derived quantity computed from parameters.

    Typically defines sets, constants, etc... that are used by multiple
    constraints and/or the objective.

    Attributes
    ----------
    description : str
        Human-readable description.
    formulation : str
        LaTeX form of the definition.
    code : dict[str, str]
        Per-language source for the definition. The ``"python"`` key is used by
        :meth:`Formulation.gen_solve_py` to generate Python code that computes the
        definition in the solver script.

    Examples
    --------

    Formulation ``a`` of :doc:`/problems/p8` defines a big-M constant ``M``::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> p8 = ds.problems[8]
        >>> d = p8.formulations["a"].definitions["M"]
        >>> d.description
        'Big-M constant: sum of all processing times'
        >>> d.code["python"]
        'M = sum(p[j][k] for j in range(n) for k in range(m))'
    """

    description: str
    code: dict[str, str]
    formulation: str

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Definition":
        return cls(
            description=d["description"],
            code=d["code"],
            formulation=d["formulation"],
        )


@dataclass(frozen=True)
class Assumption:
    """An assumption on the problem parameters.

    Attributes
    ----------
    description : str
        Human-readable description.
    formulation : str
        LaTeX form of the assumption.
    code : dict[str, str]
        Per-language source for the assumption. The ``"python"`` key is used by
        :meth:`Formulation.gen_solve_py` to generate assertions in the solver script.
    explicit : bool
        ``True`` if the assumption is stated explicitly in the source
        problem text; ``False`` if it is implicit.

    Examples
    --------

    Formulation ``a`` of :doc:`/problems/p8` assumes that all processing times
    are non-negative::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> p8 = ds.problems[8]
        >>> a = p8.formulations["a"]
        >>> a.assumptions[0].description
        'Processing times are non-negative.'
        >>> a.assumptions[0].explicit
        False
        >>> a.assumptions[0].code["python"]
        'assert all(p[j][k] >= 0 for j in range(n) for k in range(m))'
    """

    description: str
    formulation: str
    explicit: bool
    code: dict[str, str]

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Assumption":
        return cls(
            description=d["description"],
            formulation=d["formulation"],
            explicit=d["explicit"],
            code=d["code"],
        )


@dataclass(frozen=True)
class Constraint:
    r"""A constraint on the decision variables.

    Attributes
    ----------
    description : str
        Human-readable description.
    formulation : str
        LaTeX form of the constraint.
    code : dict[str, str]
        Per-language source for the constraint. The ``"gurobipy"`` key is used by
        :meth:`Formulation.gen_solve_py` to add constraints to the model in the
        solver script.
    explicit : bool
        ``True`` if the constraint is stated explicitly in the source
        problem text; ``False`` if it is implicit.

    Examples
    --------

    Formulation ``a`` of :doc:`/problems/p12` includes the MTZ subtour elimination
    constraint::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> p12 = ds.problems[12]
        >>> a = p12.formulations["a"]
        >>> c = a.constraints[2]
        >>> c.description
        'MTZ subtour elimination constraint.'
        >>> c.explicit
        True
        >>> c.formulation
        'u_i - u_j + n \\cdot x_{ij} \\leq n - 1 ...'
        >>> c.code["gurobipy"]
        'model.addConstrs(u[i] - u[j] + n * x[i, j] <= n - 1...)'
    """

    description: str
    formulation: str
    explicit: bool
    code: dict[str, str]

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Constraint":
        return cls(
            description=d["description"],
            formulation=d["formulation"],
            explicit=d["explicit"],
            code=d["code"],
        )


@dataclass(frozen=True)
class Objective:
    r"""The objective function of a formulation.

    Attributes
    ----------
    description : str
        Human-readable description.
    formulation : str
        LaTeX form of the objective.
    code : dict[str, str]
        Per-language source for the objective. The ``"gurobipy"`` key is used by
        :meth:`Formulation.gen_solve_py` to set the objective in the model in the
        solver script.

    Examples
    --------

    Formulation ``a`` of :doc:`/problems/p12` minimizes the total travel cost::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> p12 = ds.problems[12]
        >>> a = p12.formulations["a"]
        >>> a.objective.description
        'Minimize the total travel cost of the Hamiltonian cycle.'
        >>> a.objective.formulation
        '\\min \\sum_{i \\in V} \\sum_{j \\in V,\\, j \\neq i} c_{ij} \\cdot x_{ij}'
        >>> a.objective.code["gurobipy"]
        'model.setObjective(gp.quicksum(c[i][j] * x[i, j] ...), GRB.MINIMIZE)'
    """

    description: str
    formulation: str
    code: dict[str, str]

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Objective":
        return cls(
            description=d["description"],
            formulation=d["formulation"],
            code=d["code"],
        )


@dataclass(frozen=True)
class Solution:
    """A reference optimal solution.

    Attributes
    ----------
    variables : dict[str, object]
        Variable values keyed by name.
    objective : float
        Optimal objective value.

    Examples
    --------

    :doc:`/problems/p12` has a reference solution with objective value 6859::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> p12 = ds.problems[12]
        >>> p12.solution.objective
        6859

    """

    variables: dict[str, object]
    objective: float
