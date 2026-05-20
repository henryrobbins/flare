# formulation-bench

[![PyPI version](https://img.shields.io/pypi/v/formulation-bench)](https://pypi.org/project/formulation-bench/)
[![CI](https://github.com/henryrobbins/flare/actions/workflows/ci-python.yml/badge.svg)](https://github.com/henryrobbins/flare/actions/workflows/ci-python.yml)
[![Documentation Status](https://readthedocs.org/projects/formulation-bench/badge/?version=latest)](https://formulation-bench.henryrobbins.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Checked with mypy](https://www.mypy-lang.org/static/mypy_badge.svg)](https://mypy-lang.org/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)

Python utilities for loading and working with the [FormulationBench](https://formulation-bench.henryrobbins.com) dataset. FormulationBench is a collection
of 20 optimization problems with 116 mixed-integer linear programming (MILP)
formulations. Each formulation has a natural language description, LaTeX
formulation, GurobiPy implementation, and Lean representation. Furthermore,
there are 96 pairs of formulations consisting of 70 positive reformulation
examples and 26 negative examples. Each positive example has a machine-checked 
Lean 4 reformulation proof. See the [documentation](https://formulation-bench.henryrobbins.com) for details.

## Installation

```bash
pip install formulation-bench
```

## Quickstart

Download the dataset:

```python
from formulation_bench import Dataset
ds = Dataset.load()
```

Access a problem's formulations:

```python
p1 = ds.problems[1]
p1a = p1.formulations["a"]
```

Access reformulation pairs:

```python
pos = [r for r in ds.reformulations if r.is_reformulation]
neg = [r for r in ds.reformulations if not r.is_reformulation]
```

## Development

See `AGENTS.md` for development information.

## Cite

TODO: Add arXiv article citation

## License

[MIT](LICENSE.md)
