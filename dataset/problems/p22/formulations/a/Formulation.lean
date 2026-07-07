import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P22.a

structure Params where
  n : ℕ  -- number of items
  W : ℤ  -- bin capacity
  l : Fin n → ℤ  -- size of each item
  -- Assumptions
  hl_lo : ∀ j : Fin n, 1 ≤ l j
  hl_hi : ∀ j : Fin n, l j ≤ W
  -- Implicit Assumptions
  hW_pos : 1 ≤ W
  hn : NeZero n

structure Vars (p : Params) where
  y : Fin p.n → ℤ  -- 1 if bin i is used, 0 otherwise
  x : Fin p.n → Fin p.n → ℤ  -- 1 if item j is assigned to bin i, 0 otherwise

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Total size of items assigned to a bin cannot exceed its capacity, and only if the bin is used
  hcap : ∀ i : Fin p.n, ∑ j : Fin p.n, p.l j * v.x i j ≤ p.W * v.y i
  -- Every item is assigned to exactly one bin
  hassign : ∀ j : Fin p.n, ∑ i : Fin p.n, v.x i j = 1
  hy_bin : ∀ i : Fin p.n, v.y i = 0 ∨ v.y i = 1
  hx_bin : ∀ i j : Fin p.n, v.x i j = 0 ∨ v.x i j = 1

-- Minimize the total number of bins used
def obj (p : Params) (v : Vars p) : ℝ :=
  ∑ i : Fin p.n, (v.y i : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P22.a
