import Common
import dataset.problems.p6.formulations.a.Formulation
import dataset.problems.p6.formulations.h.Formulation
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

private def paramMap (p : P6.a.Params) : P6.h.Params :=
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

private def fwd (p : P6.a.Params) (v : P6.a.Vars p) : P6.h.Vars (paramMap p) :=
  { x := v.x
    y := v.y }

private lemma fwd_hec4 (p : P6.a.Params) (v : P6.a.Vars p)
    (h : P6.a.Feasible p v) :
    ∀ i : Fin p.n, ∀ j : Fin p.m, p.u j < p.d i → v.x i j = 0 := by
  intro i j hlt
  rcases h.hx_bin i j with h0 | h1
  · exact h0
  · exfalso
    -- d_i ≤ ∑ i', d_{i'} * x_{i',j} ≤ u_j * y_j ≤ u_j
    have hcap := h.hcap j
    -- Lower bound the sum by the i-th term.
    have hxi_cast : (v.x i j : ℝ) = 1 := by exact_mod_cast h1
    have hnn : ∀ i' ∈ (Finset.univ : Finset (Fin p.n)), i' ∉ ({i} : Finset (Fin p.n)) →
        0 ≤ p.d i' * (v.x i' j : ℝ) := by
      intro i' _ _
      have hd := (p.hd_pos i').le
      have hx_nn : (0 : ℝ) ≤ (v.x i' j : ℝ) := by
        rcases h.hx_bin i' j with h0' | h1'
        · rw [h0']; simp
        · rw [h1']; simp
      exact mul_nonneg hd hx_nn
    have hsum_ge : p.d i ≤ ∑ i' : Fin p.n, p.d i' * (v.x i' j : ℝ) := by
      have hsingle : ∑ i' ∈ ({i} : Finset (Fin p.n)), p.d i' * (v.x i' j : ℝ)
          = p.d i := by
        simp [hxi_cast]
      rw [← hsingle]
      exact Finset.sum_le_sum_of_subset_of_nonneg (Finset.subset_univ _) hnn
    -- Upper bound u_j * y_j ≤ u_j.
    have hy_le : (v.y j : ℝ) ≤ 1 := by
      rcases h.hy_bin j with hy0 | hy1
      · rw [hy0]; simp
      · rw [hy1]; simp
    have hu_nn := p.hu_nn j
    have hrhs_le : p.u j * (v.y j : ℝ) ≤ p.u j := by
      calc p.u j * (v.y j : ℝ) ≤ p.u j * 1 := by
            exact mul_le_mul_of_nonneg_left hy_le hu_nn
        _ = p.u j := by ring
    have : p.d i ≤ p.u j := le_trans hsum_ge (le_trans hcap hrhs_le)
    linarith

private lemma fwd_feas (p : P6.a.Params) (v : P6.a.Vars p)
    (h : P6.a.Feasible p v) :
    P6.h.Feasible (paramMap p) (fwd p v) :=
  { hassign := h.hassign
    hcap    := h.hcap
    hx_bin  := h.hx_bin
    hy_bin  := h.hy_bin
    hec4    := fwd_hec4 p v h }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P6.a.Params) (v : P6.h.Vars (paramMap p)) : P6.a.Vars p :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P6.a.Params) (v : P6.h.Vars (paramMap p))
    (h : P6.h.Feasible (paramMap p) v) :
    P6.a.Feasible p (bwd p v) :=
  { hassign := h.hassign
    hcap    := h.hcap
    hx_bin  := h.hx_bin
    hy_bin  := h.hy_bin }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aHEquiv : MILPReformulation P6.a.formulation P6.h.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P6
