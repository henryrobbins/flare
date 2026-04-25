import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Data.Int.CharZero
import dataset.problems.p3.formulations.a.Formulation
import dataset.problems.p3.formulations.g.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

private lemma scaled_cast_div (k : ℤ) : (↑(10 * k) : ℝ) / 10 = ↑k := by push_cast; ring

private lemma cast_div_exact (k : ℤ) (h : 10 ∣ k) : ((k / 10 : ℤ) : ℝ) = (k : ℝ) / 10 :=
  Int.cast_div_charZero h

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P3.a.Params) : P3.g.Params :=
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

/-- **P3.a → P3.g**: Scale each beaker count by 10; dividing by 10 recovers the original count. -/
private def fwd (_ : P3.a.Params) (v : P3.a.Vars) : P3.g.Vars :=
  { n := fun i => 10 * v.NumBeakersUsed i }

private lemma fwd_feas (p : P3.a.Params) (v : P3.a.Vars)
    (h : P3.a.Feasible p v) :
    P3.g.Feasible (paramMap p) (fwd p v) := {
  hliquid := by
    simp only [paramMap, fwd]
    simp_rw [scaled_cast_div]; exact h.hliquid
  hflour := by
    simp only [paramMap, fwd]
    simp_rw [scaled_cast_div]; exact h.hflour
  hwaste := by
    simp only [paramMap, fwd]
    simp_rw [scaled_cast_div]; exact h.hwaste
  hn_nn := fun i => by
    simp only [fwd]
    exact mul_nonneg (by norm_num) (h.hNumBeakersUsed_nn i)
  hdiv := fun i => by simp only [fwd]; exact dvd_mul_right 10 _ }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-- **P3.g → P3.a**: Recover count by dividing n by 10 (exact since hdiv guarantees 10 ∣ n i). -/
private def bwd (_ : P3.a.Params) (v : P3.g.Vars) : P3.a.Vars :=
  { NumBeakersUsed := fun i => v.n i / 10 }

private lemma bwd_feas (p : P3.a.Params) (v : P3.g.Vars)
    (h : P3.g.Feasible (paramMap p) v) :
    P3.a.Feasible p (bwd p v) := {
  hliquid := by
    have h' := h.hliquid
    simp only [paramMap] at h'
    simp only [bwd]
    simp_rw [cast_div_exact _ (h.hdiv _)]; exact h'
  hflour := by
    have h' := h.hflour
    simp only [paramMap] at h'
    simp only [bwd]
    simp_rw [cast_div_exact _ (h.hdiv _)]; exact h'
  hwaste := by
    have h' := h.hwaste
    simp only [paramMap] at h'
    simp only [bwd]
    simp_rw [cast_div_exact _ (h.hdiv _)]; exact h'
  hNumBeakersUsed_nn := fun i => by
    simp only [bwd]
    exact Int.ediv_nonneg (h.hn_nn i) (by norm_num) }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

noncomputable def aGEquiv : MILPEquiv P3.a.formulation P3.g.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := Or.inl strictMono_id
  fwd_obj     := fun _ v _ => by
    simp only [P3.g.formulation, P3.a.formulation, P3.g.obj, P3.a.obj, fwd, paramMap, id]
    congr 1
    apply Finset.sum_congr rfl
    intro i _
    push_cast; ring
  bwd_obj     := fun _ _ h => by
    simp only [P3.g.formulation, P3.a.formulation, P3.g.obj, P3.a.obj, bwd, paramMap, id]
    congr 1
    apply Finset.sum_congr rfl
    intro i _
    congr 1
    exact (cast_div_exact _ (h.hdiv i)).symm

end P3
