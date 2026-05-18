"""The :class:`Reformulation` class: a labelled pair of MILP formulations."""

from dataclasses import dataclass

from .formulation import Formulation


@dataclass(frozen=True)
class Reformulation:
    """A labelled pair of formulations from the same problem.

    Each entry records whether ``b`` is a *reformulation* of ``a`` — that is,
    whether the two formulations describe the same optimization problem
    (same feasible set up to a bijection on the decision variables, same
    optimal value on every instance). Positive entries
    (``is_reformulation=True``) are accompanied by a machine-checked Lean 4
    proof in ``reformulations/pN/<a>_<b>.lean``; negative entries are kept
    as labelled counterexamples.

    Parameters
    ----------
    a : Formulation
        The first formulation in the pair.
    b : Formulation
        The second formulation in the pair.
    is_reformulation : bool
        ``True`` iff ``b`` is a reformulation of ``a``.

    Examples
    --------
    >>> from formulation_bench import Dataset
    >>> ds = Dataset("dataset")                                   # doctest: +SKIP
    >>> refs = ds.reformulations                                  # doctest: +SKIP
    >>> positive = [r for r in refs if r.is_reformulation][0]     # doctest: +SKIP
    >>> positive.a.problem is positive.b.problem                  # doctest: +SKIP
    True
    """

    a: Formulation
    b: Formulation
    is_reformulation: bool
