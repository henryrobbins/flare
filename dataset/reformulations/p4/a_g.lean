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

private def fwd (p : P4.a.Params) (v : P4.a.Vars p) : P4.g.Vars (paramMap p) :=
  { m := v.xCars
    h := v.xBuses }

private lemma fwd_feas (p : P4.a.Params) (v : P4.a.Vars p)
    (h : P4.a.Feasible p v) :
    P4.g.Feasible (paramMap p) (fwd p v) :=
  { hmaxbus    := h.hmaxbus
    htransport := h.htransport
    hm_nn      := h.hcars_nn
    hh_nn      := h.hbus_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P4.a.Params) (v : P4.g.Vars (paramMap p)) : P4.a.Vars p :=
  { xCars  := v.m
    xBuses := v.h }

private lemma bwd_feas (p : P4.a.Params) (v : P4.g.Vars (paramMap p))
    (h : P4.g.Feasible (paramMap p) v) :
    P4.a.Feasible p (bwd p v) :=
  { htransport := h.htransport
    hmaxbus    := h.hmaxbus
    hcars_nn   := h.hm_nn
    hbus_nn    := h.hh_nn }

-- ============================================================================
-- § Objective Mapping
-- ============================================================================

private lemma fwd_obj (p : P4.a.Params) (v : P4.a.Vars p) (_ : P4.a.Feasible p v) :
    P4.g.obj (paramMap p) (fwd p v) = 2 * P4.a.obj p v := by
  simp only [P4.g.obj, P4.a.obj, fwd, paramMap]

private lemma bwd_obj (p : P4.a.Params) (v : P4.g.Vars (paramMap p)) (_ : P4.g.Feasible (paramMap p) v) :
    P4.g.obj (paramMap p) v = 2 * P4.a.obj p (bwd p v) := by
  simp only [P4.g.obj, P4.a.obj, bwd, paramMap]

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aGReformulation : MILPReformulation P4.a.formulation P4.g.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := fun x => 2 * x
  objMap_mono := (fun _ _ h => by linarith)
  fwd_obj     := fwd_obj
  bwd_obj     := bwd_obj

end P4
