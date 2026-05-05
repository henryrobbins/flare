import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P12.b

structure Params where
  n : ℕ  -- number of cities
  c : Fin n → Fin n → ℝ  -- arc cost
  -- Implicit Assumptions
  hn : NeZero n

structure Vars (p : Params) where
  x : Fin p.n → Fin p.n → ℤ  -- arc indicator
  u : Fin p.n → ℝ  -- position

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Each city has exactly one outgoing arc
  hout : ∀ i : Fin p.n, ∑ j : Fin p.n, v.x i j = 1
  -- Each city has exactly one incoming arc
  hin : ∀ j : Fin p.n, ∑ i : Fin p.n, v.x i j = 1
  -- MTZ subtour elimination
  hmtz : ∀ (i : Fin p.n) (j : Fin p.n), i.val ≠ 0 → j.val ≠ 0 → i ≠ j →
    v.u i - v.u j + (p.n : ℝ) * (v.x i j : ℝ) ≤ (p.n : ℝ) - 1
  -- Depot position fixed to 1
  hu_depot : haveI := p.hn; v.u 0 = 1
  hx_bin : ∀ (i j : Fin p.n), v.x i j = 0 ∨ v.x i j = 1
  -- u ∈ [2, n] for non-depot cities
  hu_lo : ∀ i : Fin p.n, i.val ≠ 0 → 2 ≤ v.u i
  hu_hi : ∀ i : Fin p.n, v.u i ≤ (p.n : ℝ)
  -- EC1: if the tour leaves the depot directly to city j, j is positioned at most second
  hec1 : ∀ j : Fin p.n, j.val ≠ 0 →
    haveI := p.hn
    v.u j ≤ 2 + ((p.n : ℝ) - 2) * (1 - (v.x 0 j : ℝ))
  -- [Implicit Constraints]
  -- No self-loops
  hx_no_self : ∀ i : Fin p.n, v.x i i = 0

-- Minimize total arc cost
def obj (p : Params) (v : Vars p) : ℝ :=
  ∑ i : Fin p.n, ∑ j : Fin p.n, p.c i j * (v.x i j : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P12.b
