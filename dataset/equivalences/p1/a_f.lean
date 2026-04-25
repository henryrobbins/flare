import Common
import dataset.problems.p1.formulations.a.Formulation
import dataset.problems.p1.formulations.f.Formulation


namespace P1

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P1.a.Params) : P1.f.Params :=
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

-- Each machine count is placed entirely in the first part; second part is zero
private def fwd (_ : P1.a.Params) (v : P1.a.Vars) : P1.f.Vars :=
  { s1 := v.NumCashMachines
    s2 := 0
    r1 := v.NumCardMachines
    r2 := 0 }

private lemma fwd_feas (p : P1.a.Params) (v : P1.a.Vars)
    (h : P1.a.Feasible p v) :
    P1.f.Feasible (paramMap p) (fwd p v) := by
  refine ⟨?_, ?_, ?_, h.hNumCashMachines_nn, le_refl 0, h.hNumCardMachines_nn, le_refl 0⟩
  · simp only [fwd, paramMap, Int.cast_zero, add_zero]; exact h.hpeople
  · simp only [fwd, paramMap, Int.cast_zero, add_zero]; exact h.hpaper
  · simp only [fwd, add_zero]; linarith [h.hcard]

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Both parts are summed to recover the original machine counts
private def bwd (_ : P1.a.Params) (v : P1.f.Vars) : P1.a.Vars :=
  { NumCashMachines := v.s1 + v.s2
    NumCardMachines := v.r1 + v.r2 }

private lemma bwd_feas (p : P1.a.Params) (v : P1.f.Vars)
    (h : P1.f.Feasible (paramMap p) v) :
    P1.a.Feasible p (bwd p v) := by
  simp only [bwd]
  refine ⟨?_, ?_, h.hcard, by linarith [h.hs1_nn, h.hs2_nn], by linarith [h.hr1_nn, h.hr2_nn]⟩
  · have hp := h.hpeople; simp only [paramMap] at hp
    push_cast; linarith
  · have hp := h.hpaper; simp only [paramMap] at hp
    push_cast; linarith

-- ============================================================================
-- § Objective Mapping
-- ============================================================================

private lemma fwd_obj (p : P1.a.Params) (v : P1.a.Vars) (_ : P1.a.Feasible p v) :
    P1.f.obj (paramMap p) (fwd p v) = id (P1.a.obj p v) := by
  show (↑v.NumCashMachines : ℝ) + ↑(0 : ℤ) + ↑v.NumCardMachines + ↑(0 : ℤ) =
       ↑v.NumCashMachines + ↑v.NumCardMachines
  simp [Int.cast_zero]

private lemma bwd_obj (p : P1.a.Params) (v : P1.f.Vars) (_ : P1.f.Feasible (paramMap p) v) :
    P1.f.obj (paramMap p) v = id (P1.a.obj p (bwd p v)) := by
  show (↑v.s1 + ↑v.s2 + ↑v.r1 + ↑v.r2 : ℝ) = ↑(v.s1 + v.s2) + ↑(v.r1 + v.r2)
  push_cast; ring

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def afEquiv : MILPEquiv P1.a.formulation P1.f.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := Or.inl strictMono_id
  fwd_obj     := fwd_obj
  bwd_obj     := bwd_obj

end P1
