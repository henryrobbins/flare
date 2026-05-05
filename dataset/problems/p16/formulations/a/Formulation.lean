import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P16.a

structure Params where
  N : ℕ  -- number of existing hubs that must remain open
  M : ℕ  -- total number of hub locations (existing + potential new)
  nP : ℕ  -- number of Points of Interest
  nS : ℕ  -- number of junction roads (commuter origins)
  v : Fin nS → Fin nP → ℝ  -- commuter demand from junction s to POI p
  F : Fin nS → Fin M → Fin nP → ℤ  -- feasibility indicator F_{shp}
  U : ℤ  -- maximum number of new hubs that can be opened
  -- Assumptions
  hN_le_M : N ≤ M  -- existing hub count bounded by total hub count
  hF_bin : ∀ s h p, F s h p = 0 ∨ F s h p = 1
  -- Implicit Assumptions
  hNP : NeZero nP
  hNS : NeZero nS
  hM : NeZero M
  hv_nn : ∀ s p, 0 ≤ v s p
  hU_nn : 0 ≤ U

structure Vars (p : Params) where
  y : Fin p.M → ℤ  -- hub open indicator (y h = 1 iff hub h is opened)
  z : Fin p.nS → Fin p.nP → ℤ  -- demand coverage indicator (z s p = 1 iff demand s→p is covered)

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- At most U new hubs may be opened (hubs N..M-1)
  hnew_cap :
    ∑ h ∈ (univ : Finset (Fin p.M)).filter (fun h => p.N ≤ h.val), (v.y h : ℤ) ≤ p.U
  -- All existing hubs (hubs 0..N-1) must remain open
  hexisting :
    ∑ h ∈ (univ : Finset (Fin p.M)).filter (fun h => h.val < p.N), (v.y h : ℤ) = (p.N : ℤ)
  -- Demand (s,p) is covered only if at least one feasible open hub exists
  hcover : ∀ s : Fin p.nS, ∀ q : Fin p.nP,
    (v.z s q : ℤ) ≤ ∑ h : Fin p.M, p.F s h q * v.y h
  hy_bin : ∀ h : Fin p.M, v.y h = 0 ∨ v.y h = 1
  hz_bin : ∀ s : Fin p.nS, ∀ q : Fin p.nP, v.z s q = 0 ∨ v.z s q = 1

-- Maximize total covered demand
def obj (p : Params) (v : Vars p) : ℝ :=
  -(∑ s : Fin p.nS, ∑ q : Fin p.nP, p.v s q * (v.z s q : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P16.a
