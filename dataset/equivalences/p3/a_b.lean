import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p3.formulations.a.Formulation
import dataset.problems.p3.formulations.b.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap_ab (p : P3.a.Params) : P3.b.Params :=
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

private def fwd_ab (_ : P3.a.Params) (v : P3.a.Vars) : P3.b.Vars :=
  { n := v.NumBeakersUsed }

private lemma fwd_feas_ab (p : P3.a.Params) (v : P3.a.Vars)
    (h : P3.a.Feasible p v) :
    P3.b.Feasible (paramMap_ab p) (fwd_ab p v) :=
  { hliquid := h.hliquid
    hflour  := h.hflour
    hwaste  := h.hwaste
    hn_nn   := h.hnn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd_ab (_ : P3.a.Params) (v : P3.b.Vars) : P3.a.Vars :=
  { NumBeakersUsed := v.n }

private lemma bwd_feas_ab (p : P3.a.Params) (v : P3.b.Vars)
    (h : P3.b.Feasible (paramMap_ab p) v) :
    P3.a.Feasible p (bwd_ab p v) :=
  { hflour  := h.hflour
    hliquid := h.hliquid
    hwaste  := h.hwaste
    hnn     := h.hn_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def abEquiv : MILPEquiv P3.a.formulation P3.b.formulation where
  paramMap    := paramMap_ab
  fwd         := fwd_ab
  bwd         := bwd_ab
  fwd_feas    := fwd_feas_ab
  bwd_feas    := bwd_feas_ab
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ _ _ => rfl
  bwd_obj     := fun _ _ _ => rfl

end P3
