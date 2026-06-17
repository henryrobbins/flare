import Common
import problems.p12.formulations.a.Formulation
import problems.p12.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P12

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

section Helpers

variable {p : P12.a.Params} {v : P12.a.Vars p}

private instance neZeroN (p : P12.a.Params) : NeZero p.n := ⟨by have := p.hn; omega⟩

/-- Each node has a unique outgoing arc. -/
private lemma exists_unique_out (h : P12.a.Feasible p v) (i : Fin p.n) :
    ∃! k, v.x i k = 1 := by
  have hsum := h.hout i
  have hex : ∃ k, v.x i k = 1 := by
    by_contra hc
    push_neg at hc
    have h0 : ∀ k, v.x i k = 0 := fun k => (h.hx_bin i k).resolve_right (hc k)
    simp [h0] at hsum
  obtain ⟨k, hk⟩ := hex
  refine ⟨k, hk, fun k' hk' => ?_⟩
  by_contra hne
  have : ∑ j, v.x i j ≥ v.x i k + v.x i k' :=
    calc ∑ j, v.x i j
        ≥ ∑ j ∈ ({k, k'} : Finset (Fin p.n)), v.x i j :=
          sum_le_sum_of_subset_of_nonneg (subset_univ _)
            (fun j _ _ => by rcases h.hx_bin i j with hb | hb <;> omega)
      _ = v.x i k + v.x i k' := sum_pair (Ne.symm hne)
  linarith

/-- The successor of node i (the unique node k with x i k = 1). -/
private noncomputable def succ (h : P12.a.Feasible p v) (i : Fin p.n) : Fin p.n :=
  (exists_unique_out h i).choose

private lemma succ_spec (h : P12.a.Feasible p v) (i : Fin p.n) : v.x i (succ h i) = 1 :=
  (exists_unique_out h i).choose_spec.1

private lemma succ_unique (h : P12.a.Feasible p v) (i k : Fin p.n) (hk : v.x i k = 1) :
    k = succ h i := by
  have huniq := exists_unique_out h i
  simp only [ExistsUnique] at huniq
  obtain ⟨w, hw, huniq⟩ := huniq
  have h1 : k = w := huniq k hk
  have h2 : succ h i = w := huniq (succ h i) (succ_spec h i)
  rw [h1, h2]

/-- The successor function is injective (from in-degree = 1). -/
private lemma succ_injective (h : P12.a.Feasible p v) : Function.Injective (succ h) := by
  intro a b hab
  have ha := succ_spec h a
  have hb := succ_spec h b
  rw [hab] at ha
  have hin := h.hin (succ h b)
  by_contra hne
  have : ∑ j, v.x j (succ h b) ≥ v.x a (succ h b) + v.x b (succ h b) :=
    calc ∑ j, v.x j (succ h b)
        ≥ ∑ j ∈ ({a, b} : Finset (Fin p.n)), v.x j (succ h b) :=
          sum_le_sum_of_subset_of_nonneg (subset_univ _)
            (fun j _ _ => by rcases h.hx_bin j (succ h b) with hb' | hb' <;> omega)
      _ = v.x a (succ h b) + v.x b (succ h b) := sum_pair hne
  linarith

/-- No self-loops: succ i ≠ i. -/
private lemma succ_ne_self (h : P12.a.Feasible p v) (i : Fin p.n) : succ h i ≠ i := by
  intro he
  have := succ_spec h i
  rw [he] at this
  exact absurd this (by rw [h.hx_no_self]; omega)

/-- MTZ gives strict position increase along non-depot arcs. -/
private lemma pos_increase (h : P12.a.Feasible p v) {a : Fin p.n} (ha : a ≠ 0)
    (hb : succ h a ≠ 0) : v.u a + 1 ≤ v.u (succ h a) := by
  have hx := succ_spec h a
  have hne := succ_ne_self h a
  have hmtz := h.hmtz a (succ h a)
    (by simpa using (Fin.val_ne_zero_iff (n := p.n)).mpr ha)
    (by simpa using (Fin.val_ne_zero_iff (n := p.n)).mpr hb)
    hne.symm
  have hcast : (v.x a (succ h a) : ℝ) = 1 := by exact_mod_cast hx
  nlinarith

/-- Iterating succ on non-depot nodes gives strictly increasing positions. -/
private lemma pos_iterate_increase (h : P12.a.Feasible p v) {m : Fin p.n} (_hm : m ≠ 0)
    {k : ℕ} (hall : ∀ i : ℕ, i ≤ k → (succ h)^[i] m ≠ 0) :
    v.u m + k ≤ v.u ((succ h)^[k] m) := by
  induction k with
  | zero => simp
  | succ k ih =>
    have hall_k : ∀ i, i ≤ k → (succ h)^[i] m ≠ 0 := fun i hi => hall i (by omega)
    have hk_ne : (succ h)^[k] m ≠ 0 := hall k (Nat.le_succ k)
    have hsk_ne : (succ h)^[k + 1] m ≠ 0 := hall (k + 1) le_rfl
    have ih' := ih hall_k
    rw [Function.iterate_succ', Function.comp_apply]
    rw [Function.iterate_succ', Function.comp_apply] at hsk_ne
    have step := pos_increase h hk_ne hsk_ne
    push_cast; linarith

/-- Every node eventually reaches depot by iterating succ. -/
private lemma reaches_depot (h : P12.a.Feasible p v) (m : Fin p.n) :
    ∃ k : ℕ, (succ h)^[k] m = 0 := by
  by_contra hc
  push_neg at hc
  have hall : ∀ i : ℕ, (succ h)^[i] m ≠ 0 := hc
  have hm : m ≠ 0 := hall 0
  have hgrow : ∀ k : ℕ, v.u m + k ≤ v.u ((succ h)^[k] m) :=
    fun k => pos_iterate_increase h hm (fun i _ => hall i)
  have hbound := h.hu_hi ((succ h)^[p.n] m)
  have := hgrow p.n
  have hlo := h.hu_lo m (by simpa using (Fin.val_ne_zero_iff (n := p.n)).mpr hm)
  linarith

/-- No non-depot node is periodic under succ. -/
private lemma no_nondepot_period (h : P12.a.Feasible p v) {m : Fin p.n} (hm : m ≠ 0)
    {q : ℕ} (hp : 0 < q) (hperiod : (succ h)^[q] m = m)
    (hall : ∀ i, i ≤ q → (succ h)^[i] m ≠ 0) : False := by
  have hinc := pos_iterate_increase h hm hall
  rw [hperiod] at hinc
  have : (q : ℝ) > 0 := Nat.cast_pos.mpr hp
  linarith

/-- succ is a bijection on Fin p.n. -/
private lemma succ_bijective (h : P12.a.Feasible p v) : Function.Bijective (succ h) :=
  (Finite.injective_iff_bijective.mp (succ_injective h))

/-- succ 0 = j when x 0 j = 1. -/
private lemma succ_zero (h : P12.a.Feasible p v) (j : Fin p.n) (hxj : v.x 0 j = 1) :
    succ h 0 = j :=
  (succ_unique h 0 j hxj).symm

/-- Minimal k such that succ^[k] m = 0, with all earlier iterates non-depot. -/
private lemma min_reaches_depot (h : P12.a.Feasible p v) (m : Fin p.n) :
    ∃ k : ℕ, (succ h)^[k] m = 0 ∧ ∀ i, i < k → (succ h)^[i] m ≠ 0 := by
  obtain ⟨k, hk⟩ := reaches_depot h m
  have hex : ∃ k, (succ h)^[k] m = 0 := ⟨k, hk⟩
  refine ⟨Nat.find hex, Nat.find_spec hex, fun i hi heq => ?_⟩
  exact Nat.find_min hex hi heq

/-- The chain from j to depot has exactly n - 1 steps. -/
private lemma chain_length (h : P12.a.Feasible p v) (j : Fin p.n) (_hj : j ≠ 0)
    (hxj : v.x 0 j = 1) :
    ∃ k : ℕ, k = p.n - 1 ∧ (succ h)^[k] j = 0 ∧ ∀ i, i < k → (succ h)^[i] j ≠ 0 := by
  obtain ⟨k, hk_zero, hk_nondepot⟩ := min_reaches_depot h j
  refine ⟨k, ?_, hk_zero, hk_nondepot⟩
  have hk_le : k ≤ p.n - 1 := by
    by_contra hlt; push_neg at hlt
    have hninj : ¬ Function.Injective (fun i : Fin p.n => (succ h)^[i.val] j) := by
      intro hinj
      have h0_not : ∀ i : Fin p.n, (succ h)^[i.val] j ≠ 0 :=
        fun i => hk_nondepot i.val (by omega)
      have hsurj := (Finite.injective_iff_surjective.mp hinj)
      obtain ⟨i, hi⟩ := hsurj 0
      exact h0_not i hi
    obtain ⟨⟨a, ha⟩, ⟨b, hb⟩, hab_eq, hab_ne⟩ :=
      (Function.not_injective_iff.mp hninj : ∃ a b : Fin p.n, _)
    simp only at hab_eq
    have hab_ne' : a ≠ b := fun he => hab_ne (Fin.ext he)
    rcases Nat.lt_or_gt_of_ne hab_ne' with hab | hab <;> {
      have h1_ne := hk_nondepot (min a b) (by omega)
      have h1_period :
          (succ h)^[max a b - min a b] ((succ h)^[min a b] j) = (succ h)^[min a b] j := by
        rw [← Function.iterate_add_apply, Nat.sub_add_cancel (min_le_max (a := a) (b := b))]
        simp only [Nat.max_def, Nat.min_def] at *
        split_ifs <;> [exact hab_eq.symm; exact hab_eq]
      have h1_hall :
          ∀ i, i ≤ max a b - min a b → (succ h)^[i] ((succ h)^[min a b] j) ≠ 0 := by
        intro i hi; rw [← Function.iterate_add_apply]; exact hk_nondepot _ (by omega)
      exact no_nondepot_period h h1_ne (by omega) h1_period h1_hall }
  have hk_ge : p.n - 1 ≤ k := by
    let σ : Equiv.Perm (Fin p.n) := Equiv.ofBijective (succ h) (succ_bijective h)
    have hsucc0 : succ h 0 = j := succ_zero h j hxj
    have hperiod : (σ ^ (k + 1)) (0 : Fin p.n) = 0 := by
      show (succ h)^[k + 1] 0 = 0
      rw [Function.iterate_succ_apply, hsucc0, hk_zero]
    have hpow : ∀ a, (σ ^ (a * (k + 1))) (0 : Fin p.n) = 0 := by
      intro a; induction a with
      | zero => simp
      | succ a ih =>
        rw [Nat.succ_mul, pow_add, Equiv.Perm.mul_apply, hperiod, ih]
    suffices horbit : ∀ m : Fin p.n, ∃ q, q ≤ k ∧ (σ ^ q) (0 : Fin p.n) = m by
      have hsurj : Function.Surjective (fun i : Fin (k + 1) => (σ ^ i.val) (0 : Fin p.n)) := by
        intro m; obtain ⟨q, hq, hqe⟩ := horbit m; exact ⟨⟨q, by omega⟩, hqe⟩
      have := Fintype.card_le_of_surjective _ hsurj
      simp [Fintype.card_fin] at this; omega
    suffices hinv : ∀ q (m : Fin p.n), (σ ^ q) m = 0 →
        ∃ r, r ≤ k ∧ (σ ^ r) (0 : Fin p.n) = m by
      intro m
      obtain ⟨q, hq⟩ := reaches_depot h m
      exact hinv q m (by change (succ h)^[q] m = 0; exact hq)
    intro q
    induction q with
    | zero =>
      intro m hm; simp at hm; exact ⟨0, Nat.zero_le k, by simp [hm]⟩
    | succ q ih =>
      intro m hm
      rw [pow_succ, Equiv.Perm.mul_apply] at hm
      obtain ⟨r, hr, hre⟩ := ih (σ m) hm
      by_cases hr0 : r = 0
      · subst hr0; simp at hre
        refine ⟨k, le_refl k, ?_⟩
        have hσk : σ ((σ ^ k) (0 : Fin p.n)) = 0 := by
          rw [← Equiv.Perm.mul_apply, ← pow_succ']; exact hperiod
        exact σ.injective (hσk.trans hre)
      · refine ⟨r - 1, by omega, ?_⟩
        have hpred : (σ ^ r) (0 : Fin p.n) = σ ((σ ^ (r - 1)) (0 : Fin p.n)) := by
          conv_lhs => rw [show r = (r - 1) + 1 from by omega, pow_succ', Equiv.Perm.mul_apply]
        exact σ.injective (hpred.symm.trans hre)
  omega

/-- The first city after depot has MTZ position ≤ 2. -/
private lemma first_city_pos (h : P12.a.Feasible p v) (j : Fin p.n) (hj : j ≠ 0)
    (hxj : v.x 0 j = 1) : v.u j ≤ 2 := by
  obtain ⟨k, hk_eq, hk_zero, hk_nondepot⟩ := chain_length h j hj hxj
  have hn : 2 ≤ p.n := p.hn
  have hk_pos : 1 ≤ k := by omega
  have hall : ∀ i, i ≤ k - 1 → (succ h)^[i] j ≠ 0 :=
    fun i hi => hk_nondepot i (by omega)
  have hinc := pos_iterate_increase h hj hall
  have hbound := h.hu_hi ((succ h)^[k - 1] j)
  have hkn : k - 1 = p.n - 2 := by omega
  have hcast : (↑(k - 1) : ℝ) = ↑p.n - 2 := by
    rw [hkn, Nat.cast_sub hn]; norm_num
  linarith

/-- EC1 cutting plane validity: u_j ≤ 2 + (n-2)(1 - x_{0j}). -/
private lemma tsp_ec1 (h : P12.a.Feasible p v) (j : Fin p.n) (hj : j ≠ 0) :
    v.u j ≤ 2 + ((p.n : ℝ) - 2) * (1 - (v.x 0 j : ℝ)) := by
  rcases h.hx_bin 0 j with h0 | h1
  · have hcast : (v.x 0 j : ℝ) = 0 := by exact_mod_cast h0
    have := h.hu_hi j
    nlinarith
  · have hcast : (v.x 0 j : ℝ) = 1 := by exact_mod_cast h1
    have := first_city_pos h j hj h1
    nlinarith

end Helpers

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P12.a.Params) : P12.b.Params :=
  { n  := p.n
    c  := p.c
    hn := p.hn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (p : P12.a.Params) (v : P12.a.Vars p) : P12.b.Vars (paramMap p) :=
  { x := v.x
    u := v.u }

private lemma fwd_feas (p : P12.a.Params) (v : P12.a.Vars p)
    (h : P12.a.Feasible p v) :
    P12.b.Feasible (paramMap p) (fwd p v) := by
  exact
    { hout       := h.hout
      hin        := h.hin
      hmtz       := h.hmtz
      hu_depot   := h.hu_depot
      hx_bin     := h.hx_bin
      hu_lo      := h.hu_lo
      hu_hi      := h.hu_hi
      hec1       := fun j hj => tsp_ec1 h j
        (by simpa using (Fin.val_ne_zero_iff (n := p.n)).mp hj)
      hx_no_self := h.hx_no_self }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P12.a.Params) (v : P12.b.Vars (paramMap p)) : P12.a.Vars p :=
  { x := v.x
    u := v.u }

private lemma bwd_feas (p : P12.a.Params) (v : P12.b.Vars (paramMap p))
    (h : P12.b.Feasible (paramMap p) v) :
    P12.a.Feasible p (bwd p v) := by
  simp only [bwd, paramMap] at *
  exact
    { hout       := h.hout
      hin        := h.hin
      hmtz       := h.hmtz
      hu_depot   := h.hu_depot
      hx_bin     := h.hx_bin
      hu_lo      := h.hu_lo
      hu_hi      := h.hu_hi
      hx_no_self := h.hx_no_self }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aBReformulation : MILPReformulation P12.a.formulation P12.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  bwd_fwd     := fun _ _ _ => rfl
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj p v _ := by
    simp only [P12.a.formulation, P12.b.formulation, P12.a.obj, P12.b.obj, fwd, paramMap, id]
  bwd_obj p v _ := by
    simp only [P12.a.formulation, P12.b.formulation, P12.a.obj, P12.b.obj, bwd, paramMap, id]

end P12
