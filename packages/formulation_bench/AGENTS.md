# formulation-bench Agent Guide

`formulation-bench` is a Python package for loading and working with the
**FormulationBench** dataset: a collection of optimization problems, MILP
formulations, and Lean 4 reformulation proofs.

## Monorepo context

This package currently lives inside the [FLARE
monorepo](https://github.com/henryrobbins/flare) as a uv workspace member
under `packages/formulation_bench/`. The dataset itself lives at the
monorepo root under `dataset/`, and the docs build reads from it
directly. The package owns its own `pyproject.toml`, `LICENSE.md`, and
`docs/` tree, and is published independently to PyPI.

## Tooling

- **uv** — environment and workspace management
- **ruff** — linting and formatting (`E`, `F`, `I`, `UP`; line length 88)
- **mypy** — type-checking in `strict` mode
- **pytest** — tests, including `--doctest-modules` on the source tree
- **Sphinx** (with `myst-parser`, `furo`, `numpydoc`,
  `sphinx-autodoc-typehints`) — docs, hosted on Read the Docs
- **Jinja2** — runtime templating (the package's only runtime dep)

All common commands are wrapped in the package-local `Makefile`. Run
`make help` from `packages/formulation_bench/` for the list.

## File structure

```
packages/formulation_bench/
├── src/formulation_bench/   # the package
│   ├── dataset.py           # top-level Dataset loader
│   ├── problem.py           # Problem model
│   ├── formulation.py       # Formulation model
│   ├── reformulation.py     # Reformulation model
│   ├── models.py            # shared data models (Parameter, Variable, ...)
│   ├── download.py          # dataset download helpers
│   ├── _codegen.py          # Python code generation
│   ├── _render.py           # Jinja rendering helpers
│   └── templates/           # Jinja templates
├── tests/                   # pytest suite
├── docs/                    # Sphinx docs (published to Read the Docs)
│   ├── conf.py
│   ├── index.md
│   ├── installation.md
│   ├── user_guide/
│   ├── problems/            # per-problem pages (generated from dataset/)
│   ├── lean/
│   ├── api/
│   ├── schema.md
│   └── serve.sh             # sphinx-autobuild wrapper
├── Makefile
├── pyproject.toml
└── README.md
```

## Tests

```bash
make test
```

Pytest is configured to collect from both `tests/` and
`src/formulation_bench/` (the latter for `--doctest-modules`), so
docstring examples are part of the suite — keep them runnable.

### Dataset symlink

Some doctests instantiate `Dataset("dataset")` with a relative path,
which only resolves when a `dataset/` directory exists in the package
root. In the monorepo the canonical dataset lives at the repo root, so
we symlink it in:

```bash
make dataset-link    # creates ./dataset -> ../../dataset if missing
```

`make test` runs this automatically. The symlink is gitignored; it's a
dev-only convenience and is not shipped in the published wheel.

## Coverage

```bash
make cov        # pytest with coverage; writes htmlcov/ and coverage.xml
make cov-open   # open the HTML report in a browser
make cov-clean  # remove coverage artifacts
```

CI uploads `coverage.xml` to [Codecov](https://codecov.io/gh/henryrobbins/flare)
under the `formulation_bench` flag.

## Docs

Build once:

```bash
make docs
```

Live-reload while editing (watches both `docs/` and `dataset/` so
per-problem pages regenerate when dataset JSON changes):

```bash
make docs-serve
```

Both targets pull in the `docs` extra automatically. Sphinx is
configured with `fail_on_warning: true` on Read the Docs, so `make
docs` also runs with `-W` locally.

## Lint, format, type-check

```bash
make lint        # ruff check
make format      # ruff format + ruff check --fix
make typecheck   # mypy (strict)
make check       # all of the above plus tests
```

mypy is strict and scoped to `src/formulation_bench` — new code needs
full annotations. Ruff's selected rule groups are `E`, `F`, `I`, `UP`;
let `make format` handle import ordering and modern-syntax rewrites.
