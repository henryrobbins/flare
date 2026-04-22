import Common
import dataset.problems.p4.formulations.a.Formulation
import dataset.problems.p4.formulations.e.Formulation

namespace P4

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P4.Fa.Params) : P4.Fe.Params :=
  { J := p.MinEmployeesToTransport
    M := p.CarPollution
    K := p.CarCapacity
    D := p.BusCapacity
    O := p.BusPollution
    S := p.MaxBuses }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- Slacks absorb the surplus of each inequality constraint in Fa
private def fwd (p : P4.Fa.Params) (v : P4.Fa.Vars) : P4.Fe.Vars :=
  { m       := v.xCars
    h       := v.xBuses
    slack_0 := v.xCars * p.CarCapacity + v.xBuses * p.BusCapacity - p.MinEmployeesToTransport
    slack_1 := p.MaxBuses - v.xBuses }

private lemma fwd_feas (p : P4.Fa.Params) (v : P4.Fa.Vars)
    (h : P4.Fa.Feasible p v) :
    P4.Fe.Feasible (paramMap p) (fwd p v) := by
  simp only [paramMap, fwd]
  refine ⟨by ring, by ring, h.hcars_nn, h.hbus_nn,
    by linarith [h.htransport], by linarith [h.hmaxbus]⟩

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Slack variables are dropped; xCars and xBuses project directly
private def bwd (_ : P4.Fa.Params) (v : P4.Fe.Vars) : P4.Fa.Vars :=
  { xCars  := v.m
    xBuses := v.h }

private lemma bwd_feas (p : P4.Fa.Params) (v : P4.Fe.Vars)
    (h : P4.Fe.Feasible (paramMap p) v) :
    P4.Fa.Feasible p (bwd p v) := by
  have htr := h.htransport; simp only [paramMap] at htr
  have hbu := h.hbuses;     simp only [paramMap] at hbu
  simp only [bwd]
  exact ⟨by linarith [h.hslack0_nn], by linarith [h.hslack1_nn], h.hm_nn, h.hh_nn⟩

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFeEquiv : MILPEquiv P4.Fa.formulation P4.Fe.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P4
