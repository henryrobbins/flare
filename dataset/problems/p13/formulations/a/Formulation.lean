import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P13.a

structure Params where
  nP : ℕ  -- number of flights
  nA : ℕ  -- number of locations
  nT : ℕ  -- number of time periods
  tau : Fin nA → Fin nA → ℤ  -- transition time from a to a'
  r : Fin nA → Fin nT → ℝ  -- reward for being at location a at time t
  cap : Fin nA → Fin nT → ℤ  -- capacity of location a at time t
  -- Implicit Assumptions
  hnP : NeZero nP
  hnA : NeZero nA
  hnT : NeZero nT
  htau_nn : ∀ a a', 0 ≤ tau a a'
  hcap_nn : ∀ a t, 0 ≤ cap a t

structure Vars (p : Params) where
  y : Fin p.nP → Fin p.nA → Fin p.nT → ℤ  -- 1 if flight pl is at location a at time t
  z : Fin p.nP → Fin p.nA → Fin p.nA → Fin p.nT → ℤ  -- 1 if flight pl departs location a to a' at time t

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Each flight is at exactly one location at each time
  hassign : ∀ (pl : Fin p.nP) (t : Fin p.nT), ∑ a : Fin p.nA, v.y pl a t = 1
  -- Respect location capacity at each time
  hcap : ∀ (a : Fin p.nA) (t : Fin p.nT), (∑ pl : Fin p.nP, (v.y pl a t : ℝ)) ≤ (p.cap a t : ℝ)
  -- Flow conservation with travel time (for t > 0)
  hflow : ∀ (pl : Fin p.nP) (a : Fin p.nA) (t : Fin p.nT), ∀ ht : 0 < t.val,
    v.y pl a t =
      v.y pl a ⟨t.val - 1, by omega⟩ +
      ∑ a' : Fin p.nA, (univ.filter (fun t' : Fin p.nT => t'.val + p.tau a' a = t.val)).sum
              (fun t' => v.z pl a' a t') -
      ∑ a' : Fin p.nA, v.z pl a a' t
  -- y_{p,a,t} ∈ {0,1}
  hy_bin : ∀ (pl : Fin p.nP) (a : Fin p.nA) (t : Fin p.nT), v.y pl a t = 0 ∨ v.y pl a t = 1
  -- z_{p,a,a',t} ∈ {0,1}
  hz_bin : ∀ (pl : Fin p.nP) (a a' : Fin p.nA) (t : Fin p.nT), v.z pl a a' t = 0 ∨ v.z pl a a' t = 1

-- Maximize total reward for visiting locations
def obj (p : Params) (v : Vars p) : ℝ :=
  ∑ pl : Fin p.nP, ∑ a : Fin p.nA, ∑ t : Fin p.nT, p.r a t * (v.y pl a t : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P13.a
