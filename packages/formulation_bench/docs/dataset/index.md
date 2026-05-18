# Dataset Overview

Each problem is presented in several alternative formulations that may differ
in variable naming, parameter naming, the algebraic form of the constraints,
the choice of decision variables, or the objective expression. Some pairs of
formulations describe the same optimization problem (a "reformulation");
others differ in a way that changes the feasible set or the optimal value
(not a reformulation). The Lean 4 files in `reformulations/` formalize each
reformulation pair.

```{toctree}
:maxdepth: 2

problems
notes
```

## Directory Structure

```
dataset/
├── dataset.json              # Problem IDs and all formulation pairs with reformulation labels
├── problems/                 # List of problems
│   ├── p1/
│   │   ├── description.md    # Natural-language problem statement
│   │   ├── problem.json      # Parameter schema (name, description, shape)
│   │   ├── data.json         # Concrete parameter values for one instance
│   │   ├── solution.json     # Reference optimal solution and objective
│   │   └── formulations/
│   │       ├── a/
│   │       │   ├── formulation.json
│   │       │   ├── solve.py           # Gurobi solver script
│   │       │   ├── gen_params.py      # Maps data.json to parameters
│   │       │   └── Formulation.lean   # Lean 4 MILP formulation
│   │       └── ...
│   └── ...
└── reformulations/           # Lean 4 reformulation proofs
    ├── p1/
    │   ├── a_b.lean          # Proof formulation b is a reformulation of a
    │   └── ...
    └── ...
```

## Problem-Level Files

For each problem `pN`:

- **`description.md`** — A self-contained natural-language description of the
  optimization problem.
- **`problem.json`** — Schema of the parameters: each parameter has a human
  description and a `shape` (`[]` for a scalar, `["nA", "nT"]` for a 2D array
  indexed by named dimensions). Includes `metadata.source` indicating which
  `sources/` subset the problem was adapted from.
- **`data.json`** — A concrete instance: parameter values used to test that
  all valid formulations produce the same optimum.
- **`solution.json`** — A reference optimal solution and objective value for
  the instance in `data.json`.

## Formulation-Level Files

For each formulation `pN/formulations/x/`:

- **`formulation.json`** — Structured description of the MILP:
  - `valid` — boolean indicating whether the formulation is a valid
    formulation for the parent problem.
  - `parameters` — parameters for the MILP formulation; should be a function
    of problem parameters provided in `data.json`. Each parameter has
    `{description, shape}`. Shapes use the same notation as variable shapes
    (see below).
  - `assumptions` — list of parameter assumptions, each with
    `{description, formulation (LaTeX), explicit (bool), code.python}`. The
    `explicit` flag is `true` when the assumption is stated explicitly in the
    original problem text; `false` when it is implicit (e.g., non-negativity
    of a rate that is obviously physical). Assumptions on parameters are
    distinct from constraints on decision variables.
  - `definitions` — *(optional)* ordered dict of named derived quantities
    computed from parameters before variables are declared, each with
    `{description, code.python}`. Typical uses: big-M constants, pre-computed
    index sets, and other values referenced in variable or constraint code.
    Definitions are emitted into `solve.py` in declaration order.
  - `variables` — dict of decision variables, each with
    `{description, type, shape}` and optionally `indices`. `type` is one of
    `"integer"`, `"continuous"`, or `"binary"`. The `shape` field and
    `indices` field are mutually exclusive ways of specifying the variable's
    index structure (see below).
  - `constraints` — list of
    `{description, formulation (LaTeX), explicit (bool), code.gurobipy}`. The
    `explicit` flag is `true` when the constraint appears explicitly in the
    problem statement; `false` for implied constraints such as non-negativity
    bounds.
  - `objective` — `{description, formulation (LaTeX), code.gurobipy}`.
  - `imports` — *(optional)* list of additional Python import statements to
    include in the generated `solve.py` (e.g., `["import math"]`). These are
    emitted after the standard gurobipy imports.

### Variable Shape Notation

The `shape` field of a variable (and of parameters) encodes the index
dimensions as a list of strings or integers:

- **Scalar** — `[]` (empty list): the variable is a single scalar.
- **Fixed dimension** — a string naming a scalar parameter (e.g., `"n"`,
  `"T"`): the dimension ranges over `range(param)`.
- **Expression dimension** — a string containing an arithmetic expression
  over scalar parameters (e.g., `"K+N"`): used as-is in generated code.
- **Ragged dimension** — a string of the form `"X[Y]"` where `X` is a
  parameter array and `Y` is another dimension name already in the shape:
  the size of this dimension depends on the value of `X` at the outer index
  `Y`. For example, `["n_G", "n_S[n_G]"]` means for each generator
  `g in range(n_G)`, the second dimension ranges over `range(n_S[g])`.
  Ragged variables are represented as dicts in generated code.
- **Cardinality notation** — a string of the form `"|X|"` where `X` is a
  definition or set: used in the mathematical `formulation` field to denote
  the cardinality of set `X`. When `|X|` appears in `shape`, an `indices`
  expression must be provided.

The `indices` field is an alternative to `shape` for variables indexed by an
explicit, possibly irregular set. It contains a Python expression (a
generator or comprehension) that produces the keys used to call
`model.addVars(...)`. When `indices` is present, `shape` still appears
(typically with `|X|` notation) to document the conceptual size in the
mathematical formulation, but `indices` is what drives code generation.

- **`gen_params.py`** — Generates `parameters.json` (a map of `parameters`)
  from the shared `data.json` (with stores problem-level `parameters`).
- **`solve.py`** — A Gurobi script that loads `parameters.json` and writes
  `solution.json`. A formulation and its reformulations produce the same
  objective on the same instance. Note this script is deterministically
  generated from the code defined in the `formulation.json`.
- **`Formulation.lean`** — A Lean 4 encoding of the MILP as a
  `MILPFormulation` (defined in `Common.lean`).

## Reformulation Pairs and Proofs

The `reformulations` key in `dataset.json` is a flat list of formulation pairs:

```json
{
  "a": {"problem": 1, "formulation": "a"},
  "b": {"problem": 1, "formulation": "b"},
  "reformulation": true
}
```

For each reformulation pair there is a corresponding Lean file
`reformulations/pN/a_b.lean` constructing a `MILPReformulation` instance
(defined in `Common.lean`). Pairs that are not reformulations of one another
have no Lean file by design: the dataset records them as labelled negative
examples.
