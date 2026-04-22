import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p3.formulations.a.Formulation
import dataset.problems.p3.formulations.e.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap_ae (p : P3.a.Params) : P3.e.Params :=
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

-- Each slack absorbs the gap between resource usage and its bound
private def fwd_ae (p : P3.a.Params) (v : P3.a.Vars) : P3.e.Vars :=
  { n       := v.NumBeakersUsed
    slack_0 := p.SpecialLiquidAvailable -
               ∑ i : Fin p.NumBeakers, p.SpecialLiquidUsagePerBeaker i * v.NumBeakersUsed i
    slack_1 := p.FlourAvailable -
               ∑ i : Fin p.NumBeakers, p.FlourUsagePerBeaker i * v.NumBeakersUsed i
    slack_2 := p.MaxWasteAllowed -
               ∑ i : Fin p.NumBeakers, p.WasteProducedPerBeaker i * v.NumBeakersUsed i }

private lemma fwd_feas_ae (p : P3.a.Params) (v : P3.a.Vars)
    (h : P3.a.Feasible p v) :
    P3.e.Feasible (paramMap_ae p) (fwd_ae p v) :=
  { hliquid    := by simp only [paramMap_ae, fwd_ae]; ring
    hflour     := by simp only [paramMap_ae, fwd_ae]; ring
    hwaste     := by simp only [paramMap_ae, fwd_ae]; ring
    hn_nn      := h.hnn
    hslack0_nn := by simp only [fwd_ae]; linarith [h.hliquid]
    hslack1_nn := by simp only [fwd_ae]; linarith [h.hflour]
    hslack2_nn := by simp only [fwd_ae]; linarith [h.hwaste] }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Slacks are dropped; beaker counts project directly
private def bwd_ae (_ : P3.a.Params) (v : P3.e.Vars) : P3.a.Vars :=
  { NumBeakersUsed := v.n }

private lemma bwd_feas_ae (p : P3.a.Params) (v : P3.e.Vars)
    (h : P3.e.Feasible (paramMap_ae p) v) :
    P3.a.Feasible p (bwd_ae p v) :=
  { hliquid := by
      have h' := h.hliquid
      simp only [paramMap_ae, bwd_ae] at h' ⊢
      linarith [h.hslack0_nn]
    hflour  := by
      have h' := h.hflour
      simp only [paramMap_ae, bwd_ae] at h' ⊢
      linarith [h.hslack1_nn]
    hwaste  := by
      have h' := h.hwaste
      simp only [paramMap_ae, bwd_ae] at h' ⊢
      linarith [h.hslack2_nn]
    hnn     := h.hn_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aeEquiv : MILPEquiv P3.a.formulation P3.e.formulation where
  paramMap    := paramMap_ae
  fwd         := fwd_ae
  bwd         := bwd_ae
  fwd_feas    := fwd_feas_ae
  bwd_feas    := bwd_feas_ae
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ _ _ => rfl
  bwd_obj     := fun _ _ _ => rfl

end P3
