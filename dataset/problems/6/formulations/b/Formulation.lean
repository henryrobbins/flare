import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P6.Fb

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

-- Maximum warehouse capacity
noncomputable def uMax {m n : ℕ} (p : Params m n) : ℝ := ⨆ j : Fin n, p.u j

-- Critical customers: demand exceeds half the maximum warehouse capacity
noncomputable def criticalCustomers {m n : ℕ} (p : Params m n) : Finset (Fin m) :=
  letI : DecidablePred (fun i : Fin m => uMax p / 2 < p.d i) := Classical.decPred _
  univ.filter (fun i => uMax p / 2 < p.d i)

structure Feasible {m n : ℕ} [NeZero m] [NeZero n] (p : Params m n) (v : Vars m n) : Prop where
  hassign : ∀ i, ∑ j, v.x i j = 1
  hcap : ∀ j, ∑ i, p.d i * v.x i j ≤ p.u j * v.y j
  hx_bin : ∀ i j, v.x i j = 0 ∨ v.x i j = 1
  hy_bin : ∀ j, v.y j = 0 ∨ v.y j = 1
  -- EC1 (V1): Critical-Customer Bound
  -- Customers with demand > uMax/2 are mutually conflicting; at least |C| warehouses must open
  hec1 : (criticalCustomers p).card ≤ ∑ j, v.y j

def obj {m n : ℕ} (p : Params m n) (v : Vars m n) : ℝ :=
  (∑ j, p.f j * (v.y j : ℝ)) + ∑ i, ∑ j, p.c i j * (v.x i j : ℝ)

def formulation (m n : ℕ) [NeZero m] [NeZero n] : MILPFormulation where
  Params   := Params m n
  Vars     := Vars m n
  feasible := Feasible
  obj      := obj

end P6.Fb
