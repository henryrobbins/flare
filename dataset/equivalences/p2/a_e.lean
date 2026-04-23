import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p2.formulations.a.Formulation
import dataset.problems.p2.formulations.e.Formulation

open BigOperators Finset

namespace P2

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P2.a.Params) : P2.e.Params :=
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

-- Slack absorbs the gap between resource usage and availability
private def fwd (p : P2.a.Params) (v : P2.a.Vars) : P2.e.Vars :=
  { j := v.ConductExperiment
    s := fun k =>
      if h : k < p.NumResources
      then p.ResourceAvailable ⟨k, h⟩ -
           ∑ i : Fin p.NumExperiments, p.ResourceRequired ⟨k, h⟩ i * (v.ConductExperiment i : ℝ)
      else 0 }

private lemma fwd_feas (p : P2.a.Params) (v : P2.a.Vars)
    (h : P2.a.Feasible p v) :
    P2.e.Feasible (paramMap p) (fwd p v) :=
  { hres := fun k => by
      simp only [paramMap, fwd]
      have hlt : (k : ℕ) < p.NumResources := k.isLt
      rw [dif_pos hlt, Fin.eta k hlt]
      ring
    hj_nn := h.hConductExperiment_nn
    hs_nn := fun k => by
      simp only [fwd]
      have hlt : (k : ℕ) < p.NumResources := k.isLt
      rw [dif_pos hlt, Fin.eta k hlt]
      linarith [h.hres k] }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Slack is dropped; experiment counts project directly
private def bwd (_ : P2.a.Params) (v : P2.e.Vars) : P2.a.Vars :=
  { ConductExperiment := v.j }

private lemma bwd_feas (p : P2.a.Params) (v : P2.e.Vars)
    (h : P2.e.Feasible (paramMap p) v) :
    P2.a.Feasible p (bwd p v) :=
  { hres := fun k => by
      have hk := h.hres k
      simp only [paramMap] at hk
      simp only [bwd]
      linarith [h.hs_nn k]
    hConductExperiment_nn := h.hj_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aEEquiv : MILPEquiv P2.a.formulation P2.e.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ _ _ => rfl
  bwd_obj     := fun _ _ _ => rfl

end P2
