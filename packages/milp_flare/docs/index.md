# FLARE

:::{note}
This is the official implementation of `FLARE` and `FLARE-NL`, introduced by *{paper}`FLARE: Verifying MILP Reformulations with LLM-Based Formal Proof Synthesis </>`*
:::

`FLARE` (Formulation-Level Automated Reformulation Evaluation) uses an
LLM-based agent and the Lean proof assistant to verify mixed-integer linear
program (MILP) reformulations according to the
{fb}`FormulationBench </definitions.html>` definition of *reformulation*.
`FLARE-NL` is a Large Language Model (LLM) proxy for `FLARE` that trades off formal guarantees for speed and cost.

The `milp-flare` Python package is the official implementation of both
methods. See below for installation instructions, user guides, and the API
reference.

```{toctree}
:maxdepth: 2
:caption: Contents

installation
user_guide/index
prompts
skills
api/index
```
