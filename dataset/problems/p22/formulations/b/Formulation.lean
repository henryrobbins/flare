import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Fintype.Pi
import Mathlib.Data.Fin.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P22.b

structure Params where
  W : ℕ  -- bin capacity
  m : ℕ  -- number of distinct item types
  w : Fin m → ℕ  -- size of each item type
  b : Fin m → ℤ  -- demand (number of items required) for each item type
  -- Assumptions
  hw_lo : ∀ d : Fin m, 1 ≤ w d
  hw_hi : ∀ d : Fin m, w d ≤ W
  -- Implicit Assumptions
  hW : NeZero W
  hm : NeZero m
  hb_pos : ∀ d : Fin m, 1 ≤ b d

/-
Set of all valid cutting patterns: non-negative integer vectors (a_0,...,a_{m-1})
whose total width does not exceed the bin capacity. Each entry a_d is bounded
above by W (a valid pattern can never use more than W copies of any item
since every item has size at least 1), so patterns are drawn from the finite
ambient type `Fin m → Fin (W + 1)` and cut out by the width constraint.
-/
def J (p : Params) : Finset (Fin p.m → Fin (p.W + 1)) :=
  univ.filter (fun a => ∑ d : Fin p.m, p.w d * (a d).val ≤ p.W)

structure Vars (p : Params) where
  x : (Fin p.m → Fin (p.W + 1)) → ℤ  -- number of bins cut according to pattern a

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- The full demand of every item type must be exactly satisfied by the chosen patterns
  hdemand : ∀ d : Fin p.m, ∑ a ∈ J p, ((a d).val : ℤ) * v.x a = p.b d
  hx_nn : ∀ a ∈ J p, 0 ≤ v.x a
  -- The total number of bins used across all patterns doesn't exceed the total number of items
  htotal : ∑ a ∈ J p, v.x a ≤ ∑ d : Fin p.m, p.b d

-- Minimize the total number of bins (patterns) used
def obj (p : Params) (v : Vars p) : ℝ :=
  ∑ a ∈ J p, (v.x a : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P22.b
