import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import dataset.problems.p2.formulations.a.Formulation
import dataset.problems.p2.formulations.e.Formulation

open BigOperators Finset

namespace P2

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap_ae (p : P2.a.Params) : P2.e.Params :=
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

-- Slack absorbs the gap between resource usage and availability
private def fwd_ae (p : P2.a.Params) (v : P2.a.Vars) : P2.e.Vars :=
  { j := v.ConductExperiment
    s := fun k =>
      if h : k < p.NumResources
      then p.ResourceAvailable ⟨k, h⟩ -
           ∑ i : Fin p.NumExperiments, p.ResourceRequired ⟨k, h⟩ i * v.ConductExperiment i
      else 0 }

private lemma fwd_feas_ae (p : P2.a.Params) (v : P2.a.Vars)
    (h : P2.a.Feasible p v) :
    P2.e.Feasible (paramMap_ae p) (fwd_ae p v) :=
  { hres  := fun k => by
      simp only [paramMap_ae, fwd_ae]
      have hlt : (k : ℕ) < p.NumResources := k.isLt
      rw [dif_pos hlt, Fin.eta k hlt]
      ring
    hj_nn := h.hConductExperiment_nn
    hs_nn := fun k => by
      simp only [fwd_ae]
      have hlt : (k : ℕ) < p.NumResources := k.isLt
      rw [dif_pos hlt, Fin.eta k hlt]
      linarith [h.hres k] }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Slack is dropped; experiment counts project directly
private def bwd_ae (_ : P2.a.Params) (v : P2.e.Vars) : P2.a.Vars :=
  { ConductExperiment := v.j }

private lemma bwd_feas_ae (p : P2.a.Params) (v : P2.e.Vars)
    (h : P2.e.Feasible (paramMap_ae p) v) :
    P2.a.Feasible p (bwd_ae p v) :=
  { hres                 := fun k => by
      have hk := h.hres k
      simp only [paramMap_ae] at hk
      simp only [bwd_ae]
      linarith [h.hs_nn k]
    hConductExperiment_nn := h.hj_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aeEquiv : MILPEquiv P2.a.formulation P2.e.formulation where
  paramMap    := paramMap_ae
  fwd         := fwd_ae
  bwd         := bwd_ae
  fwd_feas    := fwd_feas_ae
  bwd_feas    := bwd_feas_ae
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj     := fun _ _ _ => rfl
  bwd_obj     := fun _ _ _ => rfl

end P2
