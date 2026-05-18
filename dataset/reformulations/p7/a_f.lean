import Common
import problems.p7.formulations.a.Formulation
import problems.p7.formulations.f.Formulation
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

private def paramMap (p : P7.a.Params) : P7.f.Params :=
  { N  := p.N
    hN := p.hN }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (p : P7.a.Params) (v : P7.a.Vars p) : P7.f.Vars (paramMap p) :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

section ForwardHelpers

variable {p : P7.a.Params} {v : P7.a.Vars p} (h : P7.a.Feasible p v)
include h

private lemma fwd_h_nn (i j : Fin p.N) : 0 ≤ v.h i j := by
  rcases h.hh_bin i j with h0 | h1 <;> omega

private lemma fwd_x_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.x i ab.1 ab.2 := by
  rcases h.hx_bin i ab with h0 | h1 <;> omega

private lemma fwd_t_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.t i ab.1 ab.2 := by
  rcases h.ht_bin i ab with h0 | h1 <;> omega

private lemma fwd_s_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.s i ab.1 ab.2 := by
  rcases h.hs_bin i ab with h0 | h1 <;> omega

-- If there is a hole at (i, j), then for any row i' ≠ i (in Fin p.N),
-- v.h i' j = 0. Follows from hcol and binarity.
private lemma fwd_hole_unique_in_col (j : Fin p.N) (i i' : Fin p.N)
    (hne : i' ≠ i) (hij : v.h i j = 1) :
    v.h i' j = 0 := by
  have hsum := h.hcol j
  have hin : i ∈ (univ : Finset (Fin p.N)).erase i' :=
    Finset.mem_erase.mpr ⟨(hne.symm), mem_univ _⟩
  have hsplit :
      v.h i' j + ∑ k ∈ (univ : Finset (Fin p.N)).erase i',
        v.h k j = 1 := by
    rw [Finset.add_sum_erase _ (fun k : Fin p.N => v.h k j)
          (mem_univ i')]
    exact hsum
  have hsplit2 :
      v.h i j +
        ∑ k ∈ ((univ : Finset (Fin p.N)).erase i').erase i,
          v.h k j =
        ∑ k ∈ (univ : Finset (Fin p.N)).erase i', v.h k j :=
    Finset.add_sum_erase _ (fun k : Fin p.N => v.h k j) hin
  have hrest_nn :
      0 ≤ ∑ k ∈ ((univ : Finset (Fin p.N)).erase i').erase i,
              v.h k j :=
    Finset.sum_nonneg (fun k _ => fwd_h_nn h k j)
  rcases h.hh_bin i' j with h0 | h1
  · exact h0
  · exfalso; linarith [hsplit, hsplit2, hrest_nn, hij, h1]

end ForwardHelpers

private lemma fwd_feas (p : P7.a.Params) (v : P7.a.Vars p)
    (h : P7.a.Feasible p v) :
    P7.f.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hN
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
  · -- hintBreakAbove
    intro i j hi_pos hi_lt
    have hi_lt_p : i.val < p.N := show i.val < (paramMap p).N from i.isLt
    have hi_pred_lt : i.val - 1 < p.N := by omega
    let iPred : Fin p.N := ⟨i.val - 1, hi_pred_lt⟩
    -- The goal mentions ⟨i.val - 1, _⟩; this is defeq to iPred.
    rcases h.hh_bin i j with hij0 | hij1
    · -- v.h i j = 0
      show v.h i j ≤
          ∑ ab ∈ P7.f.strips_covering (paramMap p).N j, v.t ⟨i.val - 1, _⟩ ab.1 ab.2
      rw [hij0]
      apply Finset.sum_nonneg
      intro ab _
      change 0 ≤ v.t iPred ab.1 ab.2
      exact fwd_t_nn h iPred ab
    · -- v.h i j = 1
      show v.h i j ≤
          ∑ ab ∈ P7.f.strips_covering (paramMap p).N j, v.t ⟨i.val - 1, _⟩ ab.1 ab.2
      rw [hij1]
      have hcovi := h.hcov i j
      have hsumx_i :
          ∑ ab ∈ P7.a.strips_covering p.N j, v.x i ab.1 ab.2 = 0 := by
        linarith
      have hne : iPred ≠ i := by
        intro heq
        have : i.val - 1 = i.val := by
          have := congrArg Fin.val heq
          simpa [iPred] using this
        omega
      have hh_pred : v.h iPred j = 0 :=
        fwd_hole_unique_in_col (p := p) (v := v) h j i iPred hne hij1
      have hcov_pred := h.hcov iPred j
      have hsumx_pred :
          ∑ ab ∈ P7.a.strips_covering p.N j,
            v.x iPred ab.1 ab.2 = 1 := by
        linarith [hcov_pred, hh_pred]
      have hstrips_eq :
          P7.f.strips_covering (paramMap p).N j = P7.a.strips_covering p.N j := rfl
      -- Sum of flow equations over ab ∈ strips_covering p.N j.
      have hsum_t :
          ∑ ab ∈ P7.a.strips_covering p.N j,
              v.t iPred ab.1 ab.2 =
          (∑ ab ∈ P7.a.strips_covering p.N j,
              v.x iPred ab.1 ab.2)
          - (∑ ab ∈ P7.a.strips_covering p.N j,
              v.x i ab.1 ab.2)
          + (∑ ab ∈ P7.a.strips_covering p.N j,
              v.s i ab.1 ab.2) := by
        rw [← Finset.sum_sub_distrib, ← Finset.sum_add_distrib]
        apply Finset.sum_congr rfl
        intro ab _
        have hflow := h.hflow i ab hi_pos
        -- hflow uses ⟨i.val - 1, _⟩; that's defeq to iPred.
        change v.x i ab.1 ab.2 - v.x iPred ab.1 ab.2 -
            v.s i ab.1 ab.2 + v.t iPred ab.1 ab.2 = 0 at hflow
        linarith
      have hs_nn :
          0 ≤ ∑ ab ∈ P7.a.strips_covering p.N j, v.s i ab.1 ab.2 :=
        Finset.sum_nonneg (fun ab _ => fwd_s_nn h i ab)
      change (1 : ℤ) ≤
          ∑ ab ∈ P7.f.strips_covering (paramMap p).N j, v.t iPred ab.1 ab.2
      rw [hstrips_eq]
      have hxprev : ∑ ab ∈ P7.a.strips_covering p.N j, v.x iPred ab.1 ab.2 = 1 := hsumx_pred
      have hxi : ∑ ab ∈ P7.a.strips_covering p.N j, v.x i ab.1 ab.2 = 0 := hsumx_i
      have hkey : (1 : ℤ) ≤ ∑ ab ∈ P7.a.strips_covering p.N j, v.t iPred ab.1 ab.2 := by
        calc (1 : ℤ) = 1 + 0 := by ring
          _ ≤ 1 + ∑ ab ∈ P7.a.strips_covering p.N j, v.s i ab.1 ab.2 := by linarith
          _ = ∑ ab ∈ P7.a.strips_covering p.N j, v.x iPred ab.1 ab.2
              - ∑ ab ∈ P7.a.strips_covering p.N j, v.x i ab.1 ab.2
              + ∑ ab ∈ P7.a.strips_covering p.N j, v.s i ab.1 ab.2 := by
            rw [hxprev, hxi]; ring
          _ = ∑ ab ∈ P7.a.strips_covering p.N j, v.t iPred ab.1 ab.2 := hsum_t.symm
      exact hkey

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P7.a.Params) (v : P7.f.Vars (paramMap p)) : P7.a.Vars p :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma bwd_feas (p : P7.a.Params) (v : P7.f.Vars (paramMap p))
    (h : P7.f.Feasible (paramMap p) v) :
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

def aFReformulation : MILPReformulation P7.a.formulation P7.f.formulation where
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
