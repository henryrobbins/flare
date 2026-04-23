import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Data.Int.CharZero
import dataset.problems.p2.formulations.a.Formulation
import dataset.problems.p2.formulations.g.Formulation

open BigOperators Finset

namespace P2

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P2.a.Params) : P2.g.Params :=
  { M := p.NumExperiments
    N := p.NumResources
    A := p.ElectricityProduced
    I := p.ResourceRequired
    Y := p.ResourceAvailable
    hM := p.hNumExperiments
    hN := p.hNumResources
    hA_nn := p.hElectricityProduced_nn
    hI_nn := p.hResourceRequired_nn
    hY_nn := p.hResourceAvailable_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- j = 10 × count; dividing by 10 recovers the original count exactly
private def fwd (_ : P2.a.Params) (v : P2.a.Vars) : P2.g.Vars :=
  { j := fun i => 10 * v.ConductExperiment i }

private lemma fwd_feas (p : P2.a.Params) (v : P2.a.Vars)
    (h : P2.a.Feasible p v) :
    P2.g.Feasible (paramMap p) (fwd p v) := {
  hres := fun k => by
    simp only [paramMap, fwd]
    have heq : ∀ i : Fin p.NumExperiments,
        (↑(10 * v.ConductExperiment i) : ℝ) / 10 = ↑(v.ConductExperiment i) := fun i => by
      push_cast; ring
    simp_rw [heq]
    exact h.hres k
  hdiv := fun i => by
    simp only [fwd]
    exact dvd_mul_right 10 _
  hj_nn := fun i => by
    simp only [fwd]
    exact mul_nonneg (by norm_num) (h.hConductExperiment_nn i) }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Recover count by dividing j by 10 (exact since hdiv guarantees 10 ∣ j i)
private def bwd (_ : P2.a.Params) (v : P2.g.Vars) : P2.a.Vars :=
  { ConductExperiment := fun i => v.j i / 10 }

private lemma bwd_feas (p : P2.a.Params) (v : P2.g.Vars)
    (h : P2.g.Feasible (paramMap p) v) :
    P2.a.Feasible p (bwd p v) := {
  hres := fun k => by
    have h' := h.hres k
    simp only [paramMap] at h'
    simp only [bwd]
    have key : ∀ i : Fin p.NumExperiments,
        ((v.j ↑i / 10 : ℤ) : ℝ) = (v.j ↑i : ℝ) / 10 :=
      fun i => Int.cast_div_charZero (h.hdiv i)
    simp_rw [key]
    exact h'
  hConductExperiment_nn := fun i => by
    simp only [bwd]
    exact Int.ediv_nonneg (h.hj_nn i) (by norm_num) }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

noncomputable def aGEquiv : MILPEquiv P2.a.formulation P2.g.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ v _ => by
    simp only [P2.g.formulation, P2.a.formulation, P2.g.obj, P2.a.obj, fwd, paramMap, id]
    congr 1
    apply Finset.sum_congr rfl
    intro i _
    push_cast; ring
  bwd_obj     := fun _ _ h => by
    simp only [P2.g.formulation, P2.a.formulation, P2.g.obj, P2.a.obj, bwd, paramMap, id]
    congr 1
    apply Finset.sum_congr rfl
    intro i _
    congr 1
    exact (@Int.cast_div_charZero ℝ _ _ _ _ (h.hdiv i)).symm

end P2
