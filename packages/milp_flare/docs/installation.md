# Installation

## Install the package

The `milp-flare` package is available on [PyPI](https://pypi.org/project/milp-flare/) and can be installed with `pip`:

```bash
pip install milp-flare
```

## Quickstart

This quickstart runs `FLARE` on a pair of formulations from the {fb}`FormulationBench </>` dataset (see {doc}`/user_guide/run_flare` for more detail). It requires the following prerequisites:

- **Docker** installed and the `flare-agent` image built (see {doc}`user_guide/docker`)
- **Claude Code authentication key** on the host (see {doc}`user_guide/authenticate_agent`)
- **FormulationBench** Python package `formulation-bench` (see {fb}`FormulationBench </installation.html>`)


```python
from pathlib import Path

from formulation_bench import Dataset
from milp_flare import FLARE, FormulationInput
from milp_flare.harness import ClaudeCodeHarness

ds = Dataset.load()
p1 = ds.problems[1]
a = p1.formulations["a"]
b = p1.formulations["b"]

harness = ClaudeCodeHarness(model="claude-opus-4-7", effort="medium")
flare = FLARE(harness=harness)

a_in = FormulationInput(
    formulation_md=a.render_markdown(), solve_py=a.gen_solve_py()
)
b_in = FormulationInput(
    formulation_md=b.render_markdown(), solve_py=b.gen_solve_py()
)

result = flare.verify(a_in, b_in, output_path=Path("runs/p1_a_b"))
```

See the {doc}`user_guide/index` for end-to-end tutorials.
