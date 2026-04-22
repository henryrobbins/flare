import Common
import dataset.problems.p1.formulations.a.Formulation
import dataset.problems.p1.formulations.e.Formulation

namespace P1

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P1.Fa.Params) : P1.Fe.Params :=
  { A := p.CashMachineProcessingRate
    K := p.CardMachineProcessingRate
    Y := p.CashMachinePaperRolls
    W := p.CardMachinePaperRolls
    U := p.MinPeopleProcessed
    V := p.MaxPaperRolls }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- Slacks absorb the surplus/slack of each inequality constraint in Fa
private def fwd (p : P1.Fa.Params) (v : P1.Fa.Vars) : P1.Fe.Vars :=
  { s       := v.NumCashMachines
    r       := v.NumCardMachines
    slack_0 := p.CashMachineProcessingRate * v.NumCashMachines +
               p.CardMachineProcessingRate * v.NumCardMachines - p.MinPeopleProcessed
    slack_1 := v.NumCashMachines - v.NumCardMachines
    slack_2 := p.MaxPaperRolls - v.NumCashMachines * p.CashMachinePaperRolls -
               v.NumCardMachines * p.CardMachinePaperRolls }

private lemma fwd_feas (p : P1.Fa.Params) (v : P1.Fa.Vars)
    (h : P1.Fa.Feasible p v) :
    P1.Fe.Feasible (paramMap p) (fwd p v) := by
  have hcard_r : (↑v.NumCardMachines : ℝ) ≤ ↑v.NumCashMachines := by exact_mod_cast h.hcard
  simp only [paramMap, fwd]
  refine ⟨by ring, by ring, by ring, h.hNumCashMachines_nn, h.hNumCardMachines_nn,
    by linarith [h.hpeople], by linarith, by linarith [h.hpaper]⟩

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Slack variables are dropped; s and r project directly to NumCashMachines/NumCardMachines
private def bwd (_ : P1.Fa.Params) (v : P1.Fe.Vars) : P1.Fa.Vars :=
  { NumCashMachines := v.s
    NumCardMachines := v.r }

private lemma bwd_feas (p : P1.Fa.Params) (v : P1.Fe.Vars)
    (h : P1.Fe.Feasible (paramMap p) v) :
    P1.Fa.Feasible p (bwd p v) := by
  have hpe := h.hpeople;  simp only [paramMap] at hpe
  have hpa := h.hpaper;   simp only [paramMap] at hpa
  have hca := h.hcard
  simp only [bwd]
  refine ⟨by linarith [h.hslack0_nn], by linarith [h.hslack2_nn], ?_, h.hs_nn, h.hr_nn⟩
  -- hcard: goal is v.r ≤ v.s (ℤ); derive from ℝ hypothesis hca via cast
  exact_mod_cast (show (↑v.r : ℝ) ≤ ↑v.s from by linarith [hca, h.hslack1_nn])

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFeEquiv : MILPEquiv P1.Fa.formulation P1.Fe.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P1
