import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p3.formulations.a.Formulation
import dataset.problems.p3.formulations.f.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P3.a.Params) : P3.f.Params :=
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

/-- **P3.a → P3.f**: Count placed entirely in n1; n2 is zero. -/
private def fwd (p : P3.a.Params) (v : P3.a.Vars p) : P3.f.Vars (paramMap p) :=
  { n1 := v.NumBeakersUsed
    n2 := fun _ => 0 }

private lemma fwd_feas (p : P3.a.Params) (v : P3.a.Vars p)
    (h : P3.a.Feasible p v) :
    P3.f.Feasible (paramMap p) (fwd p v) := by
  refine ⟨?_, ?_, ?_, h.hNumBeakersUsed_nn, fun _ => le_refl 0⟩
  · simp only [paramMap, fwd, Int.cast_zero, add_zero]; exact h.hliquid
  · simp only [paramMap, fwd, Int.cast_zero, add_zero]; exact h.hflour
  · simp only [paramMap, fwd, Int.cast_zero, add_zero]; exact h.hwaste

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-- **P3.f → P3.a**: Both parts are summed to recover the beaker count. -/
private def bwd (p : P3.a.Params) (v : P3.f.Vars (paramMap p)) : P3.a.Vars p :=
  { NumBeakersUsed := fun i => v.n1 i + v.n2 i }

private lemma bwd_feas (p : P3.a.Params) (v : P3.f.Vars (paramMap p))
    (h : P3.f.Feasible (paramMap p) v) :
    P3.a.Feasible p (bwd p v) :=
  { hliquid := by
      have h' := h.hliquid; simp only [paramMap, bwd] at h' ⊢; push_cast at h' ⊢; exact h'
    hflour  := by
      have h' := h.hflour; simp only [paramMap, bwd] at h' ⊢; push_cast at h' ⊢; exact h'
    hwaste  := by
      have h' := h.hwaste; simp only [paramMap, bwd] at h' ⊢; push_cast at h' ⊢; exact h'
    hNumBeakersUsed_nn := fun i => by simp only [bwd]; linarith [h.hn1_nn i, h.hn2_nn i] }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aFReformulation : MILPReformulation P3.a.formulation P3.f.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj     := fun _ _ _ => by
    simp only [P3.f.formulation, P3.a.formulation, P3.f.obj, P3.a.obj, fwd, paramMap, id,
               Int.cast_zero, add_zero]
  bwd_obj     := fun _ _ _ => by
    simp only [P3.f.formulation, P3.a.formulation, P3.f.obj, P3.a.obj, bwd, paramMap, id]
    push_cast; ring

end P3
