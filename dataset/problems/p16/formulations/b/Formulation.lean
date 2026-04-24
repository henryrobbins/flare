import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P16.b

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
  hNP : NeZero nP
  hNS : NeZero nS
  hM : NeZero M
  -- Implicit Assumptions
  hv_nn : ∀ s p, 0 ≤ v s p
  hF_bin : ∀ s h p, F s h p = 0 ∨ F s h p = 1
  hU_nn : 0 ≤ U

structure Vars where
  y : ℕ → ℤ  -- hub open indicator (y h = 1 iff hub h is opened)
  x : ℕ → ℕ → ℕ → ℤ  -- assignment indicator (x s h p = 1 iff demand s→p served via hub h)

structure Feasible (p : Params) (v : Vars) : Prop where
  -- At most U new hubs may be opened (hubs N..M-1)
  hnew_cap :
    ∑ h ∈ (univ : Finset (Fin p.M)).filter (fun h => p.N ≤ h.val), (v.y h.val : ℤ) ≤ p.U
  -- All existing hubs (hubs 0..N-1) must remain open
  hexisting :
    ∑ h ∈ (univ : Finset (Fin p.M)).filter (fun h => h.val < p.N), (v.y h.val : ℤ) = (p.N : ℤ)
  -- A demand can only be assigned via hub h if that hub is open
  hopen : ∀ s : Fin p.nS, ∀ h : Fin p.M, ∀ q : Fin p.nP,
    v.x s.val h.val q.val ≤ v.y h.val
  -- A demand can only be assigned via a feasible hub
  hfeas : ∀ s : Fin p.nS, ∀ h : Fin p.M, ∀ q : Fin p.nP,
    (v.x s.val h.val q.val : ℤ) ≤ p.F s h q
  -- Each (s,p) demand is assigned to at most one hub
  hassign : ∀ s : Fin p.nS, ∀ q : Fin p.nP,
    ∑ h : Fin p.M, v.x s.val h.val q.val ≤ 1
  hy_bin : ∀ h : Fin p.M, v.y h.val = 0 ∨ v.y h.val = 1
  hx_bin : ∀ s : Fin p.nS, ∀ h : Fin p.M, ∀ q : Fin p.nP,
    v.x s.val h.val q.val = 0 ∨ v.x s.val h.val q.val = 1

-- Maximize total covered demand (assigned via some hub)
def obj (p : Params) (v : Vars) : ℝ :=
  -(∑ s : Fin p.nS, ∑ h : Fin p.M, ∑ q : Fin p.nP, p.v s q * (v.x s.val h.val q.val : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P16.b
