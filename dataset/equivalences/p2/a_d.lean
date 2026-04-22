import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p2.formulations.a.Formulation
import dataset.problems.p2.formulations.d.Formulation

open BigOperators Finset

namespace P2

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap_ad (p : P2.a.Params) : P2.d.Params :=
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

-- zed is set to total electricity so it satisfies the auxiliary equality
private def fwd_ad (p : P2.a.Params) (v : P2.a.Vars) : P2.d.Vars :=
  { j   := v.ConductExperiment
    zed := ∑ i : Fin p.NumExperiments, p.ElectricityProduced i * v.ConductExperiment i }

private lemma fwd_feas_ad (p : P2.a.Params) (v : P2.a.Vars)
    (h : P2.a.Feasible p v) :
    P2.d.Feasible (paramMap_ad p) (fwd_ad p v) :=
  { hzed  := rfl
    hres  := h.hres
    hj_nn := h.hConductExperiment_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- zed is dropped; experiment counts project directly
private def bwd_ad (_ : P2.a.Params) (v : P2.d.Vars) : P2.a.Vars :=
  { ConductExperiment := v.j }

private lemma bwd_feas_ad (p : P2.a.Params) (v : P2.d.Vars)
    (h : P2.d.Feasible (paramMap_ad p) v) :
    P2.a.Feasible p (bwd_ad p v) :=
  { hres                 := h.hres
    hConductExperiment_nn := h.hj_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def adEquiv : MILPEquiv P2.a.formulation P2.d.formulation where
  paramMap    := paramMap_ad
  fwd         := fwd_ad
  bwd         := bwd_ad
  fwd_feas    := fwd_feas_ad
  bwd_feas    := bwd_feas_ad
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ _ _ => rfl
  bwd_obj     := fun _ _ h => by
    have := h.hzed
    simp only [P2.d.formulation, P2.a.formulation, P2.d.obj, P2.a.obj, bwd_ad, paramMap_ad, id] at *
    linarith

end P2
