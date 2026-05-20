import Common
import problems.p7.formulations.a.Formulation
import problems.p7.formulations.i.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Fintype.Prod
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P7

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P7.a.Params) : P7.i.Params :=
  { N  := p.N
    hN := p.hN }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (p : P7.a.Params) (v : P7.a.Vars p) : P7.i.Vars (paramMap p) :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma strips_covering_eq (N : ℕ) (j : Fin N) :
    P7.a.strips_covering N j = P7.i.strips_covering N j := rfl

private lemma strips_covering_both_subset_j (N : ℕ) (j k : Fin N) :
    P7.i.strips_covering_both N j k ⊆ P7.a.strips_covering N j := by
  intro ab hab
  simp only [P7.i.strips_covering_both, P7.a.strips_covering,
    Finset.mem_filter, Finset.mem_univ, true_and] at hab ⊢
  refine ⟨?_, ?_⟩
  · exact le_trans hab.1 (min_le_left _ _)
  · exact le_trans (le_max_left _ _) hab.2

private lemma strips_covering_both_subset_k (N : ℕ) (j k : Fin N) :
    P7.i.strips_covering_both N j k ⊆ P7.a.strips_covering N k := by
  intro ab hab
  simp only [P7.i.strips_covering_both, P7.a.strips_covering,
    Finset.mem_filter, Finset.mem_univ, true_and] at hab ⊢
  refine ⟨?_, ?_⟩
  · exact le_trans hab.1 (min_le_right _ _)
  · exact le_trans (le_max_right _ _) hab.2

section ForwardHelpers

variable {p : P7.a.Params} {v : P7.a.Vars p} (h : P7.a.Feasible p v)
include h

private lemma fwd_t_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.t i ab.1 ab.2 := by
  rcases h.ht_bin i ab with h0 | h1 <;> omega

private lemma fwd_s_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.s i ab.1 ab.2 := by
  rcases h.hs_bin i ab with h0 | h1 <;> omega

private lemma fwd_x_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.x i ab.1 ab.2 := by
  rcases h.hx_bin i ab with h0 | h1 <;> omega

private lemma fwd_h_nn (i : Fin p.N) (j : Fin p.N) :
    0 ≤ v.h i j := by
  rcases h.hh_bin i j with h0 | h1 <;> omega

end ForwardHelpers

private lemma fwd_ec2 (p : P7.a.Params) (v : P7.a.Vars p)
    (hfeas : P7.a.Feasible p v) (i : Fin p.N) (j k : Fin p.N)
    (hi_pos : 0 < i.val) (hjk : j ≠ k) :
    (∑ ab ∈ P7.i.strips_covering_both p.N j k,
        v.x ⟨i.val - 1, by omega⟩ ab.1 ab.2 : ℤ) +
        v.h i k - 1 ≤
      ∑ ab ∈ P7.i.strips_covering p.N j, v.s i ab.1 ab.2 := by
  haveI := p.hN
  have hi_prev_lt : i.val - 1 < p.N := lt_of_le_of_lt (Nat.sub_le _ _) i.isLt
  let iPrev : Fin p.N := ⟨i.val - 1, hi_prev_lt⟩
  have hCjk_sub_Cj : P7.i.strips_covering_both p.N j k ⊆ P7.a.strips_covering p.N j :=
    strips_covering_both_subset_j p.N j k
  have hCjk_sub_Ck : P7.i.strips_covering_both p.N j k ⊆ P7.a.strips_covering p.N k :=
    strips_covering_both_subset_k p.N j k
  have hflow_pt : ∀ ab : Fin p.N × Fin p.N,
      v.x i ab.1 ab.2 - v.x iPrev ab.1 ab.2 -
        v.s i ab.1 ab.2 + v.t iPrev ab.1 ab.2 = 0 := by
    intro ab
    exact hfeas.hflow i ab hi_pos
  have hsum_flow_Cjk :
      (∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x i ab.1 ab.2) -
      (∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x iPrev ab.1 ab.2) -
      (∑ ab ∈ P7.i.strips_covering_both p.N j k, v.s i ab.1 ab.2) +
      (∑ ab ∈ P7.i.strips_covering_both p.N j k, v.t iPrev ab.1 ab.2) = 0 := by
    have hzero :
        ∑ ab ∈ P7.i.strips_covering_both p.N j k,
          (v.x i ab.1 ab.2 - v.x iPrev ab.1 ab.2 -
            v.s i ab.1 ab.2 + v.t iPrev ab.1 ab.2) = 0 := by
      apply Finset.sum_eq_zero
      intro ab _
      exact hflow_pt ab
    have := hzero
    simp only [Finset.sum_add_distrib, Finset.sum_sub_distrib] at this
    linarith
  have hsum_flow_Cj :
      (∑ ab ∈ P7.a.strips_covering p.N j, v.x i ab.1 ab.2) -
      (∑ ab ∈ P7.a.strips_covering p.N j, v.x iPrev ab.1 ab.2) -
      (∑ ab ∈ P7.a.strips_covering p.N j, v.s i ab.1 ab.2) +
      (∑ ab ∈ P7.a.strips_covering p.N j, v.t iPrev ab.1 ab.2) = 0 := by
    have hzero :
        ∑ ab ∈ P7.a.strips_covering p.N j,
          (v.x i ab.1 ab.2 - v.x iPrev ab.1 ab.2 -
            v.s i ab.1 ab.2 + v.t iPrev ab.1 ab.2) = 0 := by
      apply Finset.sum_eq_zero
      intro ab _
      exact hflow_pt ab
    have := hzero
    simp only [Finset.sum_add_distrib, Finset.sum_sub_distrib] at this
    linarith
  have hcov_i_j : (∑ ab ∈ P7.a.strips_covering p.N j, v.x i ab.1 ab.2) +
      v.h i j = 1 := hfeas.hcov i j
  have hcov_iPrev_j :
      (∑ ab ∈ P7.a.strips_covering p.N j, v.x iPrev ab.1 ab.2) +
      v.h iPrev j = 1 := hfeas.hcov iPrev j
  have hcov_i_k :
      (∑ ab ∈ P7.a.strips_covering p.N k, v.x i ab.1 ab.2) +
      v.h i k = 1 := hfeas.hcov i k
  have hrow_i : ∑ l : Fin p.N, v.h i l = 1 := hfeas.hrow i
  have hhjk_le_1 : v.h i j + v.h i k ≤ 1 := by
    let g : Fin p.N → ℤ := fun l => v.h i l
    have hrow_g : ∑ l : Fin p.N, g l = 1 := hrow_i
    have hj_in : j ∈ (univ : Finset (Fin p.N)) := mem_univ _
    have hk_in : k ∈ (univ : Finset (Fin p.N)).erase j :=
      Finset.mem_erase.mpr ⟨Ne.symm hjk, mem_univ _⟩
    have hstep1 : g j + ∑ l ∈ (univ : Finset (Fin p.N)).erase j, g l = 1 := by
      rw [Finset.add_sum_erase (univ : Finset (Fin p.N)) g hj_in]; exact hrow_g
    have hstep2 : g k +
        ∑ l ∈ ((univ : Finset (Fin p.N)).erase j).erase k, g l =
        ∑ l ∈ (univ : Finset (Fin p.N)).erase j, g l :=
      Finset.add_sum_erase ((univ : Finset (Fin p.N)).erase j) g hk_in
    have hrest_nn : 0 ≤ ∑ l ∈ ((univ : Finset (Fin p.N)).erase j).erase k, g l :=
      Finset.sum_nonneg (fun l _ => fwd_h_nn hfeas i l)
    show g j + g k ≤ 1
    linarith
  have hx_Cjk_le_Ck : ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x i ab.1 ab.2 ≤
      ∑ ab ∈ P7.a.strips_covering p.N k, v.x i ab.1 ab.2 := by
    apply Finset.sum_le_sum_of_subset_of_nonneg hCjk_sub_Ck
    intro ab _ _; exact fwd_x_nn hfeas i ab
  have hs_Cj_nn : 0 ≤ ∑ ab ∈ P7.a.strips_covering p.N j, v.s i ab.1 ab.2 :=
    Finset.sum_nonneg (fun ab _ => fwd_s_nn hfeas i ab)
  have ht_Cj_nn : 0 ≤ ∑ ab ∈ P7.a.strips_covering p.N j, v.t iPrev ab.1 ab.2 :=
    Finset.sum_nonneg (fun ab _ => fwd_t_nn hfeas iPrev ab)
  have ht_Cjk_le_Cj :
      ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.t iPrev ab.1 ab.2 ≤
      ∑ ab ∈ P7.a.strips_covering p.N j, v.t iPrev ab.1 ab.2 := by
    apply Finset.sum_le_sum_of_subset_of_nonneg hCjk_sub_Cj
    intro ab _ _; exact fwd_t_nn hfeas iPrev ab
  have hh_prev_j_nn : 0 ≤ v.h iPrev j := fwd_h_nn hfeas iPrev j
  have hA_prev_le_Cj :
      ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x iPrev ab.1 ab.2 ≤
      ∑ ab ∈ P7.a.strips_covering p.N j, v.x iPrev ab.1 ab.2 := by
    apply Finset.sum_le_sum_of_subset_of_nonneg hCjk_sub_Cj
    intro ab _ _; exact fwd_x_nn hfeas iPrev ab
  -- Translate: the goal's `⟨i.val - 1, _⟩` is `iPrev` definitionally.
  show (∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x iPrev ab.1 ab.2 : ℤ) +
        v.h i k - 1 ≤
      ∑ ab ∈ P7.i.strips_covering p.N j, v.s i ab.1 ab.2
  rw [← strips_covering_eq]
  rcases hfeas.hh_bin i k with hk0 | hk1
  · rw [hk0]
    linarith
  · have hij0 : v.h i j = 0 := by
      rcases hfeas.hh_bin i j with h0 | h1
      · exact h0
      · exfalso; rw [h1, hk1] at hhjk_le_1; linarith
    rw [hk1]
    have hx_Ck_eq_zero :
        ∑ ab ∈ P7.a.strips_covering p.N k, v.x i ab.1 ab.2 = 0 := by
      rw [hk1] at hcov_i_k; linarith
    have hAi_nn : 0 ≤ ∑ ab ∈ P7.i.strips_covering_both p.N j k,
        v.x i ab.1 ab.2 :=
      Finset.sum_nonneg (fun ab _ => fwd_x_nn hfeas i ab)
    have hAi_eq_zero :
        ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x i ab.1 ab.2 = 0 := by
      linarith
    have hs_Cjk_nn : 0 ≤ ∑ ab ∈ P7.i.strips_covering_both p.N j k,
        v.s i ab.1 ab.2 :=
      Finset.sum_nonneg (fun ab _ => fwd_s_nn hfeas i ab)
    have hSt_Cjk_ge_Aprev :
        ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x iPrev ab.1 ab.2 ≤
        ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.t iPrev ab.1 ab.2 := by
      have H := hsum_flow_Cjk
      rw [hAi_eq_zero] at H
      linarith
    have hxi_Cj : (∑ ab ∈ P7.a.strips_covering p.N j, v.x i ab.1 ab.2) =
        1 - v.h i j := by linarith
    have hxprev_Cj :
        (∑ ab ∈ P7.a.strips_covering p.N j, v.x iPrev ab.1 ab.2) =
        1 - v.h iPrev j := by linarith
    linarith

private lemma fwd_feas (p : P7.a.Params) (v : P7.a.Vars p)
    (h : P7.a.Feasible p v) :
    P7.i.Feasible (paramMap p) (fwd p v) := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro i; exact h.hrow i
  · intro j; exact h.hcol j
  · intro i j; exact h.hcov i j
  · intro ab; exact h.htop ab
  · intro i ab hi; exact h.hflow i ab hi
  · intro ab; exact h.hbot ab
  · intro i j; exact h.hh_bin i j
  · intro i ab; exact h.hx_bin i ab
  · intro i ab; exact h.hs_bin i ab
  · intro i ab; exact h.ht_bin i ab
  · intro i j k hi_pos hjk; exact fwd_ec2 p v h i j k hi_pos hjk

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P7.a.Params) (v : P7.i.Vars (paramMap p)) : P7.a.Vars p :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma bwd_feas (p : P7.a.Params) (v : P7.i.Vars (paramMap p))
    (h : P7.i.Feasible (paramMap p) v) :
    P7.a.Feasible p (bwd p v) := by
  exact
    { hrow   := h.hrow
      hcol   := h.hcol
      hcov   := h.hcov
      htop   := h.htop
      hflow  := h.hflow
      hbot   := h.hbot
      hh_bin := h.hh_bin
      hx_bin := h.hx_bin
      hs_bin := h.hs_bin
      ht_bin := h.ht_bin }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aIReformulation : MILPReformulation P7.a.formulation P7.i.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P7
