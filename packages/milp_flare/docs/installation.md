# Installation

## Install the package

The `milp-flare` package is available on [PyPI](https://pypi.org/project/milp-flare/) and can be installed with `pip`:

```bash
pip install milp-flare
```

## Quickstart

This quickstart runs `FLARE` on a pair of formulations from the {fb}`FormulationBench </>` dataset (see {doc}`/user_guide/run_flare` for more detail). It requires the following prerequisites:

- **Docker** installed and the `flare-agent` image built (see {doc}`user_guide/docker`)
- **Claude Code authentication key** on the host (see {doc}`agent_harness/index`)
- **FormulationBench** Python package `formulation-bench` (see {fb}`FormulationBench </installation.html>`)


```python
from pathlib import Path

from formulation_bench import Dataset
from milp_flare import FLARE, FormulationInput, ParameterMapInput
from milp_flare.harness import ClaudeCodeHarness

ds = Dataset.load()
pair = ds.reformulations[0]  # p1.a -> p1.b
a, b = pair.a, pair.b

harness = ClaudeCodeHarness(model="claude-opus-4-7", effort="medium")
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
```

See the {doc}`user_guide/index` for end-to-end tutorials.
