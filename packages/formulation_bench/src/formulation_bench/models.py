"""Typed records for parameters, variables, constraints, and other formulation parts.

These dataclasses mirror the JSON schema used by ``problem.json`` and
``formulation.json``. They are populated by :class:`Problem` and
:class:`Formulation` when reading from disk; you typically don't construct
them yourself except when deriving new formulations programmatically (see
:meth:`Formulation.with_constraint`).
"""

from dataclasses import dataclass
from enum import Enum


@dataclass(frozen=True)
class Parameter:
    """Schema entry for a single parameter.

    Parameters
    ----------
    description : str
        Human-readable description of the parameter.
    type : ParameterType
        Numeric type. Defaults to ``continuous`` when omitted from JSON.
    shape : list[int | str]
        Index structure. ``[]`` is a scalar; a string entry names a scalar
        parameter that drives the dimension's range; a string of the form
        ``"X[Y]"`` denotes a ragged dimension. See the dataset
        documentation for the full notation.
    """

    description: str
    type: "ParameterType"
    shape: list[int | str]


@dataclass(frozen=True)
class Variable:
    """Schema entry for a single decision variable.

    Parameters
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
    """

    description: str
    type: "VariableType"
    shape: list[int | str]
    indices: str | None = None


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

    Definitions are emitted into the generated ``solve.py`` in declaration
    order, before variables are declared. Typical uses: big-M constants,
    pre-computed index sets, and other values referenced in variable or
    constraint code.

    Parameters
    ----------
    description : str
        Human-readable description.
    code : dict[str, str]
        Per-language source for the definition. Currently only the
        ``"python"`` key is consumed by codegen.
    formulation : str
        LaTeX form of the definition.
    """

    description: str
    code: dict[str, str]
    formulation: str


@dataclass(frozen=True)
class Assumption:
    """An assumption on the problem parameters.

    Parameters
    ----------
    description : str
        Human-readable description.
    formulation : str
        LaTeX form of the assumption (e.g. ``r"d \\geq 0"``).
    explicit : bool
        ``True`` if the assumption is stated explicitly in the source
        problem text; ``False`` if it is implicit (e.g. non-negativity of
        a physical rate).
    code : dict[str, str]
        Per-language source that asserts the assumption at runtime
        (currently only ``"python"`` is used).
    """

    description: str
    formulation: str
    explicit: bool
    code: dict[str, str]


@dataclass(frozen=True)
class Constraint:
    """A constraint on the decision variables.

    Parameters
    ----------
    description : str
        Human-readable description.
    formulation : str
        LaTeX form of the constraint.
    explicit : bool
        ``True`` if the constraint appears in the original problem
        statement; ``False`` for implied constraints such as non-negativity
        bounds.
    code : dict[str, str]
        Per-language source. The ``"gurobipy"`` key is consumed by codegen.

    Examples
    --------
    Build a constraint by hand for use with
    :meth:`Formulation.with_constraint`::

        >>> from formulation_bench import Constraint
        >>> Constraint(
        ...     description="capacity bound",
        ...     formulation=r"\\sum_j x_j \\leq C",
        ...     explicit=True,
        ...     code={
        ...         "gurobipy": "model.addConstr(quicksum(x[j] for j in range(n)) <= C)"
        ...     },
        ... )                                                 # doctest: +ELLIPSIS
        Constraint(...)
    """

    description: str
    formulation: str
    explicit: bool
    code: dict[str, str]


@dataclass(frozen=True)
class Objective:
    """The objective function of a formulation.

    Parameters
    ----------
    description : str
        Human-readable description.
    formulation : str
        LaTeX form of the objective.
    code : dict[str, str]
        Per-language source. The ``"gurobipy"`` key is consumed by codegen
        and is expected to call ``model.setObjective(...)``.
    """

    description: str
    formulation: str
    code: dict[str, str]


@dataclass(frozen=True)
class Solution:
    """A reference optimal solution.

    Parameters
    ----------
    variables : dict[str, object]
        Variable values keyed by name. Each entry is a JSON-decoded payload
        of the form ``{"kind": "scalar"|"array"|"indexed", "data": ...}``
        as written by the generated ``solve.py``.
    objective : float
        Optimal objective value.
    """

    variables: dict[str, object]
    objective: float
