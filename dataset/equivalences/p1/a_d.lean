import Common
import problems.p1.formulations.a.Formulation
import problems.p1.formulations.d.Formulation

namespace P1

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P1.Fa.Params) : P1.Fd.Params :=
  { A := p.CashMachineProcessingRate
    K := p.CardMachineProcessingRate
    Y := p.CashMachinePaperRolls
    W := p.CardMachinePaperRolls
    U := p.MinPeopleProcessed
    V := p.MaxPaperRolls }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- zed is set to the sum of machines so it satisfies the auxiliary constraint
private def fwd (_ : P1.Fa.Params) (v : P1.Fa.Vars) : P1.Fd.Vars :=
  { s   := v.NumCashMachines
    r   := v.NumCardMachines
    zed := v.NumCashMachines + v.NumCardMachines }

private lemma fwd_feas (p : P1.Fa.Params) (v : P1.Fa.Vars)
    (h : P1.Fa.Feasible p v) :
    P1.Fd.Feasible (paramMap p) (fwd p v) :=
  { hzed    := rfl
    hpeople := h.hpeople
    hpaper  := h.hpaper
    hcard   := h.hcard
    hs_nn   := h.hNumCashMachines_nn
    hr_nn   := h.hNumCardMachines_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- zed is dropped; NumCashMachines and NumCardMachines are projected directly
private def bwd (_ : P1.Fa.Params) (v : P1.Fd.Vars) : P1.Fa.Vars :=
  { NumCashMachines := v.s
    NumCardMachines := v.r }

private lemma bwd_feas (p : P1.Fa.Params) (v : P1.Fd.Vars)
    (h : P1.Fd.Feasible (paramMap p) v) :
    P1.Fa.Feasible p (bwd p v) :=
  { hpeople  := h.hpeople
    hpaper   := h.hpaper
    hcard    := h.hcard
    hNumCashMachines_nn := h.hs_nn
    hNumCardMachines_nn := h.hr_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFdEquiv : MILPEquiv P1.Fa.formulation P1.Fd.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj     := fun _ _ h => h.hzed

end P1
