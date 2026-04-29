import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P13.b

structure Params where
  nP : ℕ  -- number of flights
  nA : ℕ  -- number of locations
  nT : ℕ  -- number of time periods
  tau : Fin nA → Fin nA → ℤ  -- transition time from location a to a'
  r : Fin nA → Fin nT → ℝ  -- reward for being at location a at time t
  cap : Fin nA → Fin nT → ℤ  -- capacity of location a at time t
  -- Implicit Assumptions
  hnP : NeZero nP
  hnA : NeZero nA
  hnT : NeZero nT
  htau_nn : ∀ a a', 0 ≤ tau a a'
  hcap_nn : ∀ a t, 0 ≤ cap a t

structure Vars where
  n : ℕ → ℕ → ℤ  -- number of flights at location a at time t
  f : ℕ → ℕ → ℕ → ℤ  -- number of flights departing from location a to a' at time t

structure Feasible (p : Params) (v : Vars) : Prop where
  -- All flights are accounted for at every time period
  hcount : ∀ t : Fin p.nT, ∑ a : Fin p.nA, v.n a t = (p.nP : ℤ)
  -- Number of flights at each location does not exceed capacity
  hcap : ∀ (a : Fin p.nA) (t : Fin p.nT), (v.n a t : ℝ) ≤ (p.cap a t : ℝ)
  -- Flow conservation with travel time (for t > 0)
  hflow : ∀ (a : Fin p.nA) (t : Fin p.nT), 0 < t.val →
    v.n a t =
      v.n a (t.val - 1) +
      ∑ a' : Fin p.nA, (univ.filter (fun t' : Fin p.nT => t'.val + p.tau a' a = t.val)).sum
              (fun t' => v.f a' a t') -
      ∑ a' : Fin p.nA, v.f a a' t
  hn_nn : ∀ (a : Fin p.nA) (t : Fin p.nT), 0 ≤ v.n a t
  hf_nn : ∀ (a a' : Fin p.nA) (t : Fin p.nT), 0 ≤ v.f a a' t

-- Maximize total reward for all flights across all locations and time periods
def obj (p : Params) (v : Vars) : ℝ :=
  ∑ a : Fin p.nA, ∑ t : Fin p.nT, p.r a t * (v.n a t : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P13.b
