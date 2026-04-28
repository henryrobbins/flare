import Common
import dataset.problems.p11.formulations.a.Formulation
import dataset.problems.p11.formulations.b.Formulation
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

private def paramMap (p : P11.a.Params) : P11.b.Params :=
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

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

/--
**P11.a → P11.b**: identity on all variables; the new EC1 indicator `b g t`
is set to `v.v g t * v.w g (t+1)`, which equals 1 iff both `v` and the next
period's `w` are 1 (given the binary constraints).
-/
private def fwd (_ : P11.a.Params) (v : P11.a.Vars) : P11.b.Vars :=
  { u     := v.u
    v     := v.v
    w     := v.w
    d_su  := v.d_su
    lam   := v.lam
    p     := v.p
    r     := v.r
    c_var  := v.c_var
    p_wind := v.p_wind
    b      := fun g t => v.v g t * v.w g (t + 1) }

private lemma fwd_feas (p : P11.a.Params) (v : P11.a.Vars)
    (h : P11.a.Feasible p v) :
    P11.b.Feasible (paramMap p) (fwd p v) := by
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
      hb_bin      := ?hb_bin
      hlam_nn     := h.hlam_nn
      hlam_le     := h.hlam_le
      hp_nn       := h.hp_nn
      hr_nn       := h.hr_nn
      hcvar_nn    := h.hcvar_nn
      hpwind_lo   := h.hpwind_lo
      hpwind_hi   := h.hpwind_hi
      hec1_ub_v   := ?hec1_ub_v
      hec1_ub_w   := ?hec1_ub_w
      hec1_lb     := ?hec1_lb }
  case hb_bin =>
    intro g t ht
    show v.v g.val t.val * v.w g.val (t.val + 1) = 0 ∨
         v.v g.val t.val * v.w g.val (t.val + 1) = 1
    rcases h.hv_bin g t with hv0 | hv1
    · left; rw [hv0]; ring
    · rcases h.hw_bin g ⟨t.val + 1, ht⟩ with hw0 | hw1
      · left
        have : v.w g.val (t.val + 1) = 0 := hw0
        rw [this]; ring
      · right
        have hw1' : v.w g.val (t.val + 1) = 1 := hw1
        rw [hv1, hw1']; ring
  case hec1_ub_v =>
    intro g t ht
    show v.v g.val t.val * v.w g.val (t.val + 1) ≤ v.v g.val t.val
    rcases h.hv_bin g t with hv0 | hv1
    · rw [hv0]; simp
    · rcases h.hw_bin g ⟨t.val + 1, ht⟩ with hw0 | hw1
      · have hw0' : v.w g.val (t.val + 1) = 0 := hw0
        rw [hv1, hw0']; simp
      · have hw1' : v.w g.val (t.val + 1) = 1 := hw1
        rw [hv1, hw1']; norm_num
  case hec1_ub_w =>
    intro g t ht
    show v.v g.val t.val * v.w g.val (t.val + 1) ≤ v.w g.val (t.val + 1)
    rcases h.hw_bin g ⟨t.val + 1, ht⟩ with hw0 | hw1
    · have hw0' : v.w g.val (t.val + 1) = 0 := hw0
      rw [hw0']; simp
    · have hw1' : v.w g.val (t.val + 1) = 1 := hw1
      rw [hw1']
      rcases h.hv_bin g t with hv0 | hv1
      · rw [hv0]; simp
      · rw [hv1]; norm_num
  case hec1_lb =>
    intro g t ht
    show v.v g.val t.val + v.w g.val (t.val + 1) - 1 ≤
         v.v g.val t.val * v.w g.val (t.val + 1)
    rcases h.hv_bin g t with hv0 | hv1
    · rw [hv0]
      rcases h.hw_bin g ⟨t.val + 1, ht⟩ with hw0 | hw1
      · have : v.w g.val (t.val + 1) = 0 := hw0
        rw [this]; omega
      · have : v.w g.val (t.val + 1) = 1 := hw1
        rw [this]; omega
    · rw [hv1]
      rcases h.hw_bin g ⟨t.val + 1, ht⟩ with hw0 | hw1
      · have : v.w g.val (t.val + 1) = 0 := hw0
        rw [this]; omega
      · have : v.w g.val (t.val + 1) = 1 := hw1
        rw [this]; omega

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**P11.b → P11.a**: drop the `b` auxiliary variable; all other variables are
carried over unchanged.
-/
private def bwd (_ : P11.a.Params) (v : P11.b.Vars) : P11.a.Vars :=
  { u      := v.u
    v      := v.v
    w      := v.w
    d_su   := v.d_su
    lam    := v.lam
    p      := v.p
    r      := v.r
    c_var  := v.c_var
    p_wind := v.p_wind }

private lemma bwd_feas (p : P11.a.Params) (v : P11.b.Vars)
    (h : P11.b.Feasible (paramMap p) v) :
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

def aBEquiv : MILPEquiv P11.a.formulation P11.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := Or.inl strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P11
