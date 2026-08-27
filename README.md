# FLARE

[![arXiv](https://img.shields.io/badge/arXiv-2608.25220-b31b1b.svg)](https://arxiv.org/abs/2608.25220)
[![CI](https://github.com/henryrobbins/flare/actions/workflows/ci-python.yml/badge.svg)](https://github.com/henryrobbins/flare/actions/workflows/ci-python.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Checked with mypy](https://www.mypy-lang.org/static/mypy_badge.svg)](https://mypy-lang.org/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)

This is the official code repository for *[FLARE: Verifying MILP Reformulations with LLM-Based Theorem Proving](https://flare.henryrobbins.com/)*. `FLARE` (Formulation-Level Automated Reformulation Evaluation) uses an LLM-based agent and the Lean 4 proof assistant to verify mixed-integer linear program (MILP) reformulations. `FLARE` is implemented in the `milp-flare` Python package and evaluated on the [FormulationBench](https://github.com/henryrobbins/formulation-bench) dataset using the `formulation-bench` Python package. This repository hosts `milp-flare` and all of the experimental code used to produce the paper's results.

## Packages and Code

| Code | Location | Description | Links |
| --- | --- | --- | --- |
| `formulation-bench` | [GitHub](https://github.com/henryrobbins/formulation-bench) | FormulationBench dataset and loader package. | [![PyPI](https://img.shields.io/pypi/v/formulation-bench)](https://pypi.org/project/formulation-bench/) [![Docs](https://readthedocs.org/projects/formulation-bench/badge/?version=latest)](https://formulation-bench.henryrobbins.com) [![codecov](https://codecov.io/gh/henryrobbins/formulation-bench/branch/main/graph/badge.svg)](https://codecov.io/gh/henryrobbins/formulation-bench) |
| `milp-flare` | [`packages/milp_flare/`](packages/milp_flare/) | Official implementation of `FLARE` and `FLARE-NL`. | [![PyPI](https://img.shields.io/pypi/v/milp-flare)](https://pypi.org/project/milp-flare/) [![Docs](https://readthedocs.org/projects/milp-flare/badge/?version=latest)](https://milp-flare.henryrobbins.com/en/latest) [![codecov](https://codecov.io/gh/henryrobbins/flare/branch/main/graph/badge.svg?flag=milp_flare)](https://codecov.io/gh/henryrobbins/flare?flags%5B0%5D=milp_flare) |
| Experiments | [`src/`](src/), [`experiments/`](experiments/), [`scripts/`](scripts/) | Code to reproduce paper experimental results. | - |
| Landing page | [`site/`](site/) | Paper landing page. | [Live site](https://flare.henryrobbins.com/) |

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

The experiment scripts fetch the FormulationBench dataset on first use via
`Dataset.load()`. Also see the [Downloading the dataset](https://formulation-bench.henryrobbins.com/en/latest/user_guide/download.html) user guide.

Also see the `milp-flare` [installation guide](https://milp-flare.henryrobbins.com/en/latest/installation.html) for more details on building [building the Docker image](https://milp-flare.henryrobbins.com/en/latest/user_guide/docker.html) and [configuring API keys](https://milp-flare.henryrobbins.com/en/latest/agent_harness/index.html).

### Baseline (Table 1, Table 2)

Runs `execution`, `equivamap`, and `FLARE` on every reformulation pair, 3
runs each, with results written under `runs/<timestamp>/`. With no explicit
problem filter, the experiments use the 54 pairs belonging to the 16 NP-hard
problems, the subset on which the paper's notion of reformulation is
meaningful:

```bash
uv run python -m experiments.baseline -c experiments/configs/baseline.yaml
```

Subsets and worker counts are overridable on the CLI:

```bash
uv run python -m experiments.baseline -c experiments/configs/baseline.yaml \
    --problems 1,2,3 --workers 5 --runs 3
```

### FLARE-NL Ablation Study (Table 3, Table 7)

Sweeps prompt variants and LLM models for `FLARE-NL`:

```bash
uv run python -m experiments.ablation -c experiments/configs/ablation.yaml
```

For Table 7 in the Appendix, use the `ablation_p12.yaml` configuration.

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

This repository hosts the `milp-flare` Python package implementing `FLARE` and `FLARE-NL` and the experimental code for *[FLARE: Verifying MILP Reformulations with LLM-Based Theorem Proving](https://flare.henryrobbins.com/)*. If you use either, please cite:

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
