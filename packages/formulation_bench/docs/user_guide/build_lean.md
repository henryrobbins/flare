# Compiling Lean files with `lake build`

The dataset's Lean 4 files — each formulation's `Formulation.lean`
and each reformulation proof under `dataset/reformulations/` — are
organized as a Lake project rooted at `dataset/`. The root
`lakefile.toml` requires it as a sibling package, so you can build
from either location.

## Prerequisites

1. **Install elan** (the Lean version manager). See the
   [Lean community install guide](https://leanprover-community.github.io/get_started.html).
   `elan` will read `lean-toolchain` and fetch the right Lean
   automatically the first time you build.
2. **Fetch the mathlib cache** (one-time, big download — avoids
   compiling mathlib from source):

   ```bash
   lake update
   lake exe cache get
   ```

   `lake update` resolves the mathlib dependency pinned in
   `dataset/lakefile.toml`; `cache get` downloads pre-compiled
   `.olean` files for it.

## Building everything

From the repository root:

```bash
lake build
```

This builds the default targets declared in `lakefile.toml`. From
inside `dataset/`, `lake build` instead builds the `Common` and
`Dataset` libraries, which together cover every formulation and
reformulation file in the dataset. The first build after a clean
checkout takes a while; incremental rebuilds reuse `.olean`s.

## Building a single file

To compile just one formulation or proof, pass its module path:

```bash
# From the repo root, build a single MILP formulation:
lake build problems.p1.formulations.a.Formulation

# Build a single reformulation proof:
lake build reformulations.p1.a_b
```

The module path mirrors the on-disk path with `/` replaced by `.`
and the `.lean` extension dropped. Lake will pull in only the
files actually required by the target.

## When the build is unhappy

- **`unknown package 'Mathlib'`** — `lake exe cache get` hasn't been
  run yet, or `lake-manifest.json` is out of sync. Re-run
  `lake update && lake exe cache get`.
- **`unknown package 'Common'`** — you are building from the wrong
  directory. `Common` is provided by the `FormulationBench` package
  declared in `dataset/lakefile.toml`; build from `dataset/` or the
  repo root, not from a subdirectory.
- **Toolchain mismatch** — `lean-toolchain` was bumped but `elan`
  hasn't fetched the new version. Run any `lake` command and `elan`
  will install it.
- **Slow first build / out of disk** — mathlib oleans are several GB.
  Make sure `lake exe cache get` succeeded; otherwise Lake will
  compile mathlib from source.

## Inside the FLARE Docker harness

When FLARE drives an agent inside the bundled `flare-agent` image,
the mathlib oleans live in the image layer at `/workspace/.lake` and
are symlinked into the agent working directory at
`/workspace/wd/.lake`. No `lake update` or `cache get` is required
inside the container — the build cache is baked into the image at
`milp-flare build-image` time. See {doc}`check_reformulation` for the
end-to-end FLARE workflow.
