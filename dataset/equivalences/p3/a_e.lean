import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p3.formulations.a.Formulation
import dataset.problems.p3.formulations.e.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P3.a.Params) : P3.e.Params :=
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

/-- **P3.a → P3.e**: Each slack absorbs the gap between resource usage and its bound. -/
private def fwd (p : P3.a.Params) (v : P3.a.Vars) : P3.e.Vars :=
  { n       := v.NumBeakersUsed
    slack_0 := p.SpecialLiquidAvailable -
               ∑ i : Fin p.NumBeakers, p.SpecialLiquidUsagePerBeaker i * (v.NumBeakersUsed i : ℝ)
    slack_1 := p.FlourAvailable -
               ∑ i : Fin p.NumBeakers, p.FlourUsagePerBeaker i * (v.NumBeakersUsed i : ℝ)
    slack_2 := p.MaxWasteAllowed -
               ∑ i : Fin p.NumBeakers, p.WasteProducedPerBeaker i * (v.NumBeakersUsed i : ℝ) }

private lemma fwd_feas (p : P3.a.Params) (v : P3.a.Vars)
    (h : P3.a.Feasible p v) :
    P3.e.Feasible (paramMap p) (fwd p v) :=
  { hliquid    := by simp only [paramMap, fwd]; ring
    hflour     := by simp only [paramMap, fwd]; ring
    hwaste     := by simp only [paramMap, fwd]; ring
    hn_nn      := h.hNumBeakersUsed_nn
    hslack0_nn := by simp only [fwd]; linarith [h.hliquid]
    hslack1_nn := by simp only [fwd]; linarith [h.hflour]
    hslack2_nn := by simp only [fwd]; linarith [h.hwaste] }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-- **P3.e → P3.a**: Drop slacks; beaker counts project directly. -/
private def bwd (_ : P3.a.Params) (v : P3.e.Vars) : P3.a.Vars :=
  { NumBeakersUsed := v.n }

private lemma bwd_feas (p : P3.a.Params) (v : P3.e.Vars)
    (h : P3.e.Feasible (paramMap p) v) :
    P3.a.Feasible p (bwd p v) :=
  { hliquid := by
      have h' := h.hliquid
      simp only [paramMap, bwd] at h' ⊢
      linarith [h.hslack0_nn]
    hflour  := by
      have h' := h.hflour
      simp only [paramMap, bwd] at h' ⊢
      linarith [h.hslack1_nn]
    hwaste  := by
      have h' := h.hwaste
      simp only [paramMap, bwd] at h' ⊢
      linarith [h.hslack2_nn]
    hNumBeakersUsed_nn := h.hn_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aEEquiv : MILPEquiv P3.a.formulation P3.e.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ _ _ => rfl
  bwd_obj     := fun _ _ _ => rfl

end P3
