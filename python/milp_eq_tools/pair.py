from dataclasses import dataclass

from .formulation import Formulation


@dataclass(frozen=True)
class Pair:
    a: Formulation
    b: Formulation
    reformulation: bool
