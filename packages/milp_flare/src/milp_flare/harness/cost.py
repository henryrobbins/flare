from dataclasses import dataclass


@dataclass(frozen=True)
class ModelPrice:
    """A model's USD price per million tokens.

    Attributes
    ----------
    input : float
        Uncached (cache-miss) input tokens.
    output : float
        Output tokens.
    cached_input : float, optional
        Cache-hit input tokens. ``None`` (the default) when the provider
        publishes no cached rate, in which case cached tokens are billed at
        ``input``.
    """

    input: float
    output: float
    cached_input: float | None = None


#: Cost per million tokens. Used to compute cost_usd when the agent harness
#: does not report cost directly. This is a fallback and is likely to become
#: outdated quickly. See pricing documentation for the most up-to-date pricing
#: information:
#:
#: - `Claude Pricing <https://platform.claude.com/docs/en/about-claude/pricing>`_
#: - `OpenAI Pricing <https://developers.openai.com/api/docs/pricing>`_
#: - `DeepSeek Pricing <https://api-docs.deepseek.com/quick_start/pricing>`_
COST_PER_MTOK: dict[str, ModelPrice] = {
    # Anthropic cache reads are 0.1x input; cache writes (1.25x input) are not
    # modeled, so runs that write a lot of cache are priced slightly low.
    "claude-fable-5": ModelPrice(10.0, 50.0, 1.0),
    "claude-opus-5": ModelPrice(5.0, 25.0, 0.50),
    "claude-opus-4-8": ModelPrice(5.0, 25.0, 0.50),
    "claude-opus-4-7": ModelPrice(5.0, 25.0, 0.50),
    "claude-opus-4-6": ModelPrice(5.0, 25.0, 0.50),
    # Introductory pricing through 2026-08-31; $3/$15 from 2026-09-01.
    "claude-sonnet-5": ModelPrice(2.0, 10.0, 0.20),
    "claude-sonnet-4-6": ModelPrice(3.0, 15.0, 0.30),
    "claude-sonnet-4-5": ModelPrice(3.0, 15.0, 0.30),
    "claude-haiku-4-5": ModelPrice(1.0, 5.0, 0.10),
    "gpt-5.6-sol": ModelPrice(5.0, 30.0, 0.50),
    "gpt-5.6-terra": ModelPrice(2.0, 12.0, 0.20),
    "gpt-5.5": ModelPrice(5.0, 30.0, 0.50),
    "gpt-5.4": ModelPrice(2.5, 15.0, 0.25),
    "gpt-5.4-mini": ModelPrice(0.75, 4.5, 0.075),
    "gpt-5.4-nano": ModelPrice(0.20, 1.25, 0.02),
    # Legacy OpenAI models, no longer on the pricing page above — kept at their
    # last known input/output rates, with no cached rate to cite.
    "gpt-4.1": ModelPrice(2.0, 8.0),
    "gpt-4o": ModelPrice(2.5, 10.0),
    "gpt-4o-mini": ModelPrice(0.15, 0.60),
    "deepseek-v4-pro": ModelPrice(0.435, 0.87, 0.003625),
    "deepseek-v4-flash": ModelPrice(0.14, 0.28, 0.0028),
}


def compute_cost_usd(
    model: str,
    input_tokens: int,
    output_tokens: int,
    cached_input_tokens: int = 0,
) -> float | None:
    """Estimate the USD cost of a run from token counts.

    Looks up per-million-token prices for ``model`` in the package's pricing
    table and computes the total. Used as a fallback when the underlying
    harness does not report cost directly (notably Codex).

    Parameters
    ----------
    model : str
        Model identifier (e.g., ``"claude-opus-4-7"``). Must be a key in
        the package's pricing table.
    input_tokens : int
        Total input (prompt) tokens consumed by the run.
    output_tokens : int
        Total output (completion) tokens produced by the run.
    cached_input_tokens : int, default 0
        The cache-hit *subset* of ``input_tokens``, if the harness reports it.
        If unreported, the whole input is billed as uncached, an upper bound.

    Returns
    -------
    cost_usd : float or None
        Estimated USD cost, or ``None`` if ``model`` is not in the
        pricing table.
    """
    price = COST_PER_MTOK.get(model)
    if price is None:
        return None
    cached_rate = price.input if price.cached_input is None else price.cached_input
    uncached_tokens = input_tokens - cached_input_tokens
    return (
        uncached_tokens * price.input
        + cached_input_tokens * cached_rate
        + output_tokens * price.output
    ) / 1_000_000
