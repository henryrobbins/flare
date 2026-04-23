import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p2.formulations.a.Formulation
import dataset.problems.p2.formulations.b.Formulation

open BigOperators Finset

namespace P2

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P2.a.Params) : P2.b.Params :=
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

private def fwd (_ : P2.a.Params) (v : P2.a.Vars) : P2.b.Vars :=
  { j := v.ConductExperiment }

private lemma fwd_feas (p : P2.a.Params) (v : P2.a.Vars) (h : P2.a.Feasible p v) :
    P2.b.Feasible (paramMap p) (fwd p v) :=
  { hres := h.hres
    hj_nn := h.hConductExperiment_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (_ : P2.a.Params) (v : P2.b.Vars) : P2.a.Vars :=
  { ConductExperiment := v.j }

private lemma bwd_feas (p : P2.a.Params) (v : P2.b.Vars)
    (h : P2.b.Feasible (paramMap p) v) :
    P2.a.Feasible p (bwd p v) :=
  { hres := h.hres
    hConductExperiment_nn := h.hj_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def abEquiv : MILPEquiv P2.a.formulation P2.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P2
