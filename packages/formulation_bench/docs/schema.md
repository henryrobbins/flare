# Dataset Schema

This page documents the directory structure and JSON schemas for the
FormulationBench dataset. The `formulation-bench` Python package is the
recommended way to work with the dataset. This schema reference is provided for those modifying or extending the dataset (see {doc}`user_guide/index`).

(directory-structure)=
## Directory Structure

Here is a summary of the directory structure:

```
dataset/
├── lakefile.toml            # Lean project configuration
├── lake-manifest.json       # Pinned Lean library dependencies
├── lean-toolchain           # Pinned Lean version
├── Common.lean              # Lean definitions
├── dataset.json             # Problem IDs and reformulation pairs
├── problems/                # One subdirectory per problem
│   ├── p1/
│   │   ├── description.md   # Natural-language problem description
│   │   ├── problem.json     # Problem name, data parameters, metadata
│   │   ├── data.json        # Concrete parameter values for one instance
│   │   ├── solution.json    # Reference optimal solution and objective
│   │   └── formulations/
│   │       ├── a/
│   │       │   ├── formulation.json   # Structured MILP formulation
│   │       │   ├── gen_params.py      # Maps data.json to MILP parameters
│   │       │   └── Formulation.lean   # Lean 4 MILP formulation
│   │       └── ...
│   └── ...
└── reformulations/          # Lean 4 reformulation proofs
    ├── p1/
    │   ├── a_b.lean         # Proof that formulation b is a reformulation of a
    │   └── ...
    └── ...
```

The root of the dataset directory contains:

- Lean project files: `lakefile.toml`, `lake-manifest.json`, `lean-toolchain` (see {doc}`/user_guide/build_lean`)
- Lean formulation and reformulation definitions: `Common.lean` (see {doc}`/definitions`)
- A manifest of the problems and reformulations contained in the dataset: `dataset.json`
- The problems subdirectory (see {ref}`problem-directory`)
- The reformulations subdirectory (see {ref}`reformulation-pairs-and-proofs`)

The {class}`Dataset <formulation_bench.dataset.Dataset>` loads in this dataset directory.

:::{note}
Two files appear inside a formulation directory at runtime but are *not*
shipped with the dataset: `parameters.json`, written by {meth}`Formulation.run_gen_params()
<formulation_bench.formulation.Formulation.run_gen_params>`, and `solve.py`,
written by {meth}`Formulation.gen_solve_py()
<formulation_bench.formulation.Formulation.gen_solve_py>`. Both are derived
from the files above and can be regenerated at any time.
:::

## `dataset.json`

This is the manifest at the dataset root. It has two fields:

- **`problems`** — list of integer problem IDs (e.g. `1` for `p1`). Each ID
  has a `problems/pN/` directory.
- **`reformulations`** — flat list of labelled formulation pairs (see
  {ref}`reformulation-pairs-and-proofs`)

(problem-directory)=
## Problem Directory

Each `problems/pN/` directory describes one optimization problem and loads
into a {class}`Problem <formulation_bench.problem.Problem>`.

### `description.md`

A self-contained natural-language description of the optimization problem,
exposed as the `description` attribute of {class}`Problem
<formulation_bench.problem.Problem>`. It is also interpolated into the
`problem_description` block when a formulation is rendered with
{meth}`Formulation.render_markdown()
<formulation_bench.formulation.Formulation.render_markdown>`.

:::{dropdown} `problems/p1/description.md`
:icon: code
```{literalinclude} ../../../dataset/problems/p1/description.md
:language: markdown
:class: wrap
```
:::

### `problem.json`

Defines the problem `name`, its data `parameters`, and freeform `metadata`:

- **`name`** — human-readable problem name.
- **`parameters`** — schema of the problem's data parameters, keyed by name.
  Each value is a {class}`Parameter <formulation_bench.models.Parameter>`
  with a `description`, `type`, and `shape` (see
  {ref}`variable-shape-notation`).
- **`metadata`** — freeform; typically a `source` field recording which
  dataset the problem was adapted from and a `notes` field with commentary.
  These populate the source and notes blocks on the {doc}`/problems/index`
  pages.

:::{dropdown} `problems/p1/problem.json`
:icon: code
```{literalinclude} ../../../dataset/problems/p1/problem.json
:language: json
```
:::

### `data.json`

A single concrete instance: a JSON object mapping each parameter name in
`problem.json` to a value. The same instance is reused across every
formulation of the problem (each formulation's `gen_params.py` translates it
into formulation-specific parameters). Exposed as the `data` attribute of
{class}`Problem <formulation_bench.problem.Problem>`.

:::{dropdown} `problems/p1/data.json`
:icon: code
```{literalinclude} ../../../dataset/problems/p1/data.json
:language: json
```
:::

### `solution.json`

A reference optimal solution for the instance in `data.json`, with
`variables` (values keyed by name) and `objective` (the optimal value). It
loads into a {class}`Solution <formulation_bench.models.Solution>`, exposed
as the `solution` attribute of {class}`Problem
<formulation_bench.problem.Problem>`. Variable values are specific to a
*formulation*; by convention they use the variable names of formulation `a`.

:::{dropdown} `problems/p1/solution.json`
:icon: code
```{literalinclude} ../../../dataset/problems/p1/solution.json
:language: json
```
:::

(formulation-directory)=
## Formulation Directory

Each `problems/pN/formulations/x/` directory describes one MILP formulation
of the parent problem and loads into a {class}`Formulation
<formulation_bench.formulation.Formulation>`.

### `formulation.json`

The structured description of the MILP. Each field maps onto an attribute of
{class}`Formulation <formulation_bench.formulation.Formulation>`:

- **`valid`** — boolean indicating whether the formulation is a faithful
  formulation of the parent problem.
- **`parameters`** — parameters of the MILP formulation, each a
  {class}`Parameter <formulation_bench.models.Parameter>`.
- **`assumptions`** — list of {class}`Assumption
  <formulation_bench.models.Assumption>` records, each with a `description`,
  a LaTeX `formulation`, an `explicit` flag, and `code.python`. The
  `explicit` flag is `true` when the assumption is stated explicitly in the
  original problem text and `false` when it is implicit (e.g.
  non-negativity of an obviously physical rate). Assumptions constrain
  *parameters*.
- **`definitions`** — *(optional)* ordered map of named derived quantities
  computed from parameters before variables are declared, each a
  {class}`Definition <formulation_bench.models.Definition>`. Typical uses:
  big-M constants and pre-computed index sets referenced in variable or
  constraint code.
- **`variables`** — decision variables keyed by name, each a
  {class}`Variable <formulation_bench.models.Variable>` with a
  `description`, `type` (`"integer"`, `"continuous"`, or `"binary"`), and a
  `shape` — optionally accompanied by `indices` (see
  {ref}`variable-shape-notation`).
- **`constraints`** — list of {class}`Constraint
  <formulation_bench.models.Constraint>` records, each with a `description`,
  a LaTeX `formulation`, an `explicit` flag, and `code.gurobipy`. The
  `explicit` flag is `false` for implied constraints such as non-negativity
  bounds.
- **`objective`** — a single {class}`Objective
  <formulation_bench.models.Objective>` with a `description`, a LaTeX
  `formulation`, and `code.gurobipy`.
- **`imports`** — *(optional)* list of additional Python import statements
  emitted into the generated `solve.py` (e.g. `["import math"]`).

The `code.python` / `code.gurobipy` snippets are what
{meth}`Formulation.gen_solve_py()
<formulation_bench.formulation.Formulation.gen_solve_py>` assembles into a
runnable solver script.

:::{dropdown} `problems/p12/formulations/a/formulation.json`
:icon: code
```{literalinclude} ../../../dataset/problems/p12/formulations/a/formulation.json
:language: json
```
:::

### `gen_params.py`

A Python script that reads the problem's `data.json` and writes a
`parameters.json` holding this formulation's parameters. It keeps a single
source of instance data per problem while letting each formulation define
its own parametrization. The script accepts the input `data.json` and output
`parameters.json` paths as positional arguments and is run by
{meth}`Formulation.run_gen_params()
<formulation_bench.formulation.Formulation.run_gen_params>`.

:::{dropdown} `problems/p1/formulations/b/gen_params.py`
:icon: code
```{literalinclude} ../../../dataset/problems/p1/formulations/b/gen_params.py
:language: python
```
:::

### `Formulation.lean`

A Lean 4 encoding of the MILP formulation as a `MILPFormulation` (defined in
`Common.lean`). {ref}`formulation-definition`
describes how a formulation is encoded in Lean; the path to this file is exposed as the `lean_formulation_path` attribute of {class}`Formulation
<formulation_bench.formulation.Formulation>`.

:::{dropdown} `problems/p1/formulations/a/Formulation.lean`
:icon: code
```{literalinclude} ../../../dataset/problems/p1/formulations/a/Formulation.lean
:language: lean
```
:::

(reformulation-pairs-and-proofs)=
## Reformulation Pairs and Proofs

The `reformulations` field of `dataset.json` is a flat list of formulation
pairs. Each entry names two formulations `a` and `b` and labels whether `b` is a reformulation of `a`:

```json
{
  "a": {"problem": 1, "formulation": "a"},
  "b": {"problem": 1, "formulation": "b"},
  "reformulation": true
}
```

Each entry loads into a {class}`Reformulation
<formulation_bench.reformulation.Reformulation>`. For every *positive* pair
(`"reformulation": true`) there is a corresponding Lean file
`reformulations/pN/a_b.lean` constructing a `MILPReformulation` instance (see
{ref}`reformulation-definition`). The path to the Lean file is exposed as the `lean_proof_path` attribute. Pairs that are *not* reformulations of one another have no Lean file.

:::{dropdown} `reformulations/p1/a_b.lean`
:icon: code
```{literalinclude} ../../../dataset/reformulations/p1/a_b.lean
:language: lean
```
:::


(variable-shape-notation)=
## Variable Shape Notation

The `shape` field of a variable and a parameter is a list of strings
encoding the index dimensions. `formulation-bench` parses it into a
{class}`Shape <formulation_bench.models.Shape>`, an ordered sequence of
typed {class}`Dimension <formulation_bench.models.Dimension>` objects. An
empty list `[]` denotes a **scalar**. Every dimension is one of four
{class}`DimensionType <formulation_bench.models.DimensionType>` types:

- **Fixed** (`DimensionType.fixed`) — a string naming a scalar parameter
  (e.g., `"n"`, `"T"`): the dimension ranges over `range(param)`.
- **Expression** (`DimensionType.expression`) — a string containing an
  arithmetic expression over scalar parameters (e.g., `"K+N"`): used as-is
  in generated code.
- **Ragged** (`DimensionType.ragged`) — a string of the form `"X[Y]"` where
  `X` is a scalar array and `Y` is another dimension already in the
  shape: the size of this dimension depends on the value of `X` at the outer
  index `Y`. For example, `["n_G", "n_S[n_G]"]` means for each generator
  `g in range(n_G)`, the second dimension ranges over `range(n_S[g])`.
  Ragged variables are represented as dicts in generated code.
- **Cardinality** (`DimensionType.cardinality`) — a string of the form
  `"|X|"` denotes the cardinality of set `X`. When an `|X|` dimension appears, 
  the variable must also provide an `indices` expression.

The {class}`Shape <formulation_bench.models.Shape>`, {class}`Dimension
<formulation_bench.models.Dimension>`, {class}`Parameter
<formulation_bench.models.Parameter>`, and {class}`Variable
<formulation_bench.models.Variable>` API references give worked examples of
each case.
