"""The :class:`Reformulation` class: a labelled pair of MILP formulations."""

from dataclasses import dataclass
from pathlib import Path

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

    @property
    def lean_proof_path(self) -> Path | None:
        """Path to the Lean reformulation proof file, or ``None``.

        For positive entries (``is_reformulation=True``), resolves to
        ``<dataset_root>/reformulations/<problem>/<a>_<b>.lean``. Returns
        ``None`` for negative entries, since no proof exists.
        """
        if not self.is_reformulation:
            return None
        problem_dir = self.a.problem.path
        dataset_root = problem_dir.parent.parent
        return (
            dataset_root
            / "reformulations"
            / problem_dir.name
            / f"{self.a.path.name}_{self.b.path.name}.lean"
        )
