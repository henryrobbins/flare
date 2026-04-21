from pathlib import Path


class Formulation:
    """Represents a single formulation of a problem."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path).resolve()

    def __repr__(self) -> str:
        return f"Formulation(path={self.path!r})"
