/-
NOTE: Add necessary imports at the top of the file.

Always include the project's common MILP definitions module:
  import Common

Use targeted imports, NOT `import Mathlib`.

For files with only ℝ/ℤ (no BigOperators):
  import Mathlib.Data.Real.Basic

For files with BigOperators + ∑ over Fin p.<dim> (like this template):
  import Mathlib.Algebra.BigOperators.Group.Finset.Basic
  import Mathlib.Data.Fintype.Basic
  import Mathlib.Data.Real.Basic
  import Mathlib.Data.Int.Basic

If constraints use Fin p.<dim1> × Fin p.<dim2> (pair-indexed variables),
also add:
  import Mathlib.Data.Fintype.Prod
-/

import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

-- NOTE: Always include `open BigOperators Finset` when using ∑ and Finsets.
open BigOperators Finset

/-
NOTE: Open a namespace that uniquely identifies this formulation.
Use `<Problem>.<formulation>`, e.g. `P1.a` for problem p1 formulation a.
-/
namespace P1.a

/-
NOTE: Include any definitions used in constructing `Params`, `Vars`, `Feasible`,
or `obj` here. These must be included *within* the namespace to avoid polluting
the global namespace with duplicate definitions across formulations.
-/

/-
NOTE: Params structure — problem dimensions, data, and assumptions.

- `Params` is a plain (parameter-less) structure. Do NOT write
  `structure Params (n : ℕ)` or attach any `[NeZero …]` to it.
- Dimensions come first as `ℕ` fields. Later data fields reference them.
- Data fields follow: vectors `Fin <dim> → <ℝ|ℤ>`, matrices
  `Fin <dim1> → Fin <dim2> → <ℝ|ℤ>`, scalars `<ℝ|ℤ>`.
- In `Params`, indexed data MUST use `Fin <dim>` for every index, never `ℕ`.
- If an index range itself depends on a prior parameter (e.g. each item
  `a` in set `A` has different set size `n_B a`) — use a *dependent*
  function type, not flat `ℕ → ℕ`:
    n_B  : Fin n_A → ℕ
    x  : (a : Fin n_A) → Fin (n_B a) → ℤ
  Do NOT collapse these to `ℕ → ℕ` or `ℕ → ℕ → ℝ`.
- Each parameter has an inline comment with a short description.
- Single space before `:`; do NOT pad field names for column alignment.
- Do NOT wrap inline comments in parentheses (write `-- arc cost`, not
  `-- (arc cost)`).
- Assumptions go at the end under an `-- Assumptions` comment.
- Separate explicitly stated assumptions from implicit ones (e.g. non-negativity)
  by placing implicit assumptions under an `-- ImplicitAssumptions` comment.
- The `-- Assumptions` and `-- ImplicitAssumptions` sections are both optional;
  if there are no assumptions of that type, omit the section entirely.
- For `NeZero` assumptions on dimensions, use `h<DimName> : NeZero <DimField>`.
- Use `_nn`, `_pos`, `_bin` suffixes where applicable. Sign assumptions
  do not require an inline comment.
-/
structure Params where
  NumExperiments : ℕ  -- number of experiments
  NumResources   : ℕ  -- number of resource types
  ElectricityProduced : Fin NumExperiments → ℝ  -- electricity produced by experiment i
  ResourceRequired    : Fin NumResources → Fin NumExperiments → ℝ  -- resource j required by experiment i
  ResourceAvailable   : Fin NumResources → ℝ  -- amount of resource j available
  -- Assumptions
  hNumExperiments : NeZero NumExperiments
  hNumResources   : NeZero NumResources
  -- Implicit Assumptions
  hElectricityProduced_nn : ∀ i, 0 ≤ ElectricityProduced i
  hResourceRequired_nn    : ∀ j i, 0 ≤ ResourceRequired j i
  hResourceAvailable_nn   : ∀ j, 0 ≤ ResourceAvailable j

/-
NOTE: Vars structure — decision variables.

- `Vars` is a plain (parameter-less) structure. It has no access to `Params`.
- Scalar variables: `ℤ` or `ℝ`.
- Vector variables: `ℕ → ℤ` or `ℕ → ℝ`. Do NOT write `Fin <dim> → ℤ` because
  `<dim>` is a `Params` field and is not in scope here.
- Binary-ness is enforced in `Feasible`, not in the type.
- Each variable has an inline comment with a short description.
- Single space before `:`; do NOT pad field names for column alignment.
- `Vars` contains no assumptions; assumptions involving variables go in `Feasible`.
-/
structure Vars where
  ConductExperiment : ℕ → ℤ  -- number of times each experiment is conducted

/-
NOTE: Feasible structure — constraints.

- Signature is exactly `(p : Params) (v : Vars) : Prop`. No other args.
- If `Vars` contains fields with names `p` or `v`, that is fine; they will be
  accessed unambiguously as `v.<field>` or `p.<field>`.
- One `--` comment line precedes each constraint or group of like
  constraints. Sign constraints do not need a comment.
- Use `_nn`, `_pos`, `_bin`, `_lo`, `_hi` suffixes where applicable.
- Group implicit constraints at the end under `-- [Implicit Constraints]`.
-/
structure Feasible (p : Params) (v : Vars) : Prop where
  -- For each resource, total requirement across all experiments is within supply
  hres : ∀ j : Fin p.NumResources,
    ∑ i : Fin p.NumExperiments, p.ResourceRequired j i * (v.ConductExperiment i : ℝ)
      ≤ p.ResourceAvailable j
  hConductExperiment_nn : ∀ i : Fin p.NumExperiments, 0 ≤ v.ConductExperiment i

/-
NOTE: Objective — always ℝ-valued, named `obj`.

- Signature is exactly `(p : Params) (v : Vars) : ℝ`.
- Define the equation on the second line for readability.
- Precede with a one-line `--` comment stating direction and what is
  optimized. For maximization, negate the sum (MILPFormulation expects
  minimization-style objectives as ℝ values).
-/

-- Maximize total electricity produced
def obj (p : Params) (v : Vars) : ℝ :=
  -(∑ i : Fin p.NumExperiments, p.ElectricityProduced i * (v.ConductExperiment i : ℝ))

/-
NOTE: Include EXACTLY as formatted below, with the padded alignment and spacing.
-/
def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

-- NOTE: End the namespace at the end of the file
end P1.a
