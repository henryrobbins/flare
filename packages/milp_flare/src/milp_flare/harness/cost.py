#: Cost per million tokens (input, output). Used to compute cost_usd when the
#: agent harness does not report cost directly. This is a fallback and is
#: likely to become outdated quickly. See pricing documentation for the most
#: up-to-date pricing information:
#:
#: - `Claude Pricing <https://platform.claude.com/docs/en/about-claude/pricing>`_
#: - `OpenAI Pricing <https://developers.openai.com/api/docs/pricing>`_
#: - `DeepSeek Pricing <https://api-docs.deepseek.com/quick_start/pricing>`_
COST_PER_MTOK: dict[str, tuple[float, float]] = {
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
    entry = COST_PER_MTOK.get(model)
    if entry is None:
        return None
    input_price, output_price = entry
    return (input_tokens * input_price + output_tokens * output_price) / 1_000_000
