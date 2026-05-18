import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import problems.p3.formulations.a.Formulation
import problems.p3.formulations.b.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P3.a.Params) : P3.b.Params :=
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

/-- **P3.a → P3.b**: Rename parameters and variable; feasibility is immediate. -/
private def fwd (p : P3.a.Params) (v : P3.a.Vars p) : P3.b.Vars (paramMap p) :=
  { n := v.NumBeakersUsed }

private lemma fwd_feas (p : P3.a.Params) (v : P3.a.Vars p)
    (h : P3.a.Feasible p v) :
    P3.b.Feasible (paramMap p) (fwd p v) :=
  { hliquid := h.hliquid
    hflour  := h.hflour
    hwaste  := h.hwaste
    hn_nn   := h.hNumBeakersUsed_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-- **P3.b → P3.a**: Rename variable back; feasibility is immediate. -/
private def bwd (p : P3.a.Params) (v : P3.b.Vars (paramMap p)) : P3.a.Vars p :=
  { NumBeakersUsed := v.n }

private lemma bwd_feas (p : P3.a.Params) (v : P3.b.Vars (paramMap p))
    (h : P3.b.Feasible (paramMap p) v) :
    P3.a.Feasible p (bwd p v) :=
  { hflour  := h.hflour
    hliquid := h.hliquid
    hwaste  := h.hwaste
    hNumBeakersUsed_nn := h.hn_nn }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aBReformulation : MILPReformulation P3.a.formulation P3.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj     := fun _ _ _ => rfl
  bwd_obj     := fun _ _ _ => rfl

end P3
