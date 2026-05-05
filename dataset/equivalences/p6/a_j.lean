import Common
import dataset.problems.p6.formulations.a.Formulation
import dataset.problems.p6.formulations.j.Formulation
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

private def paramMap (p : P6.a.Params) : P6.j.Params :=
  { n := p.n, m := p.m, d := p.d, u := p.u, f := p.f, c := p.c
    hd_pos := p.hd_pos, hu_nn := p.hu_nn, hc_nn := p.hc_nn, hf_nn := p.hf_nn
    hn := p.hn, hm := p.hm }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (_ : P6.a.Params) (v : P6.a.Vars) : P6.j.Vars :=
  { x := v.x, y := v.y }

private lemma fwd_feas (p : P6.a.Params) (v : P6.a.Vars)
    (h : P6.a.Feasible p v) :
    P6.j.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hn
  haveI := p.hm
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · intro i; exact h.hassign i
  · intro j; exact h.hcap j
  · intro i j; exact h.hx_bin i j
  · intro j; exact h.hy_bin j
  · intro j
    -- Goal: ∑ i ∈ thirdExceed (paramMap p) j, v.x i j ≤ 2 * v.y j
    -- Strategy: case on y_j. If y_j = 0, all x_ij = 0 by capacity.
    -- If y_j = 1, suppose sum ≥ 3 → contradiction with capacity.
    rcases h.hy_bin j with hy0 | hy1
    · -- y_j = 0
      -- capacity: ∑ d_i * x_ij ≤ u_j * 0 = 0
      have hcap := h.hcap j
      rw [hy0] at hcap
      simp at hcap
      -- Each d_i * x_ij ≥ 0, so each = 0, so each x_ij = 0
      have hx_zero : ∀ i : Fin p.n, v.x i j = 0 := by
        intro i
        rcases h.hx_bin i j with hx | hx
        · exact hx
        · -- x_ij = 1, then d_i * 1 = d_i > 0 contributes to sum; others ≥ 0; total > 0, contra
          exfalso
          have hsum_pos : 0 < ∑ i : Fin p.n, p.d i * (v.x i j : ℝ) := by
            apply Finset.sum_pos'
            · intro k _
              rcases h.hx_bin k j with hk | hk
              · rw [hk]; simp
              · rw [hk]; push_cast
                have := p.hd_pos k; linarith
            · refine ⟨i, mem_univ _, ?_⟩
              rw [hx]; push_cast
              have := p.hd_pos i; linarith
          linarith
      -- Now ∑ i ∈ thirdExceed, v.x i j = 0 ≤ 2 * 0
      show (∑ i ∈ P6.j.thirdExceed (paramMap p) j, v.x i j) ≤ 2 * v.y j
      rw [hy0]
      have : (∑ i ∈ P6.j.thirdExceed (paramMap p) j, v.x i j) = 0 := by
        apply Finset.sum_eq_zero
        intro i _
        exact hx_zero i
      rw [this]; simp
    · -- y_j = 1
      show (∑ i ∈ P6.j.thirdExceed (paramMap p) j, v.x i j) ≤ 2 * v.y j
      rw [hy1]
      classical
      by_contra hcontra
      push_neg at hcontra
      -- hcontra : 2 * 1 < ∑ i ∈ thirdExceed, v.x i j
      have hsum_ge : (3 : ℤ) ≤ ∑ i ∈ P6.j.thirdExceed (paramMap p) j, v.x i j := by
        omega
      -- Capacity: ∑ p.d i * x_ij ≤ p.u j * 1
      have hcap := h.hcap j
      -- The key fact about thirdExceed membership
      have hmem_iff : ∀ i : Fin p.n, i ∈ P6.j.thirdExceed (paramMap p) j ↔ p.u j / 3 < p.d i := by
        intro i
        show i ∈ (_ : Finset _) ↔ _
        unfold P6.j.thirdExceed
        simp [paramMap]
      -- The subset T₁ of thirdExceed where x = 1
      let T₁ : Finset (Fin p.n) :=
        (P6.j.thirdExceed (paramMap p) j).filter (fun i => v.x i j = 1)
      have hT₁_sub : T₁ ⊆ P6.j.thirdExceed (paramMap p) j := Finset.filter_subset _ _
      -- Sum over thirdExceed equals sum over T₁
      have hsum_eq : ∑ i ∈ P6.j.thirdExceed (paramMap p) j, v.x i j = ∑ i ∈ T₁, v.x i j := by
        symm
        apply Finset.sum_subset hT₁_sub
        intro i hi hi_notin
        simp [T₁, hi] at hi_notin
        rcases h.hx_bin i j with hx | hx
        · exact hx
        · exact absurd hx hi_notin
      -- Over T₁, each term = 1, so sum = |T₁|
      have hsum_T₁ : ∑ i ∈ T₁, v.x i j = (T₁.card : ℤ) := by
        have h1 : (∑ i ∈ T₁, v.x i j) = ∑ _ ∈ T₁, (1 : ℤ) := by
          apply Finset.sum_congr rfl
          intro i hi
          simp [T₁] at hi
          exact hi.2
        rw [h1, Finset.sum_const]
        simp
      have hT₁_card : 3 ≤ T₁.card := by
        have : (3 : ℤ) ≤ (T₁.card : ℤ) := by rw [← hsum_T₁, ← hsum_eq]; exact hsum_ge
        exact_mod_cast this
      -- ∑_{i ∈ thirdExceed} p.d i * x_ij = ∑_{i ∈ T₁} p.d i
      have hT_sum_eq : ∑ i ∈ P6.j.thirdExceed (paramMap p) j, p.d i * (v.x i j : ℝ)
                     = ∑ i ∈ T₁, p.d i := by
        have hrestrict : (∑ i ∈ P6.j.thirdExceed (paramMap p) j, p.d i * (v.x i j : ℝ))
                       = ∑ i ∈ T₁, p.d i * (v.x i j : ℝ) := by
          symm
          apply Finset.sum_subset hT₁_sub
          intro i hi hi_notin
          simp [T₁, hi] at hi_notin
          rcases h.hx_bin i j with hx | hx
          · rw [hx]; simp
          · exact absurd hx hi_notin
        rw [hrestrict]
        apply Finset.sum_congr rfl
        intro i hi
        simp [T₁] at hi
        rw [hi.2]; push_cast; ring
      -- For i ∈ T₁, p.d i > p.u j / 3
      have hT₁_mem : ∀ i ∈ T₁, p.u j / 3 < p.d i := by
        intro i hi
        have : i ∈ P6.j.thirdExceed (paramMap p) j := hT₁_sub hi
        exact (hmem_iff i).mp this
      -- ∑_{i ∈ T₁} p.d i > |T₁| * (u_j/3)
      have hT₁_nonempty : T₁.Nonempty := Finset.card_pos.mp (by omega)
      have hT₁_sum_gt : (T₁.card : ℝ) * (p.u j / 3) < ∑ i ∈ T₁, p.d i := by
        have hlt := Finset.sum_lt_sum_of_nonempty (s := T₁)
          (f := fun _ : Fin p.n => p.u j / 3) (g := p.d) hT₁_nonempty hT₁_mem
        simp at hlt
        linarith
      -- ∑_{i ∈ thirdExceed} p.d i * x_ij ≤ ∑_i p.d i * x_ij
      have hT_le_full :
          (∑ i ∈ P6.j.thirdExceed (paramMap p) j, p.d i * (v.x i j : ℝ))
            ≤ ∑ i : Fin p.n, p.d i * (v.x i j : ℝ) := by
        apply Finset.sum_le_sum_of_subset_of_nonneg
        · exact subset_univ _
        · intro k _ _
          rcases h.hx_bin k j with hk | hk
          · rw [hk]; simp
          · rw [hk]; push_cast
            have := p.hd_pos k; linarith
      have h3le : (3 : ℝ) * (p.u j / 3) ≤ (T₁.card : ℝ) * (p.u j / 3) := by
        apply mul_le_mul_of_nonneg_right
        · exact_mod_cast hT₁_card
        · have := p.hu_nn j; linarith
      have h3eq : (3 : ℝ) * (p.u j / 3) = p.u j := by ring
      have h2 : p.u j < ∑ i ∈ T₁, p.d i := by linarith
      -- p.u j < ∑_{T₁} p.d i = ∑_{thirdExceed} p.d i * x ≤ ∑_i p.d i * x ≤ p.u j * 1 = p.u j
      rw [← hT_sum_eq] at h2
      rw [hy1] at hcap
      push_cast at hcap
      linarith

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (_ : P6.a.Params) (v : P6.j.Vars) : P6.a.Vars :=
  { x := v.x, y := v.y }

private lemma bwd_feas (p : P6.a.Params) (v : P6.j.Vars)
    (h : P6.j.Feasible (paramMap p) v) :
    P6.a.Feasible p (bwd p v) := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro i; exact h.hassign i
  · intro j; exact h.hcap j
  · intro i j; exact h.hx_bin i j
  · intro j; exact h.hy_bin j

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aJEquiv : MILPReformulation P6.a.formulation P6.j.formulation where
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
