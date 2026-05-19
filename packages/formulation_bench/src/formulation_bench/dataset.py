import json
from pathlib import Path

from .download import download_dataset
from .problem import Problem
from .reformulation import Reformulation


class Dataset:
    """FormulationBench dataset.

    Parameters
    ----------
    root : str or pathlib.Path
        Path to the root directory containing the FormulationBench dataset. See
        :doc:`/schema` for the expected directory structure.

    Attributes
    ----------
    root : pathlib.Path
        Resolved absolute path to the dataset root.
    problems : dict[int, Problem]
        Mapping from integer problem ID (e.g., ``1`` for ``p1``) to :class:`Problem`.
    reformulations : list[Reformulation]
        List of all labelled reformulation pairs in the dataset.

    Examples
    --------
    Load the dataset from a local ``./dataset`` directory::

        >>> from formulation_bench import Dataset
        >>> ds = Dataset("./dataset")
        >>> ds
        Dataset(root=..., n_problems=20, n_reformulations=96)

    Access a specific problem and one of its formulations::

        >>> p1 = ds.problems[1]
        >>> p1.formulations["a"].valid
        True

    Iterate over labelled reformulations::

        >>> pos = [r for r in ds.reformulations if r.is_reformulation]
        >>> neg = [r for r in ds.reformulations if not r.is_reformulation]
        >>> len(pos), len(neg)
        (70, 26)
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
        force: bool = False,
    ) -> "Dataset":
        """Load the FormulationBench dataset, downloading it if necessary.

        Thin wrapper around :func:`formulation_bench.download_dataset` that
        downloads the dataset and constructs a :class:`Dataset`. See that
        function for versioning and caching semantics.

        Parameters
        ----------
        version, cache_dir, force
            Passed through to :func:`formulation_bench.download_dataset`.

        Returns
        -------
        dataset : Dataset
            The loaded dataset.

        Examples
        --------

        Download the default version of the dataset (or load from cache)::

            >>> from formulation_bench import Dataset
            >>> ds = Dataset.load()
            >>> sorted(ds.problems)[:5]
            [1, 2, 3, 4, 5]

        """
        root = download_dataset(version, cache_dir=cache_dir, force=force)
        return cls(root)

    def __repr__(self) -> str:
        return (
            f"Dataset(root={self.root!r},"
            f" n_problems={len(self.problems)},"
            f" n_reformulations={len(self.reformulations)})"
        )
