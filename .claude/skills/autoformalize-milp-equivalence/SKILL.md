---
name: autoformalize-milp-equivalence
description: >
  Use when proving the equivalence of two MILP formulations. Covers the full
  workflow from reading a PROBLEM.md problem file through scaffolding the correct
  Lean file structure and formalizing the result. Use alongside the lean-lsp
  MCP server and lean4 skill for general Lean tooling.
---

# Autoformalize MILP Equivalence

This skill takes a `PROBLEM.md` file describing multiple equivalent MILP
formulations for a common optimization problem and proves their equivalence
using the `MILPEquiv` structure in Lean. It is expected that the MILP
formulations have already been formalized into Lean files using the
`create-lean-milp-formulation` skill. This skill covers extracting the equivalence
information from `PROBLEM.md`, scaffolding the correct Lean file structure with
sorry placeholders, filling the proofs, and lastly final review and
organization.

## Input

This skill can either be invoked by an agent or directly by a user via a slash
command. If the skill was invoked by slash command, the user provided the
following arguments: `$ARGUMENTS`.

Common input types:

- Problem summary file: e.g., `datasets/General/TSP/PROBLEM.md`. Read the
  entire file and identify all equivalences. If the user does not specify which
  equivalence to prove, determine the easiest pairs of formulations to formalize
  equivalence in order to show the full chain of equivalences. Prove those.
- A specific pair of formulations: e.g., "SCF ↔ MCF for TSP". Identify the
  relevant summary and read it.

If either formulation file does not yet exist as a Lean file, use the
`create-lean-milp-formulation` skill to generate it before proceeding.

## Output

Each equivalence proof should be placed in its own `.lean` file within the
problem's `Equivalence` directory. A single barrel file in the problem
directory, `Equivalence.lean`, imports all the equivalence files. Name each
equivalence file using the abbreviated equivalence name. If no abbreviation
exists, use the full name in CamelCase. E.g., the equivalence between the
"Original" and "C" formulations of the Laundromat problem would be named
`OriginalC.lean`. If the abbreviation is an all-caps acronym, separate the
formulations by an underscore for readability. E.g., `SCF_MCF.lean` for the SCF
vs. MCF equivalence for TSP. Lemmas used in more than one equivalence file
should be placed in `Lemmas.lean` -- equivalence files should not import each
other. Two valid example directory structures are shown below.

```
MILP/EquivaFormulation/Laundromat
├── Equivalence
│   ├── OriginalC.lean
│   ├── ...
│   └── OriginalI.lean
├── Equivalence.lean
├── Formulation
│   ├── C.lean
│   ├── ...
│   ├── I.lean
│   └── Original.lean
└── Formulation.lean
```

```
MILP/General/TSP
├── Equivalence
│   ├── DFJ_MTZ.lean
│   ├── ...
│   └── SCF_MTZ.lean
├── Equivalence.lean
├── Formulation
│   ├── Degree.lean
│   ├── ...
│   └── SCF.lean
├── Formulation.lean
└── Lemmas.lean
```

## Workflow

### Step 0: Identify formulation and equivalences

Review the relevant formulation definitions in `PROBLEM.md`. If the user
specified a specific pair of formulations to prove equivalent, focus on that pair.
Otherwise, consider the full equivalence graph and identify the easiest pairs of
formulations to prove equivalent in order to show the full chain of equivalences.

### Step 1: Collect context

Once the equivalence(s) have been identified, read the following context:

- If the associated `PROBLEM.md` includes a source, read the source
- Reference `ref.bib` to find other potentially relevant papers
- Review all the corresponding Lean formulation files for the cuts to be proved.

### Step 2: Proof approach

Reason about the equivalence before writing any Lean.

**Pre-flight feasibility checks:**

1. **Semantic strength of MILPEquiv**: `MILPEquiv` requires pointwise feasibility
   and objective preservation for *all* feasible solutions, not merely equal optimal
   values. If the paper's claim is weaker (e.g., "these two have the same optimal
   value"), the hard direction will likely be intractable under `MILPEquiv`. Decide
   upfront which directions are provable and which will need `sorry`.

2. **Type-level vs. value-level dimensions**: If one formulation stores a problem
   dimension as a type-level `ℕ` parameter (e.g., `{n : ℕ} [NeZero n]`) and another
   stores it as a runtime record field, `MILPEquiv` cannot express an unconditional
   equivalence. Identify this mismatch before writing any Lean; it may require
   leaving a `sorry` or restructuring the formulation.

3. **Params types from different namespaces are distinct types**, even when
   structurally identical. `A.Params` and `B.Params` are never definitionally equal.
   Always write an explicit field-by-field `paramMap`, even when it looks trivial
   (e.g., `{ c := p.c, d := p.d }`). Never use `id` as `paramMap` when the two
   `Params` types differ.

For each direction, reason about:

- What variables are kept, dropped, or constructed?
- For `bwd`: is the construction trivial (projecting fields) or nontrivial
  (extracting structure such as a tour order or permutation)?
- Which constraints from `Feasible` are trivially inherited vs. need proof?
- Are there helper lemmas that would be shared with other equivalence files?

Mark nontrivial variable constructions as `noncomputable`. Prefer deterministic
constructions (e.g., minimum-index selection via `LinearOrder` on `Fin n`) over
`Classical.choice` when possible — they are cleaner and avoid `noncomputable`.

### Step 3: Create output files

Create the directory structure described in the "Output" section if it does
not exist. Create empty `.lean` equivalence files for each equivalence to be proved.

### Step 4: Scaffold the equivalence files

**Templates:**

- **Equivalence file:** `.claude/skills/autoformalize-milp-equivalence/templates/equivalence.lean`
- **Shared lemmas:** `.claude/skills/autoformalize-milp-equivalence/templates/lemmas.lean`

Create the equivalence file in the appropriate location and follow the instructions in
the templates to properly structure the file. Use the lemmas template for any
shared lemmas across equivalences.

When first scaffolding the equivalence file, do not write the actual proofs. Instead,
focus on properly structuring the file. Use `sorry` placeholders and check
that the file compiles before moving on.

### Step 5: Fill in the proofs

Iteratively fill in the `sorry` placeholders with actual proofs. Routinely check
that the file compiles with the `lean-lsp` MCP server. If there are errors, use
the `lean4` skill family to debug and fix errors. The `lean_goal` and
`lean_diagnostic_messages` from the MCP server are useful to check proof state.

**LSP build-in-progress**: After editing a file, the LSP runs a background
rebuild. Calling `lean_diagnostic_messages` or `lean_goal` while it is running
returns `"A project build is in progress. Retry after the build completes."` —
this is normal; retry in a few seconds. If you need a synchronous check, run
`lake build MILP.<Family>.<Problem>.Equivalence.<Name>` (target the specific
module, not the whole package). Do NOT use `sleep` — the harness will block it.

DO NOT run `lake build` on the whole package. Target specific modules only.

### Step 6: Clean up and review

Once proofs are complete, review each file:

- Remove all `sorry` placeholders.
- Remove all `/-  NOTE ... -/` template comments.
- Remove any empty sections; do not leave section headers with no content.
- Check for lemmas in one file that would be better shared in `Lemmas.lean`,
  and vice versa for lemmas in `Lemmas.lean` only used by one file.

### Step 7: Update barrels and verify

Finally, update any necessary barrel files to import the new cut files. Check
that the barrel file compiles. Again, utilize the `lean-lsp` MCP server and
`lean4` skill to debug and resolve any compilation errors.

## Common Pitfalls

These patterns caused the most wasted iterations in practice. Check each one
before writing any Lean.

### `|>.field` in type positions

The `|>.` pipe-chained accessor notation is **invalid in Lean 4 type
annotations** (lemma return types, `show` targets, etc.). Always use explicit
parenthesization instead:

```lean
-- WRONG (parse error):
private lemma fwd_obj ... :
    Formulation.A.formulation n |>.obj (paramMap p) (fwd p v) = ... := by

-- CORRECT:
private lemma fwd_obj ... :
    (Formulation.A.formulation n).obj (paramMap p) (fwd p v) = ... := by
```

### Cast non-definitional equality

`↑(∑ i, f i)` is **not definitionally equal** to `∑ i, ↑(f i)` in Lean 4.
`show` and `rfl` will both fail. Use `push_cast`, `simp_rw [Int.cast_sum]`, or
`Finset.cast_sum` to push the coercion through:

```lean
-- FAILS:
show ↑(∑ j, v.y i j) = ↑(v.y i) -- mismatch with ∑ j, ↑(v.y i j)

-- WORKS:
simp_rw [Int.cast_sum]  -- or push_cast; ring
```

### `rewrite` failing due to rw-in-condition

When a goal contains `if h_cond then ...` and you `rw [some_eq]` that
substitutes inside `h_cond`, any subsequent `rw` looking for the original
pattern fails because the condition has changed. Scope such rewrites to
specific subgoals rather than using them globally.

### `NeZero` metavariable not inferred

If a helper lemma has implicit dimension parameters `{nK nA : ℕ}` with
`[NeZero nK] [NeZero nA]`, Lean may fail to unify them across `paramMap` and
`fwd` applications, producing `"typeclass instance problem is stuck: NeZero ?m"`.
Fix: make dimensions explicit parameters in the helper lemma signature and
apply with `@` where needed.

### `linarith` failing on integer/real cast chains

When `linarith` must reason across a cast boundary (`ℤ` → `ℝ` or `ℕ` → `ℤ`),
it often fails. Break the chain with explicit `have` steps using `norm_cast` or
`push_cast` before handing to `linarith`.

### File naming convention for equivalences

The file name encodes the direction A→B: use `<NameA><NameB>.lean` for
short names, `<NAME_A>_<NAME_B>.lean` when both names are all-caps acronyms.
If confused about which name comes first, use the forward direction defined by
`fwd` (A-feasible → B-feasible) as the canonical A→B order.

## References

- `MILP/General/TSP/Equivalence/SCF_MCF.lean`
- `MILP/EquivaFormulation/Laundromat/Equivalence/OriginalC.lean`
- `MILP/General/TSP/Lemmas.lean`

Read the relevant reference before starting any new equivalence file.
