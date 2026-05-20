# Prompts

FLARE ships two Jinja2 prompt templates: one for the FLARE agent
(driven by a coding agent inside the Docker container) and one for
FLARE-NL (a single-shot natural-language judge).

## FLARE agent prompt

Used by {func}`milp_flare.flare.FLARE.verify` to instruct the agent on the working directory
layout, workflow, rules, and available tools.

```{literalinclude} ../src/milp_flare/assets/prompts/flare_agent.j2
:language: jinja
```

## FLARE-NL prompt

Used by {func}`milp_flare.flare_nl.flare_nl_prompt` to build a
single-turn prompt that asks an LLM to decide whether two given
formulations are reformulations of each other, without any Lean
machinery.

```{literalinclude} ../src/milp_flare/assets/prompts/flare_nl.j2
:language: jinja
```
