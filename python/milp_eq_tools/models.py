from dataclasses import dataclass
from enum import Enum


@dataclass(frozen=True)
class Parameter:
    description: str
    shape: list[int | str]


@dataclass(frozen=True)
class Variable:
    description: str
    type: "VariableType"
    shape: list[int | str]


class VariableType(str, Enum):
    continuous = "continuous"
    integer = "integer"


@dataclass(frozen=True)
class Assumption:
    description: str
    formulation: str
    explicit: bool
    code: dict[str, str]


@dataclass(frozen=True)
class Constraint:
    description: str
    formulation: str
    explicit: bool
    code: dict[str, str]


@dataclass(frozen=True)
class Objective:
    description: str
    formulation: str
    code: dict[str, str]


@dataclass(frozen=True)
class Solution:
    variables: dict[str, object]
    objective: float


