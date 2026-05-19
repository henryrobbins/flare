from dataclasses import dataclass
from pathlib import Path

from .formulation import Formulation


@dataclass(frozen=True)
class Reformulation:
    """A pair of MILP formulations with a reformulation label.

    Consists of two MILP formulations ``a`` and ``b`` and a boolean ``is_reformulation``
    label indicating whether ``b`` is a reformulation of ``a``. The formal definition
    of *reformulation* is given in :doc:`/lean/reformulation`. Positive entries
    (``is_reformulation=True``) are accompanied by a Lean 4 proof whose path is
    accessible via the ``lean_proof_path`` attribute; negative entries have no proof
    and ``lean_proof_path`` resolves to ``None``.

    Attributes
    ----------
    a : Formulation
        The base formulation.
    b : Formulation
        The reformulation candidate.
    is_reformulation : bool
        ``True`` iff ``b`` is a *reformulation* of ``a``.
    lean_proof_path : pathlib.Path or None
        For positive entries, the path to the accompanying Lean 4 proof file. For
        negative entries, ``None`` since no proof exists.

    Examples
    --------

    Formulation ``b`` of :doc:`/problems/p12` is a reformulation of formulation ``a``::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> reform = ds.reformulations[80]  # corresponds to p12.a -> p12.b
        >>> reform.a.problem.name
        'Traveling Salesman Problem (TSP)'
        >>> reform.b.problem.name
        'Traveling Salesman Problem (TSP)'
        >>> reform.b.constraints[-1].description  # cutting plane added by p12.b
        'Depot-Exit Position Bound (EC1)...'
        >>> reform.is_reformulation
        True
    """

    a: Formulation
    b: Formulation
    is_reformulation: bool

    @property
    def lean_proof_path(self) -> Path | None:
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
