import Common
import problems.p6.formulations.a.Formulation
import problems.p6.formulations.e.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P6

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P6.a.Params) : P6.e.Params :=
  { n := p.n
    m := p.m
    d := p.d
    u := p.u
    f := p.f
    c := p.c
    hd_pos := p.hd_pos
    hu_nn := p.hu_nn
    hc_nn := p.hc_nn
    hf_nn := p.hf_nn
    hn := p.hn
    hm := p.hm }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (p : P6.a.Params) (v : P6.a.Vars p) : P6.e.Vars (paramMap p) :=
  { x := v.x
    y := v.y }

private lemma fwd_feas (p : P6.a.Params) (v : P6.a.Vars p)
    (h : P6.a.Feasible p v) :
    P6.e.Feasible (paramMap p) (fwd p v) := by
  refine
    { hassign := h.hassign
      hcap    := h.hcap
      hx_bin  := h.hx_bin
      hy_bin  := h.hy_bin
      hec1    := ?_ }
  -- EC1: ∑ i, d i ≤ ∑ j, u j * y j
  -- Proof: ∑ d i = ∑ i, d i * (∑ j, x i j) = ∑ j ∑ i, d i * x i j ≤ ∑ j, u j * y j
  have step1 : ∀ i : Fin p.n, p.d i = ∑ j : Fin p.m, p.d i * (v.x i j : ℝ) := by
    intro i
    have := h.hassign i
    calc p.d i = p.d i * 1 := by ring
      _ = p.d i * ((∑ j : Fin p.m, v.x i j : ℤ) : ℝ) := by rw [this]; norm_num
      _ = p.d i * (∑ j : Fin p.m, (v.x i j : ℝ)) := by push_cast; rfl
      _ = ∑ j : Fin p.m, p.d i * (v.x i j : ℝ) := by rw [Finset.mul_sum]
  calc ∑ i : Fin p.n, p.d i
      = ∑ i : Fin p.n, ∑ j : Fin p.m, p.d i * (v.x i j : ℝ) := by
        apply Finset.sum_congr rfl
        intro i _; exact step1 i
    _ = ∑ j : Fin p.m, ∑ i : Fin p.n, p.d i * (v.x i j : ℝ) := Finset.sum_comm
    _ ≤ ∑ j : Fin p.m, p.u j * (v.y j : ℝ) := by
        apply Finset.sum_le_sum
        intro j _; exact h.hcap j

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P6.a.Params) (v : P6.e.Vars (paramMap p)) : P6.a.Vars p :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P6.a.Params) (v : P6.e.Vars (paramMap p))
    (h : P6.e.Feasible (paramMap p) v) :
    P6.a.Feasible p (bwd p v) :=
  { hassign := h.hassign
    hcap    := h.hcap
    hx_bin  := h.hx_bin
    hy_bin  := h.hy_bin }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aEReformulation : MILPReformulation P6.a.formulation P6.e.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  bwd_fwd     := fun _ _ _ => rfl
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P6
