import Common
import dataset.problems.p7.formulations.a.Formulation
import dataset.problems.p7.formulations.i.Formulation
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

-- fwd is the identity on variables; i adds the EC2 (V2) cut, which we must prove.
private def fwd (_ : P7.a.Params) (v : P7.a.Vars) : P7.i.Vars :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

-- strips_covering agrees between a and i (both defined identically).
private lemma strips_covering_eq (N : ℕ) (j : Fin N) :
    P7.a.strips_covering N j = P7.i.strips_covering N j := rfl

-- Any (a,b) that covers both j and k covers j.
private lemma strips_covering_both_subset_j (N : ℕ) (j k : Fin N) :
    P7.i.strips_covering_both N j k ⊆ P7.a.strips_covering N j := by
  intro ab hab
  simp only [P7.i.strips_covering_both, P7.a.strips_covering,
    Finset.mem_filter, Finset.mem_univ, true_and] at hab ⊢
  refine ⟨?_, ?_⟩
  · exact le_trans hab.1 (min_le_left _ _)
  · exact le_trans (le_max_left _ _) hab.2

-- Any (a,b) that covers both j and k covers k.
private lemma strips_covering_both_subset_k (N : ℕ) (j k : Fin N) :
    P7.i.strips_covering_both N j k ⊆ P7.a.strips_covering N k := by
  intro ab hab
  simp only [P7.i.strips_covering_both, P7.a.strips_covering,
    Finset.mem_filter, Finset.mem_univ, true_and] at hab ⊢
  refine ⟨?_, ?_⟩
  · exact le_trans hab.1 (min_le_right _ _)
  · exact le_trans (le_max_right _ _) hab.2

section ForwardHelpers

variable {p : P7.a.Params} {v : P7.a.Vars} (h : P7.a.Feasible p v)
include h

private lemma fwd_t_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.t i.val ab.1.val ab.2.val := by
  rcases h.ht_bin i ab with h0 | h1 <;> omega

private lemma fwd_s_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.s i.val ab.1.val ab.2.val := by
  rcases h.hs_bin i ab with h0 | h1 <;> omega

private lemma fwd_x_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.x i.val ab.1.val ab.2.val := by
  rcases h.hx_bin i ab with h0 | h1 <;> omega

private lemma fwd_h_nn (i : Fin p.N) (j : Fin p.N) :
    0 ≤ v.h i.val j.val := by
  rcases h.hh_bin i j with h0 | h1 <;> omega

end ForwardHelpers

-- The EC2 (V2) "Broken Interval" lemma: if a strip in row i-1 covers both
-- columns j and k and the hole in row i is at column k, then column j must
-- be covered by a new strip start in row i.
private lemma fwd_ec2 (p : P7.a.Params) (v : P7.a.Vars)
    (hfeas : P7.a.Feasible p v) (i : Fin p.N) (j k : Fin p.N)
    (hi_pos : 0 < i.val) (hjk : j ≠ k) :
    (∑ ab ∈ P7.i.strips_covering_both p.N j k,
        v.x (i.val - 1) ab.1.val ab.2.val : ℤ) +
        v.h i.val k.val - 1 ≤
      ∑ ab ∈ P7.i.strips_covering p.N j, v.s i.val ab.1.val ab.2.val := by
  haveI := p.hN
  -- Fin index for row i-1.
  have hi_prev_lt : i.val - 1 < p.N := lt_of_le_of_lt (Nat.sub_le _ _) i.isLt
  let iPrev : Fin p.N := ⟨i.val - 1, hi_prev_lt⟩
  have hiPrev_eq : iPrev.val = i.val - 1 := rfl
  -- Subset facts.
  have hCjk_sub_Cj : P7.i.strips_covering_both p.N j k ⊆ P7.a.strips_covering p.N j :=
    strips_covering_both_subset_j p.N j k
  have hCjk_sub_Ck : P7.i.strips_covering_both p.N j k ⊆ P7.a.strips_covering p.N k :=
    strips_covering_both_subset_k p.N j k
  -- Flow balance at row i, for each ab, pointwise.
  have hflow_pt : ∀ ab : Fin p.N × Fin p.N,
      v.x i.val ab.1.val ab.2.val - v.x iPrev.val ab.1.val ab.2.val -
        v.s i.val ab.1.val ab.2.val + v.t iPrev.val ab.1.val ab.2.val = 0 := by
    intro ab
    exact hfeas.hflow i ab hi_pos
  -- Sum flow balance over Cjk.
  have hsum_flow_Cjk :
      (∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x i.val ab.1.val ab.2.val) -
      (∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x iPrev.val ab.1.val ab.2.val) -
      (∑ ab ∈ P7.i.strips_covering_both p.N j k, v.s i.val ab.1.val ab.2.val) +
      (∑ ab ∈ P7.i.strips_covering_both p.N j k, v.t iPrev.val ab.1.val ab.2.val) = 0 := by
    have hzero :
        ∑ ab ∈ P7.i.strips_covering_both p.N j k,
          (v.x i.val ab.1.val ab.2.val - v.x iPrev.val ab.1.val ab.2.val -
            v.s i.val ab.1.val ab.2.val + v.t iPrev.val ab.1.val ab.2.val) = 0 := by
      apply Finset.sum_eq_zero
      intro ab _
      exact hflow_pt ab
    have := hzero
    simp only [Finset.sum_add_distrib, Finset.sum_sub_distrib] at this
    linarith
  -- Sum flow balance over Cj.
  have hsum_flow_Cj :
      (∑ ab ∈ P7.a.strips_covering p.N j, v.x i.val ab.1.val ab.2.val) -
      (∑ ab ∈ P7.a.strips_covering p.N j, v.x iPrev.val ab.1.val ab.2.val) -
      (∑ ab ∈ P7.a.strips_covering p.N j, v.s i.val ab.1.val ab.2.val) +
      (∑ ab ∈ P7.a.strips_covering p.N j, v.t iPrev.val ab.1.val ab.2.val) = 0 := by
    have hzero :
        ∑ ab ∈ P7.a.strips_covering p.N j,
          (v.x i.val ab.1.val ab.2.val - v.x iPrev.val ab.1.val ab.2.val -
            v.s i.val ab.1.val ab.2.val + v.t iPrev.val ab.1.val ab.2.val) = 0 := by
      apply Finset.sum_eq_zero
      intro ab _
      exact hflow_pt ab
    have := hzero
    simp only [Finset.sum_add_distrib, Finset.sum_sub_distrib] at this
    linarith
  -- Coverage at (i, j): ∑_{ab∈Cj} v.x i ab + v.h i j = 1
  have hcov_i_j : (∑ ab ∈ P7.a.strips_covering p.N j, v.x i.val ab.1.val ab.2.val) +
      v.h i.val j.val = 1 := hfeas.hcov i j
  -- Coverage at (i-1, j).
  have hcov_iPrev_j :
      (∑ ab ∈ P7.a.strips_covering p.N j, v.x iPrev.val ab.1.val ab.2.val) +
      v.h iPrev.val j.val = 1 := hfeas.hcov iPrev j
  -- Coverage at (i, k).
  have hcov_i_k :
      (∑ ab ∈ P7.a.strips_covering p.N k, v.x i.val ab.1.val ab.2.val) +
      v.h i.val k.val = 1 := hfeas.hcov i k
  -- hrow at i: ∑_l v.h i l = 1; in particular h_{i,j} + h_{i,k} ≤ 1.
  have hrow_i : ∑ l : Fin p.N, v.h i.val l.val = 1 := hfeas.hrow i
  have hhjk_le_1 : v.h i.val j.val + v.h i.val k.val ≤ 1 := by
    -- Use explicit function for rewriting.
    let g : Fin p.N → ℤ := fun l => v.h i.val l.val
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
  -- Bound: ∑_{ab∈Cjk} v.x i ab ≤ ∑_{ab∈Ck} v.x i ab.
  have hx_Cjk_le_Ck : ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x i.val ab.1.val ab.2.val ≤
      ∑ ab ∈ P7.a.strips_covering p.N k, v.x i.val ab.1.val ab.2.val := by
    apply Finset.sum_le_sum_of_subset_of_nonneg hCjk_sub_Ck
    intro ab _ _; exact fwd_x_nn hfeas i ab
  -- Nonnegativity sums.
  have hs_Cj_nn : 0 ≤ ∑ ab ∈ P7.a.strips_covering p.N j, v.s i.val ab.1.val ab.2.val :=
    Finset.sum_nonneg (fun ab _ => fwd_s_nn hfeas i ab)
  have ht_Cj_nn : 0 ≤ ∑ ab ∈ P7.a.strips_covering p.N j, v.t iPrev.val ab.1.val ab.2.val :=
    Finset.sum_nonneg (fun ab _ => fwd_t_nn hfeas iPrev ab)
  -- ∑_{ab∈Cjk} v.t (i-1) ab ≤ ∑_{ab∈Cj} v.t (i-1) ab.
  have ht_Cjk_le_Cj :
      ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.t iPrev.val ab.1.val ab.2.val ≤
      ∑ ab ∈ P7.a.strips_covering p.N j, v.t iPrev.val ab.1.val ab.2.val := by
    apply Finset.sum_le_sum_of_subset_of_nonneg hCjk_sub_Cj
    intro ab _ _; exact fwd_t_nn hfeas iPrev ab
  -- Nonnegativity of h (i-1) j.
  have hh_prev_j_nn : 0 ≤ v.h iPrev.val j.val := fwd_h_nn hfeas iPrev j
  -- A_prev ≤ (∑_Cj x_{i-1}) (via subset + nonneg), and ≤ 1.
  have hA_prev_le_Cj :
      ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x iPrev.val ab.1.val ab.2.val ≤
      ∑ ab ∈ P7.a.strips_covering p.N j, v.x iPrev.val ab.1.val ab.2.val := by
    apply Finset.sum_le_sum_of_subset_of_nonneg hCjk_sub_Cj
    intro ab _ _; exact fwd_x_nn hfeas iPrev ab
  -- Rewrite goal to use Cj (instead of P7.i.strips_covering p.N j).
  rw [← strips_covering_eq]
  -- Case split on v.h i k.
  rcases hfeas.hh_bin i k with hk0 | hk1
  · -- v.h i k = 0. LHS = A_prev - 1. A_prev ≤ 1 - v.h (i-1) j ≤ 1. So LHS ≤ 0 ≤ RHS.
    rw [hk0]
    linarith
  · -- v.h i k = 1. Then v.h i j = 0.
    have hij0 : v.h i.val j.val = 0 := by
      rcases hfeas.hh_bin i j with h0 | h1
      · exact h0
      · exfalso; rw [h1, hk1] at hhjk_le_1; linarith
    rw [hk1]
    -- From hcov_i_k with v.h i k = 1: ∑_Ck x_i = 0.
    have hx_Ck_eq_zero :
        ∑ ab ∈ P7.a.strips_covering p.N k, v.x i.val ab.1.val ab.2.val = 0 := by
      rw [hk1] at hcov_i_k; linarith
    -- A_i := ∑_Cjk x_i ≤ ∑_Ck x_i = 0, and A_i ≥ 0, so A_i = 0.
    have hAi_nn : 0 ≤ ∑ ab ∈ P7.i.strips_covering_both p.N j k,
        v.x i.val ab.1.val ab.2.val :=
      Finset.sum_nonneg (fun ab _ => fwd_x_nn hfeas i ab)
    have hAi_eq_zero :
        ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x i.val ab.1.val ab.2.val = 0 := by
      linarith
    -- From hsum_flow_Cjk: 0 - A_prev - S_s_Cjk + S_t_Cjk = 0
    --   => S_t_Cjk ≥ A_prev (since S_s_Cjk ≥ 0).
    have hs_Cjk_nn : 0 ≤ ∑ ab ∈ P7.i.strips_covering_both p.N j k,
        v.s i.val ab.1.val ab.2.val :=
      Finset.sum_nonneg (fun ab _ => fwd_s_nn hfeas i ab)
    have hSt_Cjk_ge_Aprev :
        ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.x iPrev.val ab.1.val ab.2.val ≤
        ∑ ab ∈ P7.i.strips_covering_both p.N j k, v.t iPrev.val ab.1.val ab.2.val := by
      have H := hsum_flow_Cjk
      rw [hAi_eq_zero] at H
      linarith
    -- From hsum_flow_Cj with hcov_i_j, hcov_iPrev_j:
    --   (1 - v.h i j) - (1 - v.h (i-1) j) - (∑_Cj s_i) + (∑_Cj t_{i-1}) = 0
    --   => (∑_Cj s_i) = v.h (i-1) j - v.h i j + (∑_Cj t_{i-1}).
    have hxi_Cj : (∑ ab ∈ P7.a.strips_covering p.N j, v.x i.val ab.1.val ab.2.val) =
        1 - v.h i.val j.val := by linarith
    have hxprev_Cj :
        (∑ ab ∈ P7.a.strips_covering p.N j, v.x iPrev.val ab.1.val ab.2.val) =
        1 - v.h iPrev.val j.val := by linarith
    -- Now combine: goal is A_prev + 1 - 1 ≤ ∑_Cj s_i.
    linarith

private lemma fwd_feas (p : P7.a.Params) (v : P7.a.Vars)
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

-- bwd simply drops the EC2 cut.
private def bwd (_ : P7.a.Params) (v : P7.i.Vars) : P7.a.Vars :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma bwd_feas (p : P7.a.Params) (v : P7.i.Vars)
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
-- § Equivalence Structure
-- ============================================================================

def aIEquiv : MILPEquiv P7.a.formulation P7.i.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := Or.inl strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P7
