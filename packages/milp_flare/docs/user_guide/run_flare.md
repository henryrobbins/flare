# Running FLARE on FormulationBench

`FLARE` takes two MILP formulations and their parameter mapping as input. For each formulation and the parameter mapping, it expects both a templated LaTeX description and a runnable Gurobi Python script. The [FormulationBench](https://formulation-bench.henryrobbins.com/) provides all of these artifacts, making it easy to run `FLARE`.

## Prerequisites

- `formulation-bench` and `milp-flare` installed in the same
  environment.
- Docker running and the `flare-agent:latest` image built (see
  {doc}`docker`).
- A harness credential available on the host (see
  {doc}`../agent_harness/index`).

## Verifying a dataset pair

```{testcode}
from pathlib import Path

from formulation_bench import Dataset
from milp_flare import FLARE, FormulationInput, ParameterMapInput
from milp_flare.harness import ClaudeCodeHarness

ds = Dataset.load()
pair = ds.reformulations[0]  # p1.a -> p1.b
a, b = pair.a, pair.b

harness = ClaudeCodeHarness(model="claude-opus-5", effort="medium")
flare = FLARE(harness=harness)

a_in = FormulationInput(
    formulation_md=a.render_markdown(), solve_py=a.gen_solve_py()
)
b_in = FormulationInput(
    formulation_md=b.render_markdown(), solve_py=b.gen_solve_py()
)
map_in = ParameterMapInput(
    map_md=pair.parameter_map.render_markdown(), map_py=pair.gen_map_py()
)

result = flare.verify(a_in, b_in, map_in, output_path=Path("runs/p1_a_b"))

print("is_reformulation:", result.is_reformulation)
print("duration_s:", result.duration_s)
print("cost_usd:", result.cost_usd)
```

```{testoutput}
is_reformulation: True
duration_s: 322.4
cost_usd: 1.49
```

{class}`~milp_flare.flare.FormulationInput` carries the two artifacts the agent needs per formulation; {meth}`~formulation_bench.formulation.Formulation.render_markdown` and {meth}`~formulation_bench.formulation.Formulation.gen_solve_py` produce them directly from the dataset. Additionally, {class}`~milp_flare.flare.ParameterMapInput` carries the two artifacts the agent needs for the parameter mapping; {meth}`~formulation_bench.models.ParameterMap.render_markdown` and {meth}`~formulation_bench.reformulation.Reformulation.gen_map_py` produce them directly from the dataset.

## Lean definitions

`FLARE` writes Lean files against the same `MILPFormulation` /
`MILPReformulation` structures used by FormulationBench. They are
documented in the FormulationBench docs:

- {fb}`MILPFormulation </definitions.html#milp-formulation>`
- {fb}`MILPReformulation </definitions.html#reformulation>`

A copy of `Common.lean` (and a minimal Lake skeleton) is bundled with
`milp_flare` and copied into the agent working directory at runtime.

## Inspecting the run artifacts

`output_path` is populated with everything `FLARE` produced:

```
runs/p1_a_b/
├── config.json             # Harness, image, model, and effort configuration
├── result.json             # Final verdict, sub-checks, token usage, cost
└── wd/                     # Agent working directory
    ├── A/
    │   ├── formulation.md       # Input written by FLARE
    │   ├── solve.py             # Input written by FLARE
    │   └── Formulation.lean     # Output written by the agent
    ├── B/
    │   ├── formulation.md
    │   ├── solve.py
    │   └── Formulation.lean
    ├── map.md                   # Parameter map description written by FLARE
    ├── map.py                   # Parameter map script written by FLARE
    ├── Reformulation.lean       # The proof produced by the agent
    ├── agent_output.jsonl       # Stream of agent turns
    ├── compile_log.txt          # Output of the post-hoc Lean compile
    └── result.json              # Agent and per-file compile exit codes
```

- **Input:** The `A/`, `B/`, and `map.*` inputs come straight from the {class}`~milp_flare.flare.FormulationInput` and {class}`~milp_flare.flare.ParameterMapInput` arguments.
- **Output:** The `/A/Formulation.lean` and `/B/Formulation.lean` files contain `FLARE`'s autoformalization of each formulation, and `/Reformulation.lean` is `FLARE`'s reformulation certificate.

The two `result.json` files are distinct: `wd/result.json` is written by the
container entrypoint and holds raw exit codes (`agent_exit`,
`form_a_compile_exit`, `form_b_compile_exit`, `compile_exit`), while the
top-level `result.json` is `FLARE`'s evaluation of the run. It records the
individual sub-checks behind the verdict: whether each `Formulation.lean`
was written and compiled, whether `Reformulation.lean` contains a
`def : MILPReformulation`, whether it compiled, whether it is `sorry`-free,
and whether it depends only on the standard axioms ({data}`~milp_flare.flare.STANDARD_AXIOMS`).

## Using FLARE on a non-dataset pair

{class}`~milp_flare.flare.FormulationInput` and {class}`~milp_flare.flare.ParameterMapInput` do not depend on FormulationBench. You just need to supply a Markdown description and Python implementation for each formulation and the parameter mapping. It is recommended that the descriptions resemble the FormulationBench {fb}`schema </schema.html>`.
