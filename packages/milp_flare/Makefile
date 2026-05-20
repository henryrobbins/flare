# Common dev commands for the milp-flare package.
# Run from this directory (packages/milp_flare/).

.PHONY: help install test test-docker lint format typecheck check build-image docs docs-serve docs-clean clean

help:
	@echo "Targets:"
	@echo "  install         Sync workspace deps with uv"
	@echo "  test            Run pytest, skipping docker-marked tests"
	@echo "  test-docker     Run docker-marked tests (requires Docker)"
	@echo "  lint            Run ruff check"
	@echo "  format          Run ruff format + ruff check --fix"
	@echo "  typecheck       Run mypy"
	@echo "  check           Run lint + typecheck + test"
	@echo "  build-image     Build the flare-agent Docker image"
	@echo "  docs            Build the Sphinx docs once"
	@echo "  docs-serve      Live-reload docs in browser"
	@echo "  docs-clean      Remove built docs"
	@echo "  clean           Remove build + cache artifacts"

install:
	uv sync

test:
	uv run --package milp-flare pytest -m 'not docker'

test-docker:
	uv run --package milp-flare pytest -m 'docker'

lint:
	uv run --package milp-flare ruff check src tests

format:
	uv run --package milp-flare ruff format src tests
	uv run --package milp-flare ruff check --fix src tests

typecheck:
	uv run --package milp-flare mypy

check: lint typecheck test

build-image:
	uv run --package milp-flare milp-flare build-image

docs:
	uv run --package milp-flare --extra docs sphinx-build -W -b html docs docs/_build/html

docs-serve:
	uv run --package milp-flare --extra docs sphinx-autobuild --watch src docs docs/_build/html

docs-clean:
	rm -rf docs/_build

clean: docs-clean
	rm -rf _build build dist .pytest_cache .mypy_cache .ruff_cache
	find . -type d -name __pycache__ -exec rm -rf {} +
