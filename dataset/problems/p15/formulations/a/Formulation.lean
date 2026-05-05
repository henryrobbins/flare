import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P15.a

structure Params where
  nI : ℕ  -- number of sectors
  nJ : ℕ  -- number of distinct apartment floor areas
  nH : ℕ  -- number of owner classes
  nV : ℕ  -- number of floor configurations
  K : ℕ  -- total number of floors in the tower
  R : Fin nJ → Fin nV → ℤ  -- number of apartments with area j in configuration v
  O : Fin nI → Fin nJ → Fin nH → ℝ  -- profit per apartment for sector i, area j, owner h
  area : Fin nJ → ℝ  -- actual floor area value for area index j
  m : Fin nI → Fin nH → ℝ  -- minimum floor area for sector i and owner h
  a : Fin nI → ℝ  -- minimum fraction of total apartments in sector i
  s : Fin nI → ℝ  -- minimum average floor area for sector i
  o : Fin nH → ℝ  -- minimum fraction of total apartments for owner h
  iFree : ℕ  -- index of the free sector
  hCorp : ℕ  -- index of the corporation owner
  -- Assumptions
  hiFree : iFree < nI
  hhCorp : hCorp < nH
  -- Implicit Assumptions
  hnI : NeZero nI
  hnJ : NeZero nJ
  hnH : NeZero nH
  hnV : NeZero nV
  hR_nn : ∀ j v, 0 ≤ R j v
  harea_nn : ∀ j, 0 ≤ area j
  hm_nn : ∀ i h, 0 ≤ m i h
  ha_nn : ∀ i, 0 ≤ a i
  hs_nn : ∀ i, 0 ≤ s i
  ho_nn : ∀ h, 0 ≤ o h

structure Vars (p : Params) where
  x : Fin p.nV → Fin p.nH → ℤ  -- number of floors with configuration v and owner h; indexed (v, h)
  y : Fin p.nI → Fin p.nJ → Fin p.nH → ℤ  -- number of apartments in sector i, area j, owner h; indexed (i, j, h)

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Total number of floors equals K
  hfloors : ∑ cfg : Fin p.nV, ∑ h : Fin p.nH, v.x cfg h = (p.K : ℤ)
  -- Apartment-count consistency between configurations and sector assignments
  hconsistency : ∀ (j : Fin p.nJ) (h : Fin p.nH),
    ∑ cfg : Fin p.nV, p.R j cfg * v.x cfg h = ∑ i : Fin p.nI, v.y i j h
  -- Minimum fraction of apartments in sector i
  hsector_pct : ∀ i : Fin p.nI,
    ((∑ j : Fin p.nJ, ∑ h : Fin p.nH, v.y i j h : ℤ) : ℝ) ≥
      p.a i * ((∑ l : Fin p.nI, ∑ j : Fin p.nJ, ∑ h : Fin p.nH, v.y l j h : ℤ) : ℝ)
  -- Minimum average floor area for sector i
  havg_area : ∀ i : Fin p.nI,
    (∑ j : Fin p.nJ, ∑ h : Fin p.nH, p.area j * (v.y i j h : ℝ)) ≥
      p.s i * ((∑ j : Fin p.nJ, ∑ h : Fin p.nH, v.y i j h : ℤ) : ℝ)
  -- Minimum floor area for sector-owner pair (disallow areas below minimum)
  hmin_area : ∀ (i : Fin p.nI) (j : Fin p.nJ) (h : Fin p.nH),
    p.area j < p.m i h → v.y i j h = 0
  -- Corporations cannot own free sector apartments
  hno_free_corp : ∀ j : Fin p.nJ, v.y ⟨p.iFree, p.hiFree⟩ j ⟨p.hCorp, p.hhCorp⟩ = 0
  -- Minimum fraction of apartments for owner h
  howner_pct : ∀ h : Fin p.nH,
    ((∑ i : Fin p.nI, ∑ j : Fin p.nJ, v.y i j h : ℤ) : ℝ) ≥
      p.o h * ((∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH, v.y i j h' : ℤ) : ℝ)
  -- [Implicit Constraints]
  hx_nn : ∀ (cfg : Fin p.nV) (h : Fin p.nH), 0 ≤ v.x cfg h
  hy_nn : ∀ (i : Fin p.nI) (j : Fin p.nJ) (h : Fin p.nH), 0 ≤ v.y i j h

-- Maximize total profit from apartment assignments
def obj (p : Params) (v : Vars p) : ℝ :=
  -(∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h : Fin p.nH, p.O i j h * (v.y i j h : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P15.a
