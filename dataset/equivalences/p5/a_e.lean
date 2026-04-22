import Common
import dataset.problems.p5.formulations.a.Formulation
import dataset.problems.p5.formulations.e.Formulation

namespace P5

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P5.a.Params) : P5.e.Params :=
  { Z := p.WaterSubsoil
    B := p.WaterTopsoil
    D := p.MaxTotalBags
    P := p.MinTopsoilBags
    K := p.MaxTopsoilProportion }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- Slacks absorb the surplus of each inequality constraint in Fa
private def fwd (p : P5.a.Params) (v : P5.a.Vars) : P5.e.Vars :=
  { h       := v.SubsoilBags
    d       := v.TopsoilBags
    slack_0 := p.MaxTopsoilProportion * (v.TopsoilBags + v.SubsoilBags) - v.TopsoilBags
    slack_1 := p.MaxTotalBags - v.SubsoilBags - v.TopsoilBags
    slack_2 := v.TopsoilBags - p.MinTopsoilBags }

private lemma fwd_feas (p : P5.a.Params) (v : P5.a.Vars)
    (h : P5.a.Feasible p v) :
    P5.e.Feasible (paramMap p) (fwd p v) := by
  simp only [paramMap, fwd]
  refine ⟨by ring, by ring, by ring, h.hss_nn, h.hts_nn,
    by linarith [h.hprop], by linarith [h.htotal], by linarith [h.hmin_top]⟩

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Slack variables are dropped; SubsoilBags and TopsoilBags project directly
private def bwd (_ : P5.a.Params) (v : P5.e.Vars) : P5.a.Vars :=
  { SubsoilBags := v.h
    TopsoilBags := v.d }

private lemma bwd_feas (p : P5.a.Params) (v : P5.e.Vars)
    (h : P5.e.Feasible (paramMap p) v) :
    P5.a.Feasible p (bwd p v) := by
  have hprop  := h.hprop;   simp only [paramMap] at hprop
  have htotal := h.htotal;  simp only [paramMap] at htotal
  have hmin   := h.hmin_top; simp only [paramMap] at hmin
  simp only [bwd]
  refine ⟨by linarith [h.hslack1_nn], by linarith [h.hslack2_nn],
          by linarith [h.hslack0_nn], h.hh_nn, h.hd_nn⟩

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFeEquiv : MILPEquiv P5.a.formulation P5.e.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P5
