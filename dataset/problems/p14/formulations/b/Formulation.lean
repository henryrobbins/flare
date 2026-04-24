import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P14.b

structure Params where
  nS : ℕ  -- number of candidate DC locations
  nH : ℕ  -- number of hospitals
  numDC : ℕ  -- number of DCs to open
  T : Fin nS → Fin nH → ℝ  -- travel time from candidate DC i to hospital j
  T_limit : ℝ  -- travel time limit
  -- Assumptions
  hnS : NeZero nS
  hnH : NeZero nH
  -- Implicit Assumptions
  hT_nn : ∀ i j, 0 ≤ T i j
  hT_limit_nn : 0 ≤ T_limit

structure Vars where
  x : ℕ → ℤ      -- DC activation: 1 if candidate DC i is opened
  y : ℕ → ℕ → ℤ  -- assignment: 1 if hospital j is assigned to DC i

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Select exactly numDC DC locations
  hselect : ∑ i : Fin p.nS, v.x i = (p.numDC : ℤ)
  -- Hospitals can only be allocated to active DCs (big-M bound of nH)
  hactive : ∀ i : Fin p.nS, ∑ j : Fin p.nH, v.y i j ≤ v.x i * (p.nH : ℤ)
  -- Each hospital is assigned to exactly one DC
  hassign : ∀ j : Fin p.nH, ∑ i : Fin p.nS, v.y i j = 1
  -- Enforce travel time limit for each DC-hospital assignment
  htime : ∀ i : Fin p.nS, ∀ j : Fin p.nH, p.T i j * (v.y i j : ℝ) ≤ p.T_limit
  hx_bin : ∀ i : Fin p.nS, v.x i = 0 ∨ v.x i = 1
  hy_bin : ∀ i : Fin p.nS, ∀ j : Fin p.nH, v.y i j = 0 ∨ v.y i j = 1

-- Minimize total travel time across all hospital-DC assignments
def obj (p : Params) (v : Vars) : ℝ :=
  ∑ i : Fin p.nS, ∑ j : Fin p.nH, (v.y i j : ℝ) * p.T i j

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P14.b
