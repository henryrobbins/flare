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
  nT : ℕ  -- number of event times
  tau : Fin nA → Fin nA → ℕ  -- transition time from location a to a'
  r : Fin nA → Fin nT → ℝ  -- reward for being at location a at event time t
  cap : Fin nA → Fin nT → ℝ  -- capacity of location a at event time t
  -- Implicit Assumptions
  hnP : NeZero nP
  hnA : NeZero nA
  hnT : NeZero nT
  hcap_nn : ∀ a t, 0 ≤ cap a t

structure Vars where
  x : ℕ → ℕ → ℕ → ℕ → ℤ  -- 1 if flight p departs location a to a' at event time t

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Each flight must make at least one trip
  htrip : ∀ pl : Fin p.nP,
    1 ≤ ∑ a : Fin p.nA, ∑ a' : Fin p.nA, ∑ t : Fin p.nT, v.x pl a a' t
  -- Respect location capacity at each event time
  hcap : ∀ (a : Fin p.nA) (t : Fin p.nT),
    (∑ pl : Fin p.nP, ∑ a' : Fin p.nA, (v.x pl a a' t : ℝ)) ≤ p.cap a t
  -- x_{p,a,a',t} ∈ {0,1}
  hx_bin : ∀ (pl : Fin p.nP) (a a' : Fin p.nA) (t : Fin p.nT),
    v.x pl a a' t = 0 ∨ v.x pl a a' t = 1

-- Maximize total reward (reward accrues at arrival times)
def obj (p : Params) (v : Vars) : ℝ :=
  ∑ pl : Fin p.nP, ∑ a : Fin p.nA, ∑ t : Fin p.nT, p.r a t *
    ∑ a' : Fin p.nA,
      (univ.filter (fun t' : Fin p.nT => t'.val + p.tau a a' = t.val)).sum
        (fun t' => (v.x pl a a' t' : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P13.b
