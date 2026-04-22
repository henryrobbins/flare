import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p2.formulations.a.Formulation
import dataset.problems.p2.formulations.f.Formulation

open BigOperators Finset

namespace P2

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap_af (p : P2.a.Params) : P2.f.Params :=
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

-- Count placed entirely in j1; j2 is zero
private def fwd_af (_ : P2.a.Params) (v : P2.a.Vars) : P2.f.Vars :=
  { j1 := v.ConductExperiment
    j2 := fun _ => 0 }

private lemma fwd_feas_af (p : P2.a.Params) (v : P2.a.Vars)
    (h : P2.a.Feasible p v) :
    P2.f.Feasible (paramMap_af p) (fwd_af p v) := by
  refine ⟨fun k => ?_, h.hConductExperiment_nn, fun _ => le_refl 0⟩
  simp only [paramMap_af, fwd_af, Int.cast_zero, add_zero]
  exact h.hres k

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Both parts are summed to recover the experiment count
private def bwd_af (_ : P2.a.Params) (v : P2.f.Vars) : P2.a.Vars :=
  { ConductExperiment := fun i => v.j1 i + v.j2 i }

private lemma bwd_feas_af (p : P2.a.Params) (v : P2.f.Vars)
    (h : P2.f.Feasible (paramMap_af p) v) :
    P2.a.Feasible p (bwd_af p v) :=
  { hres := fun j => by
      have h' := h.hres j
      simp only [paramMap_af, bwd_af] at h' ⊢
      push_cast at h' ⊢
      exact h'
    hConductExperiment_nn := fun i => by
      simp only [bwd_af]
      linarith [h.hj1_nn i, h.hj2_nn i] }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def afEquiv : MILPEquiv P2.a.formulation P2.f.formulation where
  paramMap    := paramMap_af
  fwd         := fwd_af
  bwd         := bwd_af
  fwd_feas    := fwd_feas_af
  bwd_feas    := bwd_feas_af
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ v _ => by
    simp only [P2.f.formulation, P2.a.formulation, P2.f.obj, P2.a.obj, fwd_af, paramMap_af, id,
               Int.cast_zero, add_zero]
  bwd_obj     := fun _ v _ => by
    simp only [P2.f.formulation, P2.a.formulation, P2.f.obj, P2.a.obj, bwd_af, paramMap_af, id]
    push_cast; ring

end P2
