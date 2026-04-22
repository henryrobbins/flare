import Common
import dataset.problems.p4.formulations.a.Formulation
import dataset.problems.p4.formulations.f.Formulation

namespace P4

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P4.Fa.Params) : P4.Ff.Params :=
  { J := p.MinEmployeesToTransport
    M := p.CarPollution
    K := p.CarCapacity
    D := p.BusCapacity
    O := p.BusPollution
    S := p.MaxBuses }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- Each count is placed entirely in the first part; second part is zero
private def fwd (_ : P4.Fa.Params) (v : P4.Fa.Vars) : P4.Ff.Vars :=
  { m1 := v.xCars
    m2 := 0
    h1 := v.xBuses
    h2 := 0 }

private lemma fwd_feas (p : P4.Fa.Params) (v : P4.Fa.Vars)
    (h : P4.Fa.Feasible p v) :
    P4.Ff.Feasible (paramMap p) (fwd p v) := by
  refine ⟨?_, ?_, h.hcars_nn, le_refl 0, h.hbus_nn, le_refl 0⟩
  · simp only [fwd, paramMap, Int.cast_zero, add_zero]; exact h.hmaxbus
  · simp only [fwd, paramMap, Int.cast_zero, add_zero]; exact h.htransport

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Both parts are summed to recover the original counts
private def bwd (_ : P4.Fa.Params) (v : P4.Ff.Vars) : P4.Fa.Vars :=
  { xCars  := v.m1 + v.m2
    xBuses := v.h1 + v.h2 }

private lemma bwd_feas (p : P4.Fa.Params) (v : P4.Ff.Vars)
    (h : P4.Ff.Feasible (paramMap p) v) :
    P4.Fa.Feasible p (bwd p v) :=
  { htransport := by simp only [bwd, paramMap] at *; push_cast; exact h.htransport
    hmaxbus    := by simp only [bwd, paramMap] at *; push_cast; exact h.hmaxbus
    hcars_nn   := by simp only [bwd]; linarith [h.hm1_nn, h.hm2_nn]
    hbus_nn    := by simp only [bwd]; linarith [h.hh1_nn, h.hh2_nn] }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFfEquiv : MILPEquiv P4.Fa.formulation P4.Ff.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj := fun _ v _ => by
    simp only [P4.Ff.formulation, P4.Ff.obj, P4.Fa.formulation, P4.Fa.obj, fwd, paramMap, id]
    push_cast; ring
  bwd_obj := fun _ v _ => by
    simp only [P4.Ff.formulation, P4.Ff.obj, P4.Fa.formulation, P4.Fa.obj, bwd, paramMap, id]
    push_cast; ring

end P4
