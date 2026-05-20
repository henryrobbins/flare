# milp-flare Agent Guide

`milp-flare` is a Python package implementing `FLARE` and `FLARE-NL`. `FLARE` uses an LLM-based agent and the Lean proof assistant to verify mixed-integer linear program (MILP) reformulations according to the FormulationBench definition of reformulation. `FLARE-NL` is a Large Language Model (LLM) proxy for `FLARE` that trades off formal guarantees for speed and cost.

## Monorepo context

This package currently lives inside the [FLARE
monorepo](https://github.com/henryrobbins/flare) as a uv workspace member
under `packages/milp_flare/`. The other workspace member,
[`formulation-bench`](../formulation_bench/), provides the dataset loader
and is a dev dependency here. The package owns its own `pyproject.toml`,
`LICENSE.md`, and `docs/` tree, and is published independently to PyPI.

## Tooling

- **uv** — environment and workspace management
- **ruff** — linting and formatting (`E`, `F`, `I`, `UP`; line length 88)
- **mypy** — type-checking in `strict` mode
- **pytest** — tests, including `--doctest-modules` on the source tree;
  a `docker` marker gates tests that require a running Docker daemon
- **Sphinx** (with `myst-parser`, `furo`, `numpydoc`,
  `sphinx-autodoc-typehints`) — docs, hosted on Read the Docs
- **Jinja2** — runtime templating (the package's only runtime dep)
- **Docker** — required at runtime for the agent sandbox

All common commands are wrapped in the package-local `Makefile`. Run
`make help` from `packages/milp_flare/` for the list.

## File structure

```
packages/milp_flare/
├── src/milp_flare/          # the package
│   ├── flare.py             # FLARE implementation 
│   ├── flare_nl.py          # FLARE-NL implementation
│   ├── __main__.py          # `milp-flare` CLI (e.g. build-image)
│   ├── _prompts.py          # agent prompt assembly
│   ├── _assets.py           # bundled-asset loader
│   ├── harness/             # agent harnesses
│   │   ├── base.py          # Harness interface
│   │   ├── claude_code.py
│   │   ├── codex.py
│   │   ├── opencode.py
│   │   └── cost.py          # LLM cost estimation
│   └── assets/              # bundled prompts, skills, Lean scaffolding, Dockerfile
│       ├── docker/          # Dockerfile + entrypoint for flare-agent image
│       ├── lean/            # lake project skeleton (Common.lean, lakefile, ...)
│       ├── prompts/         # Jinja prompt templates
│       ├── skills/          # Agent Skill files
│       ├── scripts/
│       └── configs/
├── tests/                   # pytest suite
├── docs/                    # Sphinx docs (published to Read the Docs)
│   ├── conf.py
│   ├── index.md
│   ├── installation.md
│   ├── prompts.md
│   ├── skills.md
│   ├── user_guide/
│   └── api/
├── Makefile
├── pyproject.toml
└── README.md
```

## Tests

```bash
make test            # skips docker-marked tests
make test-docker     # docker-marked tests requires a running Docker daemon
```

Pytest is configured to collect from both `tests/` and `src/milp_flare/`
(the latter for `--doctest-modules`), so docstring examples are part of
the suite — keep them runnable. Tests that exercise the agent sandbox
are tagged with the `docker` marker; use `make test` to skip them when
Docker isn't available.

The `flare-agent` image must be built once before docker-marked tests
will pass:

```bash
make build-image
```

## Docs

Build once:

```bash
make docs
```

Live-reload while editing:

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
make check       # all of the above plus test
```

mypy is strict and scoped to `src/milp_flare` — new code needs full
annotations. Ruff's selected rule groups are `E`, `F`, `I`, `UP`; let
`make format` handle import ordering and modern-syntax rewrites.
