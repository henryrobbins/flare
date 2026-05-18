import Common
import problems.p6.formulations.a.Formulation
import problems.p6.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Order.ConditionallyCompleteLattice.Finset
import Mathlib.Tactic

open BigOperators Finset

namespace P6

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P6.a.Params) : P6.b.Params :=
  { n      := p.n
    m      := p.m
    d      := p.d
    u      := p.u
    f      := p.f
    c      := p.c
    hd_pos := p.hd_pos
    hu_nn  := p.hu_nn
    hc_nn  := p.hc_nn
    hf_nn  := p.hf_nn
    hn     := p.hn
    hm     := p.hm }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- fwd is the identity on variables; b adds the EC1 cut, which we must prove.
private def fwd (p : P6.a.Params) (v : P6.a.Vars p) : P6.b.Vars (paramMap p) :=
  { x := v.x
    y := v.y }

-- u j ≤ uMax p.
private lemma u_le_uMax (p : P6.a.Params) (j : Fin p.m) :
    p.u j ≤ P6.b.uMax (paramMap p) := by
  haveI := p.hm
  exact Finite.le_ciSup (α := ℝ) (ι := Fin p.m) (f := fun k : Fin p.m => p.u k) j

section ForwardHelpers

variable {p : P6.a.Params} {v : P6.a.Vars p} (h : P6.a.Feasible p v)
include h

-- Assignment values are nonneg (on Fin indices).
private lemma fwd_x_nn (i : Fin p.n) (j : Fin p.m) : 0 ≤ v.x i j := by
  rcases h.hx_bin i j with h0 | h1 <;> omega

-- y values are nonneg.
private lemma fwd_y_nn (j : Fin p.m) : 0 ≤ v.y j := by
  rcases h.hy_bin j with h0 | h1 <;> omega

-- Each customer has exactly one assigned warehouse (value 1 among binary ys).
private lemma fwd_exists_unique_assign (i : Fin p.n) :
    ∃! j : Fin p.m, v.x i j = 1 := by
  have hsum := h.hassign i
  -- Work with explicit function over Fin p.m.
  let f : Fin p.m → ℤ := fun j => v.x i j
  have hsum' : ∑ j : Fin p.m, f j = 1 := hsum
  have hbin : ∀ j : Fin p.m, f j = 0 ∨ f j = 1 := fun j => h.hx_bin i j
  -- existence
  have hexists : ∃ j : Fin p.m, f j = 1 := by
    by_contra hne
    push_neg at hne
    have hall0 : ∀ j : Fin p.m, f j = 0 := fun j =>
      (hbin j).resolve_right (hne j)
    have : ∑ j : Fin p.m, f j = 0 := by
      apply Finset.sum_eq_zero; intro j _; exact hall0 j
    omega
  obtain ⟨j0, hj0⟩ := hexists
  refine ⟨j0, hj0, ?_⟩
  intro j' hj'
  by_contra hne
  have hj'_in : j' ∈ (univ : Finset (Fin p.m)).erase j0 :=
    Finset.mem_erase.mpr ⟨hne, mem_univ _⟩
  have hsplit : f j0 + ∑ k ∈ (univ : Finset (Fin p.m)).erase j0, f k = 1 := by
    rw [Finset.add_sum_erase _ f (mem_univ j0)]; exact hsum'
  have hsplit2 :
      f j' + ∑ k ∈ ((univ : Finset (Fin p.m)).erase j0).erase j', f k =
        ∑ k ∈ (univ : Finset (Fin p.m)).erase j0, f k :=
    Finset.add_sum_erase _ f hj'_in
  have hrest_nn : 0 ≤ ∑ k ∈ ((univ : Finset (Fin p.m)).erase j0).erase j', f k :=
    Finset.sum_nonneg (fun k _ => fwd_x_nn h i k)
  have hfj0 : f j0 = 1 := hj0
  have hfj' : f j' = 1 := hj'
  omega

end ForwardHelpers

private lemma fwd_feas (p : P6.a.Params) (v : P6.a.Vars p)
    (h : P6.a.Feasible p v) :
    P6.b.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hm
  haveI := p.hn
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · -- hassign
    intro i; exact h.hassign i
  · -- hcap
    intro j; exact h.hcap j
  · -- hx_bin
    intro i j; exact h.hx_bin i j
  · -- hy_bin
    intro j; exact h.hy_bin j
  · -- hec1 : (criticalCustomers (paramMap p)).card ≤ ∑ j, v.y j
    -- Choose, for each critical customer, its unique assigned warehouse.
    classical
    set P := paramMap p
    -- Opened warehouses.
    let O : Finset (Fin P.m) := (univ : Finset (Fin P.m)).filter (fun j => v.y j = 1)
    -- For each i, pick the unique j with v.x i j = 1.
    have hassign_unique : ∀ i : Fin P.n, ∃! j : Fin P.m, v.x i j = 1 := fun i =>
      fwd_exists_unique_assign h i
    let g : Fin P.n → Fin P.m := fun i => Classical.choose (hassign_unique i).exists
    have hg_spec : ∀ i : Fin P.n, v.x i (g i) = 1 := fun i =>
      Classical.choose_spec (hassign_unique i).exists
    -- The critical customers set.
    let C := P6.b.criticalCustomers P
    -- Define y as an explicit Fin-indexed function to avoid ℕ/Fin coercion noise.
    let yF : Fin P.m → ℤ := fun j => v.y j
    have hy_bin' : ∀ j : Fin P.m, yF j = 0 ∨ yF j = 1 := fun j => h.hy_bin j
    -- sum y_j equals card of O.
    have hsum_y : ∑ j : Fin P.m, yF j = (O.card : ℤ) := by
      rw [← Finset.sum_filter_add_sum_filter_not (univ : Finset (Fin P.m))
          (fun j : Fin P.m => yF j = 1) yF]
      have h1 : ∑ j ∈ (univ : Finset (Fin P.m)).filter (fun j => yF j = 1),
          yF j = ((univ : Finset (Fin P.m)).filter (fun j => yF j = 1)).card := by
        rw [Finset.sum_congr rfl (fun j hj => (Finset.mem_filter.mp hj).2)]
        simp
      have h0 : ∑ j ∈ (univ : Finset (Fin P.m)).filter (fun j => ¬ yF j = 1),
          yF j = 0 := by
        apply Finset.sum_eq_zero
        intro j hj
        have hne := (Finset.mem_filter.mp hj).2
        exact (hy_bin' j).resolve_right hne
      rw [h1, h0]
      show ((O).card : ℤ) + 0 = (O.card : ℤ)
      ring
    -- Show g maps C into O, and is injective on C.
    -- Step 1: For critical i, v.y (g i) = 1.
    have hg_open : ∀ i ∈ C, v.y (g i) = 1 := by
      intro i hi
      have hd_crit : P6.b.uMax P / 2 < P.d i := by
        have := (Finset.mem_filter.mp hi).2
        simpa [P6.b.criticalCustomers] using this
      -- From capacity at j = g i : ∑_k d_k * x_k,(gi) ≤ u_(gi) * y_(gi)
      have hcap := h.hcap (g i)
      -- d i * 1 ≤ ∑_k d_k * x_k,(gi)
      have hdi_term : P.d i * (v.x i (g i) : ℝ) = P.d i := by
        rw [hg_spec i]; simp
      -- Show y_(gi) ≠ 0. If it were 0, u*0 = 0 ≥ d_i > 0, contradiction.
      rcases h.hy_bin (g i) with hy0 | hy1
      · exfalso
        -- Use explicit Fin-indexed function for the sum.
        let F : Fin P.n → ℝ := fun k => P.d k * (v.x k (g i) : ℝ)
        have hcap' : ∑ k : Fin P.n, F k ≤ P.u (g i) * (v.y (g i) : ℝ) := hcap
        have hterms_nn : ∀ k ∈ (univ : Finset (Fin P.n)).erase i, 0 ≤ F k := by
          intro k _
          exact mul_nonneg (le_of_lt (P.hd_pos k))
            (by exact_mod_cast fwd_x_nn h k (g i))
        have hsplit := Finset.add_sum_erase (univ : Finset (Fin P.n)) F (mem_univ i)
        have hFi : F i = P.d i := hdi_term
        have hrest_nn : 0 ≤ ∑ k ∈ (univ : Finset (Fin P.n)).erase i, F k :=
          Finset.sum_nonneg hterms_nn
        have hrhs : P.u (g i) * (v.y (g i) : ℝ) = 0 := by
          rw [hy0]; simp
        have hdi_pos : 0 < P.d i := P.hd_pos i
        linarith
      · exact hy1
    -- Step 2: g is injective on C.
    have hg_inj : ∀ i1 ∈ C, ∀ i2 ∈ C, g i1 = g i2 → i1 = i2 := by
      intro i1 hi1 i2 hi2 heq
      by_contra hne
      -- Two distinct critical customers assigned to same warehouse j = g i1
      have hd1 : P6.b.uMax P / 2 < P.d i1 := by
        have := (Finset.mem_filter.mp hi1).2
        simpa [P6.b.criticalCustomers] using this
      have hd2 : P6.b.uMax P / 2 < P.d i2 := by
        have := (Finset.mem_filter.mp hi2).2
        simpa [P6.b.criticalCustomers] using this
      -- Capacity at j = g i1
      have hcap := h.hcap (g i1)
      -- Extract two terms d_{i1} and d_{i2} from the sum
      have hx1 : v.x i1 (g i1) = 1 := hg_spec i1
      have hx2 : v.x i2 (g i1) = 1 := by rw [heq]; exact hg_spec i2
      have hd1_term : P.d i1 * (v.x i1 (g i1) : ℝ) = P.d i1 := by rw [hx1]; simp
      have hd2_term : P.d i2 * (v.x i2 (g i1) : ℝ) = P.d i2 := by rw [hx2]; simp
      have hi2_in : i2 ∈ (univ : Finset (Fin P.n)).erase i1 :=
        Finset.mem_erase.mpr ⟨Ne.symm hne, mem_univ _⟩
      let F : Fin P.n → ℝ := fun k => P.d k * (v.x k (g i1) : ℝ)
      have hcap' : ∑ k : Fin P.n, F k ≤ P.u (g i1) * (v.y (g i1) : ℝ) := hcap
      have step1 := Finset.add_sum_erase (univ : Finset (Fin P.n)) F (mem_univ i1)
      have step2 := Finset.add_sum_erase ((univ : Finset (Fin P.n)).erase i1) F hi2_in
      have hrest_nn : 0 ≤ ∑ k ∈ ((univ : Finset (Fin P.n)).erase i1).erase i2, F k :=
        Finset.sum_nonneg (fun k _ =>
          mul_nonneg (le_of_lt (P.hd_pos k))
            (by exact_mod_cast fwd_x_nn h k (g i1)))
      have hF1 : F i1 = P.d i1 := hd1_term
      have hF2 : F i2 = P.d i2 := hd2_term
      have hu_le : P.u (g i1) ≤ P6.b.uMax P := u_le_uMax p (g i1)
      have hy_le : (v.y (g i1) : ℝ) ≤ 1 := by
        rcases h.hy_bin (g i1) with hy0 | hy1
        · rw [hy0]; norm_num
        · rw [hy1]; norm_num
      have hu_nn : 0 ≤ P.u (g i1) := P.hu_nn (g i1)
      have hrhs_le : P.u (g i1) * (v.y (g i1) : ℝ) ≤ P.u (g i1) := by
        calc P.u (g i1) * (v.y (g i1) : ℝ)
            ≤ P.u (g i1) * 1 :=
              mul_le_mul_of_nonneg_left hy_le hu_nn
          _ = P.u (g i1) := by ring
      linarith
    -- Step 3: conclude |C| ≤ |O| ≤ ∑ y_j.
    -- Use Finset.card_le_card_of_injOn.
    have hg_mapsTo : ∀ i ∈ C, g i ∈ O := by
      intro i hi
      exact Finset.mem_filter.mpr ⟨mem_univ _, hg_open i hi⟩
    have hC_le_O : C.card ≤ O.card :=
      Finset.card_le_card_of_injOn g hg_mapsTo hg_inj
    -- Translate to ℤ.
    show ((P6.b.criticalCustomers P).card : ℤ) ≤ ∑ j : Fin P.m, v.y j
    rw [hsum_y]
    exact_mod_cast hC_le_O

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- bwd simply drops the EC1 cut.
private def bwd (p : P6.a.Params) (v : P6.b.Vars (paramMap p)) : P6.a.Vars p :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P6.a.Params) (v : P6.b.Vars (paramMap p))
    (h : P6.b.Feasible (paramMap p) v) :
    P6.a.Feasible p (bwd p v) := by
  exact
    { hassign := h.hassign
      hcap    := h.hcap
      hx_bin  := h.hx_bin
      hy_bin  := h.hy_bin }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aBReformulation : MILPReformulation P6.a.formulation P6.b.formulation where
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
