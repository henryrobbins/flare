# milp-flare

[![arXiv](https://img.shields.io/badge/arXiv-2608.25220-b31b1b.svg)](https://arxiv.org/abs/2608.25220)
[![PyPI version](https://img.shields.io/pypi/v/milp-flare)](https://pypi.org/project/milp-flare/)
[![CI](https://github.com/henryrobbins/flare/actions/workflows/ci-python.yml/badge.svg)](https://github.com/henryrobbins/flare/actions/workflows/ci-python.yml)
[![codecov](https://codecov.io/gh/henryrobbins/flare/branch/main/graph/badge.svg?flag=milp_flare)](https://codecov.io/gh/henryrobbins/flare?flags%5B0%5D=milp_flare)
[![Documentation Status](https://readthedocs.org/projects/milp-flare/badge/?version=latest)](https://milp-flare.henryrobbins.com/en/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Checked with mypy](https://www.mypy-lang.org/static/mypy_badge.svg)](https://mypy-lang.org/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)

> [!NOTE]
> This is the official implementation of `FLARE` and `FLARE-NL` introduced in *[FLARE: Verifying MILP Reformulations with LLM-Based Theorem Proving](https://flare.henryrobbins.com/)*.

`FLARE` (Formulation-Level Automated Reformulation Evaluation) uses an LLM-based agent and the Lean proof assistant to verify mixed-integer linear program (MILP) reformulations according to the [FormulationBench](https://formulation-bench.henryrobbins.com/en/latest/definitions.html) definition of reformulation. `FLARE-NL` is a Large Language Model (LLM) proxy for `FLARE` that trades off formal guarantees for speed and cost. See the [documentation](https://milp-flare.henryrobbins.com) for details.

## Installation

```bash
pip install milp-flare
```

`FLARE` runs an agent harness (e.g., Claude Code, Codex, OpenCode) in a Docker container. The Docker image must be built prior to running the method.

```bash
milp-flare build-image
```

Furthermore, each agent harness has different requirements for authentication. See [Installation](https://milp-flare.readthedocs.io/en/latest/installation.html) for more details.

## Quickstart

`FLARE` is most frequently run on the [FormulationBench](https://formulation-bench.henryrobbins.com) dataset (though it is not a strict dependency).

```python
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
```

## Development

See `AGENTS.md` for development information.

## Cite

```bibtex
@misc{robbins2026flare,
  title = {{{FLARE}}: Verifying {{MILP}} Reformulations with {{LLM}}-Based Theorem Proving},
  author = {Robbins, Henry and Lawless, Connor and Udell, Madeleine and Vitercik, Ellen},
  year = 2026,
  eprint = {2608.25220},
  archivePrefix = {arXiv},
  primaryClass = {cs.AI},
  url = {https://arxiv.org/abs/2608.25220}
}
```

## License

[MIT](LICENSE.md)
