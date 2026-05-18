"""Top-level entry point for loading the FormulationBench dataset."""

import json
from pathlib import Path

from .download import download_dataset
from .problem import Problem
from .reformulation import Reformulation


class Dataset:
    """An on-disk FormulationBench dataset.

    A ``Dataset`` loads the problems and reformulations listed in
    ``<root>/dataset.json``. Individual formulations are read from disk on
    first access (see :class:`Formulation`).

    Parameters
    ----------
    root : str or pathlib.Path
        Path to the dataset root directory, i.e. the directory containing
        ``dataset.json`` and the ``problems/`` subtree.

    Attributes
    ----------
    root : pathlib.Path
        Resolved absolute path to the dataset root.
    problems : dict[int, Problem]
        Mapping from integer problem id (``1`` for ``p1``, ``2`` for ``p2``,
        ...) to :class:`Problem`. Iteration order matches ``dataset.json``.
    reformulations : list[Reformulation]
        All reformulation entries declared under the ``reformulations`` key
        of ``dataset.json``. Empty if no such key is present. Includes both
        positive (``is_reformulation=True``) and negative
        (``is_reformulation=False``) examples; filter on
        :attr:`Reformulation.is_reformulation` if you only want one.

    Examples
    --------
    Load the dataset shipped with this repository (run from the repo root)::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("dataset")
        >>> sorted(ds.problems)[:5]
        [1, 2, 3, 4, 5]

    Access a specific problem and one of its formulations::

        >>> p1 = ds.problems[1]
        >>> p1.formulations["a"].valid
        True

    Iterate over labelled reformulations::

        >>> pos = [r for r in ds.reformulations if r.is_reformulation]
        >>> neg = [r for r in ds.reformulations if not r.is_reformulation]
        >>> len(pos), len(neg)  # doctest: +SKIP
        (..., ...)
    """

    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).resolve()
        self._raw = json.loads((self.root / "dataset.json").read_text())
        self.problems: dict[int, Problem] = {
            pid: Problem(self.root / "problems" / f"p{pid}")
            for pid in self._raw["problems"]
        }
        self.reformulations: list[Reformulation] = [
            Reformulation(
                a=self.problems[entry["a"]["problem"]].formulations[
                    entry["a"]["formulation"]
                ],
                b=self.problems[entry["b"]["problem"]].formulations[
                    entry["b"]["formulation"]
                ],
                is_reformulation=entry["reformulation"],
            )
            for entry in self._raw.get("reformulations", [])
        ]

    @classmethod
    def load(
        cls,
        version: str | None = None,
        cache_dir: str | Path | None = None,
        *,
        force: bool = False,
        sha256: str | None = None,
    ) -> "Dataset":
        """Download a released dataset tarball and return a :class:`Dataset`.

        Thin wrapper around :func:`formulation_bench.download_dataset` that
        constructs a :class:`Dataset` from the extracted root. See that
        function for caching and verification semantics.

        Parameters
        ----------
        version : str, optional
            Release tag on the FLARE GitHub repo, e.g. ``"dataset-v0.1"``.
            Defaults to :data:`formulation_bench.DEFAULT_DATASET_VERSION`.
        cache_dir, force, sha256
            Passed through to :func:`download_dataset`.
        """
        root = download_dataset(
            version, cache_dir=cache_dir, force=force, sha256=sha256
        )
        return cls(root)

    def __repr__(self) -> str:
        return f"Dataset(root={self.root!r}, problems={list(self.problems.keys())})"
