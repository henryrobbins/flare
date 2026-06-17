import Common
import problems.p7.formulations.a.Formulation
import problems.p7.formulations.g.Formulation
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

private def fwd (p : P7.a.Params) (v : P7.a.Vars p) : P7.g.Vars (paramMap p) :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma strips_covering_eq (N : ℕ) (j : Fin N) :
    P7.a.strips_covering N j = P7.g.strips_covering N j := rfl

section ForwardHelpers

variable {p : P7.a.Params} {v : P7.a.Vars p} (h : P7.a.Feasible p v)
include h

private lemma sum_x_eq (i j : Fin p.N) :
    ∑ ab ∈ P7.a.strips_covering p.N j, v.x i ab.1 ab.2 = 1 - v.h i j := by
  have := h.hcov i j
  linarith

private lemma t_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.t i ab.1 ab.2 := by
  rcases h.ht_bin i ab with h0 | h1 <;> omega

private lemma s_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.s i ab.1 ab.2 := by
  rcases h.hs_bin i ab with h0 | h1 <;> omega

private lemma h_nn (i j : Fin p.N) :
    0 ≤ v.h i j := by
  rcases h.hh_bin i j with h0 | h1 <;> omega

end ForwardHelpers

private lemma fwd_ec6 (p : P7.a.Params) (v : P7.a.Vars p)
    (h : P7.a.Feasible p v) :
    ∀ i : Fin p.N, ∀ j : Fin p.N, 0 < i.val → ∀ hi1 : i.val + 1 < p.N,
      v.h i j ≤
        ∑ ab ∈ P7.g.strips_covering p.N j, v.s ⟨i.val + 1, hi1⟩ ab.1 ab.2 := by
  intro i j hi_pos hi_succ_lt
  let ip1 : Fin p.N := ⟨i.val + 1, hi_succ_lt⟩
  have hip1_pos : 0 < ip1.val := by show 0 < i.val + 1; omega
  -- Predecessor of ip1 (Fin p.N) is i, definitionally.
  have hpred_eq : (⟨ip1.val - 1, by omega⟩ : Fin p.N) = i := by
    apply Fin.ext; show i.val + 1 - 1 = i.val; omega
  have hcov_i : ∑ ab ∈ P7.a.strips_covering p.N j, v.x i ab.1 ab.2
              = 1 - v.h i j := sum_x_eq h i j
  have hcov_ip1 : ∑ ab ∈ P7.a.strips_covering p.N j, v.x ip1 ab.1 ab.2
                = 1 - v.h ip1 j := sum_x_eq h ip1 j
  have hflow_sum :
      ∑ ab ∈ P7.a.strips_covering p.N j,
        (v.x ip1 ab.1 ab.2 - v.x i ab.1 ab.2
         - v.s ip1 ab.1 ab.2 + v.t i ab.1 ab.2) = 0 := by
    apply Finset.sum_eq_zero
    intro ab _
    have hf := h.hflow ip1 ab hip1_pos
    rw [hpred_eq] at hf
    exact hf
  have hsplit :
      ∑ ab ∈ P7.a.strips_covering p.N j, v.x ip1 ab.1 ab.2
      - ∑ ab ∈ P7.a.strips_covering p.N j, v.x i ab.1 ab.2
      - ∑ ab ∈ P7.a.strips_covering p.N j, v.s ip1 ab.1 ab.2
      + ∑ ab ∈ P7.a.strips_covering p.N j, v.t i ab.1 ab.2 = 0 := by
    rw [← hflow_sum]
    rw [Finset.sum_add_distrib, Finset.sum_sub_distrib, Finset.sum_sub_distrib]
  rw [hcov_i, hcov_ip1] at hsplit
  have ht_nn_sum : 0 ≤ ∑ ab ∈ P7.a.strips_covering p.N j,
      v.t i ab.1 ab.2 :=
    Finset.sum_nonneg (fun ab _ => t_nn h i ab)
  rcases h.hh_bin i j with hhij0 | hhij1
  · -- h i j = 0: RHS ≥ 0
    rw [hhij0]
    rw [strips_covering_eq p.N j] at *
    exact Finset.sum_nonneg (fun ab _ => s_nn h ip1 ab)
  · -- h i j = 1: must show 1 ≤ ∑ s ip1
    have hcol := h.hcol j
    have hi_ne_ip1 : i ≠ ip1 := by
      intro heq
      have hval : i.val = ip1.val := by rw [heq]
      have : i.val = i.val + 1 := hval
      omega
    have hsplit_col : v.h i j +
        ∑ k ∈ (univ : Finset (Fin p.N)).erase i, v.h k j = 1 := by
      have := Finset.add_sum_erase (univ : Finset (Fin p.N))
        (fun k : Fin p.N => v.h k j) (mem_univ i)
      rw [this]; exact hcol
    rw [hhij1] at hsplit_col
    have hrest_zero : ∑ k ∈ (univ : Finset (Fin p.N)).erase i, v.h k j = 0 := by
      linarith
    have hip1_in : ip1 ∈ (univ : Finset (Fin p.N)).erase i :=
      Finset.mem_erase.mpr ⟨Ne.symm hi_ne_ip1, mem_univ _⟩
    have hrest_nn : ∀ k ∈ (univ : Finset (Fin p.N)).erase i,
        0 ≤ v.h k j := fun k _ => h_nn h k j
    have hh_ip1 : v.h ip1 j = 0 := by
      have := Finset.sum_eq_zero_iff_of_nonneg hrest_nn |>.mp hrest_zero ip1 hip1_in
      exact this
    rw [hhij1, hh_ip1] at hsplit
    rw [strips_covering_eq p.N j] at hsplit
    rw [hhij1]
    -- hsplit : (1 - 0) - (1 - 1) - ∑s + ∑t = 0
    rw [strips_covering_eq p.N j] at ht_nn_sum
    -- We want: (1 : ℤ) ≤ ∑ ab ∈ g.strips_covering p.N j, v.s ⟨i.val + 1, hi_succ_lt⟩ ab.1 ab.2
    -- This is the same as ∑ s ip1 (definitionally).
    show (1 : ℤ) ≤ ∑ ab ∈ P7.g.strips_covering p.N j, v.s ip1 ab.1 ab.2
    linarith

private lemma fwd_feas (p : P7.a.Params) (v : P7.a.Vars p)
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

private def bwd (p : P7.a.Params) (v : P7.g.Vars (paramMap p)) : P7.a.Vars p :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma bwd_feas (p : P7.a.Params) (v : P7.g.Vars (paramMap p))
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
-- § Reformulation Structure
-- ============================================================================

def aGReformulation : MILPReformulation P7.a.formulation P7.g.formulation where
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

end P7
