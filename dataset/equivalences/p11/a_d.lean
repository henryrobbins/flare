import Common
import dataset.problems.p11.formulations.a.Formulation
import dataset.problems.p11.formulations.d.Formulation
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

private def paramMap (p : P11.a.Params) : P11.d.Params :=
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
    hMR_nn     := p.hMR_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

/--
**P11.a → P11.d**: identity on all variables; `P_bar` is set to `0`, which
trivially satisfies the EC2b upper bound since the RHS is nonnegative
(combining `hcap_sd`, `hPmin_nn`, and binary `u`).
-/
private def fwd (_ : P11.a.Params) (v : P11.a.Vars) : P11.d.Vars :=
  { u      := v.u
    v      := v.v
    w      := v.w
    d_su   := v.d_su
    lam    := v.lam
    p      := v.p
    r      := v.r
    c_var  := v.c_var
    p_wind := v.p_wind
    P_bar  := fun _ _ => 0 }

private lemma fwd_feas (p : P11.a.Params) (v : P11.a.Vars)
    (h : P11.a.Feasible p v) :
    P11.d.Feasible (paramMap p) (fwd p v) := by
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
      hec2b       := ?hec2b }
  case hec2b =>
    intro g t ht
    show (0 : ℝ) ≤
      p.P_max g * (v.u g.val t.val : ℝ) - max (p.P_max g - p.SD g) 0 * (v.w g.val (t.val + 1) : ℝ)
    have hcap := h.hcap_sd g t ht
    have hpnn := h.hp_nn g t
    have hrnn := h.hr_nn g t
    have hPmin := p.hPmin_nn g
    have hu_nn : (0 : ℝ) ≤ (v.u g.val t.val : ℝ) := by
      rcases h.hu_bin g t with hu0 | hu1
      · rw [hu0]; simp
      · rw [hu1]; norm_num
    have h1 : (0 : ℝ) ≤
        (p.P_max g - p.P_min g) * (v.u g.val t.val : ℝ) -
          max (p.P_max g - p.SD g) 0 * (v.w g.val (t.val + 1) : ℝ) := by
      linarith
    have h2 : (0 : ℝ) ≤ p.P_min g * (v.u g.val t.val : ℝ) :=
      mul_nonneg hPmin hu_nn
    linarith [h1, h2]

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**P11.d → P11.a**: drop the `P_bar` auxiliary variable; all other variables are
carried over unchanged.
-/
private def bwd (_ : P11.a.Params) (v : P11.d.Vars) : P11.a.Vars :=
  { u      := v.u
    v      := v.v
    w      := v.w
    d_su   := v.d_su
    lam    := v.lam
    p      := v.p
    r      := v.r
    c_var  := v.c_var
    p_wind := v.p_wind }

private lemma bwd_feas (p : P11.a.Params) (v : P11.d.Vars)
    (h : P11.d.Feasible (paramMap p) v) :
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
-- § Equivalence Structure
-- ============================================================================

def aDEquiv : MILPEquiv P11.a.formulation P11.d.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P11
