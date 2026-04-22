import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P11.Fh

structure Params (nT nG nW nS nL : ℕ) where
  ell    : Fin nG → Fin nS → ℕ
  Csu    : Fin nG → Fin nS → ℝ
  P      : Fin nG → Fin nL → ℝ
  C      : Fin nG → Fin nL → ℝ
  C1     : Fin nG → ℝ
  Lt     : Fin nT → ℝ
  Rt     : Fin nT → ℝ
  Pmin   : Fin nG → ℝ
  Pmax   : Fin nG → ℝ
  Pw_min : Fin nW → Fin nT → ℝ
  Pw_max : Fin nW → Fin nT → ℝ
  RU     : Fin nG → ℝ
  RD     : Fin nG → ℝ
  SU     : Fin nG → ℝ
  SD     : Fin nG → ℝ
  U      : Fin nG → ℕ
  D      : Fin nG → ℕ
  MR     : Fin nG → ℝ
  u0     : Fin nG → ℤ
  p0     : Fin nG → ℝ
  hu0_bin  : ∀ g, u0 g = 0 ∨ u0 g = 1
  hp0_nn   : ∀ g, 0 ≤ p0 g
  hPmax_ge : ∀ g, Pmin g ≤ Pmax g

structure Vars (nT nG nW nS nL : ℕ) where
  u   : Fin nG → Fin nT → ℤ
  v   : Fin nG → Fin nT → ℤ
  w   : Fin nG → Fin nT → ℤ
  p   : Fin nG → Fin nT → ℝ
  r   : Fin nG → Fin nT → ℝ
  c   : Fin nG → Fin nT → ℝ
  pw  : Fin nW → Fin nT → ℝ
  d   : Fin nG → Fin nS → Fin nT → ℤ
  lam : Fin nG → Fin nL → Fin nT → ℝ

structure Feasible {nT nG nW nS nL : ℕ}
    [NeZero nT] [NeZero nG] [NeZero nW] [NeZero nS] [NeZero nL]
    (p : Params nT nG nW nS nL) (v : Vars nT nG nW nS nL) : Prop where
  hdemand : ∀ t, ∑ g, (v.p g t + p.Pmin g * v.u g t) + ∑ k, v.pw k t = p.Lt t
  hreserve : ∀ t, p.Rt t ≤ ∑ g, v.r g t
  hstart_stop : ∀ g t (ht : 0 < t.val),
    v.u g t - v.u g ⟨t.val - 1, by omega⟩ = v.v g t - v.w g t
  hstart_stop0 : ∀ g, v.u g 0 - p.u0 g = v.v g 0 - v.w g 0
  hmin_up : ∀ g t, p.U g ≤ t.val →
    ∑ τ ∈ univ.filter (fun τ => t.val - p.U g + 1 ≤ τ.val ∧ τ.val ≤ t.val),
      v.v g τ ≤ v.u g t
  hmin_dn : ∀ g t, p.D g ≤ t.val →
    ∑ τ ∈ univ.filter (fun τ => t.val - p.D g + 1 ≤ τ.val ∧ τ.val ≤ t.val),
      v.w g τ ≤ 1 - v.u g t
  hv_eq : ∀ g t, v.v g t = ∑ s : Fin nS, v.d g s t
  hlag : ∀ g s t (hs : s.val + 1 < nS), p.ell g ⟨s.val + 1, hs⟩ ≤ t.val →
    v.d g s t ≤ ∑ τ ∈ univ.filter (fun τ : Fin nT =>
      p.ell g s ≤ t.val - τ.val ∧ t.val - τ.val ≤ p.ell g ⟨s.val + 1, hs⟩ + 1),
      v.w g τ
  hmust_run : ∀ g t, p.MR g ≤ v.u g t
  hcap_su : ∀ g t, v.p g t + v.r g t ≤
    (p.Pmax g - p.Pmin g) * v.u g t - max (p.Pmax g - p.SU g) 0 * v.v g t
  hcap_sd : ∀ g t (ht : t.val + 1 < nT), v.p g t + v.r g t ≤
    (p.Pmax g - p.Pmin g) * v.u g t -
      max (p.Pmax g - p.SD g) 0 * v.w g ⟨t.val + 1, ht⟩
  hramp_up : ∀ g t (ht : 0 < t.val),
    v.p g t + v.r g t - v.p g ⟨t.val - 1, by omega⟩ ≤ p.RU g
  hramp_up0 : ∀ g, v.p g 0 + v.r g 0 - p.p0 g ≤ p.RU g
  hramp_dn : ∀ g t (ht : 0 < t.val),
    v.p g ⟨t.val - 1, by omega⟩ - v.p g t ≤ p.RD g
  hramp_dn0 : ∀ g, p.p0 g - v.p g 0 ≤ p.RD g
  hp_eq : ∀ g t, v.p g t = ∑ l, (p.P g l - p.P g 0) * v.lam g l t
  hc_eq : ∀ g t, v.c g t = ∑ l, (p.C g l - p.C g 0) * v.lam g l t
  hu_lam : ∀ g t, (v.u g t : ℝ) = ∑ l, v.lam g l t
  hpw_lb : ∀ k t, p.Pw_min k t ≤ v.pw k t
  hpw_ub : ∀ k t, v.pw k t ≤ p.Pw_max k t
  hu_bin : ∀ g t, v.u g t = 0 ∨ v.u g t = 1
  hv_bin : ∀ g t, v.v g t = 0 ∨ v.v g t = 1
  hw_bin : ∀ g t, v.w g t = 0 ∨ v.w g t = 1
  hd_bin : ∀ g s t, v.d g s t = 0 ∨ v.d g s t = 1
  hlam_nn : ∀ g l t, 0 ≤ v.lam g l t
  hlam_le : ∀ g l t, v.lam g l t ≤ 1
  hp_nn   : ∀ g t, 0 ≤ v.p g t
  hr_nn   : ∀ g t, 0 ≤ v.r g t
  hc_nn   : ∀ g t, 0 ≤ v.c g t
  hpw_nn  : ∀ k t, 0 ≤ v.pw k t
  -- EC3c: Ramp-Up Reachability with Current-Period Shutdown Derating
  -- Pbar bounded by ramp-reachable capacity accounting for shutdown derating at t
  hec3c : ∀ g t (ht : 0 < t.val),
    v.p g t + v.r g t ≤
      (p.Pmax g - p.Pmin g) * v.u g ⟨t.val - 1, by omega⟩
        - max (p.Pmax g - p.SD g) 0 * v.w g t
        + p.RU g

def obj {nT nG nW nS nL : ℕ}
    (p : Params nT nG nW nS nL) (v : Vars nT nG nW nS nL) : ℝ :=
  (∑ g, ∑ t, (v.c g t + p.C1 g * (v.u g t : ℝ))) +
  ∑ g, ∑ s, ∑ t, p.Csu g s * (v.d g s t : ℝ)

def formulation (nT nG nW nS nL : ℕ)
    [NeZero nT] [NeZero nG] [NeZero nW] [NeZero nS] [NeZero nL] :
    MILPFormulation where
  Params   := Params nT nG nW nS nL
  Vars     := Vars nT nG nW nS nL
  feasible := Feasible
  obj      := obj

end P11.Fh
