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

private def paramMap_ag (p : P2.a.Params) : P2.g.Params :=
  { m     := p.NumExperiments
    n     := p.NumResources
    A     := p.ElectricityProduced
    I     := p.ResourceRequired
    Y     := p.ResourceAvailable
    hm    := p.hNumExperiments
    hn    := p.hNumResources
    hA_nn := p.hElectricityProduced_nn
    hI_nn := p.hResourceRequired_nn
    hY_nn := p.hResourceAvailable_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- j = 10 × count; dividing by 10 recovers the original count exactly
private def fwd_ag (_ : P2.a.Params) (v : P2.a.Vars) : P2.g.Vars :=
  { j := fun i => 10 * v.ConductExperiment i }

private lemma fwd_feas_ag (p : P2.a.Params) (v : P2.a.Vars)
    (h : P2.a.Feasible p v) :
    P2.g.Feasible (paramMap_ag p) (fwd_ag p v) := {
  hres := fun k => by
    simp only [paramMap_ag, fwd_ag]
    have heq : ∀ i : Fin p.NumExperiments,
        (↑(10 * v.ConductExperiment i) : ℝ) / 10 = ↑(v.ConductExperiment i) := fun i => by
      push_cast; ring
    simp_rw [heq]
    exact h.hres k
  hj_nn := fun i => by
    simp only [fwd_ag]
    exact mul_nonneg (by norm_num) (h.hConductExperiment_nn i)
  hdiv := fun i => by
    simp only [fwd_ag]
    exact dvd_mul_right 10 _ }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Recover count by dividing j by 10 (exact since hdiv guarantees 10 ∣ j i)
private def bwd_ag (_ : P2.a.Params) (v : P2.g.Vars) : P2.a.Vars :=
  { ConductExperiment := fun i => v.j i / 10 }

private lemma bwd_feas_ag (p : P2.a.Params) (v : P2.g.Vars)
    (h : P2.g.Feasible (paramMap_ag p) v) :
    P2.a.Feasible p (bwd_ag p v) := {
  hres := fun k => by
    have h' := h.hres k
    simp only [paramMap_ag] at h'
    simp only [bwd_ag, paramMap_ag]
    have key : ∀ i : Fin p.NumExperiments,
        ((v.j ↑i / 10 : ℤ) : ℝ) = (v.j ↑i : ℝ) / 10 :=
      fun i => Int.cast_div_charZero (h.hdiv i)
    simp_rw [key]
    exact h'
  hConductExperiment_nn := fun i => by
    simp only [bwd_ag]
    exact Int.ediv_nonneg (h.hj_nn i) (by norm_num) }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def agEquiv : MILPEquiv P2.a.formulation P2.g.formulation where
  paramMap    := paramMap_ag
  fwd         := fwd_ag
  bwd         := bwd_ag
  fwd_feas    := fwd_feas_ag
  bwd_feas    := bwd_feas_ag
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ v _ => by
    simp only [P2.g.formulation, P2.a.formulation, P2.g.obj, P2.a.obj, fwd_ag, paramMap_ag, id]
    congr 1
    apply Finset.sum_congr rfl
    intro i _
    push_cast; ring
  bwd_obj     := fun _ _ h => by
    simp only [P2.g.formulation, P2.a.formulation, P2.g.obj, P2.a.obj, bwd_ag, paramMap_ag, id]
    congr 1
    apply Finset.sum_congr rfl
    intro i _
    congr 1
    exact (@Int.cast_div_charZero ℝ _ _ _ _ (h.hdiv i)).symm

end P2
