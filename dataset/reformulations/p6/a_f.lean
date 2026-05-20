import Common
import problems.p6.formulations.a.Formulation
import problems.p6.formulations.f.Formulation
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

private def paramMap (p : P6.a.Params) : P6.f.Params :=
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

private def fwd (p : P6.a.Params) (v : P6.a.Vars p) : P6.f.Vars (paramMap p) :=
  { x := v.x
    y := v.y }

section ForwardHelpers

variable {p : P6.a.Params} {v : P6.a.Vars p} (h : P6.a.Feasible p v)
include h

-- For each warehouse j, the number of qualifying customers (demand ≥ thresh)
-- assigned to j is at most ⌊u_j / thresh⌋ * y_j.
open Classical in
private lemma count_le_floor_cap
    (thresh : ℝ) (hthresh_pos : 0 < thresh) (j : Fin p.m) :
    (((univ.filter (fun k : Fin p.n => thresh ≤ p.d k)).filter
        (fun k => v.x k j = 1)).card : ℤ) ≤
      ⌊p.u j / thresh⌋ * v.y j := by
  haveI := p.hn
  -- Nonneg for x on Fin indices
  have xnn : ∀ (a : Fin p.n) (b : Fin p.m), 0 ≤ v.x a b := fun a b => by
    rcases h.hx_bin a b with h0 | h1
    · rw [h0]
    · rw [h1]; decide
  -- Let S be the selected set
  set S : Finset (Fin p.n) :=
    (univ.filter (fun k : Fin p.n => thresh ≤ p.d k)).filter
      (fun k => v.x k j = 1) with hS_def
  -- Case split on y_j
  rcases h.hy_bin j with hy0 | hy1
  · -- y_j = 0 case: need to show |S| ≤ 0, i.e., S is empty
    rw [hy0]
    simp only [mul_zero]
    -- Show |S| = 0 using capacity constraint
    have hcap_j := h.hcap j
    rw [hy0] at hcap_j
    simp only [Int.cast_zero, mul_zero] at hcap_j
    -- ∑ d_i * x_{ij} ≤ 0; all nonneg so all zero; in particular x_{kj} = 0 for qualifying k
    have hall_nn : ∀ k : Fin p.n,
        0 ≤ p.d k * (v.x k j : ℝ) := by
      intro k
      exact mul_nonneg (le_of_lt (p.hd_pos k)) (by exact_mod_cast xnn k j)
    have hsum_zero : ∑ k : Fin p.n, p.d k * (v.x k j : ℝ) = 0 := by
      have hle := hcap_j
      have hge : 0 ≤ ∑ k : Fin p.n, p.d k * (v.x k j : ℝ) :=
        Finset.sum_nonneg (fun k _ => hall_nn k)
      linarith
    have hall_zero : ∀ k : Fin p.n, p.d k * (v.x k j : ℝ) = 0 := by
      intro k
      exact (Finset.sum_eq_zero_iff_of_nonneg (fun k _ => hall_nn k)).mp hsum_zero k (mem_univ _)
    -- So for each qualifying k, x_{kj} = 0, hence not in S
    have hS_empty : S = ∅ := by
      rw [← Finset.not_nonempty_iff_eq_empty]
      rintro ⟨k, hk⟩
      simp only [S, mem_filter, mem_univ, true_and] at hk
      obtain ⟨_, hx1⟩ := hk
      have hdx := hall_zero k
      rw [hx1] at hdx
      push_cast at hdx
      have := p.hd_pos k
      linarith
    rw [hS_empty]
    simp
  · -- y_j = 1 case
    rw [hy1]
    -- Capacity: ∑_i d_i * x_{ij} ≤ u_j
    have hcap_j := h.hcap j
    rw [hy1] at hcap_j
    simp only [Int.cast_one, mul_one] at hcap_j
    -- Lower bound for the capacity sum restricted to S
    have hS_bound : (S.card : ℝ) * thresh ≤ p.u j := by
      -- S.card * thresh ≤ ∑_{k ∈ S} d_k ≤ ∑_{k ∈ S} d_k * 1 = ∑_{k ∈ S} d_k * x_{kj}
      -- ≤ ∑_k d_k * x_{kj} ≤ u_j
      have step1 : (S.card : ℝ) * thresh ≤ ∑ k ∈ S, p.d k := by
        have := Finset.sum_le_sum (s := S) (f := fun _ => thresh) (g := fun k => p.d k)
          (fun k hk => by
            simp only [S, mem_filter, mem_univ, true_and] at hk
            exact hk.1)
        simpa [mul_comm, Finset.sum_const, nsmul_eq_mul] using this
      have step2 : ∑ k ∈ S, p.d k = ∑ k ∈ S, p.d k * (v.x k j : ℝ) := by
        apply Finset.sum_congr rfl
        intro k hk
        simp only [S, mem_filter, mem_univ, true_and] at hk
        rw [hk.2]; push_cast; ring
      have step3 : ∑ k ∈ S, p.d k * (v.x k j : ℝ) ≤
          ∑ k : Fin p.n, p.d k * (v.x k j : ℝ) := by
        apply Finset.sum_le_sum_of_subset_of_nonneg
        · exact fun k _ => mem_univ _
        · intro k _ _
          exact mul_nonneg (le_of_lt (p.hd_pos k)) (by exact_mod_cast xnn k j)
      linarith
    -- So S.card ≤ u_j / thresh, hence S.card ≤ ⌊u_j/thresh⌋ (integer)
    have hSdiv : (S.card : ℝ) ≤ p.u j / thresh := by
      rw [le_div_iff₀ hthresh_pos]
      exact hS_bound
    have hfloor : (S.card : ℤ) ≤ ⌊p.u j / thresh⌋ := by
      apply Int.le_floor.mpr
      exact_mod_cast hSdiv
    linarith

end ForwardHelpers

private lemma fwd_feas (p : P6.a.Params) (v : P6.a.Vars p)
    (h : P6.a.Feasible p v) :
    P6.f.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hn
  haveI := p.hm
  classical
  refine
    { hassign := h.hassign
      hcap := h.hcap
      hx_bin := h.hx_bin
      hy_bin := h.hy_bin
      hec2 := ?_ }
  intro i
  -- Set threshold
  set thresh : ℝ := p.d i with hthresh_def
  have hthresh_pos : 0 < thresh := p.hd_pos i
  -- demandCustomers unfolds to the filter
  have hdc : P6.f.demandCustomers (paramMap p) thresh =
      (univ : Finset (Fin p.n)).filter (fun k => thresh ≤ p.d k) := by
    unfold P6.f.demandCustomers
    congr 1
  change ((P6.f.demandCustomers (paramMap p) thresh).card : ℤ) ≤
      ∑ j : Fin p.m, ⌊p.u j / thresh⌋ * v.y j
  rw [hdc]
  -- Notation
  set Q : Finset (Fin p.n) :=
    (univ : Finset (Fin p.n)).filter (fun k => thresh ≤ p.d k) with hQ_def
  -- Key: card Q = ∑_j card (Q.filter (x·j = 1))
  have hx_bin := h.hx_bin
  have hassign := h.hassign
  -- For each k ∈ Q, exactly one j has x k j = 1
  have hcount_eq :
      (Q.card : ℤ) =
      ∑ j : Fin p.m, ((Q.filter (fun k => v.x k j = 1)).card : ℤ) := by
    -- Rewrite using double counting: card(Q) = ∑_{k ∈ Q} 1 = ∑_{k ∈ Q} ∑_j [x k j = 1] = ∑_j ∑_{k ∈ Q} [x k j = 1]
    have hone : ∀ k : Fin p.n, k ∈ Q →
        ∑ j : Fin p.m, (if v.x k j = 1 then (1 : ℤ) else 0) = 1 := by
      intro k _
      have hka := hassign k
      have : ∀ j : Fin p.m,
          (if v.x k j = 1 then (1 : ℤ) else 0) = v.x k j := by
        intro j
        rcases hx_bin k j with h0 | h1
        · simp [h0]
        · simp [h1]
      rw [Finset.sum_congr rfl (fun j _ => this j)]
      exact hka
    calc (Q.card : ℤ)
        = ∑ k ∈ Q, (1 : ℤ) := by
          rw [Finset.sum_const, nsmul_eq_mul, mul_one]
      _ = ∑ k ∈ Q, ∑ j : Fin p.m, (if v.x k j = 1 then (1 : ℤ) else 0) := by
          apply Finset.sum_congr rfl
          intro k hk
          rw [hone k hk]
      _ = ∑ j : Fin p.m, ∑ k ∈ Q, (if v.x k j = 1 then (1 : ℤ) else 0) := by
          rw [Finset.sum_comm]
      _ = ∑ j : Fin p.m, ((Q.filter (fun k => v.x k j = 1)).card : ℤ) := by
          apply Finset.sum_congr rfl
          intro j _
          rw [Finset.sum_ite, Finset.sum_const_zero, add_zero, Finset.sum_const,
              nsmul_eq_mul, mul_one, Finset.filter_filter]
  rw [hcount_eq]
  -- Now bound each term using the helper
  apply Finset.sum_le_sum
  intro j _
  exact count_le_floor_cap h thresh hthresh_pos j

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P6.a.Params) (v : P6.f.Vars (paramMap p)) : P6.a.Vars p :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P6.a.Params) (v : P6.f.Vars (paramMap p))
    (h : P6.f.Feasible (paramMap p) v) :
    P6.a.Feasible p (bwd p v) := by
  exact
    { hassign := h.hassign
      hcap := h.hcap
      hx_bin := h.hx_bin
      hy_bin := h.hy_bin }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aFReformulation : MILPReformulation P6.a.formulation P6.f.formulation where
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
