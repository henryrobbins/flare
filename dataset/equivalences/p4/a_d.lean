import Common
import dataset.problems.p4.formulations.a.Formulation
import dataset.problems.p4.formulations.d.Formulation

namespace P4

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P4.a.Params) : P4.d.Params :=
  { J := p.MinEmployeesToTransport
    M := p.CarPollution
    K := p.CarCapacity
    D := p.BusCapacity
    O := p.BusPollution
    S := p.MaxBuses
    hK_nn := p.hCarCapacity_nn
    hM_nn := p.hCarPollution_nn
    hD_nn := p.hBusCapacity_nn
    hO_nn := p.hBusPollution_nn
    hJ_nn := p.hMinEmployeesToTransport_nn
    hS_nn := p.hMaxBuses_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- zed is set to the total pollution so it satisfies the auxiliary constraint
private def fwd (p : P4.a.Params) (v : P4.a.Vars) : P4.d.Vars :=
  { m   := v.xCars
    h   := v.xBuses
    zed := (v.xCars : ℝ) * p.CarPollution + (v.xBuses : ℝ) * p.BusPollution }

private lemma fwd_feas (p : P4.a.Params) (v : P4.a.Vars)
    (h : P4.a.Feasible p v) :
    P4.d.Feasible (paramMap p) (fwd p v) :=
  { hzed       := rfl
    hmaxbus    := h.hmaxbus
    htransport := h.htransport
    hm_nn      := h.hcars_nn
    hh_nn      := h.hbus_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- zed is dropped; xCars and xBuses are projected directly
private def bwd (_ : P4.a.Params) (v : P4.d.Vars) : P4.a.Vars :=
  { xCars  := v.m
    xBuses := v.h }

private lemma bwd_feas (p : P4.a.Params) (v : P4.d.Vars)
    (h : P4.d.Feasible (paramMap p) v) :
    P4.a.Feasible p (bwd p v) :=
  { htransport := h.htransport
    hmaxbus    := h.hmaxbus
    hcars_nn   := h.hm_nn
    hbus_nn    := h.hh_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aDEquiv : MILPReformulation P4.a.formulation P4.d.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj     := fun _ _ h => h.hzed

end P4
