/-
NOTE: Add necessary imports at the top of the file.

Always include:
  import MILP.Common

Use targeted imports, NOT `import Mathlib`.

For files with only ℝ/ℤ (no BigOperators):
  import Mathlib.Data.Real.Basic

For files with BigOperators + ∑ over Fin n (like this template):
  import Mathlib.Algebra.BigOperators.Group.Finset.Basic
  import Mathlib.Data.Fintype.Basic
  import Mathlib.Data.Real.Basic
  import Mathlib.Data.Int.Basic

If constraints use Fin N × Fin N (e.g. pair-indexed variables), also add:
  import Mathlib.Data.Fintype.Prod
-/

import MILP.Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

-- NOTE: Always be sure to include `open BigOperators Finset` when using ∑ and Finsets.
open BigOperators Finset

/-
NOTE: Open a namespace that corresponds to the formulation file location

- For single formulation files, use <family>.<problem>
  e.g. `EvoCut.TSP` for `MILP/EvoCut/TSP/Formulation.lean`
- For multi-formulation files, use <family>.<problem>.<formulation>
  e.g. `General.TSP.Degree` for `MILP/General/TSP/Formulation/Degree.lean`
-/
namespace Example.TSP

/-
NOTE: Params structure: list all problem data and assumption on data here

- Params should take relevant dimension parameters (e.g. n, m) as arguments
- Use explicit arguments for dimension parameters
- Do not include `[NeZero n]` on the `Params` structure
- List all problem data using a short name and the type
- Each parameter should have an inline comment with a short description
- Do NOT pad field names with extra spaces before `:` to force column alignment
- Do NOT wrap inline comments in parentheses (write `-- arc cost`, not `-- (arc cost)`)
- Use minimal spacing so inline `--` comments align naturally with the longest field
- If a type is too long to fit on one line with a comment, place the comment after
  the field name on the same line, and the type on the next line indented 2 spaces
- Include assumptions at the end of the structure
- Sign assumptions (e.g. non-negativity, positivity) do not require a comment
- Implicit assumptions should be specifically noted as such
- Use standard `_nn`, `_pos`, `_bin` suffixes for assumptions when applicable
-/
structure Params (n : ℕ) where
  c : Fin n → Fin n → ℝ  -- arc cost
  -- Assumptions
  hc_nn : ∀ i j, 0 < c i j
  -- Implicit Assumptions
  hc_tri : ∀ i j k, c i k ≤ c i j + c j k  -- triangle inequality

/-
NOTE: Vars structure: list all decision variables here

- Vars should take relevant dimension parameters (e.g. n, m) as arguments
- Use explicit arguments for dimension parameters
- Do not include `[NeZero n]` on the `Vars` structure
- List all decision variables using a short name and the type
- Ensure ℤ for integer (and binary) variables and ℝ for continuous variables
- Each variable should have an inline comment with a short description
- Do NOT pad field names with extra spaces before `:` to force column alignment
- Do NOT wrap inline comments in parentheses
- The Vars structure should not include any assumptions
-/
structure Vars (n : ℕ) where
  x : Fin n → Fin n → ℤ  -- arc indicator
  u : Fin n → ℝ           -- position

/-
NOTE: Feasible structure: list all constraints here

- Feasible should take relevant dimension parameters (e.g. n, m) as arguments
- Use implicit arguments for dimension parameters (can be inferred from Params and Vars)
- Include `[NeZero x]` for *every* dimension parameter
- List all constraints using a short name and the type
- There should be a single space between the constraint name and `:`
- A comment line should proceed each constraint with a short description
- Sign constraints (e.g. non-negativity, positivity) do not require a comment
- Like constraints can be grouped under a single comment
- Implicit constraints should be specifically notes as such under `[Implicit Constraints]`
- Use standard `_nn`, `_pos`, `_bin` suffixes for constraints/assumptions when applicable
-/
structure Feasible {n : ℕ} [NeZero n] (_ : Params n) (v : Vars n) : Prop where
  -- Enforce unit in-degree
  hin : ∀ j, ∑ i, v.x i j = 1
  -- Enforce unit out-degree
  hout : ∀ i, ∑ j, v.x i j = 1
  -- Subtour elimination constraints
  hmtz : ∀ i j, i ≠ 0 → j ≠ 0 → i ≠ j →
    v.u i - v.u j + n * v.x i j ≤ n - 1
  -- Anchor depot to position 1
  hu_depot : v.u 0 = 1
  hx_bin : ∀ i j, v.x i j = 0 ∨ v.x i j = 1
  -- u ∈ [2,n]
  hu_lo : ∀ i, i ≠ 0 → 2 ≤ v.u i
  hu_hi : ∀ i, v.u i ≤ n
  -- [Implicit Constraints]
  -- No self-loops
  hx_no_self : ∀ i, v.x i i = 0

/-
NOTE: Objective definition: add the objective function here

- The objective should be defined as a function of Params and Vars
- It should have implicit dimension parameters inferred from Params and Vars
- The objective should always be a real-valued function with return type ℝ
- Define the equation on a second line for readability
- The objective should always be called `obj`
- Include a command above the definition with a short description and direction
-/

-- Minimize the total arc cost
def obj {n : ℕ} (p : Params n) (v : Vars n) : ℝ :=
  ∑ i, ∑ j, p.c i j * (v.x i j : ℝ)

/-
NOTE: formulation definition here

- Include this exactly as formatted below
- Only dimension parameters should vary from the template
- All dimension arguments should be explicit and include [NeZero] instances
-/

def formulation (n : ℕ) [NeZero n] : MILPFormulation where
  Params   := Params n
  Vars     := Vars n
  feasible := Feasible
  obj      := obj

-- NOTE: End the namespace at the end of the file
end Example.TSP
