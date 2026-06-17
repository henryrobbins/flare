import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import problems.p2.formulations.a.Formulation
import problems.p2.formulations.f.Formulation

open BigOperators Finset

namespace P2

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P2.a.Params) : P2.f.Params :=
  { M := p.NumExperiments
    N := p.NumResources
    A := p.ElectricityProduced
    I := p.ResourceRequired
    Y := p.ResourceAvailable
    hM := p.hNumExperiments
    hN := p.hNumResources
    hA_nn := p.hElectricityProduced_nn
    hY_nn := p.hResourceAvailable_nn
    hI_nn := p.hResourceRequired_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- Count placed entirely in j1; j2 is zero
private def fwd (p : P2.a.Params) (v : P2.a.Vars p) : P2.f.Vars (paramMap p) :=
  { j1 := v.ConductExperiment
    j2 := fun _ => 0 }

private lemma fwd_feas (p : P2.a.Params) (v : P2.a.Vars p)
    (h : P2.a.Feasible p v) :
    P2.f.Feasible (paramMap p) (fwd p v) := by
  refine ⟨fun k => ?_, h.hConductExperiment_nn, fun _ => le_refl 0⟩
  simp only [paramMap, fwd, Int.cast_zero, add_zero]
  exact h.hres k

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Both parts are summed to recover the experiment count
private def bwd (p : P2.a.Params) (v : P2.f.Vars (paramMap p)) : P2.a.Vars p :=
  { ConductExperiment := fun i => v.j1 i + v.j2 i }

private lemma bwd_feas (p : P2.a.Params) (v : P2.f.Vars (paramMap p))
    (h : P2.f.Feasible (paramMap p) v) :
    P2.a.Feasible p (bwd p v) :=
  { hres := fun j => by
      have h' := h.hres j
      simp only [paramMap, bwd] at h' ⊢
      push_cast at h' ⊢
      exact h'
    hConductExperiment_nn := fun i => by
      simp only [bwd]
      linarith [h.hj1_nn i, h.hj2_nn i] }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aFReformulation : MILPReformulation P2.a.formulation P2.f.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  bwd_fwd     := fun _ v _ => by cases v; simp [bwd, fwd]
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj     := fun _ v _ => by
    simp only [P2.f.formulation, P2.a.formulation, P2.f.obj, P2.a.obj, fwd, paramMap, id,
               Int.cast_zero, add_zero]
  bwd_obj     := fun _ v _ => by
    simp only [P2.f.formulation, P2.a.formulation, P2.f.obj, P2.a.obj, bwd, paramMap, id]
    push_cast; ring

end P2
