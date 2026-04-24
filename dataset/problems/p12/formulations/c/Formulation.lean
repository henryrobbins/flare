import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P12.c

structure Params where
  n : ℕ  -- number of cities
  c : Fin n → Fin n → ℝ  -- arc cost
  -- Implicit Assumptions
  hn : NeZero n

structure Vars where
  x : ℕ → ℕ → ℤ  -- arc indicator
  u : ℕ → ℝ  -- position

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Each city has exactly one outgoing arc
  hout : ∀ i : Fin p.n, ∑ j : Fin p.n, v.x i j = 1
  -- Each city has exactly one incoming arc
  hin : ∀ j : Fin p.n, ∑ i : Fin p.n, v.x i j = 1
  -- MTZ subtour elimination
  hmtz : ∀ (i : Fin p.n) (j : Fin p.n), i.val ≠ 0 → j.val ≠ 0 → i ≠ j →
    v.u i - v.u j + (p.n : ℝ) * (v.x i j : ℝ) ≤ (p.n : ℝ) - 1
  -- Depot position fixed to 1
  hu_depot : v.u 0 = 1
  hx_bin : ∀ (i j : Fin p.n), v.x i j = 0 ∨ v.x i j = 1
  -- u ∈ [2, n] for non-depot cities
  hu_lo : ∀ i : Fin p.n, i.val ≠ 0 → 2 ≤ v.u i
  hu_hi : ∀ i : Fin p.n, v.u i ≤ (p.n : ℝ)
  -- EC2: if the tour returns to the depot from city i, then i is positioned last
  hec2 : ∀ i : Fin p.n, i.val ≠ 0 → (p.n : ℝ) - ((p.n : ℝ) - 2) * (1 - (v.x i 0 : ℝ)) ≤ v.u i
  -- [Implicit Constraints]
  -- No self-loops
  hx_no_self : ∀ i : Fin p.n, v.x i i = 0

-- Minimize total arc cost
def obj (p : Params) (v : Vars) : ℝ :=
  ∑ i : Fin p.n, ∑ j : Fin p.n, p.c i j * (v.x i j : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P12.c
