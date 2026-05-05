import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p2.formulations.a.Formulation
import dataset.problems.p2.formulations.d.Formulation

open BigOperators Finset

namespace P2

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P2.a.Params) : P2.d.Params :=
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

-- zed is set to total electricity so it satisfies the auxiliary equality
private def fwd (p : P2.a.Params) (v : P2.a.Vars p) : P2.d.Vars (paramMap p) :=
  { j := v.ConductExperiment
    zed := ∑ i : Fin p.NumExperiments, p.ElectricityProduced i * (v.ConductExperiment i : ℝ) }

private lemma fwd_feas (p : P2.a.Params) (v : P2.a.Vars p)
    (h : P2.a.Feasible p v) :
    P2.d.Feasible (paramMap p) (fwd p v) :=
  { hzed := rfl
    hres := h.hres
    hj_nn := h.hConductExperiment_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- zed is dropped; experiment counts project directly
private def bwd (p : P2.a.Params) (v : P2.d.Vars (paramMap p)) : P2.a.Vars p :=
  { ConductExperiment := v.j }

private lemma bwd_feas (p : P2.a.Params) (v : P2.d.Vars (paramMap p))
    (h : P2.d.Feasible (paramMap p) v) :
    P2.a.Feasible p (bwd p v) :=
  { hres := h.hres
    hConductExperiment_nn := h.hj_nn }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aDEquiv : MILPReformulation P2.a.formulation P2.d.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj     := fun _ _ _ => rfl
  bwd_obj     := fun _ _ h => by
    have := h.hzed
    simp only [P2.d.formulation, P2.a.formulation, P2.d.obj, P2.a.obj, bwd, paramMap, id] at *
    linarith

end P2
