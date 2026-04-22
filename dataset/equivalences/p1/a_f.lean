import Common
import dataset.problems.p1.formulations.a.Formulation
import dataset.problems.p1.formulations.f.Formulation

namespace P1

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P1.Fa.Params) : P1.Ff.Params :=
  { A := p.CashMachineProcessingRate
    K := p.CardMachineProcessingRate
    Y := p.CashMachinePaperRolls
    W := p.CardMachinePaperRolls
    U := p.MinPeopleProcessed
    V := p.MaxPaperRolls }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- Each machine count is placed entirely in the first part; second part is zero
private def fwd (_ : P1.Fa.Params) (v : P1.Fa.Vars) : P1.Ff.Vars :=
  { s1 := v.NumCashMachines
    s2 := 0
    r1 := v.NumCardMachines
    r2 := 0 }

private lemma fwd_feas (p : P1.Fa.Params) (v : P1.Fa.Vars)
    (h : P1.Fa.Feasible p v) :
    P1.Ff.Feasible (paramMap p) (fwd p v) := by
  refine ⟨?_, ?_, ?_, h.hNumCashMachines_nn, le_refl 0, h.hNumCardMachines_nn, le_refl 0⟩
  · simp only [fwd, paramMap, Int.cast_zero, add_zero]; exact h.hpeople
  · simp only [fwd, paramMap, Int.cast_zero, add_zero]; exact h.hpaper
  · simp only [fwd, add_zero]; linarith [h.hcard]

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- Both parts are summed to recover the original machine counts
private def bwd (_ : P1.Fa.Params) (v : P1.Ff.Vars) : P1.Fa.Vars :=
  { NumCashMachines := v.s1 + v.s2
    NumCardMachines := v.r1 + v.r2 }

private lemma bwd_feas (p : P1.Fa.Params) (v : P1.Ff.Vars)
    (h : P1.Ff.Feasible (paramMap p) v) :
    P1.Fa.Feasible p (bwd p v) := by
  simp only [bwd]
  refine ⟨?_, ?_, h.hcard, by linarith [h.hs1_nn, h.hs2_nn], by linarith [h.hr1_nn, h.hr2_nn]⟩
  · have hp := h.hpeople; simp only [paramMap] at hp
    push_cast; linarith
  · have hp := h.hpaper; simp only [paramMap] at hp
    push_cast; linarith

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def faFfEquiv : MILPEquiv P1.Fa.formulation P1.Ff.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  -- Ff.obj (fwd v) = NumCash + ↑0 + NumCard + ↑0 = NumCash + NumCard = Fa.obj v
  fwd_obj := fun _ v _ => by
    show (↑v.NumCashMachines : ℝ) + ↑(0 : ℤ) + ↑v.NumCardMachines + ↑(0 : ℤ) =
         ↑v.NumCashMachines + ↑v.NumCardMachines
    simp [Int.cast_zero]
  -- Ff.obj v = ↑s1+↑s2+↑r1+↑r2 = ↑(s1+s2)+↑(r1+r2) = Fa.obj (bwd v)
  bwd_obj := fun _ v _ => by
    show (↑v.s1 + ↑v.s2 + ↑v.r1 + ↑v.r2 : ℝ) = ↑(v.s1 + v.s2) + ↑(v.r1 + v.r2)
    push_cast; ring

end P1
