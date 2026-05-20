# Common dev commands for the monorepo root.
# Covers experiment trees (src/ + experiments/ + scripts/).
# For per-package commands, see packages/*/Makefile.

PACKAGES := packages/formulation_bench packages/milp_flare

.PHONY: help install test cov cov-open cov-clean lint format typecheck check \
        cov-all check-all clean

help:
	@echo "Targets (root — experiment code under src/, experiments/, scripts/):"
	@echo "  install     Sync workspace deps with uv"
	@echo "  test        Run pytest (excluding docker and gurobi marked tests)"
	@echo "  cov         Run pytest with coverage scoped to src/; writes htmlcov/ and coverage.xml"
	@echo "  cov-open    Open the HTML coverage report"
	@echo "  cov-clean   Remove coverage artifacts"
	@echo "  lint        Run ruff check on src, experiments, scripts"
	@echo "  format      Run ruff format + ruff check --fix on src, experiments, scripts"
	@echo "  typecheck   Run mypy (strict) on src, experiments, scripts"
	@echo "  check       Run lint + typecheck + test"
	@echo "  clean       Remove build + cache artifacts"
	@echo ""
	@echo "Cross-package targets:"
	@echo "  cov-all     Run cov for the root and every package"
	@echo "  check-all   Run check for the root and every package"
	@echo ""
	@echo "Per-package targets live in packages/*/Makefile (run 'make -C packages/<name> help')."

install:
	uv sync

test:
	uv run pytest -m 'not docker and not gurobi'

cov:
	uv run pytest -m 'not docker and not gurobi' \
		--cov=src \
		--cov-report=term-missing \
		--cov-report=html \
		--cov-report=xml

cov-open: cov
	@python -c "import os, webbrowser; webbrowser.open('file://' + os.path.abspath('htmlcov/index.html'))"

cov-clean:
	rm -rf htmlcov coverage.xml .coverage

lint:
	uv run ruff check src experiments scripts

format:
	uv run ruff format src experiments scripts
	uv run ruff check --fix src experiments scripts

typecheck:
	uv run mypy

check: lint typecheck test

cov-all: cov
	@for pkg in $(PACKAGES); do \
		echo "==> $$pkg"; \
		$(MAKE) -C $$pkg cov || exit $$?; \
	done

check-all: check
	@for pkg in $(PACKAGES); do \
		echo "==> $$pkg"; \
		$(MAKE) -C $$pkg check || exit $$?; \
	done

clean: cov-clean
	rm -rf _build build dist .pytest_cache .mypy_cache .ruff_cache
	find . -type d -name __pycache__ -exec rm -rf {} +
