import Common
import dataset.problems.p1.formulations.a.Formulation
import dataset.problems.p1.formulations.e.Formulation

namespace P1

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P1.a.Params) : P1.e.Params :=
  { A := p.CashMachineProcessingRate
    K := p.CardMachineProcessingRate
    Y := p.CashMachinePaperRolls
    W := p.CardMachinePaperRolls
    U := p.MinPeopleProcessed
    V := p.MaxPaperRolls
    hA_nn := p.hCashMachineProcessingRate_nn
    hK_nn := p.hCardMachineProcessingRate_nn
    hY_nn := p.hCashMachinePaperRolls_nn
    hW_nn := p.hCardMachinePaperRolls_nn
    hU_nn := p.hMinPeopleProcessed_nn
    hV_nn := p.hMaxPaperRolls_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- Slacks absorb the surplus/slack of each inequality constraint in Fa
private def fwd (p : P1.a.Params) (v : P1.a.Vars) : P1.e.Vars :=
  { s       := v.NumCashMachines
    r       := v.NumCardMachines
    slack_0 := p.CashMachineProcessingRate * (v.NumCashMachines : ℝ) +
               p.CardMachineProcessingRate * (v.NumCardMachines : ℝ) - p.MinPeopleProcessed
    slack_1 := (v.NumCashMachines : ℝ) - (v.NumCardMachines : ℝ)
    slack_2 := p.MaxPaperRolls - (v.NumCashMachines : ℝ) * p.CashMachinePaperRolls -
               (v.NumCardMachines : ℝ) * p.CardMachinePaperRolls }

private lemma fwd_feas (p : P1.a.Params) (v : P1.a.Vars)
    (h : P1.a.Feasible p v) :
    P1.e.Feasible (paramMap p) (fwd p v) := by
  have hcard_r : (↑v.NumCardMachines : ℝ) ≤ ↑v.NumCashMachines := by exact_mod_cast h.hcard
  simp only [paramMap, fwd]
  refine ⟨by ring, by ring, by ring, h.hNumCashMachines_nn, h.hNumCardMachines_nn,
    by linarith [h.hpeople], by linarith, by linarith [h.hpaper]⟩

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Slack variables are dropped; s and r project directly to NumCashMachines/NumCardMachines
private def bwd (_ : P1.a.Params) (v : P1.e.Vars) : P1.a.Vars :=
  { NumCashMachines := v.s
    NumCardMachines := v.r }

private lemma bwd_feas (p : P1.a.Params) (v : P1.e.Vars)
    (h : P1.e.Feasible (paramMap p) v) :
    P1.a.Feasible p (bwd p v) := by
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

def aEEquiv : MILPReformulation P1.a.formulation P1.e.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P1
