# Adding a new formulation to the dataset

A formulation is one specific MILP encoding of a problem: a choice of
variables, constraints, and objective expressed both
mathematically (LaTeX) and as runnable Gurobi code. Most files in a
formulation directory are *generated* from `formulation.json` — the
JSON is the source of truth.

Pick the next free single-letter label for the problem (e.g. `g` if
`a` through `f` exist) and create
`dataset/problems/pN/formulations/g/` with two hand-written files
and two generated files.

## 1. `formulation.json` (hand-written)

The structured description of the MILP. See {doc}`../dataset/index`
for the full schema; the required keys are:

- `valid` — `true` if the formulation correctly captures the parent
  problem, `false` if it is being kept as a labelled negative example.
- `parameters` — parameters consumed by this formulation. Usually a
  subset of the problem's parameters, possibly with renames or
  derived constants.
- `assumptions` — list of `{description, formulation, explicit, code.python}`
  entries; `explicit` is `true` when the assumption appears in the
  problem statement, `false` when implied (e.g., non-negativity).
- `variables` — dict of `{description, type, shape}` entries.
  `type` is one of `"integer"`, `"continuous"`, `"binary"`.
- `constraints` — list of `{description, formulation, explicit, code.gurobipy}`.
- `objective` — `{description, formulation, code.gurobipy}`.
- Optional: `definitions` (ordered derived quantities) and `imports`
  (extra Python imports for `solve.py`).

Pay attention to the **`shape`** and **`indices`** fields on
variables: they determine how the generator builds `model.addVars(...)`
calls.

```json
{
    "valid": true,
    "parameters": { "...": "..." },
    "variables": {
        "NumCashMachines": {
            "description": "The number of cash-based machines",
            "type": "integer",
            "shape": []
        }
    },
    "constraints": [ { "...": "..." } ],
    "objective": {
        "description": "Minimize the total number of machines.",
        "formulation": "Min \\ NumCashMachines + NumCardMachines",
        "code": {"gurobipy": "model.setObjective(NumCashMachines + NumCardMachines, GRB.MINIMIZE)"}
    },
    "metadata": {"source": { "...": "..." }}
}
```

## 2. `gen_params.py` (hand-written)

A short script that reads the problem's `data.json` and writes a
`parameters.json` containing exactly the parameters listed in
`formulation.json`. If the formulation uses the same parameter names
as the problem, this is a one-to-one copy; if it renames or derives
parameters, the mapping happens here.

```python
import argparse
import json


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    params = {
        "CashMachineProcessingRate": data["CashMachineProcessingRate"],
        # ... one entry per parameter in formulation.json
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data")
    parser.add_argument("output")
    args = parser.parse_args()
    main(args.data, args.output)
```

## 3. `solve.py` (generated)

Deterministically generated from `formulation.json` by the
`formulation_bench` package. Do **not** edit by hand; regenerate it
whenever `formulation.json` changes:

```python
from formulation_bench import Dataset

ds = Dataset.load()
f = ds.problem("p57").formulation("g")

(f.path / "solve.py").write_text(f.gurobipy_code)
```

Alternatively, run the dataset-wide regenerate-and-validate script,
which rewrites every `solve.py` from JSON and then confirms each
formulation produces the expected objective:

```bash
python scripts/dataset/validate_solve.py
```

## 4. `Formulation.lean` (Lean 4 encoding)

A `MILPFormulation` (see `dataset/Common.lean`) corresponding to the
JSON. This file is what reformulation proofs depend on. The repository
ships a `milp-formulator` agent that produces this file from the
problem and formulation source — see `AGENTS.md` at the repo root for
the workflow.

## Registering reformulation pairs

If your new formulation forms a (positive or negative) reformulation
pair with another formulation of the same problem, add an entry to
`dataset/dataset.json`:

```json
{
  "a": {"problem": 57, "formulation": "a"},
  "b": {"problem": 57, "formulation": "g"},
  "reformulation": true
}
```

For *positive* pairs (`reformulation: true`), add the Lean proof at
`dataset/reformulations/p57/a_g.lean`. The repository's
`milp-reformulation-autoformalizer` agent can scaffold this; see
`AGENTS.md`. Negative pairs (`reformulation: false`) have no Lean
file by design.

## Validating

After adding everything:

```bash
# Regenerate solve.py for every formulation and check objectives match.
python scripts/dataset/validate_solve.py

# Check the Lean files compile.
lake build
```
