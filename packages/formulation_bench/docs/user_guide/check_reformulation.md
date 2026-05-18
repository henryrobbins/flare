# Checking a reformulation with FLARE

FLARE verifies whether one MILP formulation is a constructive
reformulation of another by driving a coding agent inside a sandboxed
Docker container. The agent writes Lean 4 encodings of both
formulations and a `MILPReformulation` proof connecting them, then a
post-hoc Lean compile step decides whether the proof type-checks.

This tutorial uses the `milp_flare` package, which is distributed
separately from `formulation_bench`.

## Prerequisites

1. **Install `milp_flare`** alongside `formulation_bench`.
2. **Install Docker** and ensure the daemon is running.
3. **Authenticate the coding agent.** For the Claude Code harness:

   ```bash
   claude setup-token
   ```

   Save the printed token to a `.env` file as
   `CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...`. This is how the agent
   bills against your Claude.ai plan inside the container.
4. **Build the agent image** (one-time, ~5 minutes cold):

   ```bash
   milp-flare build-image
   ```

   This builds the `flare-agent:latest` image used by every harness.

## Verifying a pair from the dataset

The snippet below loads formulations `a` and `b` of problem `p1` and
asks FLARE to check whether `b` is a reformulation of `a`.

```python
from pathlib import Path

from formulation_bench import Dataset
from milp_flare import FLARE, FormulationInput, HarnessConfig
from milp_flare.harness import ClaudeCodeHarness

ds = Dataset.load()
p1 = ds.problem("p1")
a = p1.formulation("a")
b = p1.formulation("b")

harness = ClaudeCodeHarness(
    HarnessConfig(model="claude-opus-4-7", reasoning_effort="medium")
)
flare = FLARE(harness=harness)

a_in = FormulationInput(formulation_md=a.render_markdown(), solve_py=a.gurobipy_code)
b_in = FormulationInput(formulation_md=b.render_markdown(), solve_py=b.gurobipy_code)

result = flare.verify(a_in, b_in, output_path=Path("runs/p1_a_b"))

print("is_reformulation:", result.is_reformulation)
print("duration_s:", result.duration_s)
print("cost_usd:", result.cost_usd)
```

`FormulationInput` carries just the two artifacts the agent needs: a
markdown description of the formulation (`formulation_md`) and a
runnable Gurobi script (`solve_py`). The `Formulation` class on the
dataset side produces both directly.

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

`result.json` records the individual sub-checks that make up the
final verdict: whether each `Formulation.lean` was written and
compiled, whether `Reformulation.lean` contains a `def : MILPReformulation`,
whether it compiled, and whether it is `sorry`-free.

## Using a different agent

`milp_flare` ships three harnesses: `ClaudeCodeHarness`, `CodexHarness`,
and `OpenCodeHarness`. They share the `HarnessConfig` API; swap in a
different harness class and update `model` accordingly.

For a non-dataset pair, build the two `FormulationInput`s manually
from your own markdown and `solve.py` files — FLARE does not depend
on `formulation_bench` at runtime.
