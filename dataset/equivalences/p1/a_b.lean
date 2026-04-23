import Common
import dataset.problems.p1.formulations.a.Formulation
import dataset.problems.p1.formulations.b.Formulation

namespace P1

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P1.a.Params) : P1.b.Params :=
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

private def fwd (_ : P1.a.Params) (v : P1.a.Vars) : P1.b.Vars :=
  { s := v.NumCashMachines
    r := v.NumCardMachines }

private lemma fwd_feas (p : P1.a.Params) (v : P1.a.Vars)
    (h : P1.a.Feasible p v) :
    P1.b.Feasible (paramMap p) (fwd p v) :=
  { hpeople := h.hpeople
    hpaper  := h.hpaper
    hcard   := h.hcard
    hs_nn   := h.hNumCashMachines_nn
    hr_nn   := h.hNumCardMachines_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (_ : P1.a.Params) (v : P1.b.Vars) : P1.a.Vars :=
  { NumCashMachines := v.s
    NumCardMachines := v.r }

private lemma bwd_feas (p : P1.a.Params) (v : P1.b.Vars)
    (h : P1.b.Feasible (paramMap p) v) :
    P1.a.Feasible p (bwd p v) :=
  { hpeople  := h.hpeople
    hpaper   := h.hpaper
    hcard    := h.hcard
    hNumCashMachines_nn := h.hs_nn
    hNumCardMachines_nn := h.hr_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def abEquiv : MILPEquiv P1.a.formulation P1.b.formulation where
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
