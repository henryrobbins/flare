import Common
import dataset.problems.p18.formulations.a.Formulation
import dataset.problems.p18.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P18

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P18.a.Params) : P18.b.Params :=
  { nI     := p.nI
    m      := p.m
    M      := p.M
    v      := p.v
    a      := p.a
    p      := p.p
    hnI    := p.hnI
    hM     := p.hM
    hmM    := p.hmM
    hv_nn  := p.hv_nn
    ha_bin := p.ha_bin
    hp_nn  := p.hp_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

/-- Set of hospitals `j` such that `a i j = 1` and `x j = 1`. -/
private def coverSet (p : P18.a.Params) (v : P18.a.Vars) (i : Fin p.nI) :
    Finset (Fin p.M) :=
  (univ : Finset (Fin p.M)).filter (fun j => p.a i j = 1 ∧ v.x j.val = 1)

/-- The chosen hospital for household `i`: smallest-index covering open hospital,
if one exists. -/
private noncomputable def chosenHosp (p : P18.a.Params) (v : P18.a.Vars)
    (i : Fin p.nI) : Option (Fin p.M) :=
  haveI := p.hM
  if hS : (coverSet p v i).Nonempty then some ((coverSet p v i).min' hS) else none

open Classical in
/--
**A → B**: `y_{ij} = 1` iff `y_i = 1` and `j` is the chosen (smallest-index)
covering open hospital for `i`; else `0`. `x` is copied.
-/
private noncomputable def fwd (p : P18.a.Params) (v : P18.a.Vars) : P18.b.Vars :=
  { x := v.x
    y := fun i j =>
      if hi : i < p.nI then
        if v.y i = 1 then
          match chosenHosp p v ⟨i, hi⟩ with
          | some j0 => if j0.val = j then 1 else 0
          | none => 0
        else 0
      else 0 }

/-- When `v.y i = 1`, the cover set for `i` is nonempty. -/
private lemma coverSet_nonempty_of_y {p : P18.a.Params} {v : P18.a.Vars}
    (h : P18.a.Feasible p v) {i : Fin p.nI} (hy : v.y i.val = 1) :
    (coverSet p v i).Nonempty := by
  haveI := p.hM
  have hcov := h.hcover i
  rw [hy] at hcov
  -- 1 ≤ Σ_j a_{ij} * x_j, with each term in {0,1} (product of binaries)
  by_contra hemp
  rw [Finset.not_nonempty_iff_eq_empty] at hemp
  have hzero : ∀ j : Fin p.M, p.a i j * v.x j.val = 0 := by
    intro j
    have hj_not : j ∉ coverSet p v i := by rw [hemp]; exact notMem_empty _
    simp only [coverSet, mem_filter, mem_univ, true_and, not_and_or] at hj_not
    rcases p.ha_bin i j with ha0 | ha1
    · rw [ha0]; ring
    · rcases h.hx_bin j with hx0 | hx1
      · rw [hx0]; ring
      · exfalso
        rcases hj_not with hna | hnx
        · exact hna ha1
        · exact hnx hx1
  have hsum_zero : ∑ j : Fin p.M, p.a i j * v.x j.val = 0 := by
    apply Finset.sum_eq_zero; intro j _; exact hzero j
  rw [hsum_zero] at hcov
  exact absurd hcov (by norm_num)

/-- The chosen hospital, when it exists, satisfies `a i j = 1` and `x j = 1`. -/
private lemma chosenHosp_spec (p : P18.a.Params) (v : P18.a.Vars)
    (i : Fin p.nI) (j : Fin p.M) (hch : chosenHosp p v i = some j) :
    p.a i j = 1 ∧ v.x j.val = 1 := by
  haveI := p.hM
  unfold chosenHosp at hch
  by_cases hS : (coverSet p v i).Nonempty
  · rw [dif_pos hS] at hch
    have hjEq : (coverSet p v i).min' hS = j := Option.some_injective _ hch
    have hmem := Finset.min'_mem _ hS
    rw [hjEq] at hmem
    simp only [coverSet, mem_filter, mem_univ, true_and] at hmem
    exact hmem
  · rw [dif_neg hS] at hch
    exact absurd hch (by simp)

/-- Simplified form of `fwd.y` on valid indices. -/
private lemma fwd_y_apply (p : P18.a.Params) (v : P18.a.Vars)
    (i : Fin p.nI) (j : Fin p.M) :
    (fwd p v).y i.val j.val =
      if v.y i.val = 1 then
        match chosenHosp p v i with
        | some j0 => if j0.val = j.val then 1 else 0
        | none => 0
      else 0 := by
  unfold fwd
  simp only
  rw [dif_pos i.isLt]

/-- Sum of `fwd.y i j` over `j` equals `v.y i`. -/
private lemma fwd_sum_y_eq_y (p : P18.a.Params) (v : P18.a.Vars)
    (h : P18.a.Feasible p v) (i : Fin p.nI) :
    ∑ j : Fin p.M, (fwd p v).y i.val j.val = v.y i.val := by
  haveI := p.hM
  simp_rw [fwd_y_apply p v i]
  rcases h.hy_bin i with hy0 | hy1
  · rw [hy0]; simp
  · rw [hy1]
    simp only [if_true]
    have hne := coverSet_nonempty_of_y h hy1
    have : chosenHosp p v i = some ((coverSet p v i).min' hne) := by
      unfold chosenHosp; rw [dif_pos hne]
    rcases hch : chosenHosp p v i with _ | j0
    · rw [this] at hch; simp at hch
    · simp only
      rw [Finset.sum_eq_single j0]
      · simp
      · intro b _ hbne
        rw [if_neg]
        intro heq
        apply hbne
        exact Fin.ext heq.symm
      · intro hnmem; exact absurd (mem_univ j0) hnmem

private lemma fwd_feas (p : P18.a.Params) (v : P18.a.Vars)
    (h : P18.a.Feasible p v) :
    P18.b.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hM
  haveI := p.hnI
  -- y is binary
  have hy_bin : ∀ (i : Fin p.nI) (j : Fin p.M),
      (fwd p v).y i.val j.val = 0 ∨ (fwd p v).y i.val j.val = 1 := by
    intro i j
    rw [fwd_y_apply]
    by_cases hy : v.y i.val = 1
    · rw [if_pos hy]
      rcases hch : chosenHosp p v i with _ | j0
      · simp
      · simp only
        by_cases hjeq : j0.val = j.val
        · right; rw [if_pos hjeq]
        · left; rw [if_neg hjeq]
    · rw [if_neg hy]; left; rfl
  have hy_nn : ∀ (i : Fin p.nI) (j : Fin p.M), 0 ≤ (fwd p v).y i.val j.val := by
    intro i j; rcases hy_bin i j with h0 | h1 <;> omega
  -- y = 1 implies a i j = 1 and x j = 1
  have hy_one_spec : ∀ (i : Fin p.nI) (j : Fin p.M),
      (fwd p v).y i.val j.val = 1 → p.a i j = 1 ∧ v.x j.val = 1 := by
    intro i j hone
    rw [fwd_y_apply] at hone
    by_cases hy : v.y i.val = 1
    · rw [if_pos hy] at hone
      rcases hch : chosenHosp p v i with _ | j0
      · rw [hch] at hone; simp at hone
      · rw [hch] at hone
        simp only at hone
        by_cases hjeq : j0.val = j.val
        · have hspec := chosenHosp_spec p v i j0 hch
          have hjeq' : j0 = j := Fin.ext hjeq
          rw [hjeq'] at hspec
          exact hspec
        · rw [if_neg hjeq] at hone; exact absurd hone (by norm_num)
    · rw [if_neg hy] at hone; exact absurd hone (by norm_num)
  refine ?_
  constructor
  · -- hexisting
    intro j hj
    show v.x j.val = 1
    exact h.hexisting j hj
  · -- hnew_cap
    show ∑ j ∈ (univ : Finset (Fin (paramMap p).M)).filter
          (fun j => (paramMap p).m ≤ j.val), (v.x j.val : ℤ) ≤ (paramMap p).p
    simp only [paramMap]
    exact h.hnew_cap
  · -- hlink: Σ_i y_{ij} ≤ nI * x_j
    intro j
    show ∑ i : Fin (paramMap p).nI, (fwd p v).y i.val j.val
      ≤ ((paramMap p).nI : ℤ) * v.x j.val
    simp only [paramMap]
    rcases h.hx_bin j with hx0 | hx1
    · -- x_j = 0 → all y_{ij} = 0
      rw [hx0, mul_zero]
      apply Finset.sum_nonpos
      intro i _
      rcases hy_bin i j with hy0 | hy1
      · rw [hy0]
      · have := hy_one_spec i j hy1
        rw [hx0] at this; exact absurd this.2 (by norm_num)
    · -- x_j = 1 → Σ_i y_{ij} ≤ nI (since each ≤ 1, there are nI terms)
      rw [hx1, mul_one]
      calc ∑ i : Fin p.nI, (fwd p v).y i.val j.val
          ≤ ∑ _i : Fin p.nI, (1 : ℤ) := by
            apply Finset.sum_le_sum
            intro i _
            rcases hy_bin i j with hy0 | hy1
            · rw [hy0]; norm_num
            · rw [hy1]
        _ = (p.nI : ℤ) := by simp
  · -- hassign: Σ_j y_{ij} ≤ 1
    intro i
    show ∑ j : Fin (paramMap p).M, (fwd p v).y i.val j.val ≤ 1
    simp only [paramMap]
    rw [fwd_sum_y_eq_y p v h i]
    rcases h.hy_bin i with hy0 | hy1
    · rw [hy0]; norm_num
    · rw [hy1]
  · -- hcover: y_{ij} ≤ a_{ij}
    intro i j
    show (fwd p v).y i.val j.val ≤ (paramMap p).a i j
    simp only [paramMap]
    rcases hy_bin i j with hy0 | hy1
    · rw [hy0]; rcases p.ha_bin i j with h0 | h1 <;> omega
    · rw [hy1]
      have := hy_one_spec i j hy1
      rw [this.1]
  · -- hx_bin
    exact h.hx_bin
  · -- hy_bin
    exact hy_bin

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**B → A**: set `y_i = Σ_j y_{ij}` and keep `x`.
-/
private def bwd (p : P18.a.Params) (v : P18.b.Vars) : P18.a.Vars :=
  { x := v.x
    y := fun i => ∑ j : Fin p.M, v.y i j.val }

private lemma bwd_feas (p : P18.a.Params) (v : P18.b.Vars)
    (h : P18.b.Feasible (paramMap p) v) :
    P18.a.Feasible p (bwd p v) := by
  haveI := p.hM
  haveI := p.hnI
  have hy_nn : ∀ (i : Fin p.nI) (j : Fin p.M), 0 ≤ v.y i.val j.val := by
    intro i j; rcases h.hy_bin i j with h0 | h1 <;> omega
  have hx_nn : ∀ j : Fin p.M, 0 ≤ v.x j.val := by
    intro j; rcases h.hx_bin j with h0 | h1 <;> omega
  -- key: y_{ij} ≤ a_{ij} * x_j
  have hy_le_ax : ∀ (i : Fin p.nI) (j : Fin p.M),
      v.y i.val j.val ≤ p.a i j * v.x j.val := by
    intro i j
    rcases h.hx_bin j with hx0 | hx1
    · -- x_j = 0: from hlink, Σ_i y_{ij} ≤ 0, and each y ≥ 0, so y_{ij} = 0
      have hlink := h.hlink j
      simp only [paramMap] at hlink
      rw [hx0, mul_zero] at hlink
      have hy_zero : v.y i.val j.val = 0 := by
        have hsum_nn : ∀ i' : Fin p.nI, 0 ≤ v.y i'.val j.val := fun i' => hy_nn i' j
        have hle : v.y i.val j.val ≤ 0 :=
          (Finset.single_le_sum (f := fun i' : Fin p.nI => v.y i'.val j.val)
            (s := univ) (fun i' _ => hsum_nn i') (mem_univ i)).trans hlink
        linarith [hsum_nn i]
      rw [hy_zero, hx0, mul_zero]
    · -- x_j = 1: y_{ij} ≤ a_{ij} = a_{ij} * 1 = a_{ij} * x_j
      rw [hx1, mul_one]
      have hc := h.hcover i j
      simp only [paramMap] at hc
      exact hc
  refine ?_
  constructor
  · -- hexisting
    exact h.hexisting
  · -- hnew_cap
    exact h.hnew_cap
  · -- hcover: (bwd).y_i ≤ Σ_j a_{ij} x_j
    intro i
    show (∑ j : Fin p.M, v.y i.val j.val) ≤ ∑ j : Fin p.M, p.a i j * v.x j.val
    apply Finset.sum_le_sum
    intro j _
    exact hy_le_ax i j
  · -- hx_bin
    exact h.hx_bin
  · -- hy_bin: Σ_j y_{ij} ∈ {0,1}
    intro i
    show (∑ j : Fin p.M, v.y i.val j.val) = 0 ∨
         (∑ j : Fin p.M, v.y i.val j.val) = 1
    have hsum_nn : 0 ≤ ∑ j : Fin p.M, v.y i.val j.val := by
      apply Finset.sum_nonneg
      intro j _; exact hy_nn i j
    have hsum_le : ∑ j : Fin p.M, v.y i.val j.val ≤ 1 := by
      have := h.hassign i
      simp only [paramMap] at this
      exact this
    omega

-- ============================================================================
-- § Objective Mapping
-- ============================================================================

private lemma fwd_obj (p : P18.a.Params) (v : P18.a.Vars)
    (h : P18.a.Feasible p v) :
    (P18.b.formulation).obj (paramMap p) (fwd p v) = P18.a.formulation.obj p v := by
  show P18.b.obj (paramMap p) (fwd p v) = P18.a.obj p v
  unfold P18.b.obj P18.a.obj
  congr 1
  apply Finset.sum_congr rfl
  intro i _
  -- Σ_j p.v i * y_{ij} = p.v i * Σ_j y_{ij} = p.v i * y_i
  rw [← Finset.mul_sum]
  congr 1
  have hsum := fwd_sum_y_eq_y p v h i
  exact_mod_cast hsum

private lemma bwd_obj (p : P18.a.Params) (v : P18.b.Vars)
    (_h : P18.b.Feasible (paramMap p) v) :
    (P18.b.formulation).obj (paramMap p) v = P18.a.formulation.obj p (bwd p v) := by
  show P18.b.obj (paramMap p) v = P18.a.obj p (bwd p v)
  unfold P18.b.obj P18.a.obj
  congr 1
  apply Finset.sum_congr rfl
  intro i _
  rw [← Finset.mul_sum]
  -- (bwd p v).y i.val = Σ_j v.y i.val j.val
  show (paramMap p).v i * _ = p.v i * ((∑ j : Fin p.M, v.y i.val j.val : ℤ) : ℝ)
  congr 1
  push_cast
  rfl

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

noncomputable def aBEquiv : MILPReformulation P18.a.formulation P18.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj p v h := fwd_obj p v h
  bwd_obj p v h := bwd_obj p v h

end P18
