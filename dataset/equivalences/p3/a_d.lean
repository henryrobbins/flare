import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p3.formulations.a.Formulation
import dataset.problems.p3.formulations.d.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P3.a.Params) : P3.d.Params :=
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

/-- **P3.a → P3.d**: Set zed to total slime so it satisfies the auxiliary equality. -/
private def fwd (p : P3.a.Params) (v : P3.a.Vars p) : P3.d.Vars (paramMap p) :=
  { n   := v.NumBeakersUsed
    zed := ∑ i : Fin p.NumBeakers, p.SlimeProducedPerBeaker i * (v.NumBeakersUsed i : ℝ) }

private lemma fwd_feas (p : P3.a.Params) (v : P3.a.Vars p)
    (h : P3.a.Feasible p v) :
    P3.d.Feasible (paramMap p) (fwd p v) :=
  { hzed    := rfl
    hliquid := h.hliquid
    hflour  := h.hflour
    hwaste  := h.hwaste
    hn_nn   := h.hNumBeakersUsed_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-- **P3.d → P3.a**: Drop zed; beaker counts project directly. -/
private def bwd (p : P3.a.Params) (v : P3.d.Vars (paramMap p)) : P3.a.Vars p :=
  { NumBeakersUsed := v.n }

private lemma bwd_feas (p : P3.a.Params) (v : P3.d.Vars (paramMap p))
    (h : P3.d.Feasible (paramMap p) v) :
    P3.a.Feasible p (bwd p v) :=
  { hflour  := h.hflour
    hliquid := h.hliquid
    hwaste  := h.hwaste
    hNumBeakersUsed_nn := h.hn_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aDEquiv : MILPReformulation P3.a.formulation P3.d.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj     := fun _ _ _ => rfl
  bwd_obj     := fun _ _ h => by
    have hzed := h.hzed
    simp only [P3.d.formulation, P3.a.formulation, P3.d.obj, P3.a.obj, bwd, paramMap, id] at *
    linarith

end P3
