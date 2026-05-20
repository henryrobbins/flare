# Common dev commands for the formulation-bench package.
# Run from this directory (packages/formulation_bench/).

.PHONY: help install dataset-link test lint format typecheck check docs docs-serve docs-clean clean

help:
	@echo "Targets:"
	@echo "  install      Sync workspace deps with uv"
	@echo "  dataset-link Symlink ./dataset -> ../../dataset (needed for doctests)"
	@echo "  test         Run pytest"
	@echo "  lint         Run ruff check"
	@echo "  format       Run ruff format + ruff check --fix"
	@echo "  typecheck    Run mypy"
	@echo "  check        Run lint + typecheck + test"
	@echo "  docs         Build the Sphinx docs once"
	@echo "  docs-serve   Live-reload docs in browser"
	@echo "  docs-clean   Remove built docs"
	@echo "  clean        Remove build + cache artifacts"

install:
	uv sync

dataset-link:
	@test -e dataset || ln -s ../../dataset dataset

test: dataset-link
	uv run --package formulation-bench pytest

lint:
	uv run --package formulation-bench ruff check src tests

format:
	uv run --package formulation-bench ruff format src tests
	uv run --package formulation-bench ruff check --fix src tests

typecheck:
	uv run --package formulation-bench mypy

check: lint typecheck test

docs:
	uv run --package formulation-bench --extra docs sphinx-build -W -b html docs docs/_build/html

docs-serve:
	uv run --package formulation-bench --extra docs bash docs/serve.sh

docs-clean:
	rm -rf docs/_build

clean: docs-clean
	rm -rf _build build dist .pytest_cache .mypy_cache .ruff_cache
	find . -type d -name __pycache__ -exec rm -rf {} +
