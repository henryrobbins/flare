import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import dataset.problems.p3.formulations.a.Formulation
import dataset.problems.p3.formulations.g.Formulation

open BigOperators Finset

namespace P3

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P3.a.Params) : P3.g.Params :=
  { N     := p.NumBeakers
    C     := p.WasteProducedPerBeaker
    E     := p.MaxWasteAllowed
    X     := p.SlimeProducedPerBeaker
    T     := p.FlourUsagePerBeaker
    D     := p.FlourAvailable
    V     := p.SpecialLiquidUsagePerBeaker
    Z     := p.SpecialLiquidAvailable
    hN    := p.hNumBeakers
    hC_nn := p.hWaste_nn
    hX_nn := p.hSlime_nn
    hT_nn := p.hFlour_nn
    hV_nn := p.hLiquid_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

/-- **P3.a → P3.g**: Identity on vars; beaker counts map directly. -/
private def fwd (p : P3.a.Params) (v : P3.a.Vars p) : P3.g.Vars (paramMap p) :=
  { n := v.NumBeakersUsed }

private lemma fwd_feas (p : P3.a.Params) (v : P3.a.Vars p)
    (h : P3.a.Feasible p v) :
    P3.g.Feasible (paramMap p) (fwd p v) := {
  hliquid := by simp only [paramMap, fwd]; exact h.hliquid
  hflour  := by simp only [paramMap, fwd]; exact h.hflour
  hwaste  := by simp only [paramMap, fwd]; exact h.hwaste
  hn_nn   := fun i => by simp only [fwd]; exact h.hNumBeakersUsed_nn i }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-- **P3.g → P3.a**: Identity on vars; beaker counts map directly. -/
private def bwd (p : P3.a.Params) (v : P3.g.Vars (paramMap p)) : P3.a.Vars p :=
  { NumBeakersUsed := v.n }

private lemma bwd_feas (p : P3.a.Params) (v : P3.g.Vars (paramMap p))
    (h : P3.g.Feasible (paramMap p) v) :
    P3.a.Feasible p (bwd p v) := {
  hliquid := by simp only [paramMap] at h; exact h.hliquid
  hflour  := by simp only [paramMap] at h; exact h.hflour
  hwaste  := by simp only [paramMap] at h; exact h.hwaste
  hNumBeakersUsed_nn := fun i => by simp only [bwd]; exact h.hn_nn i }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

noncomputable def aGReformulation : MILPReformulation P3.a.formulation P3.g.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := fun x => 2 * x
  objMap_mono := (fun a b h => by simp only; linarith)
  fwd_obj     := fun _ _ _ => by
    simp only [P3.g.formulation, P3.a.formulation, P3.g.obj, P3.a.obj, fwd, paramMap]
    ring
  bwd_obj     := fun _ _ _ => by
    simp only [P3.g.formulation, P3.a.formulation, P3.g.obj, P3.a.obj, bwd, paramMap]
    ring

end P3
