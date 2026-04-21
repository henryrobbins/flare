from pathlib import Path


class Dataset:
    """Top-level entry point for the AHD formal dataset."""

    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).resolve()

    def __repr__(self) -> str:
        return f"Dataset(root={self.root!r})"
