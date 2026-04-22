/-
NOTE: Imports go at the very top.

Always include:
  import MILP.Common

Import any formulations used within the lemmas:
  import MILP.<family>.<problem>.Formulation.<A>
  import MILP.<family>.<problem>.Formulation.<B>

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

/-
NOTE: Add `open BigOperators Finset` only if the lemmas use ∑ or Finsets.
-/
open BigOperators Finset

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

/-
NOTE: This section is *optional*. Include only general lemmas with no dependency
on the MILP formulations. These lemmas live outside any namespace.

- Use the `lemma` keyword.
- Do NOT mark as `private`; these are shared across equivalence proof files.
- Remove this section entirely if no such lemmas are needed.
-/

-- ============================================================================
-- § <A> Helper Lemmas
-- ============================================================================

/-
NOTE: This section is *optional*. Include only when there are multiple lemmas
about <A>-feasible solutions that are shared across more than one equivalence
proof file for this problem. Any lemma used in only one equivalence file should
stay `private` in that file instead.

- Use a `namespace <Family>.<Problem>.<A>` block.
- Do NOT mark lemmas as `private`; they are imported by equivalence files.
-/

/-
NOTE: Open a namespace corresponding to the shared formulation scope.
-/
namespace <Family>.<Problem>.<A>

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

-- Shared lemmas about <A>-feasible solutions go here.

end <Family>.<Problem>.<A>

-- ============================================================================
-- § <B> Helper Lemmas
-- ============================================================================

/-
NOTE: This section is *optional*. Same rules as the <A> section above.
-/

namespace <Family>.<Problem>.<B>

variable {n : ℕ} [NeZero n] {p : <B>.Params n} {v : <B>.Vars n} (h : <B>.Feasible p v)
include h

-- Shared lemmas about <B>-feasible solutions go here.

end <Family>.<Problem>.<B>
