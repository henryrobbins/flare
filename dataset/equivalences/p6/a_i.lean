import Common
import dataset.problems.p6.formulations.a.Formulation
import dataset.problems.p6.formulations.i.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P6

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

/-- The pairwise conflict property: any two distinct customers in `S` together
exceed the warehouse capacity `p.u j`. -/
private def PairConflict (p : P6.i.Params) (j : Fin p.m) (S : Finset (Fin p.n)) : Prop :=
  ∀ i ∈ S, ∀ i' ∈ S, i ≠ i' → p.u j < p.d i + p.d i'

/-- The initial clique (customers with `d_i > u_j/2`) is pairwise conflicting. -/
private lemma pairConflict_clique (p : P6.i.Params) (j : Fin p.m) :
    PairConflict p j (P6.i.clique p j) := by
  intro i hi i' hi' _
  simp [P6.i.clique] at hi hi'
  linarith

/-- `P6.i.greedyStep` preserves `PairConflict`. -/
private lemma pairConflict_greedyStep (p : P6.i.Params) (j : Fin p.m)
    (acc : Finset (Fin p.n)) (hacc : PairConflict p j acc) (i : Fin p.n) :
    PairConflict p j (P6.i.greedyStep p j acc i) := by
  unfold P6.i.greedyStep
  split_ifs with hcond
  · intro a ha b hb hab
    rw [mem_insert] at ha
    rw [mem_insert] at hb
    rcases ha with rfl | ha
    · rcases hb with rfl | hb
      · exact (hab rfl).elim
      · exact hcond b hb
    · rcases hb with rfl | hb
      · have := hcond a ha
        linarith
      · exact hacc a ha b hb hab
  · exact hacc

/-- Folding `P6.i.greedyStep` over a list preserves `PairConflict`. -/
private lemma pairConflict_foldl (p : P6.i.Params) (j : Fin p.m)
    (l : List (Fin p.n)) (acc : Finset (Fin p.n)) (hacc : PairConflict p j acc) :
    PairConflict p j (l.foldl (P6.i.greedyStep p j) acc) := by
  induction l generalizing acc with
  | nil => simpa
  | cons x xs ih =>
    simp only [List.foldl_cons]
    exact ih _ (pairConflict_greedyStep p j acc hacc x)

/-- The lifted clique is pairwise conflicting. -/
private lemma pairConflict_liftedClique (p : P6.i.Params) (j : Fin p.m) :
    PairConflict p j (P6.i.liftedClique p j) := by
  unfold P6.i.liftedClique
  exact pairConflict_foldl p j _ _ (pairConflict_clique p j)

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P6.a.Params) : P6.i.Params :=
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

private def fwd (_ : P6.a.Params) (v : P6.a.Vars) : P6.i.Vars :=
  { x := v.x
    y := v.y }

private lemma fwd_hec5 (p : P6.a.Params) (v : P6.a.Vars)
    (h : P6.a.Feasible p v) :
    ∀ j : Fin (paramMap p).m,
      ∑ i ∈ P6.i.liftedClique (paramMap p) j, (fwd p v).x i j ≤ (fwd p v).y j := by
  intro j
  -- Use C for the clique to keep the goal readable.
  have hpair : PairConflict (paramMap p) j (P6.i.liftedClique (paramMap p) j) :=
    pairConflict_liftedClique (paramMap p) j
  set C := P6.i.liftedClique (paramMap p) j with hC_def
  change ∑ i ∈ C, v.x i j ≤ v.y j
  -- x values are 0 or 1 and nonnegative
  have hx_nn_int : ∀ i : Fin p.n, 0 ≤ v.x i j := fun i => by
    rcases h.hx_bin i j with h0 | h1 <;> omega
  have hx_nn_real : ∀ i : Fin p.n, (0 : ℝ) ≤ (v.x i j : ℝ) := fun i => by
    exact_mod_cast hx_nn_int i
  -- Case on whether the sum contains any 1.
  by_cases hex : ∃ i ∈ C, v.x i j = 1
  · obtain ⟨i₀, hi₀_mem, hi₀_val⟩ := hex
    -- All other members of C must have x = 0 (else two conflict).
    have hothers : ∀ i ∈ C, i ≠ i₀ → v.x i j = 0 := by
      intro i hi_mem hi_ne
      rcases h.hx_bin i j with h0 | h1
      · exact h0
      · exfalso
        have hconflict : p.u j < p.d i + p.d i₀ := by
          have := hpair i hi_mem i₀ hi₀_mem hi_ne
          simpa [paramMap] using this
        have hcap := h.hcap j
        -- Lower bound on ∑ p.d k * x_{kj} using k ∈ {i, i₀}.
        have hsub : ({i, i₀} : Finset (Fin p.n)) ⊆ univ := subset_univ _
        have hx_i_real : (v.x i j : ℝ) = 1 := by exact_mod_cast h1
        have hx_i₀_real : (v.x i₀ j : ℝ) = 1 := by exact_mod_cast hi₀_val
        have hfnn : ∀ k ∈ (univ : Finset (Fin p.n)), k ∉ ({i, i₀} : Finset (Fin p.n)) →
            0 ≤ p.d k * (v.x k j : ℝ) :=
          fun k _ _ => mul_nonneg (le_of_lt (p.hd_pos k)) (hx_nn_real k)
        have hle := Finset.sum_le_sum_of_subset_of_nonneg hsub hfnn
        have hpair_sum : ∑ k ∈ ({i, i₀} : Finset (Fin p.n)), p.d k * (v.x k j : ℝ) =
            p.d i + p.d i₀ := by
          rw [show ({i, i₀} : Finset (Fin p.n)) = insert i {i₀} from rfl,
              Finset.sum_insert (by simp [hi_ne]),
              Finset.sum_singleton, hx_i_real, hx_i₀_real]
          ring
        rw [hpair_sum] at hle
        -- y_j ≤ 1 since binary.
        have hy_le_one : (v.y j : ℝ) ≤ 1 := by
          rcases h.hy_bin j with hy0 | hy1
          · have : (v.y j : ℝ) = 0 := by exact_mod_cast hy0
            linarith
          · have : (v.y j : ℝ) = 1 := by exact_mod_cast hy1
            linarith
        have hunn : 0 ≤ p.u j := p.hu_nn j
        have huy : p.u j * (v.y j : ℝ) ≤ p.u j := by
          have : p.u j * (v.y j : ℝ) ≤ p.u j * 1 :=
            mul_le_mul_of_nonneg_left hy_le_one hunn
          linarith
        linarith
    -- ∑ over C = v.x i₀ j = 1.
    have hsum_C : ∑ i ∈ C, v.x i j = 1 := by
      rw [← Finset.add_sum_erase C (fun i => v.x i j) hi₀_mem]
      have hrest : ∑ i ∈ C.erase i₀, v.x i j = 0 := by
        apply Finset.sum_eq_zero
        intro i hi
        rw [mem_erase] at hi
        exact hothers i hi.2 hi.1
      rw [hrest, hi₀_val, add_zero]
    rw [hsum_C]
    -- Need 1 ≤ v.y j. Use capacity.
    have hcap := h.hcap j
    -- Lower bound ∑ d k x_{kj} ≥ d i₀ via subset {i₀}.
    have hsub : ({i₀} : Finset (Fin p.n)) ⊆ univ := subset_univ _
    have hx_i₀_real : (v.x i₀ j : ℝ) = 1 := by exact_mod_cast hi₀_val
    have hfnn : ∀ k ∈ (univ : Finset (Fin p.n)), k ∉ ({i₀} : Finset (Fin p.n)) →
        0 ≤ p.d k * (v.x k j : ℝ) :=
      fun k _ _ => mul_nonneg (le_of_lt (p.hd_pos k)) (hx_nn_real k)
    have hle := Finset.sum_le_sum_of_subset_of_nonneg hsub hfnn
    have hsing : ∑ k ∈ ({i₀} : Finset (Fin p.n)), p.d k * (v.x k j : ℝ) = p.d i₀ := by
      rw [Finset.sum_singleton, hx_i₀_real]; ring
    rw [hsing] at hle
    -- unfold paramMap in hcap
    have hcap' : ∑ i, p.d i * (v.x i j : ℝ) ≤ p.u j * (v.y j : ℝ) := hcap
    have hdi₀_pos : 0 < p.d i₀ := p.hd_pos i₀
    -- So u_j * y_j > 0, and since y_j ∈ {0,1}, y_j = 1.
    rcases h.hy_bin j with hy0 | hy1
    · exfalso
      have hyr : (v.y j : ℝ) = 0 := by exact_mod_cast hy0
      rw [hyr, mul_zero] at hcap
      linarith
    · exact le_of_eq hy1.symm
  · -- No i in C has x = 1, so all are 0.
    push_neg at hex
    have hall_zero : ∀ i ∈ C, v.x i j = 0 := fun i hi =>
      (h.hx_bin i j).resolve_right (hex i hi)
    have hsum_zero : ∑ i ∈ C, v.x i j = 0 :=
      Finset.sum_eq_zero (fun i hi => hall_zero i hi)
    rw [hsum_zero]
    rcases h.hy_bin j with hy0 | hy1
    · rw [hy0]
    · rw [hy1]; decide

private lemma fwd_feas (p : P6.a.Params) (v : P6.a.Vars)
    (h : P6.a.Feasible p v) :
    P6.i.Feasible (paramMap p) (fwd p v) :=
  { hassign := h.hassign
    hcap    := h.hcap
    hx_bin  := h.hx_bin
    hy_bin  := h.hy_bin
    hec5    := fwd_hec5 p v h }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (_ : P6.a.Params) (v : P6.i.Vars) : P6.a.Vars :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P6.a.Params) (v : P6.i.Vars)
    (h : P6.i.Feasible (paramMap p) v) :
    P6.a.Feasible p (bwd p v) :=
  { hassign := h.hassign
    hcap    := h.hcap
    hx_bin  := h.hx_bin
    hy_bin  := h.hy_bin }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aIEquiv : MILPEquiv P6.a.formulation P6.i.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P6
