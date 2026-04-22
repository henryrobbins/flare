import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p3.formulations.a.Formulation
import dataset.problems.p3.formulations.d.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap_ad (p : P3.a.Params) : P3.d.Params :=
  { N     := p.NumBeakers
    C     := p.WasteProducedPerBeaker
    E     := p.MaxWasteAllowed
    X     := p.SlimeProducedPerBeaker
    T     := p.FlourUsagePerBeaker
    D     := p.FlourAvailable
    V     := p.SpecialLiquidUsagePerBeaker
    Z     := p.SpecialLiquidAvailable
    hN    := p.hNumBeakers
    hC_nn := p.hWaste_nn
    hX_nn := p.hSlime_nn
    hT_nn := p.hFlour_nn
    hV_nn := p.hLiquid_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- zed is set to total slime so it satisfies the auxiliary equality
private def fwd_ad (p : P3.a.Params) (v : P3.a.Vars) : P3.d.Vars :=
  { n   := v.NumBeakersUsed
    zed := ∑ i : Fin p.NumBeakers, p.SlimeProducedPerBeaker i * v.NumBeakersUsed i }

private lemma fwd_feas_ad (p : P3.a.Params) (v : P3.a.Vars)
    (h : P3.a.Feasible p v) :
    P3.d.Feasible (paramMap_ad p) (fwd_ad p v) :=
  { hzed    := rfl
    hliquid := h.hliquid
    hflour  := h.hflour
    hwaste  := h.hwaste
    hn_nn   := h.hnn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- zed is dropped; beaker counts project directly
private def bwd_ad (_ : P3.a.Params) (v : P3.d.Vars) : P3.a.Vars :=
  { NumBeakersUsed := v.n }

private lemma bwd_feas_ad (p : P3.a.Params) (v : P3.d.Vars)
    (h : P3.d.Feasible (paramMap_ad p) v) :
    P3.a.Feasible p (bwd_ad p v) :=
  { hflour  := h.hflour
    hliquid := h.hliquid
    hwaste  := h.hwaste
    hnn     := h.hn_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def adEquiv : MILPEquiv P3.a.formulation P3.d.formulation where
  paramMap    := paramMap_ad
  fwd         := fwd_ad
  bwd         := bwd_ad
  fwd_feas    := fwd_feas_ad
  bwd_feas    := bwd_feas_ad
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ _ _ => rfl
  bwd_obj     := fun _ _ h => by
    have hzed := h.hzed
    simp only [P3.d.formulation, P3.a.formulation, P3.d.obj, P3.a.obj, bwd_ad, paramMap_ad, id] at *
    linarith

end P3
