import Common
import dataset.problems.p4.formulations.a.Formulation
import dataset.problems.p4.formulations.b.Formulation

namespace P4

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P4.a.Params) : P4.b.Params :=
  { J := p.MinEmployeesToTransport
    M := p.CarPollution
    K := p.CarCapacity
    D := p.BusCapacity
    O := p.BusPollution
    S := p.MaxBuses }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (_ : P4.a.Params) (v : P4.a.Vars) : P4.b.Vars :=
  { m := v.xCars
    h := v.xBuses }

private lemma fwd_feas (p : P4.a.Params) (v : P4.a.Vars)
    (h : P4.a.Feasible p v) :
    P4.b.Feasible (paramMap p) (fwd p v) :=
  { hmaxbus    := h.hmaxbus
    htransport := h.htransport
    hm_nn      := h.hcars_nn
    hh_nn      := h.hbus_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (_ : P4.a.Params) (v : P4.b.Vars) : P4.a.Vars :=
  { xCars  := v.m
    xBuses := v.h }

private lemma bwd_feas (p : P4.a.Params) (v : P4.b.Vars)
    (h : P4.b.Feasible (paramMap p) v) :
    P4.a.Feasible p (bwd p v) :=
  { htransport := h.htransport
    hmaxbus    := h.hmaxbus
    hcars_nn   := h.hm_nn
    hbus_nn    := h.hh_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFbEquiv : MILPEquiv P4.a.formulation P4.b.formulation where
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
