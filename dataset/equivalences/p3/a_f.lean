import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p3.formulations.a.Formulation
import dataset.problems.p3.formulations.f.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap_af (p : P3.a.Params) : P3.f.Params :=
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

-- Count placed entirely in n1; n2 is zero
private def fwd_af (_ : P3.a.Params) (v : P3.a.Vars) : P3.f.Vars :=
  { n1 := v.NumBeakersUsed
    n2 := fun _ => 0 }

private lemma fwd_feas_af (p : P3.a.Params) (v : P3.a.Vars)
    (h : P3.a.Feasible p v) :
    P3.f.Feasible (paramMap_af p) (fwd_af p v) := by
  refine ⟨?_, ?_, ?_, h.hnn, fun _ => le_refl 0⟩
  · simp only [paramMap_af, fwd_af, Int.cast_zero, add_zero]; exact h.hliquid
  · simp only [paramMap_af, fwd_af, Int.cast_zero, add_zero]; exact h.hflour
  · simp only [paramMap_af, fwd_af, Int.cast_zero, add_zero]; exact h.hwaste

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Both parts are summed to recover the beaker count
private def bwd_af (_ : P3.a.Params) (v : P3.f.Vars) : P3.a.Vars :=
  { NumBeakersUsed := fun i => v.n1 i + v.n2 i }

private lemma bwd_feas_af (p : P3.a.Params) (v : P3.f.Vars)
    (h : P3.f.Feasible (paramMap_af p) v) :
    P3.a.Feasible p (bwd_af p v) :=
  { hliquid := by
      have h' := h.hliquid; simp only [paramMap_af, bwd_af] at h' ⊢; push_cast at h' ⊢; exact h'
    hflour  := by
      have h' := h.hflour; simp only [paramMap_af, bwd_af] at h' ⊢; push_cast at h' ⊢; exact h'
    hwaste  := by
      have h' := h.hwaste; simp only [paramMap_af, bwd_af] at h' ⊢; push_cast at h' ⊢; exact h'
    hnn     := fun i => by simp only [bwd_af]; linarith [h.hn1_nn i, h.hn2_nn i] }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def afEquiv : MILPEquiv P3.a.formulation P3.f.formulation where
  paramMap    := paramMap_af
  fwd         := fwd_af
  bwd         := bwd_af
  fwd_feas    := fwd_feas_af
  bwd_feas    := bwd_feas_af
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ _ _ => by
    simp only [P3.f.formulation, P3.a.formulation, P3.f.obj, P3.a.obj, fwd_af, paramMap_af, id,
               Int.cast_zero, add_zero]
  bwd_obj     := fun _ _ _ => by
    simp only [P3.f.formulation, P3.a.formulation, P3.f.obj, P3.a.obj, bwd_af, paramMap_af, id]
    push_cast; ring

end P3
