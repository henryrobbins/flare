import Common
import dataset.problems.p4.formulations.a.Formulation
import dataset.problems.p4.formulations.g.Formulation

namespace P4

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P4.a.Params) : P4.g.Params :=
  { J := p.MinEmployeesToTransport
    M := p.CarPollution
    K := p.CarCapacity
    D := p.BusCapacity
    O := p.BusPollution
    S := p.MaxBuses }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (_ : P4.a.Params) (v : P4.a.Vars) : P4.g.Vars :=
  { m := v.xCars
    h := v.xBuses }

private lemma fwd_feas (p : P4.a.Params) (v : P4.a.Vars)
    (h : P4.a.Feasible p v) :
    P4.g.Feasible (paramMap p) (fwd p v) :=
  { hmaxbus    := h.hmaxbus
    htransport := h.htransport
    hm_nn      := h.hcars_nn
    hh_nn      := h.hbus_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (_ : P4.a.Params) (v : P4.g.Vars) : P4.a.Vars :=
  { xCars  := v.m
    xBuses := v.h }

private lemma bwd_feas (p : P4.a.Params) (v : P4.g.Vars)
    (h : P4.g.Feasible (paramMap p) v) :
    P4.a.Feasible p (bwd p v) :=
  { htransport := h.htransport
    hmaxbus    := h.hmaxbus
    hcars_nn   := h.hm_nn
    hbus_nn    := h.hh_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFgEquiv : MILPEquiv P4.a.formulation P4.g.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := fun x => 2 * x
  objMap_mono := fun _ _ h => by linarith
  fwd_obj     := fun _ v _ => by simp only [P4.g.formulation, P4.g.obj, P4.a.formulation, P4.a.obj, fwd, paramMap]
  bwd_obj     := fun _ v _ => by simp only [P4.g.formulation, P4.g.obj, P4.a.formulation, P4.a.obj, bwd, paramMap]

end P4
