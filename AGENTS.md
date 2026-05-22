# FLARE Agent Guide

This monorepo hosts the **FormulationBench** dataset of MILP problems,
formulations, and Lean 4 reformulation proofs, alongside two publishable
Python packages and the experiment code used to produce the FLARE paper's
results.

## Top-level layout

```
.
├── dataset/                 # FormulationBench
├── packages/
│   ├── formulation_bench/   # publishable Python package `formulation-bench`
│   └── milp_flare/          # publishable Python package `milp-flare`
├── src/                     # experiment code (LLM client, prompts, verifiers)
├── experiments/             # experiment scripts and configs
├── scripts/                 # utility scripts (analysis, dataset, review)
├── site/                    # paper landing page (Astro, deployed to GitHub Pages)
├── lakefile.toml
├── lean-toolchain
├── pyproject.toml
└── Makefile
```

## Sub-project guides

Per-project development information lives next to each project. Read the
guide for the area you are working in instead of duplicating it here:

- **Dataset** — [`dataset/AGENTS.md`](dataset/AGENTS.md) (points to the
  published [dataset schema](packages/formulation_bench/docs/schema.md)).
- **`formulation-bench` package** —
  [`packages/formulation_bench/AGENTS.md`](packages/formulation_bench/AGENTS.md).
- **`milp-flare` package** —
  [`packages/milp_flare/AGENTS.md`](packages/milp_flare/AGENTS.md), including
  the Docker harness setup.
- **Paper landing page** — [`site/README.md`](site/README.md). Astro project
  built with `npm run dev` / `npm run build` from `site/`; deployed to
  GitHub Pages (https://flare.henryrobbins.com/) on pushes to the `site`
  branch by `.github/workflows/deploy-site.yml`. Content lives in
  [`site/src/paper.mdx`](site/src/paper.mdx).

## Experiment code (`src/`)

Not published; installed editable as the package `src`. The
[`verify/base.py`](src/verify/base.py) `ReformulationVerifier` interface is
the common contract shared by every verifier implementation; verifiers are
constructed from dict specs (loaded from YAML configs) via
[`verify/factory.py`](src/verify/factory.py).

```
src/
├── llm_client/          # provider-agnostic LLM client with retry/backoff
│   ├── base.py          # LLMClient protocol + retry helpers + cost helpers
│   ├── anthropic.py     # Anthropic (Claude) client
│   ├── openai.py        # OpenAI client
│   └── deepseek.py      # DeepSeek client
├── verify/
│   ├── base.py          # ReformulationVerifier + ReformulationResult
│   ├── factory.py       # build verifiers from YAML configs
│   ├── equivamap/       # EquivaMap baseline
│   ├── execution/       # Execution-based numerical baseline
│   ├── llm/             # Direct LLM baseline (FLARE-NL family)
│   └── flare.py         # Adapter wrapping milp_flare.FLARE
└── analysis/
    └── agent_jsonl.py   # Normalizes agent JSONL traces into a CSV schema
```

## `experiments/`

Entry-point scripts plus YAML configs under `experiments/configs/`. Each
script writes a timestamped subdirectory under `runs/<timestamp>/` with
`results.jsonl` and per-pair artifacts.

- `experiments/baseline.py` — runs every configured verifier on every
  reformulation pair (multi-run aware via per-verifier `multi_run`).
- `experiments/ablation.py` — prompt-template × model sweep for `FLARE-NL`.

See the [Reproducing the paper](README.md#reproducing-the-paper) section of
the root README for invocation details.

## `scripts/`

Standalone utilities. Each script has a top-of-file docstring with full
usage; the summary below is just an index.

**Top-level**

- `scripts/report.py` — classification metrics (precision, recall, accuracy)
  for `runs/<id>/results.jsonl`; aggregated by default, per-instance with
  `-i`. Reports mean ± std across runs when `run` is set.
- `scripts/combine_runs.py` — merge multiple run directories into a new run
  by symlinking artifact dirs and merging `results.jsonl`. Later runs win on
  duplicate `(pair_id, method)`. Supports `--last N`.

**`scripts/analysis/`** — derive plots/tables from a run's normalized agent
traces (produced via `src/analysis/agent_jsonl.py`).

- `time_cost_analysis.py` — wall-clock and `$USD` summary across artifact
  dirs; aggregate by default, `-i` for per-artifact rows. Falls back to
  estimated cost via the project pricing table when the harness (e.g.
  `codex`) doesn't report `cost_usd`.
- `plot_agent_time.py` — horizontal Gantt of each artifact dir's tool
  activity over wall-clock time, colored by tool group.
- `context_analysis.py` — per-file context-read summary
  (Read/Bash/Edit/lean-lsp) with read counts, total chars, and
  ~4-chars/token estimates.

**`scripts/dataset/`** — dataset integrity checks.

- `validate_solve.py` — regenerate `solve.py` for every formulation, then
  run `gen_params` + solve and verify objectives match `solution.json`.
- `validate_evocut_problems.py` — assert that every non-`a` formulation in
  the EvoCut problems (p6–p12) is a prefix-superset of formulation `a`.

**`scripts/review/`** — LLM-assisted FLARE result inspection.

- `extract_flare_lean.py` — pull `A/Formulation.lean`, `B/Formulation.lean`,
  and `Reformulation.lean` out of every artifact dir in a run, rewriting
  imports into a flat `results/<run_id>/<problem>/<a_b>/<artifact>/` layout.
- `flare_formulation_reviewer.py` — local HTTP UI to diff extracted FLARE
  outputs against the ground-truth dataset formulation.

## Testing and coverage

The pytest config at the repo root (`pyproject.toml`) collects from:

- `tests/` (root experiment tests, currently `tests/verifiers/`)
- `packages/formulation_bench/{tests,src/formulation_bench}`
- `packages/milp_flare/{tests,src/milp_flare}`

Source-tree paths are included so `--doctest-modules` exercises docstring
examples — keep them runnable. One marker gates an optional dependency:

- `docker` — tests that need a running Docker daemon (build
  `flare-agent` first via `make -C packages/milp_flare build-image`).

`addopts` skips `docker` by default. From the repo root:

```bash
make test          # pytest, excluding docker
make check         # lint + typecheck + test
make check-all     # check at the root and in every package
```

Each Python source tree (`src/`, `packages/formulation_bench/`,
`packages/milp_flare/`) has its own `make cov` target that runs pytest with
coverage scoped to that tree and writes `htmlcov/` + `coverage.xml`:

```bash
make cov                                # coverage for src/
make cov-open                           # open the HTML report
make cov-clean                          # remove coverage artifacts
make -C packages/formulation_bench cov  # coverage for formulation_bench
make -C packages/milp_flare cov         # coverage for milp_flare
make cov-all                            # all three trees
```

CI uploads each `coverage.xml` to
[Codecov](https://codecov.io/gh/henryrobbins/flare) under separate flags
(`src`, `formulation_bench`, `milp_flare`) so the three trees are tracked
independently.

## Lint, format, type-check

```bash
make lint          # ruff check on src, experiments, scripts
make format        # ruff format + ruff check --fix
make typecheck     # mypy (strict) — files = scripts, src, experiments
```

mypy strict mode applies to `src/`, `scripts/`, and `experiments/`; new
code in those trees needs full annotations. Ruff's selected rule groups are
`E`, `F`, `I`, `UP` with line length 88. Per-file ignores in
`pyproject.toml` exempt `scripts/review/flare_formulation_reviewer.py`
(`E501`) and the generated `gen_params.py`/`gen_data.py` files under
`dataset/` (`E741`).

## Common Workflows

The repo provides a set of skills and agents for working with the dataset.

**Generate a Lean MILP formulation**

1. Identify the relevant source file(s) to read. E.g., the relevant source
   files for problem 1, formulation e (p1.e) are the problem files in
   `dataset/problems/p1` and the formulation files in
   `dataset/problems/p1/formulations/e`. If the user requests generating
   formulations for a problem, generate all of the problem's formulations.
2. The output file(s) will be `Formulation.lean` in each formulation's
   subdirectory. E.g., the formulation for p1.e goes in
   `dataset/problems/p1/formulations/e/Formulation.lean`.
3. Invoke the `milp-formulator` agent with the identified source/output. If
   generating multiple formulations, invoke multiple agents in parallel.

**Generate Lean MILP reformulation proof**

1. Identify the relevant source file(s) to read. At minimum, read each
   MILP's `Formulation.lean` file. E.g., for proving p1.b is a reformulation
   of p1.a, read the problem files in `dataset/problems/p1` and the
   formulation files in `dataset/problems/p1/formulations/a|b`. If a
   formulation subdirectory does not yet contain `Formulation.lean`, follow
   the steps above to generate it.
2. The output file for proving formulation b is a reformulation of
   formulation a (for problem X) is `dataset/reformulations/pX/a_b.lean`.
3. Invoke the `milp-reformulation-autoformalizer` agent with the identified
   source/output. If generating multiple proofs, invoke multiple agents in
   parallel.

**Review existing Lean MILP formulations or reformulation proofs**

1. Identify the relevant file(s) to read: problem files, formulation files,
   `Formulation.lean`, and `dataset/reformulations/pX/a_b.lean`.
2. Invoke the `milp-reviewer` agent pointing to the relevant file locations.
   If reviewing multiple files, invoke multiple agents in parallel.
