from dataclasses import dataclass
from typing import Any

# Cost per million tokens (input, output). Used to compute cost_usd for direct
# API calls. Update when model pricing changes.
# https://platform.claude.com/docs/en/about-claude/pricing
# https://developers.openai.com/api/docs/pricing
_COST_PER_MTOK: dict[str, tuple[float, float]] = {
    "claude-opus-4-7": (5.0, 25.0),
    "claude-opus-4-6": (5.0, 25.0),
    "claude-sonnet-4-6": (3.0, 15.0),
    "claude-sonnet-4-5": (3.0, 15.0),
    "claude-haiku-4-5": (1, 5.0),
    "gpt-4.1": (2.0, 8.0),
    "gpt-4o": (2.5, 10.0),
    "gpt-4o-mini": (0.15, 0.60),
    "gpt-5.5": (5.0, 30.0),
    "gpt-5.4": (2.5, 15.0),
    "gpt-5.4-mini": (0.75, 4.5),
    "gpt-5.4-nano": (0.20, 1.25),
    "deepseek-v4-pro": (1.74, 3.48),
    "deepseek-v4-flash": (0.14, 0.28),
}


def compute_cost_usd(model: str, input_tokens: int, output_tokens: int) -> float | None:
    """Estimate the USD cost of a run from token counts.

    Looks up per-million-token input and output prices for ``model`` in
    the package's pricing table and computes the total. Used as a fallback
    when the underlying harness does not report cost directly (notably
    Codex).

    Parameters
    ----------
    model : str
        Model identifier (e.g., ``"claude-opus-4-7"``). Must be a key in
        the package's pricing table.
    input_tokens : int
        Total input (prompt) tokens consumed by the run.
    output_tokens : int
        Total output (completion) tokens produced by the run.

    Returns
    -------
    cost_usd : float or None
        Estimated USD cost, or ``None`` if ``model`` is not in the
        pricing table.
    """
    entry = _COST_PER_MTOK.get(model)
    if entry is None:
        return None
    input_price, output_price = entry
    return (input_tokens * input_price + output_tokens * output_price) / 1_000_000


@dataclass
class HarnessConfig:
    """Common configuration for an agent harness.

    Shared by all :class:`~milp_flare.harness.base.Harness` subclasses.
    Specific harnesses may interpret ``reasoning`` / ``reasoning_effort``
    differently depending on the underlying CLI and provider.

    Attributes
    ----------
    model : str
        Model identifier passed to the underlying CLI (e.g.,
        ``"claude-opus-4-7"``, ``"gpt-5.4"``).
    reasoning : bool, default False
        Whether to enable extended reasoning, where supported.
    reasoning_effort : str, optional
        Reasoning effort level (``"low"``, ``"medium"``, ``"high"``).
        Forwarded to the harness-specific configuration.

    Examples
    --------
    Build a config for a high-effort Claude Opus run::

        >>> from milp_flare import HarnessConfig
        >>> cfg = HarnessConfig(
        ...     model="claude-opus-4-7", reasoning=True, reasoning_effort="high"
        ... )
        >>> cfg.model
        'claude-opus-4-7'
    """

    model: str
    reasoning: bool = False
    reasoning_effort: str | None = None

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "HarnessConfig":
        """Build a :class:`HarnessConfig` from a plain dictionary.

        Parameters
        ----------
        d : dict[str, Any]
            Mapping of field name to value. Unknown keys raise
            ``TypeError``.

        Returns
        -------
        config : HarnessConfig
            The constructed configuration.
        """
        return cls(**d)
