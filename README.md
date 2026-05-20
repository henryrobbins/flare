# FLARE

[![CI](https://github.com/henryrobbins/flare/actions/workflows/ci-python.yml/badge.svg)](https://github.com/henryrobbins/flare/actions/workflows/ci-python.yml)
[![codecov](https://codecov.io/gh/henryrobbins/flare/branch/main/graph/badge.svg)](https://codecov.io/gh/henryrobbins/flare)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Checked with mypy](https://www.mypy-lang.org/static/mypy_badge.svg)](https://mypy-lang.org/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)

> [!NOTE]
> This monorepo hosts the dataset, packages, and experiment code accompanying
> *[FLARE: Verifying MILP Reformulations with LLM-Based Formal Proof
> Synthesis](https://flare.henryrobbins.com/)*.

`FLARE` (Formulation-Level Automated Reformulation Evaluation) uses an
LLM-based agent and the Lean 4 proof assistant to verify mixed-integer linear
program (MILP) reformulations. `FLARE` is implemented in the `milp-flare` Python package and evaluated on the **FormulationBench** dataset using the `formulation-bench` Python package. This repository is a monorepo hosting the FormulationBench dataset, both Python packages, and all of the experimental code used to produce the paper's results.

## Sub-Projects

| Project | Path | Description | Links |
| --- | --- | --- | --- |
| **FormulationBench** | [`dataset/`](dataset/) | 20 problems, 116 MILP formulations, 96 labelled reformulation pairs. | [![Docs](https://readthedocs.org/projects/formulation-bench/badge/?version=latest)](https://formulation-bench.henryrobbins.com) |
| **`formulation-bench`** | [`packages/formulation_bench/`](packages/formulation_bench/) | Utilities for loading and working with the FormulationBench dataset. | [![PyPI](https://img.shields.io/pypi/v/formulation-bench)](https://pypi.org/project/formulation-bench/) [![codecov](https://codecov.io/gh/henryrobbins/flare/branch/main/graph/badge.svg?flag=formulation_bench)](https://codecov.io/gh/henryrobbins/flare?flags%5B0%5D=formulation_bench) [![Docs](https://readthedocs.org/projects/formulation-bench/badge/?version=latest)](https://formulation-bench.henryrobbins.com) |
| **`milp-flare`** | [`packages/milp_flare/`](packages/milp_flare/) | Official implementation of FLARE and FLARE-NL. | [![PyPI](https://img.shields.io/pypi/v/milp-flare)](https://pypi.org/project/milp-flare/) [![codecov](https://codecov.io/gh/henryrobbins/flare/branch/main/graph/badge.svg?flag=milp_flare)](https://codecov.io/gh/henryrobbins/flare?flags%5B0%5D=milp_flare) [![Docs](https://readthedocs.org/projects/milp-flare/badge/?version=latest)](https://milp-flare.henryrobbins.com/en/latest) |
| **Experiments** | [`src/`](src/), [`experiments/`](experiments/), [`scripts/`](scripts/) | Paper experiment code: alternative verifiers, prompt templates, and experiment/analysis scripts. | [![codecov](https://codecov.io/gh/henryrobbins/flare/branch/main/graph/badge.svg?flag=src)](https://codecov.io/gh/henryrobbins/flare?flags%5B0%5D=src) |

## Reproducing Experimental Results

The two scripts in [`experiments/`](experiments/) reproduce every quantitative result.

### Setup

1. Install [uv](https://docs.astral.sh/uv/), then sync the workspace:
   ```bash
   make install
   ```
2. Build the `flare-agent` Docker image (`FLARE` runs each agent in a Docker container):
   ```bash
   make -C packages/milp_flare build-image
   ```
3. Populate all necessary API keys for the LLM-based verifiers (Anthropic, OpenAI, DeepSeek). The relevant secrets go in a top-level `.env` file (see `.env.example`).
4. Install a [Gurobi](https://www.gurobi.com/) license (required by the `execution` baseline and the dataset's `solve.py` scripts). A free [academic license](https://www.gurobi.com/academia/academic-program-and-licenses/) works.

See the `milp-flare` [installation guide](https://milp-flare.henryrobbins.com/en/latest/installation.html) for more details.

### Baseline (Table 1, Table 2)

Runs `execution`, `equivamap`, and `FLARE` on every reformulation pair, 3
runs each, with results written under `runs/<timestamp>/`:

```bash
uv run python -m experiments.baseline -c experiments/configs/baseline.yaml
```

Subsets and worker counts are overridable on the CLI:

```bash
uv run python -m experiments.baseline -c experiments/configs/baseline.yaml \
    --problems 1,2,3 --workers 5 --runs 3
```

### FLARE-NL Ablation Study (Table 3, Table 5)

Sweeps prompt variants and LLM models for `FLARE-NL`:

```bash
uv run python -m experiments.ablation -c experiments/configs/ablation.yaml
```

For Table 5 in the Appendix, use the `ablation_p12.yaml` configuration.

```bash
uv run python -m experiments.ablation -c experiments/configs/ablation_p12.yaml
```

### FLARE Harness Evaluation (Table 6)

Sweeps different agent harnesses for `FLARE`:

```bash
uv run python -m experiments.baseline -c experiments/configs/baseline_flare.yaml
```

### Aggregating results

Per-instance and aggregated classification metrics for any run directory:

```bash
uv run python scripts/report.py runs/<timestamp>           # summary
uv run python scripts/report.py runs/<timestamp> -i        # per-instance
```

Additional analysis scripts (cost/time plots, context analysis) live under
[`scripts/analysis/`](scripts/analysis/).

## Development

See `AGENTS.md` for development information.

## Cite

TODO: arXiv paper.

## License

[MIT](LICENSE.md)
