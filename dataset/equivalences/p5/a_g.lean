import Common
import dataset.problems.p5.formulations.a.Formulation
import dataset.problems.p5.formulations.g.Formulation

namespace P5

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P5.a.Params) : P5.g.Params :=
  { Z := p.WaterSubsoil
    B := p.WaterTopsoil
    D := p.MaxTotalBags
    P := p.MinTopsoilBags
    K := p.MaxTopsoilProportion }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (_ : P5.a.Params) (v : P5.a.Vars) : P5.g.Vars :=
  { h := v.SubsoilBags
    d := v.TopsoilBags }

private lemma fwd_feas (p : P5.a.Params) (v : P5.a.Vars)
    (h : P5.a.Feasible p v) :
    P5.g.Feasible (paramMap p) (fwd p v) := by
  refine ⟨h.hprop, ?_, h.hmin_top, h.hss_nn, h.hts_nn⟩
  simp only [paramMap, fwd]; linarith [h.htotal]

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (_ : P5.a.Params) (v : P5.g.Vars) : P5.a.Vars :=
  { SubsoilBags := v.h
    TopsoilBags := v.d }

private lemma bwd_feas (p : P5.a.Params) (v : P5.g.Vars)
    (h : P5.g.Feasible (paramMap p) v) :
    P5.a.Feasible p (bwd p v) := by
  have ht := h.htotal; simp only [paramMap] at ht
  refine ⟨?_, h.hmin_top, h.hprop, h.hh_nn, h.hd_nn⟩
  simp only [bwd]; linarith

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFgEquiv : MILPEquiv P5.a.formulation P5.g.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := fun x => 2 * x
  objMap_mono := fun _ _ h => by linarith
  fwd_obj := fun _ v _ => by
    simp only [P5.g.formulation, P5.g.obj, P5.a.formulation, P5.a.obj, fwd, paramMap]
  bwd_obj := fun _ v _ => by
    simp only [P5.g.formulation, P5.g.obj, P5.a.formulation, P5.a.obj, bwd, paramMap]

end P5
