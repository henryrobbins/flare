import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P15.b

/-- The set of apartments `A_v` for configuration `v`, encoded as
    `{a : Fin nA | a.val < cap v}`. -/
abbrev apts {nV : ℕ} (cap : Fin nV → ℕ) (cfg : Fin nV) (nA : ℕ) : Finset (Fin nA) :=
  (univ : Finset (Fin nA)).filter (fun a => a.val < cap cfg)

structure Params where
  nK : ℕ  -- number of floors
  nV : ℕ  -- number of floor configurations
  nH : ℕ  -- number of owner classes
  nI : ℕ  -- number of sectors
  nJ : ℕ  -- number of distinct apartment floor areas
  nA : ℕ  -- maximum number of apartments across all configurations
  cap : Fin nV → ℕ  -- number of apartments in configuration v (|A_v|)
  jApt : Fin nV → Fin nA → Fin nJ  -- area index of apartment a in configuration v
  pProfit : Fin nI → Fin nJ → Fin nH → ℝ  -- profit for sector i, area index j, owner h
  area : Fin nJ → ℝ  -- actual floor area value for area index j
  m : Fin nI → Fin nH → ℝ  -- minimum area for sector i and owner h
  b : Fin nI → ℝ  -- minimum fraction of apartments in sector i
  s : Fin nI → ℝ  -- minimum average area for sector i
  o : Fin nH → ℝ  -- minimum ownership fraction for owner h
  iFree : ℕ  -- index of the free sector
  hCorp : ℕ  -- index of the corporation owner
  -- Assumptions
  hiFree : iFree < nI
  hhCorp : hCorp < nH
  -- Implicit Assumptions
  hnK : NeZero nK
  hnV : NeZero nV
  hnH : NeZero nH
  hnI : NeZero nI
  hnJ : NeZero nJ
  hnA : NeZero nA
  hcap_le : ∀ cfg : Fin nV, cap cfg ≤ nA
  harea_nn : ∀ j : Fin nJ, 0 ≤ area j
  hm_nn : ∀ (i : Fin nI) (h : Fin nH), 0 ≤ m i h
  hb_nn : ∀ i : Fin nI, 0 ≤ b i
  hs_nn : ∀ i : Fin nI, 0 ≤ s i
  ho_nn : ∀ h : Fin nH, 0 ≤ o h

structure Vars (p : Params) where
  x : Fin p.nK → Fin p.nV → Fin p.nH → ℤ  -- binary: floor k uses configuration v with owner h; indexed (k, v, h)
  y : Fin p.nK → Fin p.nV → Fin p.nH → Fin p.nI → Fin p.nA → ℤ  -- binary: apartment a on floor k (config v, owner h) in sector i; indexed (k, v, h, i, a)

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Each floor has exactly one configuration and owner
  hfloor : ∀ k : Fin p.nK,
    ∑ cfg : Fin p.nV, ∑ h : Fin p.nH, v.x k cfg h = 1
  -- Each apartment on a chosen floor must be assigned to exactly one sector
  hlink : ∀ (k : Fin p.nK) (cfg : Fin p.nV) (h : Fin p.nH) (a : Fin p.nA),
    a ∈ apts p.cap cfg p.nA →
    ∑ i : Fin p.nI, v.y k cfg h i a = v.x k cfg h
  -- Apartments outside A_v carry no assignments
  hy_outside : ∀ (k : Fin p.nK) (cfg : Fin p.nV) (h : Fin p.nH) (i : Fin p.nI) (a : Fin p.nA),
    a ∉ apts p.cap cfg p.nA → v.y k cfg h i a = 0
  -- Minimum fraction of apartments in each sector
  hsector_pct : ∀ i : Fin p.nI,
    ((∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h : Fin p.nH,
        ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h i a : ℤ) : ℝ) ≥
      p.b i * ((∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h : Fin p.nH,
        ∑ i' : Fin p.nI, ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h i' a : ℤ) : ℝ)
  -- Minimum average area for each sector
  havg_area : ∀ i : Fin p.nI,
    (∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h : Fin p.nH,
        ∑ a ∈ apts p.cap cfg p.nA,
          p.area (p.jApt cfg a) * (v.y k cfg h i a : ℝ)) ≥
      p.s i * ((∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h : Fin p.nH,
        ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h i a : ℤ) : ℝ)
  -- Enforce minimum area requirements per sector-owner pair
  hmin_area : ∀ (k : Fin p.nK) (cfg : Fin p.nV) (h : Fin p.nH) (i : Fin p.nI) (a : Fin p.nA),
    a ∈ apts p.cap cfg p.nA →
    p.area (p.jApt cfg a) < p.m i h →
    v.y k cfg h i a = 0
  -- Corporations cannot own free sector apartments
  hno_free_corp : ∀ (k : Fin p.nK) (cfg : Fin p.nV) (a : Fin p.nA),
    a ∈ apts p.cap cfg p.nA →
    v.y k cfg ⟨p.hCorp, p.hhCorp⟩ ⟨p.iFree, p.hiFree⟩ a = 0
  -- Minimum ownership fraction requirements
  howner_pct : ∀ h : Fin p.nH,
    (∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
        (v.x k cfg h : ℝ) * (p.cap cfg : ℝ)) ≥
      p.o h * (∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
        (v.x k cfg h' : ℝ) * (p.cap cfg : ℝ))
  -- Binary decision variables
  hx_bin : ∀ (k : Fin p.nK) (cfg : Fin p.nV) (h : Fin p.nH),
    v.x k cfg h = 0 ∨ v.x k cfg h = 1
  hy_bin : ∀ (k : Fin p.nK) (cfg : Fin p.nV) (h : Fin p.nH) (i : Fin p.nI) (a : Fin p.nA),
    v.y k cfg h i a = 0 ∨ v.y k cfg h i a = 1

-- Maximize total profit from apartment assignments
def obj (p : Params) (v : Vars p) : ℝ :=
  -(∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h : Fin p.nH, ∑ i : Fin p.nI,
      ∑ a ∈ apts p.cap cfg p.nA,
        p.pProfit i (p.jApt cfg a) h * (v.y k cfg h i a : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P15.b
