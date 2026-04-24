import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P19.b

structure Params where
  nH : ℕ  -- number of candidate hub locations
  nC : ℕ  -- number of disaster-prone regions
  a : Fin nC → ℝ  -- number of people affected in each disaster region
  C : Fin nH → Fin nC → ℝ  -- cost per person from hub to region
  t : Fin nH → Fin nC → ℝ  -- transportation time from hub to region
  T : ℝ  -- maximum allowed transportation time per region
  n : ℕ  -- maximum number of hubs that can be opened
  Hf : Fin nH → ℤ  -- indicator: 1 if hub is fixed and must remain open, 0 otherwise
  -- Assumptions
  hHf_bin : ∀ h : Fin nH, Hf h = 0 ∨ Hf h = 1
  -- Implicit Assumptions
  hnH : NeZero nH
  hnC : NeZero nC
  ha_nn : ∀ c : Fin nC, 0 ≤ a c
  hC_nn : ∀ h : Fin nH, ∀ c : Fin nC, 0 ≤ C h c
  ht_nn : ∀ h : Fin nH, ∀ c : Fin nC, 0 ≤ t h c

structure Vars where
  q : ℕ → ℕ → ℝ  -- demand fraction served by hub h to region c
  z : ℕ → ℕ → ℤ  -- hub-region assignment indicator (binary)
  y : ℕ → ℤ  -- hub-open indicator (binary)

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Big-M link replaced by disjunction: hub h contributes to region c only if assigned
  hlink : ∀ h : Fin p.nH, ∀ c : Fin p.nC, v.q h c = 0 ∨ v.z h c = 1
  -- Each disaster region's demand must be fully supplied
  hdemand : ∀ c : Fin p.nC, ∑ h : Fin p.nH, v.q h c = 1
  -- Hubs can only be assigned to regions if they are open
  hcap : ∀ h : Fin p.nH, ∑ c : Fin p.nC, v.z h c ≤ (p.nC : ℤ) * v.y h
  -- Limit on the total number of hubs opened
  hopen : ∑ h : Fin p.nH, v.y h ≤ (p.n : ℤ)
  -- Fixed hubs must be open
  hfixed : ∀ h : Fin p.nH, p.Hf h = 1 → v.y h = 1
  -- Per-region weighted travel time limit
  htime : ∀ c : Fin p.nC, ∑ h : Fin p.nH, p.t h c * v.q h c ≤ p.T
  hq_nn : ∀ h : Fin p.nH, ∀ c : Fin p.nC, 0 ≤ v.q h c
  hz_bin : ∀ h : Fin p.nH, ∀ c : Fin p.nC, v.z h c = 0 ∨ v.z h c = 1
  hy_bin : ∀ h : Fin p.nH, v.y h = 0 ∨ v.y h = 1

-- Minimize total per-person-weighted transportation cost
def obj (p : Params) (v : Vars) : ℝ :=
  ∑ h : Fin p.nH, ∑ c : Fin p.nC, p.a c * p.C h c * v.q h c

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P19.b
