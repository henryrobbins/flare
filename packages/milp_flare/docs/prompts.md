# Prompts

Below are the [Jinja2](https://jinja.palletsprojects.com/en/stable/) prompt templates used by `FLARE` and `FLARE-NL`.

## FLARE Agent Prompt

Used by {func}`FLARE.verify() <milp_flare.flare.FLARE.verify>` to instruct the agent on the working directory layout, workflow, rules, and available tools.

:::{dropdown} `assets/prompts/flare_agent.j2`
:icon: file
```{literalinclude} ../src/milp_flare/assets/prompts/flare_agent.j2
:language: jinja
:class: wrap
```
:::

## FLARE-NL Prompt

Used by {func}`flare_nl_prompt() <milp_flare.flare_nl.flare_nl_prompt>` to build a single-turn prompt that asks an LLM to decide whether one formulation is a reformulation of another. Formulation descriptions are supplied through `formulation_a` and `formulation_b`. `Formulation.render_markdown()` from {fb}`FormulationBench </api/formulation.html#formulation_bench.formulation.Formulation.render_markdown>` is often used to generate these Markdown descriptions. The prompt also specifies the FormulationBench {fb}`definition </definitions.html>` of *formulation* and *reformulation*.

:::{dropdown} `assets/prompts/flare_nl.j2`
:icon: file
```{literalinclude} ../src/milp_flare/assets/prompts/flare_nl.j2
:language: jinja
:class: wrap
```
:::
