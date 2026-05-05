import Common
import dataset.problems.p5.formulations.a.Formulation
import dataset.problems.p5.formulations.d.Formulation

namespace P5

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P5.a.Params) : P5.d.Params :=
  { Z := p.WaterSubsoil
    B := p.WaterTopsoil
    D := p.MaxTotalBags
    P := p.MinTopsoilBags
    K := p.MaxTopsoilProportion
    hZ_nn := p.hWaterSubsoil_nn
    hB_nn := p.hWaterTopsoil_nn
    hD_nn := p.hMaxTotalBags_nn
    hP_nn := p.hMinTopsoilBags_nn
    hK_nn := p.hMaxTopsoilProportion_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- zed is set to the total water cost so it satisfies the auxiliary constraint
private def fwd (p : P5.a.Params) (v : P5.a.Vars p) : P5.d.Vars (paramMap p) :=
  { h   := v.SubsoilBags
    d   := v.TopsoilBags
    zed := p.WaterSubsoil * (v.SubsoilBags : ℝ) + p.WaterTopsoil * v.TopsoilBags }

private lemma fwd_feas (p : P5.a.Params) (v : P5.a.Vars p)
    (h : P5.a.Feasible p v) :
    P5.d.Feasible (paramMap p) (fwd p v) := by
  refine ⟨rfl, h.hprop, ?_, h.hmin_top, h.hss_nn, h.hts_nn⟩
  simp only [paramMap, fwd]; linarith [h.htotal]

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- zed is dropped; SubsoilBags and TopsoilBags project directly
private def bwd (p : P5.a.Params) (v : P5.d.Vars (paramMap p)) : P5.a.Vars p :=
  { SubsoilBags := v.h
    TopsoilBags := v.d }

private lemma bwd_feas (p : P5.a.Params) (v : P5.d.Vars (paramMap p))
    (h : P5.d.Feasible (paramMap p) v) :
    P5.a.Feasible p (bwd p v) := by
  have ht := h.htotal; simp only [paramMap] at ht
  refine ⟨?_, h.hmin_top, h.hprop, h.hh_nn, h.hd_nn⟩
  simp only [bwd]; linarith

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aDEquiv : MILPReformulation P5.a.formulation P5.d.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj     := fun _ _ h => h.hzed

end P5
