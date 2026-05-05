import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P19.a

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

structure Vars (p : Params) where
  x : Fin p.nH → Fin p.nC → ℝ  -- supply fraction from hub to region
  y : Fin p.nH → ℤ  -- hub-open indicator (binary)

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Each hub can serve regions only if it is open
  hcap : ∀ h : Fin p.nH, ∑ c : Fin p.nC, v.x h c ≤ (p.nC : ℝ) * (v.y h : ℝ)
  -- Each disaster region's demand must be fully supplied
  hdemand : ∀ c : Fin p.nC, ∑ h : Fin p.nH, v.x h c = 1
  -- Limit on the total number of hubs opened
  hopen : ∑ h : Fin p.nH, v.y h ≤ (p.n : ℤ)
  -- Fixed hubs must be open
  hfixed : ∀ h : Fin p.nH, p.Hf h = 1 → v.y h = 1
  -- Per-region weighted travel time limit
  htime : ∀ c : Fin p.nC, ∑ h : Fin p.nH, p.t h c * v.x h c ≤ p.T
  hx_nn : ∀ h : Fin p.nH, ∀ c : Fin p.nC, 0 ≤ v.x h c
  hy_bin : ∀ h : Fin p.nH, v.y h = 0 ∨ v.y h = 1

-- Minimize total per-person-weighted transportation cost
def obj (p : Params) (v : Vars p) : ℝ :=
  ∑ h : Fin p.nH, ∑ c : Fin p.nC, p.a c * p.C h c * v.x h c

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P19.a
