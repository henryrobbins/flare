import Common
import dataset.problems.p7.formulations.a.Formulation
import dataset.problems.p7.formulations.f.Formulation
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

-- fwd is the identity on variables; f adds the EC5 cut, which we must prove.
private def fwd (_ : P7.a.Params) (v : P7.a.Vars) : P7.f.Vars :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

section ForwardHelpers

variable {p : P7.a.Params} {v : P7.a.Vars} (h : P7.a.Feasible p v)
include h

private lemma fwd_h_nn (i j : Fin p.N) : 0 ≤ v.h i.val j.val := by
  rcases h.hh_bin i j with h0 | h1 <;> omega

private lemma fwd_x_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.x i.val ab.1.val ab.2.val := by
  rcases h.hx_bin i ab with h0 | h1 <;> omega

private lemma fwd_t_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.t i.val ab.1.val ab.2.val := by
  rcases h.ht_bin i ab with h0 | h1 <;> omega

private lemma fwd_s_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.s i.val ab.1.val ab.2.val := by
  rcases h.hs_bin i ab with h0 | h1 <;> omega

-- If there is a hole at (i, j), then for any row i' ≠ i (in Fin p.N),
-- v.h i' j = 0. Follows from hcol and binarity.
private lemma fwd_hole_unique_in_col (j : Fin p.N) (i i' : Fin p.N)
    (hne : i' ≠ i) (hij : v.h i.val j.val = 1) :
    v.h i'.val j.val = 0 := by
  have hsum := h.hcol j
  have hin : i ∈ (univ : Finset (Fin p.N)).erase i' :=
    Finset.mem_erase.mpr ⟨(hne.symm), mem_univ _⟩
  have hsplit :
      v.h i'.val j.val + ∑ k ∈ (univ : Finset (Fin p.N)).erase i',
        v.h k.val j.val = 1 := by
    rw [Finset.add_sum_erase _ (fun k : Fin p.N => v.h k.val j.val)
          (mem_univ i')]
    exact hsum
  have hsplit2 :
      v.h i.val j.val +
        ∑ k ∈ ((univ : Finset (Fin p.N)).erase i').erase i,
          v.h k.val j.val =
        ∑ k ∈ (univ : Finset (Fin p.N)).erase i', v.h k.val j.val :=
    Finset.add_sum_erase _ (fun k : Fin p.N => v.h k.val j.val) hin
  have hrest_nn :
      0 ≤ ∑ k ∈ ((univ : Finset (Fin p.N)).erase i').erase i,
              v.h k.val j.val :=
    Finset.sum_nonneg (fun k _ => fwd_h_nn h k j)
  rcases h.hh_bin i' j with h0 | h1
  · exact h0
  · exfalso; linarith [hsplit, hsplit2, hrest_nn, hij, h1]

end ForwardHelpers

private lemma fwd_feas (p : P7.a.Params) (v : P7.a.Vars)
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
    -- Reinterpret i, j as Fin p.N (paramMap does not change N).
    have hN_eq : (paramMap p).N = p.N := rfl
    let iN : Fin p.N := ⟨i.val, i.isLt⟩
    let jN : Fin p.N := ⟨j.val, j.isLt⟩
    have hiN_val : iN.val = i.val := rfl
    have hjN_val : jN.val = j.val := rfl
    -- Case split on the hole indicator at (i, j).
    rcases h.hh_bin iN jN with hij0 | hij1
    · -- v.h i j = 0: RHS is nonneg (binary sum).
      show v.h i.val j.val ≤
          ∑ ab ∈ P7.f.strips_covering (paramMap p).N j, v.t (i.val - 1) ab.1.val ab.2.val
      rw [hij0]
      apply Finset.sum_nonneg
      intro ab _
      refine fwd_t_nn h ⟨i.val - 1, ?_⟩ ab
      have := i.isLt
      omega
    · -- v.h i j = 1: use flow + coverage.
      show v.h i.val j.val ≤
          ∑ ab ∈ P7.f.strips_covering (paramMap p).N j, v.t (i.val - 1) ab.1.val ab.2.val
      rw [hij1]
      -- Coverage at (i, j): ∑ x i ab + v.h i j = 1, so ∑ x i ab = 0.
      have hcovi := h.hcov iN jN
      have hsumx_i :
          ∑ ab ∈ P7.a.strips_covering p.N jN, v.x i.val ab.1.val ab.2.val = 0 := by
        linarith
      -- iPred : Fin p.N
      have hi_pred_lt : i.val - 1 < p.N := by
        have := i.isLt
        omega
      let iPred : Fin p.N := ⟨i.val - 1, hi_pred_lt⟩
      have hne : iPred ≠ iN := by
        intro heq
        have : i.val - 1 = i.val := by
          have := congrArg Fin.val heq
          simpa [iPred, iN] using this
        omega
      -- Hole at (i-1, j) is 0 since column j has a unique hole at i.
      have hh_pred : v.h iPred.val jN.val = 0 :=
        fwd_hole_unique_in_col (p := p) (v := v) h jN iN iPred hne hij1
      have hcov_pred := h.hcov iPred jN
      have hsumx_pred :
          ∑ ab ∈ P7.a.strips_covering p.N jN,
            v.x iPred.val ab.1.val ab.2.val = 1 := by
        linarith [hcov_pred, hh_pred]
      -- strips_covering p.N j under fwd-namespace alias
      have hstrips_eq :
          P7.f.strips_covering (paramMap p).N j = P7.a.strips_covering p.N jN := rfl
      have hiPred_val : iPred.val = i.val - 1 := rfl
      -- Sum of flow equations over ab ∈ strips_covering p.N j.
      have hsum_t :
          ∑ ab ∈ P7.a.strips_covering p.N jN,
              v.t (i.val - 1) ab.1.val ab.2.val =
          (∑ ab ∈ P7.a.strips_covering p.N jN,
              v.x iPred.val ab.1.val ab.2.val)
          - (∑ ab ∈ P7.a.strips_covering p.N jN,
              v.x i.val ab.1.val ab.2.val)
          + (∑ ab ∈ P7.a.strips_covering p.N jN,
              v.s i.val ab.1.val ab.2.val) := by
        rw [← Finset.sum_sub_distrib, ← Finset.sum_add_distrib]
        apply Finset.sum_congr rfl
        intro ab _
        have hi_pos' : 0 < iN.val := hi_pos
        have hflow := h.hflow iN ab hi_pos'
        show v.t (i.val - 1) ab.1.val ab.2.val =
            v.x iPred.val ab.1.val ab.2.val - v.x i.val ab.1.val ab.2.val
              + v.s i.val ab.1.val ab.2.val
        rw [hiPred_val]
        -- hflow: v.x iN - v.x (iN-1) - v.s iN + v.t (iN-1) = 0
        linarith
      -- Nonneg of s sum
      have hs_nn :
          0 ≤ ∑ ab ∈ P7.a.strips_covering p.N jN, v.s i.val ab.1.val ab.2.val :=
        Finset.sum_nonneg (fun ab _ => fwd_s_nn h iN ab)
      -- Conclude
      have hgoal_eq :
          ∑ ab ∈ P7.f.strips_covering (paramMap p).N j,
            v.t (i.val - 1) ab.1.val ab.2.val =
          ∑ ab ∈ P7.a.strips_covering p.N jN,
            v.t (i.val - 1) ab.1.val ab.2.val := hstrips_eq ▸ rfl
      rw [hgoal_eq, hsum_t]
      linarith [hsumx_i, hsumx_pred, hs_nn]

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- bwd simply drops the EC5 cut.
private def bwd (_ : P7.a.Params) (v : P7.f.Vars) : P7.a.Vars :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma bwd_feas (p : P7.a.Params) (v : P7.f.Vars)
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
-- § Equivalence Structure
-- ============================================================================

def aFEquiv : MILPEquiv P7.a.formulation P7.f.formulation where
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
