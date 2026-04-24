import Common
import dataset.problems.p7.formulations.a.Formulation
import dataset.problems.p7.formulations.e.Formulation
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

private def paramMap (p : P7.a.Params) : P7.e.Params :=
  { N  := p.N
    hN := p.hN }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- fwd is the identity on variables; e adds the EC4 cut, which we must prove.
private def fwd (_ : P7.a.Params) (v : P7.a.Vars) : P7.e.Vars :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

-- strips_covering agrees between a and e (both defined identically).
private lemma strips_covering_eq (N : ℕ) (j : Fin N) :
    P7.a.strips_covering N j = P7.e.strips_covering N j := rfl

section ForwardHelpers

variable {p : P7.a.Params} {v : P7.a.Vars} (h : P7.a.Feasible p v)
include h

-- Nonnegativity on Fin indices.
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

-- The EC4 lemma: a hole in the bottom row forces a strip end in row N-2
-- covering the same column, provided N ≥ 2.
private lemma fwd_ec4 (p : P7.a.Params) (v : P7.a.Vars)
    (hfeas : P7.a.Feasible p v) (j : Fin p.N) (hN : 1 < p.N) :
    v.h (p.N - 1) j.val ≤
      ∑ ab ∈ P7.e.strips_covering p.N j,
        v.t (p.N - 2) ab.1.val ab.2.val := by
  haveI := p.hN
  -- Construct Fin-valued indices for rows N-1 and N-2.
  have hN1_lt : p.N - 1 < p.N := Nat.sub_lt (by omega) Nat.one_pos
  have hN2_lt : p.N - 2 < p.N := Nat.sub_lt (by omega) (by omega)
  let iLast : Fin p.N := ⟨p.N - 1, hN1_lt⟩
  let iPrev : Fin p.N := ⟨p.N - 2, hN2_lt⟩
  have hiLast_pos : 0 < iLast.val := by
    show 0 < p.N - 1; omega
  have hiPrev_succ : iLast.val - 1 = iPrev.val := by
    show p.N - 1 - 1 = p.N - 2; omega
  -- Flow balance at row N-1, summed over strips covering column j:
  -- ∑ v.x (N-1) ab - ∑ v.x (N-2) ab - ∑ v.s (N-1) ab + ∑ v.t (N-2) ab = 0
  have hflow_pt : ∀ ab : Fin p.N × Fin p.N,
      ab ∈ P7.a.strips_covering p.N j →
      v.x iLast.val ab.1.val ab.2.val - v.x iPrev.val ab.1.val ab.2.val -
        v.s iLast.val ab.1.val ab.2.val + v.t iPrev.val ab.1.val ab.2.val = 0 := by
    intro ab _
    have hf := hfeas.hflow iLast ab hiLast_pos
    -- Rewrite iLast.val - 1 to iPrev.val.
    rw [hiPrev_succ] at hf
    exact hf
  -- Sum the flow equation over strips_covering.
  have hsum_flow :
      ∑ ab ∈ P7.a.strips_covering p.N j,
        (v.x iLast.val ab.1.val ab.2.val - v.x iPrev.val ab.1.val ab.2.val -
          v.s iLast.val ab.1.val ab.2.val + v.t iPrev.val ab.1.val ab.2.val) = 0 := by
    apply Finset.sum_eq_zero
    intro ab hab
    exact hflow_pt ab hab
  -- Expand the sum into four separate sums.
  have hsum_expand :
      (∑ ab ∈ P7.a.strips_covering p.N j, v.x iLast.val ab.1.val ab.2.val) -
      (∑ ab ∈ P7.a.strips_covering p.N j, v.x iPrev.val ab.1.val ab.2.val) -
      (∑ ab ∈ P7.a.strips_covering p.N j, v.s iLast.val ab.1.val ab.2.val) +
      (∑ ab ∈ P7.a.strips_covering p.N j, v.t iPrev.val ab.1.val ab.2.val) = 0 := by
    have := hsum_flow
    simp only [Finset.sum_add_distrib, Finset.sum_sub_distrib] at this
    linarith
  -- Coverage at (iLast, j): ∑ v.x (N-1) ab + v.h (N-1) j = 1
  have hcov_last : ∑ ab ∈ P7.a.strips_covering p.N j,
      v.x iLast.val ab.1.val ab.2.val + v.h iLast.val j.val = 1 :=
    hfeas.hcov iLast j
  -- Coverage at (iPrev, j): ∑ v.x (N-2) ab + v.h (N-2) j = 1
  have hcov_prev : ∑ ab ∈ P7.a.strips_covering p.N j,
      v.x iPrev.val ab.1.val ab.2.val + v.h iPrev.val j.val = 1 :=
    hfeas.hcov iPrev j
  -- From hcol at column j: ∑_i v.h i j = 1
  have hcol_j : ∑ i : Fin p.N, v.h i.val j.val = 1 := hfeas.hcol j
  -- Each v.h is binary.
  have hh_bin := hfeas.hh_bin
  -- Each v.s, v.t is binary (hence nonneg).
  have hs_nn : ∀ ab ∈ P7.a.strips_covering p.N j,
      0 ≤ v.s iLast.val ab.1.val ab.2.val := by
    intro ab _; exact fwd_s_nn hfeas iLast ab
  have ht_nn : ∀ ab ∈ P7.a.strips_covering p.N j,
      0 ≤ v.t iPrev.val ab.1.val ab.2.val := by
    intro ab _; exact fwd_t_nn hfeas iPrev ab
  have hsum_s_nn : 0 ≤ ∑ ab ∈ P7.a.strips_covering p.N j,
      v.s iLast.val ab.1.val ab.2.val := Finset.sum_nonneg hs_nn
  -- Goal: v.h (p.N - 1) j.val ≤ ∑ v.t (p.N - 2) ab. Convert to iLast/iPrev form.
  rw [← strips_covering_eq]
  show v.h iLast.val j.val ≤
      ∑ ab ∈ P7.a.strips_covering p.N j, v.t iPrev.val ab.1.val ab.2.val

  -- Case split on v.h (N-1) j.
  rcases hfeas.hh_bin iLast j with hh0 | hh1
  · -- v.h (N-1) j = 0. Then goal is 0 ≤ ∑ v.t (N-2) ab.
    rw [hh0]
    exact Finset.sum_nonneg ht_nn
  · -- v.h (N-1) j = 1. Goal: 1 ≤ ∑ v.t (N-2) ab.
    rw [hh1]
    -- From hcol: since v.h (iLast) j = 1 and each term binary, all other v.h i j = 0.
    -- In particular v.h (iPrev) j = 0.
    have hh_prev_zero : v.h iPrev.val j.val = 0 := by
      -- iPrev ≠ iLast since N ≥ 2.
      have hne : iPrev ≠ iLast := by
        intro hEq
        have : iPrev.val = iLast.val := by rw [hEq]
        show False
        have : p.N - 2 = p.N - 1 := this
        omega
      -- Split the sum: v.h iLast j + v.h iPrev j + rest = 1
      have hiLast_in : iLast ∈ (univ : Finset (Fin p.N)) := mem_univ _
      have hiPrev_in : iPrev ∈ (univ : Finset (Fin p.N)).erase iLast :=
        Finset.mem_erase.mpr ⟨hne, mem_univ _⟩
      let fH : Fin p.N → ℤ := fun k => v.h k.val j.val
      have hstep1 : fH iLast +
          ∑ k ∈ (univ : Finset (Fin p.N)).erase iLast, fH k = 1 := by
        rw [Finset.add_sum_erase _ fH hiLast_in]
        exact hcol_j
      have hstep2 : fH iPrev +
          ∑ k ∈ ((univ : Finset (Fin p.N)).erase iLast).erase iPrev, fH k =
          ∑ k ∈ (univ : Finset (Fin p.N)).erase iLast, fH k :=
        Finset.add_sum_erase _ fH hiPrev_in
      have hrest_nn : 0 ≤ ∑ k ∈ ((univ : Finset (Fin p.N)).erase iLast).erase iPrev, fH k :=
        Finset.sum_nonneg (fun k _ => fwd_h_nn hfeas k j)
      have hh_prev_bin := hfeas.hh_bin iPrev j
      rcases hh_prev_bin with hp0 | hp1
      · exact hp0
      · exfalso
        have hstep1' : v.h iLast.val j.val +
            ∑ k ∈ (univ : Finset (Fin p.N)).erase iLast, fH k = 1 := hstep1
        have hstep2' : v.h iPrev.val j.val +
            ∑ k ∈ ((univ : Finset (Fin p.N)).erase iLast).erase iPrev, fH k =
            ∑ k ∈ (univ : Finset (Fin p.N)).erase iLast, fH k := hstep2
        rw [hh1] at hstep1'
        rw [hp1] at hstep2'
        linarith
    -- Now from hsum_expand and hcov_last and hcov_prev:
    -- (∑ x_{N-1}) = 1 - v.h (N-1) j = 0
    -- (∑ x_{N-2}) = 1 - v.h (N-2) j = 1
    have hsum_x_last : ∑ ab ∈ P7.a.strips_covering p.N j,
        v.x iLast.val ab.1.val ab.2.val = 0 := by
      have := hcov_last
      rw [hh1] at this; linarith
    have hsum_x_prev : ∑ ab ∈ P7.a.strips_covering p.N j,
        v.x iPrev.val ab.1.val ab.2.val = 1 := by
      have := hcov_prev
      rw [hh_prev_zero] at this; linarith
    -- Substitute into hsum_expand: 0 - 1 - (∑ s) + (∑ t) = 0, so (∑ t) = 1 + (∑ s) ≥ 1.
    rw [hsum_x_last, hsum_x_prev] at hsum_expand
    linarith

private lemma fwd_feas (p : P7.a.Params) (v : P7.a.Vars)
    (h : P7.a.Feasible p v) :
    P7.e.Feasible (paramMap p) (fwd p v) := by
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
  · intro j hN; exact fwd_ec4 p v h j hN

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- bwd simply drops the EC4 cut.
private def bwd (_ : P7.a.Params) (v : P7.e.Vars) : P7.a.Vars :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma bwd_feas (p : P7.a.Params) (v : P7.e.Vars)
    (h : P7.e.Feasible (paramMap p) v) :
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

def aEEquiv : MILPEquiv P7.a.formulation P7.e.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P7
