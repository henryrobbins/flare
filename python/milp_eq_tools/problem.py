from pathlib import Path


class Problem:
    """Represents a single problem in the dataset."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path).resolve()

    def __repr__(self) -> str:
        return f"Problem(path={self.path!r})"
