import Common
import dataset.problems.p7.formulations.a.Formulation
import dataset.problems.p7.formulations.d.Formulation
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

private def paramMap (p : P7.a.Params) : P7.d.Params :=
  { N  := p.N
    hN := p.hN }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- fwd is identity on variables; d adds the EC3 cut, which we must prove.
private def fwd (_ : P7.a.Params) (v : P7.a.Vars) : P7.d.Vars :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

section ForwardHelpers

variable {p : P7.a.Params} {v : P7.a.Vars} (h : P7.a.Feasible p v)
include h

-- Nonnegativity of binary variables.
private lemma fwd_h_nn (i j : Fin p.N) : 0 ≤ v.h i.val j.val := by
  rcases h.hh_bin i j with h0 | h1 <;> omega

private lemma fwd_x_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.x i.val ab.1.val ab.2.val := by
  rcases h.hx_bin i ab with h0 | h1 <;> omega

private lemma fwd_s_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.s i.val ab.1.val ab.2.val := by
  rcases h.hs_bin i ab with h0 | h1 <;> omega

end ForwardHelpers

-- strips_covering is identical in P7.a and P7.d.
private lemma strips_covering_eq (N : ℕ) (j : Fin N) :
    P7.a.strips_covering N j = P7.d.strips_covering N j := rfl

private lemma fwd_feas (p : P7.a.Params) (v : P7.a.Vars)
    (h : P7.a.Feasible p v) :
    P7.d.Feasible (paramMap p) (fwd p v) := by
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
  · -- htopBreak: v.h 0 j ≤ ∑ ab ∈ strips_covering p.N j, v.s 1 ab.1 ab.2
    intro j hN_gt
    -- Case split on v.h 0 j
    have hN_pos : 0 < p.N := lt_trans Nat.zero_lt_one hN_gt
    rcases h.hh_bin ⟨0, hN_pos⟩ j with h0 | h1
    · -- h 0 j = 0: trivially ≤ nonneg sum
      have hh0j : v.h 0 j.val = 0 := by simpa using h0
      have hsum_nn : 0 ≤ ∑ ab ∈ P7.d.strips_covering (paramMap p).N j,
          v.s 1 ab.1.val ab.2.val := by
        apply Finset.sum_nonneg
        intro ab _
        rcases h.hs_bin ⟨1, hN_gt⟩ ab with hs0 | hs1
        · simp [show v.s 1 ab.1.val ab.2.val = 0 from by simpa using hs0]
        · simp [show v.s 1 ab.1.val ab.2.val = 1 from by simpa using hs1]
      show v.h 0 j.val ≤ ∑ ab ∈ P7.d.strips_covering (paramMap p).N j,
          (fwd p v).s 1 ab.1.val ab.2.val
      show v.h 0 j.val ≤ ∑ ab ∈ P7.d.strips_covering (paramMap p).N j,
          v.s 1 ab.1.val ab.2.val
      linarith
    · -- h 0 j = 1: must show ≥ 1 on RHS
      have hh0j : v.h 0 j.val = 1 := by simpa using h1
      -- Step 1: for all ab ∈ strips_covering N j, v.x 0 ab.1 ab.2 = 0.
      -- From hcov at i=0, j: ∑_{ab ∈ cov} x 0 ab + h 0 j = 1, so sum = 0.
      have hcov0 := h.hcov ⟨0, hN_pos⟩ j
      have hsum_x0 : ∑ ab ∈ P7.a.strips_covering p.N j,
          v.x 0 ab.1.val ab.2.val = 0 := by
        have : (∑ ab ∈ P7.a.strips_covering p.N j, v.x 0 ab.1.val ab.2.val)
            + v.h 0 j.val = 1 := by simpa using hcov0
        linarith
      have hx0_zero : ∀ ab ∈ P7.a.strips_covering p.N j,
          v.x 0 ab.1.val ab.2.val = 0 := by
        intro ab hab
        rcases h.hx_bin ⟨0, hN_pos⟩ ab with hx0 | hx1
        · simpa using hx0
        · -- x = 1 would make sum ≥ 1, contradicting sum = 0
          exfalso
          have hx1' : v.x 0 ab.1.val ab.2.val = 1 := by simpa using hx1
          let F : Fin p.N × Fin p.N → ℤ := fun ab => v.x 0 ab.1.val ab.2.val
          have hother_nn : ∀ ab' ∈ (P7.a.strips_covering p.N j).erase ab,
              0 ≤ F ab' := by
            intro ab' _
            rcases h.hx_bin ⟨0, hN_pos⟩ ab' with h0' | h1'
            · simp [F, show v.x 0 ab'.1.val ab'.2.val = 0 from by simpa using h0']
            · simp [F, show v.x 0 ab'.1.val ab'.2.val = 1 from by simpa using h1']
          have hsplit : F ab + ∑ ab' ∈ (P7.a.strips_covering p.N j).erase ab, F ab'
              = ∑ ab' ∈ P7.a.strips_covering p.N j, F ab' :=
            Finset.add_sum_erase _ F hab
          have hrest_nn : 0 ≤ ∑ ab' ∈ (P7.a.strips_covering p.N j).erase ab, F ab' :=
            Finset.sum_nonneg hother_nn
          have hFab : F ab = 1 := hx1'
          have hFsum_eq : ∑ ab' ∈ P7.a.strips_covering p.N j, F ab'
              = ∑ ab' ∈ P7.a.strips_covering p.N j, v.x 0 ab'.1.val ab'.2.val := rfl
          linarith [hFsum_eq ▸ hsum_x0]
      -- Step 2: h 1 j = 0 (since column j has only one hole, at row 0).
      -- From hcol j: ∑ i : Fin p.N, v.h i.val j.val = 1, and v.h 0 j = 1,
      -- so all other rows have h = 0.
      have hcol := h.hcol j
      have hh1j : v.h 1 j.val = 0 := by
        set i0 : Fin p.N := ⟨0, hN_pos⟩ with hi0_def
        set i1 : Fin p.N := ⟨1, hN_gt⟩ with hi1_def
        have hi01_ne : i0 ≠ i1 := by
          intro heq
          have : (0 : ℕ) = 1 := congrArg Fin.val heq
          exact absurd this (by decide)
        have hi1_in_erase : i1 ∈ (univ : Finset (Fin p.N)).erase i0 :=
          Finset.mem_erase.mpr ⟨Ne.symm hi01_ne, mem_univ _⟩
        let G : Fin p.N → ℤ := fun i => v.h i.val j.val
        have hsplit0 : G i0 + ∑ i ∈ (univ : Finset (Fin p.N)).erase i0, G i
            = ∑ i : Fin p.N, G i :=
          Finset.add_sum_erase _ G (mem_univ i0)
        have hsplit1 : G i1 + ∑ i ∈ ((univ : Finset (Fin p.N)).erase i0).erase i1, G i
            = ∑ i ∈ (univ : Finset (Fin p.N)).erase i0, G i :=
          Finset.add_sum_erase _ G hi1_in_erase
        have hrest_nn : 0 ≤ ∑ i ∈ ((univ : Finset (Fin p.N)).erase i0).erase i1, G i :=
          Finset.sum_nonneg (fun i _ => fwd_h_nn h i j)
        have hG0 : G i0 = 1 := by show v.h 0 j.val = 1; exact hh0j
        have hG1_nn : 0 ≤ G i1 := fwd_h_nn h i1 j
        have hcol' : ∑ i : Fin p.N, G i = 1 := hcol
        have : G i1 = 0 := by linarith
        exact this
      -- Step 3: hcov at (1,j) gives ∑ x 1 ab over cov = 1.
      have hcov1 := h.hcov ⟨1, hN_gt⟩ j
      have hsum_x1 : ∑ ab ∈ P7.a.strips_covering p.N j,
          v.x 1 ab.1.val ab.2.val = 1 := by
        have : (∑ ab ∈ P7.a.strips_covering p.N j, v.x 1 ab.1.val ab.2.val)
            + v.h 1 j.val = 1 := by simpa using hcov1
        linarith
      -- Step 4: pick ab* with v.x 1 ab* = 1.
      -- Existence by case-splitting binary sum.
      have hexists : ∃ ab ∈ P7.a.strips_covering p.N j,
          v.x 1 ab.1.val ab.2.val = 1 := by
        by_contra hne
        push_neg at hne
        have hall0 : ∀ ab ∈ P7.a.strips_covering p.N j,
            v.x 1 ab.1.val ab.2.val = 0 := by
          intro ab hab
          rcases h.hx_bin ⟨1, hN_gt⟩ ab with h0' | h1'
          · simpa using h0'
          · exact absurd (by simpa using h1' : v.x 1 ab.1.val ab.2.val = 1) (hne ab hab)
        have : ∑ ab ∈ P7.a.strips_covering p.N j,
            v.x 1 ab.1.val ab.2.val = 0 := by
          apply Finset.sum_eq_zero
          intro ab hab; exact hall0 ab hab
        linarith
      obtain ⟨abstar, habstar_in, habstar_x1⟩ := hexists
      -- Step 5: flow at row 1 for abstar:
      -- x 1 - x 0 - s 1 + t 0 = 0, with x 1 = 1, x 0 = 0, and t 0 ∈ {0,1}.
      -- Since s ∈ {0,1} and s = 1 + t ≥ 1, we get s = 1 (and t = 0).
      have hflow1 := h.hflow ⟨1, hN_gt⟩ abstar (by norm_num)
      have hx0_zero_star : v.x 0 abstar.1.val abstar.2.val = 0 :=
        hx0_zero abstar habstar_in
      have hflow1' : v.x 1 abstar.1.val abstar.2.val
          - v.x 0 abstar.1.val abstar.2.val
          - v.s 1 abstar.1.val abstar.2.val
          + v.t 0 abstar.1.val abstar.2.val = 0 := by
        have := hflow1
        simpa using this
      have ht0_bin := h.ht_bin ⟨0, hN_pos⟩ abstar
      have hs1_bin := h.hs_bin ⟨1, hN_gt⟩ abstar
      have ht0_bin' : v.t 0 abstar.1.val abstar.2.val = 0
          ∨ v.t 0 abstar.1.val abstar.2.val = 1 := by
        rcases ht0_bin with h0' | h1'
        · left; simpa using h0'
        · right; simpa using h1'
      have hs1_bin' : v.s 1 abstar.1.val abstar.2.val = 0
          ∨ v.s 1 abstar.1.val abstar.2.val = 1 := by
        rcases hs1_bin with h0' | h1'
        · left; simpa using h0'
        · right; simpa using h1'
      have hs1_star : v.s 1 abstar.1.val abstar.2.val = 1 := by
        rcases ht0_bin' with ht0 | ht0 <;>
          rcases hs1_bin' with hs0 | hs0 <;>
          (first | rfl | (rw [habstar_x1, hx0_zero_star, ht0, hs0] at hflow1'; omega))
      -- Step 6: ∑ s 1 ab over cov ≥ s 1 abstar = 1 = v.h 0 j.
      let S : Fin p.N × Fin p.N → ℤ := fun ab => v.s 1 ab.1.val ab.2.val
      have hs1_others_nn : ∀ ab ∈ (P7.a.strips_covering p.N j).erase abstar,
          0 ≤ S ab := by
        intro ab _
        rcases h.hs_bin ⟨1, hN_gt⟩ ab with h0' | h1'
        · simp [S, show v.s 1 ab.1.val ab.2.val = 0 from by simpa using h0']
        · simp [S, show v.s 1 ab.1.val ab.2.val = 1 from by simpa using h1']
      have hsplit : S abstar + ∑ ab ∈ (P7.a.strips_covering p.N j).erase abstar, S ab
          = ∑ ab ∈ P7.a.strips_covering p.N j, S ab :=
        Finset.add_sum_erase _ S habstar_in
      have hrest_nn : 0 ≤ ∑ ab ∈ (P7.a.strips_covering p.N j).erase abstar, S ab :=
        Finset.sum_nonneg hs1_others_nn
      have hSstar : S abstar = 1 := hs1_star
      show v.h 0 j.val ≤ ∑ ab ∈ P7.d.strips_covering (paramMap p).N j,
          v.s 1 ab.1.val ab.2.val
      rw [hh0j]
      have hgoal : (1 : ℤ) ≤ ∑ ab ∈ P7.a.strips_covering p.N j, S ab := by linarith
      show (1 : ℤ) ≤ ∑ ab ∈ P7.d.strips_covering (paramMap p).N j,
          v.s 1 ab.1.val ab.2.val
      simpa [paramMap, P7.d.strips_covering, P7.a.strips_covering, S] using hgoal

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- bwd simply drops the EC3 cut.
private def bwd (_ : P7.a.Params) (v : P7.d.Vars) : P7.a.Vars :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma bwd_feas (p : P7.a.Params) (v : P7.d.Vars)
    (h : P7.d.Feasible (paramMap p) v) :
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

def aDEquiv : MILPEquiv P7.a.formulation P7.d.formulation where
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
