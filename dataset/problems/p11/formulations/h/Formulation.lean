import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P11.h

structure Params where
  nT : ℕ
  nG : ℕ
  nW : ℕ
  nS : Fin nG → ℕ
  nL : Fin nG → ℕ
  ell : ∀ g : Fin nG, Fin (nS g) → ℕ
  C_su : ∀ g : Fin nG, Fin (nS g) → ℝ
  P : ∀ g : Fin nG, Fin (nL g) → ℝ
  C : ∀ g : Fin nG, Fin (nL g) → ℝ
  C_fixed : Fin nG → ℝ
  L : Fin nT → ℝ
  R : Fin nT → ℝ
  P_min : Fin nG → ℝ
  P_max : Fin nG → ℝ
  P_wind_min : Fin nW → Fin nT → ℝ
  P_wind_max : Fin nW → Fin nT → ℝ
  RU : Fin nG → ℝ
  RD : Fin nG → ℝ
  SU : Fin nG → ℝ
  SD : Fin nG → ℝ
  U : Fin nG → ℕ
  D : Fin nG → ℕ
  MR : Fin nG → ℤ
  hMR_bin : ∀ g : Fin nG, MR g = 0 ∨ MR g = 1
  hT_pos : NeZero nT
  hG_pos : NeZero nG
  hW_pos : NeZero nW
  hnS_pos : ∀ g : Fin nG, NeZero (nS g)
  hnL_pos : ∀ g : Fin nG, NeZero (nL g)
  hCsu_nn : ∀ g : Fin nG, ∀ s : Fin (nS g), 0 ≤ C_su g s
  hP_nn : ∀ g : Fin nG, ∀ l : Fin (nL g), 0 ≤ P g l
  hC_nn : ∀ g : Fin nG, ∀ l : Fin (nL g), 0 ≤ C g l
  hCfixed_nn : ∀ g : Fin nG, 0 ≤ C_fixed g
  hL_nn : ∀ t : Fin nT, 0 ≤ L t
  hR_nn : ∀ t : Fin nT, 0 ≤ R t
  hPmin_nn : ∀ g : Fin nG, 0 ≤ P_min g
  hPmax_nn : ∀ g : Fin nG, 0 ≤ P_max g
  hPmax_ge : ∀ g : Fin nG, P_min g ≤ P_max g
  hPwmin_nn : ∀ w : Fin nW, ∀ t : Fin nT, 0 ≤ P_wind_min w t
  hPwmax_nn : ∀ w : Fin nW, ∀ t : Fin nT, 0 ≤ P_wind_max w t
  hPw_le : ∀ w : Fin nW, ∀ t : Fin nT, P_wind_min w t ≤ P_wind_max w t
  hRU_nn : ∀ g : Fin nG, 0 ≤ RU g
  hRD_nn : ∀ g : Fin nG, 0 ≤ RD g
  hSU_nn : ∀ g : Fin nG, 0 ≤ SU g
  hSD_nn : ∀ g : Fin nG, 0 ≤ SD g
  hU_pos : ∀ g : Fin nG, 1 ≤ U g
  hD_pos : ∀ g : Fin nG, 1 ≤ D g

structure Vars (P : Params) where
  u : Fin P.nG → Fin P.nT → ℤ
  v : Fin P.nG → Fin P.nT → ℤ
  w : Fin P.nG → Fin P.nT → ℤ
  d_su : ∀ g : Fin P.nG, Fin (P.nS g) → Fin P.nT → ℤ
  lam : ∀ g : Fin P.nG, Fin (P.nL g) → Fin P.nT → ℝ
  p : Fin P.nG → Fin P.nT → ℝ
  r : Fin P.nG → Fin P.nT → ℝ
  c_var : Fin P.nG → Fin P.nT → ℝ
  p_wind : Fin P.nW → Fin P.nT → ℝ
  P_bar : Fin P.nG → Fin P.nT → ℝ

structure Feasible (p : Params) (v : Vars p) : Prop where
  hdemand : ∀ t : Fin p.nT,
    ∑ g : Fin p.nG, (v.p g t + p.P_min g * (v.u g t : ℝ)) = p.L t
  hreserve : ∀ t : Fin p.nT,
    p.R t ≤ ∑ g : Fin p.nG, v.r g t
  htransition : ∀ g : Fin p.nG, ∀ t : Fin p.nT, ∀ ht : 0 < t.val,
    (v.u g t : ℤ) - v.u g ⟨t.val - 1, by omega⟩ = v.v g t - v.w g t
  hmin_up : ∀ g : Fin p.nG, ∀ t : Fin p.nT, p.U g - 1 ≤ t.val →
    ∑ τ ∈ (univ : Finset (Fin p.nT)).filter
      (fun τ => t.val - (p.U g - 1) ≤ τ.val ∧ τ.val ≤ t.val),
      v.v g τ ≤ (v.u g t : ℤ)
  hmin_dn : ∀ g : Fin p.nG, ∀ t : Fin p.nT, p.D g - 1 ≤ t.val →
    ∑ τ ∈ (univ : Finset (Fin p.nT)).filter
      (fun τ => t.val - (p.D g - 1) ≤ τ.val ∧ τ.val ≤ t.val),
      v.w g τ ≤ 1 - (v.u g t : ℤ)
  hv_decomp : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    v.v g t = ∑ s : Fin (p.nS g), v.d_su g s t
  hlag : ∀ g : Fin p.nG, ∀ s : Fin (p.nS g), ∀ t : Fin p.nT,
    ∀ hs : s.val + 1 < p.nS g, p.ell g ⟨s.val + 1, hs⟩ - 1 ≤ t.val →
    v.d_su g s t ≤
      ∑ i ∈ (Finset.range (p.ell g ⟨s.val + 1, hs⟩ - p.ell g s)).filter
        (fun i => p.ell g s + i ≤ t.val),
        v.w g ⟨t.val - (p.ell g s + i), by have := t.isLt; omega⟩
  hmust_run : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    (p.MR g : ℝ) ≤ (v.u g t : ℝ)
  hcap_su : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    v.p g t + v.r g t ≤
      (p.P_max g - p.P_min g) * (v.u g t : ℝ) -
        max (p.P_max g - p.SU g) 0 * (v.v g t : ℝ)
  hcap_sd : ∀ g : Fin p.nG, ∀ t : Fin p.nT, ∀ ht : t.val + 1 < p.nT,
    v.p g t + v.r g t ≤
      (p.P_max g - p.P_min g) * (v.u g t : ℝ) -
        max (p.P_max g - p.SD g) 0 * (v.w g ⟨t.val + 1, ht⟩ : ℝ)
  hramp_up : ∀ g : Fin p.nG, ∀ t : Fin p.nT, ∀ ht : 0 < t.val,
    v.p g t + v.r g t - v.p g ⟨t.val - 1, by omega⟩ ≤ p.RU g
  hramp_dn : ∀ g : Fin p.nG, ∀ t : Fin p.nT, ∀ ht : 0 < t.val,
    v.p g ⟨t.val - 1, by omega⟩ - v.p g t ≤ p.RD g
  hp_eq : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    v.p g t = ∑ l : Fin (p.nL g),
      (p.P g l - p.P g ⟨0, (p.hnL_pos g).pos⟩) * v.lam g l t
  hc_eq : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    v.c_var g t = ∑ l : Fin (p.nL g),
      (p.C g l - p.C_fixed g) * v.lam g l t
  hlam_sum : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    ∑ l : Fin (p.nL g), v.lam g l t = (v.u g t : ℝ)
  hu_bin : ∀ g : Fin p.nG, ∀ t : Fin p.nT, v.u g t = 0 ∨ v.u g t = 1
  hv_bin : ∀ g : Fin p.nG, ∀ t : Fin p.nT, v.v g t = 0 ∨ v.v g t = 1
  hw_bin : ∀ g : Fin p.nG, ∀ t : Fin p.nT, v.w g t = 0 ∨ v.w g t = 1
  hd_bin : ∀ g : Fin p.nG, ∀ s : Fin (p.nS g), ∀ t : Fin p.nT,
    v.d_su g s t = 0 ∨ v.d_su g s t = 1
  hlam_nn : ∀ g : Fin p.nG, ∀ l : Fin (p.nL g), ∀ t : Fin p.nT, 0 ≤ v.lam g l t
  hlam_le : ∀ g : Fin p.nG, ∀ l : Fin (p.nL g), ∀ t : Fin p.nT, v.lam g l t ≤ 1
  hp_nn : ∀ g : Fin p.nG, ∀ t : Fin p.nT, 0 ≤ v.p g t
  hr_nn : ∀ g : Fin p.nG, ∀ t : Fin p.nT, 0 ≤ v.r g t
  hcvar_nn : ∀ g : Fin p.nG, ∀ t : Fin p.nT, 0 ≤ v.c_var g t
  hpwind_lo : ∀ w : Fin p.nW, ∀ t : Fin p.nT, p.P_wind_min w t ≤ v.p_wind w t
  hpwind_hi : ∀ w : Fin p.nW, ∀ t : Fin p.nT, v.p_wind w t ≤ p.P_wind_max w t
  -- EC3c: P_bar bounded by ramp-reachability with shutdown derating at current period t
  hec3c : ∀ g : Fin p.nG, ∀ t : Fin p.nT, ∀ ht : 0 < t.val,
    v.P_bar g t ≤
      p.P_min g * (v.u g t : ℝ) +
        (p.P_max g - p.P_min g) * (v.u g ⟨t.val - 1, by omega⟩ : ℝ) -
          max (p.P_max g - p.SD g) 0 * (v.w g t : ℝ) +
            p.RU g

def obj (p : Params) (v : Vars p) : ℝ :=
  (∑ g : Fin p.nG, ∑ t : Fin p.nT,
    (v.c_var g t + p.C_fixed g * (v.u g t : ℝ))) +
  ∑ g : Fin p.nG, ∑ s : Fin (p.nS g), ∑ t : Fin p.nT,
    p.C_su g s * (v.d_su g s t : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P11.h
