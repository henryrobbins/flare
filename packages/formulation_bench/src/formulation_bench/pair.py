"""The :class:`Pair` class: a labelled pair of MILP formulations."""

from dataclasses import dataclass

from .formulation import Formulation


@dataclass(frozen=True)
class Pair:
    """A labelled pair of formulations from the same problem.

    Each pair records whether ``b`` is a *reformulation* of ``a`` — that is,
    whether the two formulations describe the same optimization problem
    (same feasible set up to a bijection on the decision variables, same
    optimal value on every instance). Positive pairs
    (``reformulation=True``) are accompanied by a machine-checked Lean 4
    proof in ``reformulations/pN/<a>_<b>.lean``; negative pairs are kept as
    labelled counterexamples.

    Parameters
    ----------
    a : Formulation
        The first formulation in the pair.
    b : Formulation
        The second formulation in the pair.
    reformulation : bool
        ``True`` iff ``b`` is a reformulation of ``a``.

    Examples
    --------
    >>> from formulation_bench import Dataset
    >>> ds = Dataset("dataset")                                   # doctest: +SKIP
    >>> positive = [p for p in ds.pairs if p.reformulation][0]    # doctest: +SKIP
    >>> positive.a.problem is positive.b.problem                  # doctest: +SKIP
    True
    """

    a: Formulation
    b: Formulation
    reformulation: bool
