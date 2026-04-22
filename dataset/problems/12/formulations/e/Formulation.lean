import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P12.Fe

structure Params (n : ℕ) where
  c : Fin n → Fin n → ℝ  -- arc cost

structure Vars (n : ℕ) where
  x : Fin n → Fin n → ℤ  -- arc indicator
  u : Fin n → ℝ           -- position

structure Feasible {n : ℕ} [NeZero n] (_ : Params n) (v : Vars n) : Prop where
  -- Each city has exactly one outgoing arc
  hout : ∀ i, ∑ j, v.x i j = 1
  -- Each city has exactly one incoming arc
  hin : ∀ j, ∑ i, v.x i j = 1
  -- MTZ subtour elimination
  hmtz : ∀ i j, i ≠ 0 → j ≠ 0 → i ≠ j →
    v.u i - v.u j + n * v.x i j ≤ n - 1
  -- Depot position fixed to 1
  hu_depot : v.u 0 = 1
  hx_bin : ∀ i j, v.x i j = 0 ∨ v.x i j = 1
  -- No self-loops
  hx_no_self : ∀ i, v.x i i = 0
  -- u ∈ [2, n] for non-depot cities
  hu_lo : ∀ i, i ≠ 0 → 2 ≤ v.u i
  hu_hi : ∀ i, v.u i ≤ n
  -- EC1 (V2): Arc Symmetry
  -- Both directions of an arc cannot be simultaneously active
  hec1 : ∀ i j : Fin n, i < j → v.x i j + v.x j i ≤ 1

-- Minimize total arc cost
def obj {n : ℕ} (p : Params n) (v : Vars n) : ℝ :=
  ∑ i, ∑ j, p.c i j * (v.x i j : ℝ)

def formulation (n : ℕ) [NeZero n] : MILPFormulation where
  Params   := Params n
  Vars     := Vars n
  feasible := Feasible
  obj      := obj

end P12.Fe
