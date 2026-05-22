"""Typed records for components of a formulation.

These dataclasses mirror the JSON schema defined in :doc:`/schema`.
"""

import re
from collections.abc import Iterator
from dataclasses import dataclass
from enum import Enum
from typing import Any

_RAGGED_RE = re.compile(r"^(\w+)\[(\w+)\]$")
_CARDINALITY_RE = re.compile(r"^\|(.+)\|$")


class DimensionType(str, Enum):
    """The type of a :class:`Dimension` of a :class:`Shape`.

    - **Fixed.** Range over scalar parameter (e.g., ``range(n)``)
    - **Expression.** Range over expression of scalar parameters (e.g., ``range(x+y)``)
    - **Ragged.** Range over indexed array of scalars (e.g., ``range(a[i])``)
    - **Cardinality.** Range over the cardinality of a set (e.g., ``range(|I|)``)
    """

    fixed = "fixed"
    expression = "expression"
    ragged = "ragged"
    cardinality = "cardinality"


@dataclass(frozen=True)
class Dimension:
    """A single dimension of a :class:`Shape`.

    Attributes
    ----------
    dim_str : str
        String representation of the dimension.
    type : DimensionType
        The type of the dimension that determines how `dim_str` is interpreted.
    array : str or None
        For a ragged dimension of the form ``"X[Y]"``, the array ``X``;
        ``None`` otherwise.
    indexed_by : str or None
        For a ragged dimension of the form ``"X[Y]"``, the index ``Y``;
        ``None`` otherwise.
    set_name : str or None
        For a cardinality dimension of the form ``"|X|"``, the set ``X``;
        ``None`` otherwise.

    Examples
    --------

    A ``fixed`` dimension names a scalar parameter::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> shape = ds.problems[12].formulations["a"].parameters["c"].shape
        >>> shape
        Shape(['n', 'n'])
        >>> shape[0]
        Dimension(dim_str='n', type=<DimensionType.fixed: 'fixed'>)

    An ``expression`` dimension names an expression of scalar parameters::

        >>> shape = ds.problems[10].formulations["a"].variables["x"].shape
        >>> shape
        Shape(['K+N', 'K+N'])
        >>> shape[0]
        Dimension(dim_str='K+N', type=<DimensionType.expression: 'expression'>)

    A ``ragged`` dimension ``"X[Y]"`` exposes its array ``X`` and index ``Y``::

        >>> shape = ds.problems[11].formulations["a"].parameters["ell"].shape
        >>> shape
        Shape(['n_G', 'n_S[n_G]'])
        >>> shape[1].type
        <DimensionType.ragged: 'ragged'>
        >>> shape[1].array
        'n_S'
        >>> shape[1].indexed_by
        'n_G'

    A ``cardinality`` dimension ``"|X|"`` exposes its set ``X``::

        >>> shape = ds.problems[7].formulations["a"].variables["x"].shape
        >>> shape
        Shape(['N', '|I|'])
        >>> shape[1].type
        <DimensionType.cardinality: 'cardinality'>
        >>> shape[1].set_name
        'I'
    """

    dim_str: str
    type: DimensionType

    @classmethod
    def parse(cls, raw: str) -> "Dimension":
        """Classify a raw dimension string into a typed :class:`Dimension`."""
        if _CARDINALITY_RE.match(raw):
            return cls(raw, DimensionType.cardinality)
        if _RAGGED_RE.match(raw):
            return cls(raw, DimensionType.ragged)
        if any(op in raw for op in "+-*/"):
            return cls(raw, DimensionType.expression)
        return cls(raw, DimensionType.fixed)

    @property
    def array(self) -> str | None:
        m = _RAGGED_RE.match(self.dim_str)
        return m.group(1) if m else None

    @property
    def indexed_by(self) -> str | None:
        m = _RAGGED_RE.match(self.dim_str)
        return m.group(2) if m else None

    @property
    def set_name(self) -> str | None:
        m = _CARDINALITY_RE.match(self.dim_str)
        return m.group(1) if m else None

    def __str__(self) -> str:
        return self.dim_str


@dataclass(frozen=True, repr=False)
class Shape:
    """The index structure of a :class:`Parameter` or :class:`Variable`.

    Attributes
    ----------
    dimensions : tuple[Dimension, ...]
        The ordered dimensions of the shape; an empty tuple denotes a scalar.
    is_scalar : bool
        Whether the shape has no dimensions (i.e. denotes a scalar).
    has_cardinality : bool
        Whether any dimension is :attr:`DimensionType.cardinality`.
    is_ragged : bool
        Whether any dimension is :attr:`DimensionType.ragged`.

    Examples
    --------

    A scalar has an empty shape::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> ds.problems[1].formulations["a"].variables["NumCashMachines"].shape
        Shape([])

    A multi-dimensional shape is a sequence of :class:`Dimension` objects::

        >>> shape = ds.problems[12].formulations["a"].parameters["c"].shape
        >>> shape
        Shape(['n', 'n'])
        >>> shape[0]
        Dimension(dim_str='n', type=<DimensionType.fixed: 'fixed'>)
        >>> shape.is_scalar
        False

    A ragged shape's index can be resolved to the dimension it refers to::

        >>> shape = ds.problems[11].formulations["a"].parameters["ell"].shape
        >>> shape
        Shape(['n_G', 'n_S[n_G]'])
        >>> shape.is_ragged
        True
        >>> shape.resolve(shape[1])
        Dimension(dim_str='n_G', type=<DimensionType.fixed: 'fixed'>)
    """

    dimensions: tuple[Dimension, ...]

    @classmethod
    def parse(cls, raw: list[Any]) -> "Shape":
        """Parse a raw JSON ``shape`` list into a typed :class:`Shape`."""
        return cls(tuple(Dimension.parse(str(d)) for d in raw))

    @property
    def is_scalar(self) -> bool:
        return not self.dimensions

    @property
    def is_ragged(self) -> bool:
        return any(d.type is DimensionType.ragged for d in self.dimensions)

    @property
    def has_cardinality(self) -> bool:
        return any(d.type is DimensionType.cardinality for d in self.dimensions)

    def resolve(self, dimension: Dimension) -> "Dimension | None":
        """Return the dimension a ragged dimension's index refers to.

        For a ragged dimension ``"X[Y]"``, returns the dimension in this
        shape whose ``dim_str`` is ``Y``, or ``None`` if there is no such
        dimension or ``dimension`` is not ragged.
        """
        if dimension.type is not DimensionType.ragged:
            return None
        return next(
            (d for d in self.dimensions if d.dim_str == dimension.indexed_by),
            None,
        )

    def __len__(self) -> int:
        return len(self.dimensions)

    def __iter__(self) -> Iterator[Dimension]:
        return iter(self.dimensions)

    def __getitem__(self, index: int) -> Dimension:
        return self.dimensions[index]

    def __str__(self) -> str:
        return str([d.dim_str for d in self.dimensions])

    def __repr__(self) -> str:
        return f"Shape({[d.dim_str for d in self.dimensions]})"


@dataclass(frozen=True)
class Parameter:
    """MILP formulation parameter.

    Attributes
    ----------
    description : str
        Human-readable description of the parameter.
    type : ParameterType
        Numeric type of a parameter (continuous, integer, or binary).
    shape : Shape
        Index structure of the parameter.

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
        Shape([])

    Examine the shape of the cost matrix ``c`` in :doc:`/problems/p12`, a
    matrix indexed by the scalar parameter ``n`` (number of cities)::

        >>> p12 = ds.problems[12]
        >>> p = p12.formulations["a"].parameters["c"]
        >>> p.description
        'Travel cost from city i to city j'
        >>> p.shape
        Shape(['n', 'n'])
    """

    description: str
    type: "ParameterType"
    shape: Shape

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Parameter":
        return cls(
            description=d["description"],
            type=ParameterType(d.get("type", "continuous")),
            shape=Shape.parse(d["shape"]),
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
    shape : Shape
        Index structure of the variable. If the shape contains a cardinality
        dimension (:class:`DimensionType.cardinality`), the Python expression
        for the indices to create the variable can't be inferred. They
        must be provided via the ``indices`` attribute (see below).
    indices : str or None, optional
        Python expression (a generator or comprehension) producing the
        explicit set of index keys passed to ``model.addVars``. Must be
        provided if the shape contains a cardinality dimension.

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
        Shape([])
        >>> v.indices is None
        True

    A one-dimensional variable in formulation ``a`` of :doc:`/problems/p2`. The
    single dimension is driven by the scalar parameter ``NumExperiments``::

        >>> v = ds.problems[2].formulations["a"].variables["ConductExperiment"]
        >>> v.type
        <VariableType.integer: 'integer'>
        >>> v.shape
        Shape(['NumExperiments'])

    A variable with a ragged dimension in formulation ``a`` of
    :doc:`/problems/p11`. The middle dimension ``n_S[n_G]`` is ragged: for each
    generator ``g`` it ranges over ``n_S[g]`` startup categories::

        >>> v = ds.problems[11].formulations["a"].variables["d_su"]
        >>> v.type
        <VariableType.binary: 'binary'>
        >>> v.shape
        Shape(['n_G', 'n_S[n_G]', 'T'])
        >>> v.shape.is_ragged
        True

    A variable indexed over an irregular set in formulation ``a`` of
    :doc:`/problems/p7`. Its ``shape`` carries a cardinality dimension ``|I|``
    documenting the conceptual size, while ``indices`` gives the explicit
    expression passed to ``model.addVars``::

        >>> p7a = ds.problems[7].formulations["a"]
        >>> p7a.definitions["I"].description
        'Set of column interval pairs (a, b) with a <= b'
        >>> x = p7a.variables["x"]
        >>> x.shape
        Shape(['N', '|I|'])
        >>> x.shape.has_cardinality
        True
        >>> x.indices
        '(i, a, b) for i in R for (a, b) in I'
    """

    description: str
    type: "VariableType"
    shape: Shape
    indices: str | None = None

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Variable":
        return cls(
            description=d["description"],
            type=VariableType(d["type"]),
            shape=Shape.parse(d.get("shape", [])),
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
