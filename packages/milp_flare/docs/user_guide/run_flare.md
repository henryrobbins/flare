# Running FLARE on FormulationBench

FLARE consumes pairs of MILP formulations — a markdown description
and a runnable Gurobi script per formulation — and decides whether
one is a constructive reformulation of the other. The
[FormulationBench](https://formulation-bench.henryrobbins.com/)
dataset ships both artifacts for every formulation, so it is the
easiest way to drive FLARE end-to-end.

## Prerequisites

- `formulation-bench` and `milp-flare` installed in the same
  environment.
- Docker running and the `flare-agent:latest` image built (see
  {doc}`docker`).
- A harness credential available on the host (see
  {doc}`../agent_harness/index`).

## Verifying a dataset pair

```python
from pathlib import Path

from formulation_bench import Dataset
from milp_flare import FLARE, FormulationInput
from milp_flare.harness import ClaudeCodeHarness

ds = Dataset.load()
p1 = ds.problem("p1")
a = p1.formulation("a")
b = p1.formulation("b")

harness = ClaudeCodeHarness(model="claude-opus-4-7", effort="medium")
flare = FLARE(harness=harness)

a_in = FormulationInput(
    formulation_md=a.render_markdown(), solve_py=a.gen_solve_py()
)
b_in = FormulationInput(
    formulation_md=b.render_markdown(), solve_py=b.gen_solve_py()
)

result = flare.verify(a_in, b_in, output_path=Path("runs/p1_a_b"))

print("is_reformulation:", result.is_reformulation)
print("duration_s:", result.duration_s)
print("cost_usd:", result.cost_usd)
```

`FormulationInput` carries the two artifacts the agent needs.
`Formulation.render_markdown()` and `Formulation.gen_solve_py()`
produce them directly from the dataset — see the
{fb}`FormulationBench API reference </api/formulation.html>`.

## Lean definitions

FLARE writes Lean files against the same `MILPFormulation` /
`MILPReformulation` structures used by FormulationBench. They are
documented in the FormulationBench docs:

- {fb}`MILPFormulation </definitions.html#milp-formulation>`
- {fb}`MILPReformulation </definitions.html#reformulation>`

A copy of `Common.lean` (and a minimal Lake skeleton) is bundled with
`milp_flare` and copied into the agent working directory at runtime.

## Inspecting the run artifacts

`output_path` is populated with everything FLARE produced:

```
runs/p1_a_b/
├── config.json            # Harness + model configuration
├── result.json            # Final verdict, token usage, cost
└── wd/                    # Agent working directory (bind-mounted into the container)
    ├── A/
    │   ├── formulation.md       # Input written by FLARE
    │   ├── solve.py             # Input written by FLARE
    │   └── Formulation.lean     # Output written by the agent
    ├── B/
    │   ├── formulation.md
    │   ├── solve.py
    │   └── Formulation.lean
    ├── Reformulation.lean       # The proof produced by the agent
    ├── agent_output.jsonl       # Stream of agent turns (tail -f live)
    └── compile_log.txt          # Output of the post-hoc Lean compile
```

`result.json` records the individual sub-checks behind the verdict:
whether each `Formulation.lean` was written and compiled, whether
`Reformulation.lean` contains a `def : MILPReformulation`, whether it
compiled, and whether it is `sorry`-free.

## Using FLARE on a non-dataset pair

`FormulationInput` does not depend on `formulation_bench` — build the
two inputs yourself from any markdown + `solve.py` pair and pass them
to `FLARE.verify`. The markdown should follow the formulation template
documented in
{fb}`/en/latest/schema.html`.
