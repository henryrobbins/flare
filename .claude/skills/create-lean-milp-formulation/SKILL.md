---
name: create-create-lean-milp-formulation
description: >
  Use when generating Lean 4 MILP formulations from the natural language
  description of MILPs in `PROBLEM.md` files.
---

# Create Lean MILP Formulation

This skill translates the structured natural language and mathematical
descriptions of MILP problems in `PROBLEM.md` files into compilable Lean 4
formulation files.

## Input

This skill can either be invoked by an agent or directly by a user via a slash
command. If the skill was invoked by slash command, the user provided the
following arguments: `$ARGUMENTS`.

The are a few common input types:

- Problem summary file: e.g., `datasets/EvoCut/TSP/PROBLEM.md`. Read the entire
  file and identify all MILP formulations. If the user does not specify a specific
  formulation to formulate in Lean, formulate all of them.
- Dataset directory: e.g., `datasets/EvoCut/`. Identify all problems in the
  dataset, then read each problem's `PROBLEM.md` file to identify all formulations.
- For any other input, first use the `extract-problem` skill to convert the raw
  input into a structured `PROBLEM.md` file within the `datasets/` directory.

If the MILP formulation is not clear from the `PROBLEM.md` file alone, use the
source field present in `PROBLEM.md` to identify the original source(s) of the
problem description and read those sources to clarify the intended formulation.
When complete, ensure you flag which aspects of the formulation weren't clear
from `PROBLEM.md`.

## Output

The `PROBLEM.md` should be at a path like `datasets/<family>/<problem>/PROBLEM.md`
where `<family>` is the dataset name (e.g., `EvoCut`) and `<problem>` is the
problem name (e.g., `TSP`). The proper output location and name of the Lean
formulation file will be one of the following.

### Single Formulation

If the `PROBLEM.md` only contains a single formulation, place the formulation
in `MILP/<family>/<problem>/Formulation.lean`. See the example below:

```
MILP/EvoCut/TSP
├── Cuts
├── Cuts.lean
├── Formulation.lean
└── Lemmas.lean
```

### Multiple Formulations

If the `PROBLEM.md` contains multiple formulations, place each formulation in
a separate file under `MILP/<family>/<problem>/Formulation/` and use the
abbreviated formulation name as the file name. Then, create a `Formulation.lean`
file that imports the individual formulations. See the example below:

```
MILP/EquivaFormulation/Laundromat
├── Equivalence
├── Formulation
│   ├── C.lean
│   ├── I.lean
│   │   ...
│   └── Original.lean
├── Equivalence.lean
└── Formulation.lean
```

## Workflow

### Step 0: Create output directory structure

After identifying each formulation to formulate in Lean, create the output
directory and file structure following the conventions above. Then, follow the
remaining steps in this workflow for EACH formulation.

### Step 1: Read the natural language description

Extract the following information from `PROBLEM.md` and any relevant sources:

- **Sets / index types:** note the variable names for the dimension of each index
- **Parameters:** (cost, capacity, etc...) these compose the Params structure
- **Decision variables:** classify each as continuous, integer, or binary
- **Constraints:** identify each constraint family and its interpretable role
- **Implicit assumptions:** (parameter signs, structural properties) these are
  not explicitly stated, but implicit assumptions that are potentially necessary
  for equivalence or cutting plane proofs.

### Step 2: Map to Lean types

| Concept                         | Lean encoding                                    |
| ------------------------------- | ------------------------------------------------ |
| Index set of size n             | `Fin n` with `[NeZero n]` on the structure       |
| Continuous variable / parameter | `ℝ`                                              |
| General integer variable        | `ℤ`                                              |
| Binary variable                 | `ℤ` with `hvar_bin : ∀ i, var i = 0 ∨ var i = 1` |
| Matrix parameter A[i][j]        | `A : Fin m → Fin n → ℝ`                          |
| Vector parameter b[i]           | `b : Fin m → ℝ`                                  |
| Summation ∑                     | `∑ i, ...` with `open BigOperators`              |

#### Subset and partition encoding

Choose based on how the subset is used:

| Scenario                                  | Encoding                                                  | Example                                          |
| ----------------------------------------- | --------------------------------------------------------- | ------------------------------------------------ |
| Subset is a fixed parameter (e.g. fixed hubs) | `S : Finset (Fin n)` in `Params`; constraints use `∀ i ∈ p.S, ...` | `Hf : Finset (Fin nH)` with `hfixed : ∀ h ∈ p.Hf, v.y h = 1` |
| Subset used as filter in summations       | Indicator `isS : Fin n → Bool` or use `Finset.filter`    | `(univ.filter (fun i => p.isS i)).sum ...`       |
| Partition into two contiguous halves      | Single `Fin n` with conditional on `.val`                 | `J_0 = {j | j.val < m}`, `J_1 = {j | m ≤ j.val}` |
| Variable-length subsets per index         | Uniform upper bound `A` with filter constraint            | `∀ v, ∑ a : Fin A, if p.valid v a then ... else 0` |

### Step 3: Create the formulation file

**Template:** `.claude/skills/create-lean-milp-formulation/template.lean`

Create the formulation file in the appropriate location and follow the
instructions in the template to properly structure the file. Some additional
instructions are provided here:

#### Constraint field naming

Use `h` + short camel-case constraint name: `hassign`, `hcap`, `hbal`,
`hprec`, `hoverlap`, `hmtz`, `hflow`, `hdemand`. Suffix with `_nn`, `_bin`,
`_lo`, `_hi` for bound constraints on variables.

#### Implicit assumptions/constraints last

Place any implicit assumptions about the parameters in the appropriate section
of the `Params` structure. Place any implicit constraints in the appropriate
section of the `Feasible` structure. The primary purpose of adding these implicit
assumptions is to ensure there are sufficient hypotheses to prove equivalence
or cutting plane results later.

#### Graph topology as functions

For network problems, represent graph structure as functions rather than
`Finset` edge lists when possible:

```lean
tail : Fin nA → Fin nN    -- (arc tail node)
head : Fin nA → Fin nN    -- (arc head node)
```

#### Filtered sums for network flow

Use `Finset.univ.filter` to express flow conservation at specific nodes:

```lean
(univ.filter (fun e => tail e = i)).sum (x · k) = ...
```

### Step 4: Register and build

1. **Update barrel files.** Add the new file's import to the parent `*.lean` barrel
   file. If this is a single formulation, add to `MILP/<family>/<problem>.lean`.
   If multi-formulation, add to `MILP/<family>/<problem>/Formulation.lean`.
   Add a barrel import to `MILP.lean` if this is a new dataset family.

   **Barrel editing protocol** — barrel files may be shared with other agents
   running in parallel and may have been modified since you last read them:
   - Always **read the barrel first**, then add your import only if not already present.
   - Maintain **alphabetical order** of imports within each barrel.
   - If the barrel does not exist yet, create it. If it was just created by another
     agent (read confirms content you didn't write), still insert idempotently.

2. **Verify with lean-lsp.** Run `lean_diagnostic_messages` on the new file.
   - **Empty items with `success: false`** is *normal* when imports are not yet
     resolved by a build — it does **not** mean the file has errors. Trust an empty
     diagnostic list.
   - Only escalate to a targeted `lake build` on the specific module if diagnostic
     items (actual errors or warnings) are reported, or for final confirmation.
   - DO NOT run `lake build` on the whole package.

## References

The following formulation files demonstrate formatting rules, conventions, and
encoding patterns described above and in the template.

**General structure and conventions:**
- `MILP/EvoCut/TSP/Formulation.lean`
- `MILP/EvoCut/CWLP/Formulation.lean`
- `MILP/General/TSP/Formulation/Degree.lean`

**Subset / partition encoding patterns:**
- `Finset` parameter subset → `MILP/Ferchtandiker2025/UNHDR/Formulation/Efficient.lean`
  (`Hf : Finset (Fin nH)` with `∀ h ∈ p.Hf, v.y h = 1`)
- Contiguous partition with `.val` predicate → `MILP/Ferchtandiker2025/TimorLeste/Formulation/Efficient.lean`
- Indicator function for beneficiary subsets → `MILP/Ferchtandiker2025/WorldFoodProgram/Formulation/Efficient.lean`

Additionally, search any existing formulation within `MILP/` to find how similar
MILPs were encoded.
