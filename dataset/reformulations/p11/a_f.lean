import Common
import problems.p11.formulations.a.Formulation
import problems.p11.formulations.f.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P11
-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P11.a.Params) : P11.f.Params :=
  { nT         := p.nT
    nG         := p.nG
    nW         := p.nW
    nS         := p.nS
    nL         := p.nL
    ell        := p.ell
    C_su       := p.C_su
    P          := p.P
    C          := p.C
    C_fixed    := p.C_fixed
    L          := p.L
    R          := p.R
    P_min      := p.P_min
    P_max      := p.P_max
    P_wind_min := p.P_wind_min
    P_wind_max := p.P_wind_max
    RU         := p.RU
    RD         := p.RD
    SU         := p.SU
    SD         := p.SD
    U          := p.U
    D          := p.D
    MR         := p.MR
    hT_pos     := p.hT_pos
    hG_pos     := p.hG_pos
    hW_pos     := p.hW_pos
    hnS_pos    := p.hnS_pos
    hnL_pos    := p.hnL_pos
    hCsu_nn    := p.hCsu_nn
    hP_nn      := p.hP_nn
    hC_nn      := p.hC_nn
    hCfixed_nn := p.hCfixed_nn
    hL_nn      := p.hL_nn
    hR_nn      := p.hR_nn
    hPmin_nn   := p.hPmin_nn
    hPmax_nn   := p.hPmax_nn
    hPmax_ge   := p.hPmax_ge
    hPwmin_nn  := p.hPwmin_nn
    hPwmax_nn  := p.hPwmax_nn
    hPw_le     := p.hPw_le
    hRU_nn     := p.hRU_nn
    hRD_nn     := p.hRD_nn
    hSU_nn     := p.hSU_nn
    hSD_nn     := p.hSD_nn
    hU_pos     := p.hU_pos
    hD_pos     := p.hD_pos
    hMR_bin    := p.hMR_bin }

private def fwd (p : P11.a.Params) (V : P11.a.Vars p) : P11.f.Vars (paramMap p) :=
  { u     := V.u
    v     := V.v
    w     := V.w
    d_su  := V.d_su
    lam   := V.lam
    p     := V.p
    r     := V.r
    c_var  := V.c_var
    p_wind := V.p_wind
-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================
    P_bar  := fun _ _ => 0 }

private lemma fwd_feas (p : P11.a.Params) (V : P11.a.Vars p)
    (h : P11.a.Feasible p V) :
    P11.f.Feasible (paramMap p) (fwd p V) := by
  refine
    { hdemand     := h.hdemand
      hreserve    := h.hreserve
      htransition := h.htransition
      hmin_up     := h.hmin_up
      hmin_dn     := h.hmin_dn
      hv_decomp   := h.hv_decomp
      hlag        := h.hlag
      hmust_run   := h.hmust_run
      hcap_su     := h.hcap_su
      hcap_sd     := h.hcap_sd
      hramp_up    := h.hramp_up
      hramp_dn    := h.hramp_dn
      hp_eq       := h.hp_eq
      hc_eq       := h.hc_eq
      hlam_sum    := h.hlam_sum
      hu_bin      := h.hu_bin
      hv_bin      := h.hv_bin
      hw_bin      := h.hw_bin
      hd_bin      := h.hd_bin
      hlam_nn     := h.hlam_nn
      hlam_le     := h.hlam_le
      hp_nn       := h.hp_nn
      hr_nn       := h.hr_nn
      hcvar_nn    := h.hcvar_nn
      hpwind_lo   := h.hpwind_lo
      hpwind_hi   := h.hpwind_hi
      hec3a       := ?hec3a }
  case hec3a =>
    intro g t ht
    have ht_lt : t.val < p.nT := t.isLt
    -- RHS: P_min g * u_t + p_{t-1} + RU g + (P_max - P_min) * (1 - u_{t-1})
    -- All terms are nonnegative; LHS (P_bar) is 0.
    show (0 : ℝ) ≤
      p.P_min g * (V.u g t : ℝ) + V.p g ⟨t.val - 1, by omega⟩ + p.RU g +
        (p.P_max g - p.P_min g) * (1 - (V.u g ⟨t.val - 1, by omega⟩ : ℝ))
    have hPmin_nn := p.hPmin_nn g
    have hPmax_ge := p.hPmax_ge g
    have hRU_nn := p.hRU_nn g
    have hp_nn := h.hp_nn g ⟨t.val - 1, by omega⟩
    have hu_t : (0 : ℝ) ≤ (V.u g t : ℝ) := by
      rcases h.hu_bin g t with h0 | h1
      · rw [show (V.u g t : ℝ) = 0 by exact_mod_cast h0]
      · rw [show (V.u g t : ℝ) = 1 by exact_mod_cast h1]; norm_num
    have hu_prev : (V.u g ⟨t.val - 1, by omega⟩ : ℝ) = 0 ∨
        (V.u g ⟨t.val - 1, by omega⟩ : ℝ) = 1 := by
      rcases h.hu_bin g ⟨t.val - 1, by omega⟩ with h0 | h1
      · left; exact_mod_cast h0
      · right; exact_mod_cast h1
    have h1 : 0 ≤ p.P_min g * (V.u g t : ℝ) := mul_nonneg hPmin_nn hu_t
    have h2 : 0 ≤ (p.P_max g - p.P_min g) *
        (1 - (V.u g ⟨t.val - 1, by omega⟩ : ℝ)) := by
      apply mul_nonneg (by linarith)
      rcases hu_prev with hp0 | hp1
      · rw [hp0]; linarith
      · rw [hp1]; linarith
    linarith

private def bwd (p : P11.a.Params) (v : P11.f.Vars (paramMap p)) : P11.a.Vars p :=
-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================
  { u      := v.u
    v      := v.v
    w      := v.w
    d_su   := v.d_su
    lam    := v.lam
    p      := v.p
    r      := v.r
    c_var  := v.c_var
    p_wind := v.p_wind }

private lemma bwd_feas (p : P11.a.Params) (v : P11.f.Vars (paramMap p))
    (h : P11.f.Feasible (paramMap p) v) :
    P11.a.Feasible p (bwd p v) := by
  exact
    { hdemand     := h.hdemand
      hreserve    := h.hreserve
      htransition := h.htransition
      hmin_up     := h.hmin_up
      hmin_dn     := h.hmin_dn
      hv_decomp   := h.hv_decomp
      hlag        := h.hlag
      hmust_run   := h.hmust_run
      hcap_su     := h.hcap_su
      hcap_sd     := h.hcap_sd
      hramp_up    := h.hramp_up
      hramp_dn    := h.hramp_dn
      hp_eq       := h.hp_eq
      hc_eq       := h.hc_eq
      hlam_sum    := h.hlam_sum
      hu_bin      := h.hu_bin
      hv_bin      := h.hv_bin
      hw_bin      := h.hw_bin
      hd_bin      := h.hd_bin
      hlam_nn     := h.hlam_nn
      hlam_le     := h.hlam_le
      hp_nn       := h.hp_nn
      hr_nn       := h.hr_nn
      hcvar_nn    := h.hcvar_nn
      hpwind_lo   := h.hpwind_lo
      hpwind_hi   := h.hpwind_hi }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================
def aFReformulation : MILPReformulation P11.a.formulation P11.f.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  bwd_fwd     := fun _ _ _ => rfl
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P11
