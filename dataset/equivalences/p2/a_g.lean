import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Int.Basic
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

private def fwd (_ : P2.a.Params) (v : P2.a.Vars) : P2.g.Vars :=
  { j := fun i => v.ConductExperiment i }

private lemma fwd_feas (p : P2.a.Params) (v : P2.a.Vars)
    (h : P2.a.Feasible p v) :
    P2.g.Feasible (paramMap p) (fwd p v) := {
  hres := fun k => by
    simp only [paramMap, fwd]
    exact h.hres k
  hj_nn := fun i => by
    simp only [fwd]
    exact h.hConductExperiment_nn i }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (_ : P2.a.Params) (v : P2.g.Vars) : P2.a.Vars :=
  { ConductExperiment := fun i => v.j i }

private lemma bwd_feas (p : P2.a.Params) (v : P2.g.Vars)
    (h : P2.g.Feasible (paramMap p) v) :
    P2.a.Feasible p (bwd p v) := {
  hres := fun k => by
    simp only [paramMap] at h
    simp only [bwd]
    exact h.hres k
  hConductExperiment_nn := fun i => by
    simp only [bwd]
    exact h.hj_nn i }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

-- g.obj = -2*(∑ A·j) = 2*(-(∑ A·j)) = 2 * a.obj, so objMap x = 2 * x
noncomputable def aGEquiv : MILPReformulation P2.a.formulation P2.g.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := fun x => 2 * x
  objMap_mono := (strictMono_mul_left_of_pos (by norm_num))
  fwd_obj     := fun _ v _ => by
    simp only [P2.g.formulation, P2.a.formulation, P2.g.obj, P2.a.obj, fwd, paramMap]
    ring
  bwd_obj     := fun _ v _ => by
    simp only [P2.g.formulation, P2.a.formulation, P2.g.obj, P2.a.obj, bwd, paramMap]
    ring

end P2
