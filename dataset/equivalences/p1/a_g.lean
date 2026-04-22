import Common
import dataset.problems.p1.formulations.a.Formulation
import dataset.problems.p1.formulations.g.Formulation

namespace P1

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P1.Fa.Params) : P1.Fg.Params :=
  { A := p.CashMachineProcessingRate
    K := p.CardMachineProcessingRate
    Y := p.CashMachinePaperRolls
    W := p.CardMachinePaperRolls
    U := p.MinPeopleProcessed
    V := p.MaxPaperRolls }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (_ : P1.Fa.Params) (v : P1.Fa.Vars) : P1.Fg.Vars :=
  { s := v.NumCashMachines
    r := v.NumCardMachines }

private lemma fwd_feas (p : P1.Fa.Params) (v : P1.Fa.Vars)
    (h : P1.Fa.Feasible p v) :
    P1.Fg.Feasible (paramMap p) (fwd p v) :=
  { hpeople := h.hpeople
    hpaper  := h.hpaper
    hcard   := h.hcard
    hs_nn   := h.hNumCashMachines_nn
    hr_nn   := h.hNumCardMachines_nn }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (_ : P1.Fa.Params) (v : P1.Fg.Vars) : P1.Fa.Vars :=
  { NumCashMachines := v.s
    NumCardMachines := v.r }

private lemma bwd_feas (p : P1.Fa.Params) (v : P1.Fg.Vars)
    (h : P1.Fg.Feasible (paramMap p) v) :
    P1.Fa.Feasible p (bwd p v) :=
  { hpeople  := h.hpeople
    hpaper   := h.hpaper
    hcard    := h.hcard
    hNumCashMachines_nn := h.hs_nn
    hNumCardMachines_nn := h.hr_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFgEquiv : MILPEquiv P1.Fa.formulation P1.Fg.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := fun x => 2 * x
  objMap_mono := fun _ _ h => by linarith
  fwd_obj     := fun _ v _ => by simp only [P1.Fg.formulation, P1.Fg.obj, P1.Fa.formulation, P1.Fa.obj, fwd]
  bwd_obj     := fun _ v _ => by simp only [P1.Fg.formulation, P1.Fg.obj, P1.Fa.formulation, P1.Fa.obj, bwd]

end P1
