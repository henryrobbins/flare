import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P6.Fa

structure Params (m n : ℕ) where
  d : Fin m → ℝ           -- customer demands
  u : Fin n → ℝ           -- warehouse capacities
  f : Fin n → ℝ           -- fixed opening costs
  c : Fin m → Fin n → ℝ  -- transportation costs
  hd_pos : ∀ i, 0 < d i
  hu_nn  : ∀ j, 0 ≤ u j

structure Vars (m n : ℕ) where
  x : Fin m → Fin n → ℤ  -- assignment
  y : Fin n → ℤ           -- warehouse activation

structure Feasible {m n : ℕ} [NeZero m] [NeZero n] (p : Params m n) (v : Vars m n) : Prop where
  -- Each customer is assigned to exactly one warehouse
  hassign : ∀ i, ∑ j, v.x i j = 1
  -- Capacity constraint at each warehouse
  hcap : ∀ j, ∑ i, p.d i * v.x i j ≤ p.u j * v.y j
  hx_bin : ∀ i j, v.x i j = 0 ∨ v.x i j = 1
  hy_bin : ∀ j, v.y j = 0 ∨ v.y j = 1

-- Minimize total fixed opening cost plus transportation cost
def obj {m n : ℕ} (p : Params m n) (v : Vars m n) : ℝ :=
  (∑ j, p.f j * (v.y j : ℝ)) + ∑ i, ∑ j, p.c i j * (v.x i j : ℝ)

def formulation (m n : ℕ) [NeZero m] [NeZero n] : MILPFormulation where
  Params   := Params m n
  Vars     := Vars m n
  feasible := Feasible
  obj      := obj

end P6.Fa
