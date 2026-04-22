import Common
import dataset.problems.p4.formulations.a.Formulation
import dataset.problems.p4.formulations.d.Formulation

namespace P4

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P4.Fa.Params) : P4.Fd.Params :=
  { J := p.MinEmployeesToTransport
    M := p.CarPollution
    K := p.CarCapacity
    D := p.BusCapacity
    O := p.BusPollution
    S := p.MaxBuses }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- zed is set to the total pollution so it satisfies the auxiliary constraint
private def fwd (p : P4.Fa.Params) (v : P4.Fa.Vars) : P4.Fd.Vars :=
  { m   := v.xCars
    h   := v.xBuses
    zed := v.xCars * p.CarPollution + v.xBuses * p.BusPollution }

private lemma fwd_feas (p : P4.Fa.Params) (v : P4.Fa.Vars)
    (h : P4.Fa.Feasible p v) :
    P4.Fd.Feasible (paramMap p) (fwd p v) :=
  { hzed       := rfl
    hmaxbus    := h.hmaxbus
    htransport := h.htransport
    hm_nn      := h.hcars_nn
    hh_nn      := h.hbus_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- zed is dropped; xCars and xBuses are projected directly
private def bwd (_ : P4.Fa.Params) (v : P4.Fd.Vars) : P4.Fa.Vars :=
  { xCars  := v.m
    xBuses := v.h }

private lemma bwd_feas (p : P4.Fa.Params) (v : P4.Fd.Vars)
    (h : P4.Fd.Feasible (paramMap p) v) :
    P4.Fa.Feasible p (bwd p v) :=
  { htransport := h.htransport
    hmaxbus    := h.hmaxbus
    hcars_nn   := h.hm_nn
    hbus_nn    := h.hh_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFdEquiv : MILPEquiv P4.Fa.formulation P4.Fd.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj     := fun _ _ h => h.hzed

end P4
