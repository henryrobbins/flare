import Common
import dataset.problems.p5.formulations.a.Formulation
import dataset.problems.p5.formulations.f.Formulation

namespace P5

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P5.a.Params) : P5.f.Params :=
  { Z := p.WaterSubsoil
    B := p.WaterTopsoil
    D := p.MaxTotalBags
    P := p.MinTopsoilBags
    K := p.MaxTopsoilProportion }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- Each bag count is placed entirely in the first part; second part is zero
private def fwd (_ : P5.a.Params) (v : P5.a.Vars) : P5.f.Vars :=
  { d1 := v.TopsoilBags
    d2 := 0
    h1 := v.SubsoilBags
    h2 := 0 }

private lemma fwd_feas (p : P5.a.Params) (v : P5.a.Vars)
    (h : P5.a.Feasible p v) :
    P5.f.Feasible (paramMap p) (fwd p v) := by
  refine ⟨?_, ?_, ?_, h.hts_nn, le_refl 0, h.hss_nn, le_refl 0⟩
  · simp only [fwd, paramMap, Int.cast_zero, add_zero]; exact h.hprop
  · simp only [fwd, paramMap, Int.cast_zero, add_zero]; exact h.htotal
  · simp only [fwd, paramMap, Int.cast_zero, add_zero]; exact h.hmin_top

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Both parts are summed to recover the original bag counts
private def bwd (_ : P5.a.Params) (v : P5.f.Vars) : P5.a.Vars :=
  { SubsoilBags := v.h1 + v.h2
    TopsoilBags := v.d1 + v.d2 }

private lemma bwd_feas (p : P5.a.Params) (v : P5.f.Vars)
    (h : P5.f.Feasible (paramMap p) v) :
    P5.a.Feasible p (bwd p v) := by
  simp only [bwd]
  refine ⟨?_, ?_, ?_, by linarith [h.hh1_nn, h.hh2_nn], by linarith [h.hd1_nn, h.hd2_nn]⟩
  · have hp := h.htotal; simp only [paramMap] at hp; push_cast; linarith
  · have hp := h.hmin_top; simp only [paramMap] at hp; push_cast; linarith
  · have hp := h.hprop; simp only [paramMap] at hp; push_cast; linarith

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFfEquiv : MILPEquiv P5.a.formulation P5.f.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj := fun p v _ => by
    show P5.f.obj (paramMap p) (fwd p v) = P5.a.obj p v
    simp only [P5.f.obj, P5.a.obj, paramMap, fwd, Int.cast_zero, add_zero]
  bwd_obj := fun p v _ => by
    show P5.f.obj (paramMap p) v = P5.a.obj p (bwd p v)
    simp only [P5.f.obj, P5.a.obj, paramMap, bwd]
    push_cast; ring

end P5
