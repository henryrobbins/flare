import Common
import dataset.problems.p4.formulations.a.Formulation
import dataset.problems.p4.formulations.g.Formulation

namespace P4

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P4.Fa.Params) : P4.Fg.Params :=
  { J := p.MinEmployeesToTransport
    M := p.CarPollution
    K := p.CarCapacity
    D := p.BusCapacity
    O := p.BusPollution
    S := p.MaxBuses }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (_ : P4.Fa.Params) (v : P4.Fa.Vars) : P4.Fg.Vars :=
  { m := v.xCars
    h := v.xBuses }

private lemma fwd_feas (p : P4.Fa.Params) (v : P4.Fa.Vars)
    (h : P4.Fa.Feasible p v) :
    P4.Fg.Feasible (paramMap p) (fwd p v) :=
  { hmaxbus    := h.hmaxbus
    htransport := h.htransport
    hm_nn      := h.hcars_nn
    hh_nn      := h.hbus_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (_ : P4.Fa.Params) (v : P4.Fg.Vars) : P4.Fa.Vars :=
  { xCars  := v.m
    xBuses := v.h }

private lemma bwd_feas (p : P4.Fa.Params) (v : P4.Fg.Vars)
    (h : P4.Fg.Feasible (paramMap p) v) :
    P4.Fa.Feasible p (bwd p v) :=
  { htransport := h.htransport
    hmaxbus    := h.hmaxbus
    hcars_nn   := h.hm_nn
    hbus_nn    := h.hh_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFgEquiv : MILPEquiv P4.Fa.formulation P4.Fg.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := fun x => 2 * x
  objMap_mono := fun _ _ h => by linarith
  fwd_obj     := fun _ v _ => by simp only [P4.Fg.formulation, P4.Fg.obj, P4.Fa.formulation, P4.Fa.obj, fwd, paramMap]
  bwd_obj     := fun _ v _ => by simp only [P4.Fg.formulation, P4.Fg.obj, P4.Fa.formulation, P4.Fa.obj, bwd, paramMap]

end P4
