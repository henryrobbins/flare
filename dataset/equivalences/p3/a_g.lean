import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Data.Int.CharZero
import dataset.problems.p3.formulations.a.Formulation
import dataset.problems.p3.formulations.g.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap_ag (p : P3.a.Params) : P3.g.Params :=
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

-- n = 10 × count; dividing by 10 recovers the original count exactly
private def fwd_ag (_ : P3.a.Params) (v : P3.a.Vars) : P3.g.Vars :=
  { n := fun i => 10 * v.NumBeakersUsed i }

private lemma fwd_feas_ag (p : P3.a.Params) (v : P3.a.Vars)
    (h : P3.a.Feasible p v) :
    P3.g.Feasible (paramMap_ag p) (fwd_ag p v) := {
  hliquid := by
    simp only [paramMap_ag, fwd_ag]
    have heq : ∀ i : Fin p.NumBeakers,
        (↑(10 * v.NumBeakersUsed i) : ℝ) / 10 = ↑(v.NumBeakersUsed i) := fun i => by
      push_cast; ring
    simp_rw [heq]; exact h.hliquid
  hflour := by
    simp only [paramMap_ag, fwd_ag]
    have heq : ∀ i : Fin p.NumBeakers,
        (↑(10 * v.NumBeakersUsed i) : ℝ) / 10 = ↑(v.NumBeakersUsed i) := fun i => by
      push_cast; ring
    simp_rw [heq]; exact h.hflour
  hwaste := by
    simp only [paramMap_ag, fwd_ag]
    have heq : ∀ i : Fin p.NumBeakers,
        (↑(10 * v.NumBeakersUsed i) : ℝ) / 10 = ↑(v.NumBeakersUsed i) := fun i => by
      push_cast; ring
    simp_rw [heq]; exact h.hwaste
  hn_nn := fun i => by
    simp only [fwd_ag]
    exact mul_nonneg (by norm_num) (h.hnn i)
  hdiv := fun i => by simp only [fwd_ag]; exact dvd_mul_right 10 _ }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Recover count by dividing n by 10 (exact since hdiv guarantees 10 ∣ n i)
private def bwd_ag (_ : P3.a.Params) (v : P3.g.Vars) : P3.a.Vars :=
  { NumBeakersUsed := fun i => v.n i / 10 }

private lemma bwd_feas_ag (p : P3.a.Params) (v : P3.g.Vars)
    (h : P3.g.Feasible (paramMap_ag p) v) :
    P3.a.Feasible p (bwd_ag p v) := {
  hliquid := by
    have h' := h.hliquid
    simp only [paramMap_ag] at h'
    simp only [bwd_ag]
    have key : ∀ i : Fin p.NumBeakers,
        ((v.n ↑i / 10 : ℤ) : ℝ) = (v.n ↑i : ℝ) / 10 :=
      fun i => Int.cast_div_charZero (h.hdiv i)
    simp_rw [key]; exact h'
  hflour := by
    have h' := h.hflour
    simp only [paramMap_ag] at h'
    simp only [bwd_ag]
    have key : ∀ i : Fin p.NumBeakers,
        ((v.n ↑i / 10 : ℤ) : ℝ) = (v.n ↑i : ℝ) / 10 :=
      fun i => Int.cast_div_charZero (h.hdiv i)
    simp_rw [key]; exact h'
  hwaste := by
    have h' := h.hwaste
    simp only [paramMap_ag] at h'
    simp only [bwd_ag]
    have key : ∀ i : Fin p.NumBeakers,
        ((v.n ↑i / 10 : ℤ) : ℝ) = (v.n ↑i : ℝ) / 10 :=
      fun i => Int.cast_div_charZero (h.hdiv i)
    simp_rw [key]; exact h'
  hnn := fun i => by
    simp only [bwd_ag]
    exact Int.ediv_nonneg (h.hn_nn i) (by norm_num) }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def agEquiv : MILPEquiv P3.a.formulation P3.g.formulation where
  paramMap    := paramMap_ag
  fwd         := fwd_ag
  bwd         := bwd_ag
  fwd_feas    := fwd_feas_ag
  bwd_feas    := bwd_feas_ag
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ v _ => by
    simp only [P3.g.formulation, P3.a.formulation, P3.g.obj, P3.a.obj, fwd_ag, paramMap_ag, id]
    congr 1
    apply Finset.sum_congr rfl
    intro i _
    push_cast; ring
  bwd_obj     := fun _ _ h => by
    simp only [P3.g.formulation, P3.a.formulation, P3.g.obj, P3.a.obj, bwd_ag, paramMap_ag, id]
    congr 1
    apply Finset.sum_congr rfl
    intro i _
    congr 1
    exact (@Int.cast_div_charZero ℝ _ _ _ _ (h.hdiv i)).symm

end P3
