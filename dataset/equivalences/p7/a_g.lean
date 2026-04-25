import Common
import dataset.problems.p7.formulations.a.Formulation
import dataset.problems.p7.formulations.g.Formulation
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

private def paramMap (p : P7.a.Params) : P7.g.Params :=
  { N  := p.N
    hN := p.hN }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- fwd is the identity on variables; g adds the EC6 cut, which we must prove.
private def fwd (_ : P7.a.Params) (v : P7.a.Vars) : P7.g.Vars :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

-- strips_covering in P7.a and P7.g are identical.
private lemma strips_covering_eq (N : ℕ) (j : Fin N) :
    P7.a.strips_covering N j = P7.g.strips_covering N j := rfl

section ForwardHelpers

variable {p : P7.a.Params} {v : P7.a.Vars} (h : P7.a.Feasible p v)
include h

-- Helper: sum of x over strips_covering j in row i equals 1 minus h i j.
private lemma sum_x_eq (i j : Fin p.N) :
    ∑ ab ∈ P7.a.strips_covering p.N j, v.x i.val ab.1.val ab.2.val = 1 - v.h i.val j.val := by
  have := h.hcov i j
  linarith

-- Helper: t values are non-negative (for Fin indices).
private lemma t_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.t i.val ab.1.val ab.2.val := by
  rcases h.ht_bin i ab with h0 | h1 <;> omega

-- Helper: s values are non-negative (for Fin indices).
private lemma s_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.s i.val ab.1.val ab.2.val := by
  rcases h.hs_bin i ab with h0 | h1 <;> omega

-- Helper: h values are non-negative.
private lemma h_nn (i j : Fin p.N) :
    0 ≤ v.h i.val j.val := by
  rcases h.hh_bin i j with h0 | h1 <;> omega

end ForwardHelpers

-- The key EC6 proof.
private lemma fwd_ec6 (p : P7.a.Params) (v : P7.a.Vars)
    (h : P7.a.Feasible p v) :
    ∀ i : Fin p.N, ∀ j : Fin p.N, 0 < i.val → i.val + 1 < p.N →
      v.h i.val j.val ≤
        ∑ ab ∈ P7.g.strips_covering p.N j, v.s (i.val + 1) ab.1.val ab.2.val := by
  intro i j hi_pos hi_succ_lt
  -- Let ip1 : Fin p.N be i+1.
  let ip1 : Fin p.N := ⟨i.val + 1, hi_succ_lt⟩
  have hip1_val : ip1.val = i.val + 1 := rfl
  have hip1_pos : 0 < ip1.val := by simp [hip1_val]
  have hip1_sub : ip1.val - 1 = i.val := by simp [hip1_val]
  -- Sum hcov at row i, col j: ∑ x i ab + h i j = 1
  have hcov_i : ∑ ab ∈ P7.a.strips_covering p.N j, v.x i.val ab.1.val ab.2.val
              = 1 - v.h i.val j.val := sum_x_eq h i j
  -- Sum hcov at row ip1, col j: ∑ x (i+1) ab + h (i+1) j = 1
  have hcov_ip1 : ∑ ab ∈ P7.a.strips_covering p.N j, v.x ip1.val ab.1.val ab.2.val
                = 1 - v.h ip1.val j.val := sum_x_eq h ip1 j
  -- Sum hflow at row ip1 over ab ∈ strips_covering j.
  have hflow_sum :
      ∑ ab ∈ P7.a.strips_covering p.N j,
        (v.x ip1.val ab.1.val ab.2.val - v.x (ip1.val - 1) ab.1.val ab.2.val
         - v.s ip1.val ab.1.val ab.2.val + v.t (ip1.val - 1) ab.1.val ab.2.val) = 0 := by
    apply Finset.sum_eq_zero
    intro ab _
    exact h.hflow ip1 ab hip1_pos
  -- Split the sum.
  have hsplit :
      ∑ ab ∈ P7.a.strips_covering p.N j, v.x ip1.val ab.1.val ab.2.val
      - ∑ ab ∈ P7.a.strips_covering p.N j, v.x (ip1.val - 1) ab.1.val ab.2.val
      - ∑ ab ∈ P7.a.strips_covering p.N j, v.s ip1.val ab.1.val ab.2.val
      + ∑ ab ∈ P7.a.strips_covering p.N j, v.t (ip1.val - 1) ab.1.val ab.2.val = 0 := by
    rw [← hflow_sum]
    rw [Finset.sum_add_distrib, Finset.sum_sub_distrib, Finset.sum_sub_distrib]
  -- Substitute ip1.val - 1 = i.val.
  rw [hip1_sub] at hsplit
  -- Use hcov.
  rw [hcov_i, hcov_ip1] at hsplit
  -- hsplit : (1 - h(i+1)j) - (1 - h(i)j) - ∑s(i+1) + ∑t(i) = 0
  -- So ∑s(i+1) = h(i)j - h(i+1)j + ∑t(i).
  -- Non-negativity of ∑t(i):
  have ht_nn : 0 ≤ ∑ ab ∈ P7.a.strips_covering p.N j,
      v.t i.val ab.1.val ab.2.val :=
    Finset.sum_nonneg (fun ab _ => t_nn h i ab)
  -- Case split on h i j (binary).
  rcases h.hh_bin i j with hhij0 | hhij1
  · -- h i j = 0: RHS ≥ 0 by s non-negativity.
    rw [hhij0]
    rw [strips_covering_eq p.N j] at *
    exact Finset.sum_nonneg (fun ab _ => by
      -- Need 0 ≤ v.s (i.val + 1) ab.1.val ab.2.val
      -- But ab is in strips_covering, indexed by Fin p.N × Fin p.N.
      -- We need ip1 as Fin p.N for s_nn.
      have := s_nn h ip1 ab
      simpa [hip1_val] using this)
  · -- h i j = 1. Then from column j hole uniqueness, h(i+1)j = 0.
    -- Use hcol j: ∑_{k : Fin p.N} v.h k.val j.val = 1.
    have hcol := h.hcol j
    -- Extract the term at k = i and k = ip1.
    have hi_ne_ip1 : i ≠ ip1 := by
      intro heq
      have : i.val = ip1.val := by rw [heq]
      simp [hip1_val] at this
    -- Sum: v.h i.val j.val + ∑ k ≠ i, v.h k.val j.val = 1.
    have hsplit_col : v.h i.val j.val +
        ∑ k ∈ (univ : Finset (Fin p.N)).erase i, v.h k.val j.val = 1 := by
      have := Finset.add_sum_erase (univ : Finset (Fin p.N))
        (fun k : Fin p.N => v.h k.val j.val) (mem_univ i)
      rw [this]; exact hcol
    rw [hhij1] at hsplit_col
    have hrest_zero : ∑ k ∈ (univ : Finset (Fin p.N)).erase i, v.h k.val j.val = 0 := by
      linarith
    -- Since ip1 ∈ erase i, and all terms non-neg, h ip1 j = 0.
    have hip1_in : ip1 ∈ (univ : Finset (Fin p.N)).erase i :=
      Finset.mem_erase.mpr ⟨Ne.symm hi_ne_ip1, mem_univ _⟩
    have hrest_nn : ∀ k ∈ (univ : Finset (Fin p.N)).erase i,
        0 ≤ v.h k.val j.val := fun k _ => h_nn h k j
    have hh_ip1 : v.h ip1.val j.val = 0 := by
      have := Finset.sum_eq_zero_iff_of_nonneg hrest_nn |>.mp hrest_zero ip1 hip1_in
      exact this
    -- Now hsplit becomes: (1 - 0) - (1 - 1) - ∑s(i+1) + ∑t(i) = 0
    -- i.e., 1 - ∑s(i+1) + ∑t(i) = 0, so ∑s(i+1) = 1 + ∑t(i) ≥ 1 = h i j.
    rw [hhij1, hh_ip1] at hsplit
    -- hsplit is in terms of strips_covering; goal uses P7.g.strips_covering.
    rw [strips_covering_eq p.N j] at hsplit
    rw [hhij1]
    -- Now show 1 ≤ ∑ s(i.val+1)
    have hsum_s_ge :
        (1 : ℤ) ≤ ∑ ab ∈ P7.g.strips_covering p.N j,
          v.s (i.val + 1) ab.1.val ab.2.val := by
      -- rewrite sum over P7.a.strips_covering as same as P7.g.strips_covering
      rw [strips_covering_eq p.N j] at ht_nn
      -- hsplit : (1 - 0) - (1 - 1) - ∑s + ∑t = 0
      -- Rewrite the s sum to match i.val + 1 = ip1.val
      linarith
    exact hsum_s_ge

-- ============================================================================
-- § fwd_feas
-- ============================================================================

private lemma fwd_feas (p : P7.a.Params) (v : P7.a.Vars)
    (h : P7.a.Feasible p v) :
    P7.g.Feasible (paramMap p) (fwd p v) := by
  refine
    { hrow := h.hrow
      hcol := h.hcol
      hcov := h.hcov
      htop := h.htop
      hflow := h.hflow
      hbot := h.hbot
      hh_bin := h.hh_bin
      hx_bin := h.hx_bin
      hs_bin := h.hs_bin
      ht_bin := h.ht_bin
      hintBreakBelow := ?_ }
  exact fwd_ec6 p v h

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- bwd simply drops the EC6 cut.
private def bwd (_ : P7.a.Params) (v : P7.g.Vars) : P7.a.Vars :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma bwd_feas (p : P7.a.Params) (v : P7.g.Vars)
    (h : P7.g.Feasible (paramMap p) v) :
    P7.a.Feasible p (bwd p v) := by
  exact
    { hrow := h.hrow
      hcol := h.hcol
      hcov := h.hcov
      htop := h.htop
      hflow := h.hflow
      hbot := h.hbot
      hh_bin := h.hh_bin
      hx_bin := h.hx_bin
      hs_bin := h.hs_bin
      ht_bin := h.ht_bin }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aGEquiv : MILPEquiv P7.a.formulation P7.g.formulation where
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
