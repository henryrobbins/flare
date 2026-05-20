# Common dev commands for the monorepo root (covers src/ + experiments/ + scripts/).
# For per-package commands, see packages/*/Makefile.

.PHONY: help cov cov-open cov-clean

help:
	@echo "Targets:"
	@echo "  cov        Run root pytest with coverage scoped to src/; writes htmlcov/ and coverage.xml"
	@echo "  cov-open   Open the HTML coverage report"
	@echo "  cov-clean  Remove coverage artifacts"

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
