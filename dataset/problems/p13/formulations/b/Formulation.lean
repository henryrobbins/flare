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
  adj : Fin nA → Fin nA → ℤ  -- adjacency matrix (1 if a adjacent to a', 0 otherwise)
  r : Fin nA → Fin nT → ℝ  -- reward for being at location a at time t
  cap : Fin nA → Fin nT → ℤ  -- capacity of location a at time t
  -- Assumptions
  hadj_bin : ∀ a a', adj a a' = 0 ∨ adj a a' = 1
  -- Implicit Assumptions
  hnP : NeZero nP
  hnA : NeZero nA
  hnT : NeZero nT
  hadj_self : ∀ a, adj a a = 1
  hcap_nn : ∀ a t, 0 ≤ cap a t

structure Vars (p : Params) where
  n : Fin p.nA → Fin p.nT → ℤ  -- number of flights at location a at time t
  f : Fin p.nA → Fin p.nA → Fin p.nT → ℤ  -- number of flights moving from a at time t to a' at time t+1

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- All flights are accounted for at every time period
  hcount : ∀ t : Fin p.nT, ∑ a : Fin p.nA, v.n a t = (p.nP : ℤ)
  -- Number of flights at each location does not exceed capacity
  hcap : ∀ (a : Fin p.nA) (t : Fin p.nT), (v.n a t : ℝ) ≤ (p.cap a t : ℝ)
  -- Flow conservation: one-step transitions (for t > 0)
  hflow : ∀ (a : Fin p.nA) (t : Fin p.nT), ∀ ht : 0 < t.val,
    v.n a t =
      v.n a ⟨t.val - 1, by omega⟩ +
      ∑ a' : Fin p.nA, v.f a' a ⟨t.val - 1, by
        have _ : t.val < p.nT := t.isLt
        omega⟩ -
      ∑ a' : Fin p.nA, v.f a a' ⟨t.val - 1, by
        have _ : t.val < p.nT := t.isLt
        omega⟩
  -- Movements only between adjacent locations
  hadj : ∀ (a a' : Fin p.nA) (t : Fin p.nT),
    v.f a a' t ≤ (p.nP : ℤ) * p.adj a a'
  -- No movements out of the final time period
  hno_depart_last : ∀ (a a' : Fin p.nA) (t : Fin p.nT),
    t.val + 1 = p.nT → v.f a a' t = 0
  -- Aggregate departures at time t do not exceed presence at time t (stay-flow ≥ 0)
  hstay_nn : ∀ (a : Fin p.nA) (t : Fin p.nT),
    (∑ a' : Fin p.nA, v.f a a' t) ≤ v.n a t
  hn_nn : ∀ (a : Fin p.nA) (t : Fin p.nT), 0 ≤ v.n a t
  hf_nn : ∀ (a a' : Fin p.nA) (t : Fin p.nT), 0 ≤ v.f a a' t

-- Maximize total reward for all flights across all locations and time periods
def obj (p : Params) (v : Vars p) : ℝ :=
  ∑ a : Fin p.nA, ∑ t : Fin p.nT, p.r a t * (v.n a t : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P13.b
