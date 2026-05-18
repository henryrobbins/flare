#!/usr/bin/env bash
# Live-rebuild the FormulationBench docs.
#
# Watches both the docs source tree and the dataset tree so edits to
# problem/formulation JSON trigger a regen of the per-problem pages.
set -euo pipefail

docs_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$docs_dir/../../.." && pwd)"

exec sphinx-autobuild \
    --watch "$repo_root/dataset" \
    "$docs_dir" \
    "$docs_dir/_build/html" \
    "$@"
