/-
NOTE: Imports go at the very top.

Always include:
  import MILP.Common

Import both formulations being compared:
  import MILP.<family>.<problem>.Formulation.<A>
  import MILP.<family>.<problem>.Formulation.<B>

If the file requires shared lemmas:
  import MILP.<family>.<problem>.Lemmas

Use targeted Mathlib imports, NOT `import Mathlib`. Common options:
  import Mathlib.Algebra.BigOperators.Group.Finset.Basic
  import Mathlib.Data.Fintype.Basic
  import Mathlib.Data.Real.Basic
  import Mathlib.Data.Int.Basic
  import Mathlib.Order.ConditionallyCompleteLattice.Basic
-/

import MILP.Common
import MILP.<family>.<problem>.Formulation.<A>
import MILP.<family>.<problem>.Formulation.<B>
import MILP.<family>.<problem>.Lemmas

/-
NOTE: Add `open BigOperators Finset` only if the feasibility proofs use ∑ or Finsets.
-/
open BigOperators Finset

/-!
# <A> ↔ <B> Equivalence

See `datasets/<family>/<problem>/PROBLEM.md` for MILP description and formulations.
-/

/-
NOTE: Do NOT add any additional doc-comment blocks (e.g., "## Proof Strategy",
"## Forward Direction") after the module header above. The module header is the
only /-! ... -/ block allowed in an equivalence file. Proof reasoning belongs in
tactic-line comments (`-- ...`) inside the proof body.
-/

/-
NOTE: Open a namespace corresponding to the shared family/problem scope.
e.g., `EquivaFormulation.Laundromat` or `General.TSP`.
-/
namespace <Family>.<Problem>

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

/-
NOTE: This section is *optional*. Include only general lemmas that have no
dependency on the MILP formulation or any specific feasible solution AND are
specific to this equivalence proof (not shared across multiple files).

- Use the `lemma` keyword.
- Mark as `private`. Lemmas shared across multiple equivalence files for the
  same problem belong in `Lemmas.lean` instead.
- Lemmas specific to a particular formulation that are needed by fwd_feas or
  bwd_feas belong in ForwardHelpers / BackwardHelpers sections below.
- Remove this section entirely if no such lemmas are needed.
-/

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

/-
NOTE: This section is *optional*. Include only if the paramMap body is longer
than a single line. If the mapping is trivial (e.g., `id`, `{ c := p.c }`),
put it inline in the equivalence structure instead.

- Use `private def paramMap`.
-/

private def paramMap (p : <A>.formulation.Params) : <B>.formulation.Params :=
  { ... }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

/-
NOTE: This section is *optional*. Include only if `fwd` or `fwd_feas` are longer
than a single line. Otherwise, put them inline in the equivalence structure.

- Use `private def fwd` and `private lemma fwd_feas`.
- Mark `noncomputable` when the construction uses Classical.choice. If the
  majority of the construction requires `noncomputable`, mark the entire section
  as `noncomputable` instead.
-/

/-
NOTE: The ForwardHelpers section is *optional*. Include it when there are private
helper lemmas or definitions needed by `fwd_feas` that depend on a feasible
solution from formulation <A>. Remove the section entirely if not needed.
-/

section ForwardHelpers

/-
NOTE: Use `variable` to automatically add parameters for convenience.

- Introduce the index dimensions as *implicit* parameters
- Add `[NeZero n]` for every dimension parameter (as required by the formulation)
- Introduce the `Params` and `Vars` structures as *implicit* parameters
- Introduce the feasibility hypothesis as an *explicit* parameter (h)
- Explicitly `include h` to avoid issues with Lean inferring the variable
-/
variable {n : ℕ} [NeZero n] {p : <A>.Params n} {v : <A>.Vars n} (h : <A>.Feasible p v)
include h

-- Private helper lemmas and definitions depending on h go here.

end ForwardHelpers

/--
**<A> → <B>**: {Brief informal description of the forward map construction}
-/
private def fwd (_ : <A>.formulation.Params)
    (v : <A>.formulation.Vars) : <B>.formulation.Vars :=
  { ... }

private lemma fwd_feas (p : <A>.formulation.Params) (v : <A>.formulation.Vars)
    (h : <A>.formulation.feasible p v) :
    <B>.formulation.feasible (paramMap p) (fwd p v) := by
  sorry

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-
NOTE: This section is *optional*. Include only if `bwd` or `bwd_feas` are longer
than a single line. Otherwise, put them inline in the equivalence structure.

- Use `private def bwd` and `private lemma bwd_feas`.
- Mark `noncomputable` when the construction uses Classical.choice or extracts
  structure from the solution (e.g., tour order, permutation).
-/

/-
NOTE: The BackwardHelpers section is *optional*. Include it when there are private
helper lemmas or definitions needed by `bwd_feas` that depend on a feasible
solution from formulation <B>. Remove the section entirely if not needed.
-/

section BackwardHelpers

variable {n : ℕ} [NeZero n] {p : <B>.Params n} {v : <B>.Vars n} (h : <B>.Feasible p v)
include h

-- Private helper lemmas and definitions depending on h go here.

end BackwardHelpers

/--
**<B> → <A>**: {Brief informal description of the backward map construction}
-/
private def bwd (_ : <B>.formulation.Params)
    (v : <B>.formulation.Vars) : <A>.formulation.Vars :=
  { ... }

private lemma bwd_feas (p : <B>.formulation.Params) (v : <B>.formulation.Vars)
    (h : <B>.formulation.feasible (paramMap p) v) :
    <A>.formulation.feasible p (bwd p v) := by
  sorry

-- ============================================================================
-- § Objective Mapping
-- ============================================================================

/-
NOTE: This section is *optional*. Include only if the objective map is not a
single inline expression. If `objMap = id` or a simple lambda (e.g., `fun v => 2 * v`),
put it inline in the equivalence structure instead.

When the section is needed, define:
  - `private def objMap : ℝ → ℝ := ...`
  - `private lemma objMap_mono : Monotone objMap := ...`
  - `private lemma fwd_obj ...` and `private lemma bwd_obj ...` if the objective
    commutativity proofs are non-trivial (not just `rfl`).
-/

private def objMap : ℝ → ℝ := fun v => ...

private lemma objMap_mono : Monotone objMap := by
  sorry

private lemma fwd_obj (p : <A>.formulation.Params) (v : <A>.formulation.Vars)
    (h : <A>.formulation.feasible p v) :
    <B>.formulation.obj (paramMap p) (fwd p v) = objMap (<A>.formulation.obj p v) := by
  sorry

private lemma bwd_obj (p : <B>.formulation.Params) (v : <B>.formulation.Vars)
    (h : <B>.formulation.feasible (paramMap p) v) :
    <B>.formulation.obj (paramMap p) v = objMap (<A>.formulation.obj p (bwd p v)) := by
  sorry

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

/-
NOTE: The final def should be a `MILPEquiv` structure:

- See `MILP/Common.lean` for the definition of `MILPEquiv` and its fields.
- Named camelCase: <formA><FormB>Equiv (e.g., `originalCEquiv`, `scfMcfEquiv`)
- Marked `noncomputable` if any helper def is noncomputable
- `paramMap`: reference the private def above, or inline for trivial cases
    e.g., `paramMap p := { c := p.c }` or `paramMap := id`
- `fwd` / `bwd`: reference the private defs above, or inline for trivial cases
    e.g., `fwd _ v := { a := v.numTop, g := v.numFront }`
- `fwd_feas` / `bwd_feas`: reference the private lemmas above
- `objMap`: use `id` when both objectives are identical; reference the private
    def above when the Objective Mapping section is present
- `objMap_mono`: use `monotone_id` when `objMap = id`; reference the private
    lemma above when the Objective Mapping section is present
- `fwd_obj` / `bwd_obj`: use `_ _ _ := rfl` when `objMap = id` and objectives
    are definitionally equal; reference private lemmas when the section is present
-/

def <formA><FormB>Equiv : MILPEquiv <A>.formulation <B>.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end <Family>.<Problem>
