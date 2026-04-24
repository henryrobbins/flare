import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P14.a

structure Params where
  nS : ℕ  -- number of candidate DC locations
  nH : ℕ  -- number of hospital locations
  numDC : ℕ  -- number of DCs to open
  T : Fin nS → Fin nH → ℝ  -- travel time from candidate DC i to hospital j
  T_limit : ℝ  -- travel time limit
  delta : Fin nS → Fin nH → ℤ  -- feasibility indicator, 1 if T i j ≤ T_limit else 0
  -- Assumptions
  hnS : NeZero nS
  hnH : NeZero nH
  -- Implicit Assumptions
  hT_nn : ∀ i j, 0 ≤ T i j
  hT_limit_nn : 0 ≤ T_limit
  hdelta_bin : ∀ i j, delta i j = 0 ∨ delta i j = 1
  hdelta_def : ∀ i j, (delta i j = 1 ↔ T i j ≤ T_limit) ∧ (delta i j = 0 ↔ T_limit < T i j)

structure Vars where
  x : ℕ → ℤ      -- DC activation: 1 if candidate DC i is selected
  y : ℕ → ℕ → ℤ  -- assignment: 1 if hospital j is assigned to DC i

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Select exactly numDC DC locations
  hselect : ∑ i : Fin p.nS, v.x i = (p.numDC : ℤ)
  -- Hospitals can only be allocated to active DCs
  hactive : ∀ i : Fin p.nS,
    ∑ j : Fin p.nH, p.delta i j * v.y i j ≤ v.x i * ∑ j : Fin p.nH, p.delta i j
  -- Each hospital is assigned to exactly one feasible DC
  hassign : ∀ j : Fin p.nH, ∑ i : Fin p.nS, p.delta i j * v.y i j = 1
  -- No allocation if travel time is infeasible
  hinfeas : ∀ i : Fin p.nS, ∀ j : Fin p.nH, p.delta i j = 0 → v.y i j = 0
  hx_bin : ∀ i : Fin p.nS, v.x i = 0 ∨ v.x i = 1
  hy_bin : ∀ i : Fin p.nS, ∀ j : Fin p.nH, v.y i j = 0 ∨ v.y i j = 1

-- Minimize total drive time across all feasible hospital-DC assignments
def obj (p : Params) (v : Vars) : ℝ :=
  ∑ i : Fin p.nS, ∑ j : Fin p.nH, (p.delta i j : ℝ) * (v.y i j : ℝ) * p.T i j

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P14.a
