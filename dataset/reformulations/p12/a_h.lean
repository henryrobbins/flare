import Common
import problems.p12.formulations.a.Formulation
import problems.p12.formulations.h.Formulation
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

private lemma xnn {p : P12.a.Params} {v : P12.a.Vars p} (h : P12.a.Feasible p v)
    (a b : Fin p.n) : 0 ≤ v.x a b := by
  rcases h.hx_bin a b with h0 | h1 <;> omega

/-- Each node has a unique outgoing arc in Fin p.n. -/
private lemma exists_unique_out {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) (i : Fin p.n) :
    ∃! k : Fin p.n, v.x i k = 1 := by
  haveI : NeZero p.n := ⟨by have := p.hn; omega⟩
  have hsum := h.hout i
  have hex : ∃ k : Fin p.n, v.x i k = 1 := by
    by_contra hc
    push_neg at hc
    have h0 : ∀ k : Fin p.n, v.x i k = 0 := fun k =>
      (h.hx_bin i k).resolve_right (hc k)
    simp [h0] at hsum
  obtain ⟨k, hk⟩ := hex
  refine ⟨k, hk, fun k' hk' => ?_⟩
  by_contra hne
  have hge : ∑ j : Fin p.n, v.x i j ≥ v.x i k + v.x i k' :=
    calc ∑ j : Fin p.n, v.x i j
        ≥ ∑ j ∈ ({k, k'} : Finset (Fin p.n)), v.x i j :=
          sum_le_sum_of_subset_of_nonneg (subset_univ _)
            (fun j _ _ => xnn h i j)
      _ = v.x i k + v.x i k' := sum_pair (Ne.symm hne)
  linarith

/-- Each node has a unique incoming arc in Fin p.n. -/
private lemma exists_unique_in {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) (j : Fin p.n) :
    ∃! k : Fin p.n, v.x k j = 1 := by
  haveI : NeZero p.n := ⟨by have := p.hn; omega⟩
  have hsum := h.hin j
  have hex : ∃ k : Fin p.n, v.x k j = 1 := by
    by_contra hc
    push_neg at hc
    have h0 : ∀ k : Fin p.n, v.x k j = 0 := fun k =>
      (h.hx_bin k j).resolve_right (hc k)
    simp [h0] at hsum
  obtain ⟨k, hk⟩ := hex
  refine ⟨k, hk, fun k' hk' => ?_⟩
  by_contra hne
  have hge : ∑ i : Fin p.n, v.x i j ≥ v.x k j + v.x k' j :=
    calc ∑ i : Fin p.n, v.x i j
        ≥ ∑ i ∈ ({k, k'} : Finset (Fin p.n)), v.x i j :=
          sum_le_sum_of_subset_of_nonneg (subset_univ _)
            (fun i _ _ => xnn h i j)
      _ = v.x k j + v.x k' j := sum_pair (Ne.symm hne)
  linarith

/-- The successor of i (unique k with x i k = 1), as Fin p.n. -/
private noncomputable def succF {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) (i : Fin p.n) : Fin p.n :=
  (exists_unique_out h i).choose

private lemma succF_spec {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) (i : Fin p.n) : v.x i (succF h i) = 1 :=
  (exists_unique_out h i).choose_spec.1

private lemma succF_unique {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) (i k : Fin p.n) (hk : v.x i k = 1) :
    k = succF h i := by
  obtain ⟨w, hw, hun⟩ := exists_unique_out h i
  have h1 : k = w := hun k hk
  have h2 : succF h i = w := hun (succF h i) (succF_spec h i)
  rw [h1, h2]

private lemma succF_injective {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) : Function.Injective (succF h) := by
  intro a b hab
  have ha := succF_spec h a
  have hb := succF_spec h b
  rw [hab] at ha
  by_contra hne
  have hin := h.hin (succF h b)
  have hge : ∑ j : Fin p.n, v.x j (succF h b) ≥
      v.x a (succF h b) + v.x b (succF h b) :=
    calc ∑ j : Fin p.n, v.x j (succF h b)
        ≥ ∑ j ∈ ({a, b} : Finset (Fin p.n)), v.x j (succF h b) :=
          sum_le_sum_of_subset_of_nonneg (subset_univ _)
            (fun j _ _ => xnn h j (succF h b))
      _ = v.x a (succF h b) + v.x b (succF h b) := sum_pair hne
  linarith

private lemma succF_ne_self {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) (i : Fin p.n) : succF h i ≠ i := by
  intro heq
  have hs := succF_spec h i
  rw [heq] at hs
  have : v.x i i = 0 := h.hx_no_self i
  omega

/-- MTZ gives strict position increase along non-depot arcs. -/
private lemma pos_increase {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) {a : Fin p.n} (ha : a.val ≠ 0)
    (hsa : (succF h a).val ≠ 0) :
    v.u a + 1 ≤ v.u (succF h a) := by
  have hx := succF_spec h a
  have hne := succF_ne_self h a
  have hmtz := h.hmtz a (succF h a) ha hsa (Ne.symm hne)
  have hcast : (v.x a (succF h a) : ℝ) = 1 := by exact_mod_cast hx
  nlinarith [hmtz, hcast]

private lemma pos_iterate_increase {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) {m : Fin p.n} (_hm : m.val ≠ 0) {k : ℕ}
    (hall : ∀ i : ℕ, i ≤ k → ((succF h)^[i] m).val ≠ 0) :
    v.u m + k ≤ v.u ((succF h)^[k] m) := by
  induction k with
  | zero => simp
  | succ k ih =>
    have hall_k : ∀ i, i ≤ k → ((succF h)^[i] m).val ≠ 0 :=
      fun i hi => hall i (by omega)
    have hk_ne : ((succF h)^[k] m).val ≠ 0 := hall k (Nat.le_succ k)
    have hsk_ne : ((succF h)^[k + 1] m).val ≠ 0 := hall (k + 1) le_rfl
    have ih' := ih hall_k
    rw [Function.iterate_succ', Function.comp_apply]
    rw [Function.iterate_succ', Function.comp_apply] at hsk_ne
    have step := pos_increase h hk_ne hsk_ne
    push_cast; linarith

private lemma reaches_depot {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) (m : Fin p.n) :
    ∃ k : ℕ, ((succF h)^[k] m).val = 0 := by
  haveI : NeZero p.n := ⟨by have := p.hn; omega⟩
  by_contra hc
  push_neg at hc
  have hall : ∀ i : ℕ, ((succF h)^[i] m).val ≠ 0 := hc
  have hm : m.val ≠ 0 := hall 0
  have hgrow : ∀ k : ℕ, v.u m + k ≤ v.u ((succF h)^[k] m) :=
    fun k => pos_iterate_increase h hm (fun i _ => hall i)
  have hbound := h.hu_hi ((succF h)^[p.n] m)
  have hpn := hgrow p.n
  have hlo := h.hu_lo m hm
  linarith

private lemma no_nondepot_period {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) {m : Fin p.n} (hm : m.val ≠ 0) {q : ℕ} (hq : 0 < q)
    (hperiod : (succF h)^[q] m = m)
    (hall : ∀ i, i ≤ q → ((succF h)^[i] m).val ≠ 0) : False := by
  have hinc := pos_iterate_increase h hm hall
  rw [hperiod] at hinc
  have : (q : ℝ) > 0 := Nat.cast_pos.mpr hq
  linarith

private lemma succF_bijective {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) : Function.Bijective (succF h) :=
  Finite.injective_iff_bijective.mp (succF_injective h)

private lemma min_reaches_depot {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) (m : Fin p.n) :
    ∃ k : ℕ, ((succF h)^[k] m).val = 0 ∧
      ∀ i, i < k → ((succF h)^[i] m).val ≠ 0 := by
  have hex := reaches_depot h m
  refine ⟨Nat.find hex, Nat.find_spec hex, fun i hi heq => ?_⟩
  exact Nat.find_min hex hi heq

private lemma chain_length_aux {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) (j : Fin p.n) (_hj : j.val ≠ 0)
    (hxj : haveI : NeZero p.n := ⟨by have := p.hn; omega⟩; v.x 0 j = 1) :
    ∃ k : ℕ, k = p.n - 1 ∧ ((succF h)^[k] j).val = 0 ∧
      ∀ i, i < k → ((succF h)^[i] j).val ≠ 0 := by
  haveI : NeZero p.n := ⟨by have := p.hn; omega⟩
  have hn_pos : 0 < p.n := Nat.pos_of_ne_zero (NeZero.ne p.n)
  obtain ⟨k, hk_zero, hk_nondepot⟩ := min_reaches_depot h j
  refine ⟨k, ?_, hk_zero, hk_nondepot⟩
  have hk_le : k ≤ p.n - 1 := by
    by_contra hlt; push_neg at hlt
    have hninj : ¬ Function.Injective (fun i : Fin p.n => (succF h)^[i.val] j) := by
      intro hinj
      have h0_not : ∀ i : Fin p.n, ((succF h)^[i.val] j).val ≠ 0 :=
        fun i => hk_nondepot i.val (by omega)
      have hsurj := Finite.injective_iff_surjective.mp hinj
      obtain ⟨i, hi⟩ := hsurj ⟨0, hn_pos⟩
      simp only at hi
      have hvz : ((succF h)^[i.val] j).val = 0 := by rw [hi]
      exact h0_not i hvz
    obtain ⟨⟨a, ha⟩, ⟨b, hb⟩, hab_eq, hab_ne⟩ :=
      (Function.not_injective_iff.mp hninj : ∃ a b : Fin p.n, _)
    simp only at hab_eq
    have hab_ne' : a ≠ b := fun heq => hab_ne (Fin.ext heq)
    rcases Nat.lt_or_gt_of_ne hab_ne' with hab | hab <;> {
      have h1_ne := hk_nondepot (min a b) (by omega)
      have h1_period : (succF h)^[max a b - min a b] ((succF h)^[min a b] j) =
          (succF h)^[min a b] j := by
        rw [← Function.iterate_add_apply, Nat.sub_add_cancel (min_le_max (a := a) (b := b))]
        simp only [Nat.max_def, Nat.min_def] at *
        split_ifs <;> [exact hab_eq.symm; exact hab_eq]
      have h1_hall : ∀ i, i ≤ max a b - min a b →
          ((succF h)^[i] ((succF h)^[min a b] j)).val ≠ 0 := by
        intro i hi; rw [← Function.iterate_add_apply]; exact hk_nondepot _ (by omega)
      exact no_nondepot_period h h1_ne (by omega) h1_period h1_hall }
  have hk_ge : p.n - 1 ≤ k := by
    let σ : Equiv.Perm (Fin p.n) := Equiv.ofBijective (succF h) (succF_bijective h)
    have hsucc0 : succF h ⟨0, hn_pos⟩ = j :=
      (succF_unique h ⟨0, hn_pos⟩ j hxj).symm
    have hperiod : (σ ^ (k + 1)) (⟨0, hn_pos⟩ : Fin p.n) = ⟨0, hn_pos⟩ := by
      show (succF h)^[k + 1] ⟨0, hn_pos⟩ = ⟨0, hn_pos⟩
      rw [Function.iterate_succ_apply, hsucc0]
      exact Fin.ext hk_zero
    suffices horbit : ∀ m : Fin p.n,
        ∃ q, q ≤ k ∧ (σ ^ q) (⟨0, hn_pos⟩ : Fin p.n) = m by
      have hsurj : Function.Surjective
          (fun i : Fin (k + 1) => (σ ^ i.val) (⟨0, hn_pos⟩ : Fin p.n)) := by
        intro m; obtain ⟨q, hq, hqe⟩ := horbit m; exact ⟨⟨q, by omega⟩, hqe⟩
      have := Fintype.card_le_of_surjective _ hsurj
      simp [Fintype.card_fin] at this; omega
    suffices hinv : ∀ q (m : Fin p.n), (σ ^ q) m = ⟨0, hn_pos⟩ →
        ∃ r, r ≤ k ∧ (σ ^ r) (⟨0, hn_pos⟩ : Fin p.n) = m by
      intro m
      obtain ⟨q, hq⟩ := reaches_depot h m
      refine hinv q m ?_
      show (succF h)^[q] m = ⟨0, hn_pos⟩
      exact Fin.ext hq
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
        have hσk : σ ((σ ^ k) (⟨0, hn_pos⟩ : Fin p.n)) = ⟨0, hn_pos⟩ := by
          rw [← Equiv.Perm.mul_apply, ← pow_succ']; exact hperiod
        exact σ.injective (hσk.trans hre)
      · refine ⟨r - 1, by omega, ?_⟩
        have hpred : (σ ^ r) (⟨0, hn_pos⟩ : Fin p.n) =
            σ ((σ ^ (r - 1)) (⟨0, hn_pos⟩ : Fin p.n)) := by
          conv_lhs => rw [show r = (r - 1) + 1 from by omega, pow_succ',
            Equiv.Perm.mul_apply]
        exact σ.injective (hpred.symm.trans hre)
  omega

/-- When j → i (x_{ji} = 1) with i, j ∈ Fin p.n non-depot, u i = u j + 1. -/
private lemma arc_consec_nondepot {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) {i j : Fin p.n} (hi : i.val ≠ 0) (hj : j.val ≠ 0)
    (hxji : v.x j i = 1) : v.u i = v.u j + 1 := by
  haveI : NeZero p.n := ⟨by have := p.hn; omega⟩
  have hn_pos : 0 < p.n := Nat.pos_of_ne_zero (NeZero.ne p.n)
  have hn2 : 2 ≤ p.n := by
    by_contra hlt; push_neg at hlt
    have hjlt := j.isLt
    exact hj (by omega)
  have hsucc_j : succF h j = i := (succF_unique h j i hxji).symm
  have hlb : v.u j + 1 ≤ v.u i := by
    have := pos_increase h hj (hsucc_j ▸ hi)
    rw [hsucc_j] at this; exact this
  set j0 : Fin p.n := succF h ⟨0, hn_pos⟩ with hj0_def
  have hj0_ne : j0.val ≠ 0 := by
    intro h0
    have : succF h ⟨0, hn_pos⟩ = ⟨0, hn_pos⟩ := Fin.ext h0
    exact succF_ne_self h ⟨0, hn_pos⟩ this
  have hx0j0 : v.x 0 j0 = 1 := by
    have := succF_spec h (⟨0, hn_pos⟩ : Fin p.n)
    simpa using this
  obtain ⟨k, hk_eq, hk_zero, hk_nd⟩ := chain_length_aux h j0 hj0_ne hx0j0
  have hj_in_orbit : ∃ a : ℕ, a ≤ p.n - 2 ∧ (succF h)^[a] j0 = j := by
    let σ : Equiv.Perm (Fin p.n) := Equiv.ofBijective (succF h) (succF_bijective h)
    have hperiod : (σ ^ (k + 1)) (⟨0, hn_pos⟩ : Fin p.n) = ⟨0, hn_pos⟩ := by
      show (succF h)^[k + 1] ⟨0, hn_pos⟩ = ⟨0, hn_pos⟩
      rw [Function.iterate_succ_apply]
      change (succF h)^[k] j0 = ⟨0, hn_pos⟩
      exact Fin.ext hk_zero
    have horbit : ∀ m : Fin p.n,
        ∃ r, r ≤ k ∧ (σ ^ r) (⟨0, hn_pos⟩ : Fin p.n) = m := by
      suffices hinv : ∀ q (m : Fin p.n), (σ ^ q) m = ⟨0, hn_pos⟩ →
          ∃ r, r ≤ k ∧ (σ ^ r) (⟨0, hn_pos⟩ : Fin p.n) = m by
        intro m
        obtain ⟨q, hq⟩ := reaches_depot h m
        refine hinv q m ?_
        show (succF h)^[q] m = ⟨0, hn_pos⟩
        exact Fin.ext hq
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
          have hσk : σ ((σ ^ k) (⟨0, hn_pos⟩ : Fin p.n)) = ⟨0, hn_pos⟩ := by
            rw [← Equiv.Perm.mul_apply, ← pow_succ']; exact hperiod
          exact σ.injective (hσk.trans hre)
        · refine ⟨r - 1, by omega, ?_⟩
          have hpred : (σ ^ r) (⟨0, hn_pos⟩ : Fin p.n) =
              σ ((σ ^ (r - 1)) (⟨0, hn_pos⟩ : Fin p.n)) := by
            conv_lhs => rw [show r = (r - 1) + 1 from by omega, pow_succ',
              Equiv.Perm.mul_apply]
          exact σ.injective (hpred.symm.trans hre)
    obtain ⟨r, hr, hre⟩ := horbit j
    have hr_pos : 1 ≤ r := by
      by_contra hc; push_neg at hc
      interval_cases r; simp at hre
      exact hj (by rw [← hre]; rfl)
    refine ⟨r - 1, by omega, ?_⟩
    show (succF h)^[r - 1] j0 = j
    have heq : (σ ^ r) (⟨0, hn_pos⟩ : Fin p.n) = (succF h)^[r] ⟨0, hn_pos⟩ := rfl
    rw [heq] at hre
    have hshift : (succF h)^[r] (⟨0, hn_pos⟩ : Fin p.n) = (succF h)^[r - 1] j0 := by
      conv_lhs => rw [show r = (r - 1) + 1 from by omega]
      rw [Function.iterate_succ_apply]
    rw [hshift] at hre; exact hre
  obtain ⟨a, ha_le, ha_eq⟩ := hj_in_orbit
  have hi_eq : (succF h)^[a + 1] j0 = i := by
    rw [Function.iterate_succ_apply', ha_eq]; exact hsucc_j
  have hj0_all_nd : ∀ s, s ≤ p.n - 2 → ((succF h)^[s] j0).val ≠ 0 :=
    fun s hs => hk_nd s (by omega)
  by_cases hcase : a + 1 ≤ p.n - 2
  · have ha1_nd : ((succF h)^[a + 1] j0).val ≠ 0 := hk_nd (a + 1) (by omega)
    have hall_j0 : ∀ s, s ≤ p.n - 2 → ((succF h)^[s] j0).val ≠ 0 := hj0_all_nd
    have hinc_j0_last := pos_iterate_increase h hj0_ne hall_j0 (k := p.n - 2)
    have hcast_nm2 : ((p.n - 2 : ℕ) : ℝ) = (p.n : ℝ) - 2 := by
      rw [Nat.cast_sub hn2]; norm_num
    have hj0_pos_ub : v.u j0 ≤ 2 := by
      have hu_last_ub := h.hu_hi ((succF h)^[p.n - 2] j0)
      rw [hcast_nm2] at hinc_j0_last
      linarith
    have hj0_pos_lb : (2 : ℝ) ≤ v.u j0 := h.hu_lo j0 hj0_ne
    have hj0_pos : v.u j0 = 2 := le_antisymm hj0_pos_ub hj0_pos_lb
    have hu_last : v.u ((succF h)^[p.n - 2] j0) = (p.n : ℝ) := by
      have hu_last_ub := h.hu_hi ((succF h)^[p.n - 2] j0)
      rw [hcast_nm2, hj0_pos] at hinc_j0_last
      linarith
    have hu_a1_eq : v.u ((succF h)^[a + 1] j0) = 2 + ((a + 1 : ℕ) : ℝ) := by
      have hall_a1 : ∀ s, s ≤ a + 1 → ((succF h)^[s] j0).val ≠ 0 :=
        fun s hs => hj0_all_nd s (by omega)
      have hinc_a1 := pos_iterate_increase h hj0_ne hall_a1
      have hstep_tail : ∀ s, s ≤ p.n - 2 - (a + 1) →
          ((succF h)^[s] ((succF h)^[a + 1] j0)).val ≠ 0 := by
        intro s hs; rw [← Function.iterate_add_apply]; exact hj0_all_nd _ (by omega)
      have hinc_tail := pos_iterate_increase h ha1_nd hstep_tail
      have heq_tail : (succF h)^[p.n - 2 - (a + 1)] ((succF h)^[a + 1] j0) =
          (succF h)^[p.n - 2] j0 := by
        rw [← Function.iterate_add_apply]; congr 1; omega
      rw [heq_tail, hu_last] at hinc_tail
      rw [hj0_pos] at hinc_a1
      have hcast_tail : ((p.n - 2 - (a + 1) : ℕ) : ℝ) = (p.n : ℝ) - 2 - ((a + 1 : ℕ) : ℝ) := by
        rw [Nat.cast_sub hcase, hcast_nm2]
      rw [hcast_tail] at hinc_tail
      linarith
    have hu_a_eq : v.u ((succF h)^[a] j0) = 2 + (a : ℝ) := by
      by_cases ha0 : a = 0
      · subst ha0; simp; rw [hj0_pos]
      · have ha_pos : 1 ≤ a := Nat.one_le_iff_ne_zero.mpr ha0
        have ha_le' : a ≤ p.n - 2 := by omega
        have hall_a : ∀ s, s ≤ a → ((succF h)^[s] j0).val ≠ 0 :=
          fun s hs => hj0_all_nd s (by omega)
        have hinc_a := pos_iterate_increase h hj0_ne hall_a
        have ha_nd : ((succF h)^[a] j0).val ≠ 0 := hj0_all_nd a (by omega)
        have hstep_a : ∀ s, s ≤ p.n - 2 - a →
            ((succF h)^[s] ((succF h)^[a] j0)).val ≠ 0 := by
          intro s hs; rw [← Function.iterate_add_apply]; exact hj0_all_nd _ (by omega)
        have hinc_a_tail := pos_iterate_increase h ha_nd hstep_a
        have heq_a_tail : (succF h)^[p.n - 2 - a] ((succF h)^[a] j0) =
            (succF h)^[p.n - 2] j0 := by
          rw [← Function.iterate_add_apply]; congr 1; omega
        rw [heq_a_tail, hu_last] at hinc_a_tail
        rw [hj0_pos] at hinc_a
        have hcast_a : ((p.n - 2 - a : ℕ) : ℝ) = (p.n : ℝ) - 2 - (a : ℝ) := by
          rw [Nat.cast_sub ha_le', hcast_nm2]
        rw [hcast_a] at hinc_a_tail
        linarith
    rw [← ha_eq, ← hi_eq, hu_a_eq, hu_a1_eq]
    push_cast; ring
  · push_neg at hcase
    have ha1_eq : a + 1 = p.n - 1 := by omega
    have hi_is_zero : i.val = 0 := by
      rw [← hi_eq, ha1_eq]
      have : (succF h)^[p.n - 1] j0 = ⟨0, hn_pos⟩ := by
        rw [← hk_eq]; exact Fin.ext hk_zero
      rw [this]
    exact absurd hi_is_zero hi

/-- If `x_{i0} = 1` and `i ≠ 0`, then `u_i = n`. -/
private lemma u_eq_n_of_arc_to_depot {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) {i : Fin p.n} (hi : i.val ≠ 0)
    (hxi0 : haveI : NeZero p.n := ⟨by have := p.hn; omega⟩; v.x i 0 = 1) : v.u i = (p.n : ℝ) := by
  haveI : NeZero p.n := ⟨by have := p.hn; omega⟩
  have hn_pos : 0 < p.n := Nat.pos_of_ne_zero (NeZero.ne p.n)
  have hn2 : 2 ≤ p.n := by
    by_contra hlt; push_neg at hlt
    have hilt := i.isLt
    exact hi (by omega)
  -- succF h i = 0
  have hsucc_i : succF h i = ⟨0, hn_pos⟩ :=
    (succF_unique h i ⟨0, hn_pos⟩ (by simpa using hxi0)).symm
  -- Set up j0 = succF h 0
  set j0 : Fin p.n := succF h ⟨0, hn_pos⟩ with hj0_def
  have hj0_ne : j0.val ≠ 0 := by
    intro h0
    have : succF h ⟨0, hn_pos⟩ = ⟨0, hn_pos⟩ := Fin.ext h0
    exact succF_ne_self h ⟨0, hn_pos⟩ this
  have hx0j0 : v.x 0 j0 = 1 := by
    have := succF_spec h (⟨0, hn_pos⟩ : Fin p.n)
    simpa using this
  obtain ⟨k, hk_eq, hk_zero, hk_nd⟩ := chain_length_aux h j0 hj0_ne hx0j0
  -- u j0 = 2 and u (succF^[p.n-2] j0) = p.n
  have hj0_all_nd : ∀ s, s ≤ p.n - 2 → ((succF h)^[s] j0).val ≠ 0 :=
    fun s hs => hk_nd s (by omega)
  have hinc_j0_last := pos_iterate_increase h hj0_ne hj0_all_nd (k := p.n - 2)
  have hcast_nm2 : ((p.n - 2 : ℕ) : ℝ) = (p.n : ℝ) - 2 := by
    rw [Nat.cast_sub hn2]; norm_num
  have hj0_pos_ub : v.u j0 ≤ 2 := by
    have hu_last_ub := h.hu_hi ((succF h)^[p.n - 2] j0)
    rw [hcast_nm2] at hinc_j0_last
    linarith
  have hj0_pos_lb : (2 : ℝ) ≤ v.u j0 := h.hu_lo j0 hj0_ne
  have hj0_pos : v.u j0 = 2 := le_antisymm hj0_pos_ub hj0_pos_lb
  have hu_last : v.u ((succF h)^[p.n - 2] j0) = (p.n : ℝ) := by
    have hu_last_ub := h.hu_hi ((succF h)^[p.n - 2] j0)
    rw [hcast_nm2, hj0_pos] at hinc_j0_last
    linarith
  -- Now show i = (succF h)^[p.n - 2] j0.
  -- Chain: (succF h)^[p.n - 1] j0 = 0 = succF h i, so by injectivity
  -- (succF h)^[p.n - 2] j0 = i (when p.n - 2 = (p.n - 1) - 1).
  have hk_eq' : k = p.n - 1 := hk_eq
  have hchain_last : (succF h)^[p.n - 1] j0 = ⟨0, hn_pos⟩ := by
    rw [← hk_eq']; exact Fin.ext hk_zero
  -- (succF h)^[p.n - 1] j0 = succF h ((succF h)^[p.n - 2] j0)
  have hstep : (succF h)^[p.n - 1] j0 = succF h ((succF h)^[p.n - 2] j0) := by
    conv_lhs => rw [show p.n - 1 = (p.n - 2) + 1 from by omega]
    rw [Function.iterate_succ_apply']
  rw [hstep] at hchain_last
  -- succF h i = ⟨0, hn_pos⟩ = succF h ((succF h)^[p.n - 2] j0)
  have hinj : (succF h)^[p.n - 2] j0 = i :=
    succF_injective h (hchain_last.trans hsucc_i.symm)
  rw [← hinj]; exact hu_last

/-- If `x_{0i} = 1` and `i ≠ 0`, then `u_i = 2`. -/
private lemma u_eq_2_of_arc_from_depot {p : P12.a.Params} {v : P12.a.Vars p}
    (h : P12.a.Feasible p v) {i : Fin p.n} (hi : i.val ≠ 0)
    (hx0i : haveI : NeZero p.n := ⟨by have := p.hn; omega⟩; v.x 0 i = 1) : v.u i = 2 := by
  haveI : NeZero p.n := ⟨by have := p.hn; omega⟩
  have hn_pos : 0 < p.n := Nat.pos_of_ne_zero (NeZero.ne p.n)
  have hn2 : 2 ≤ p.n := by
    by_contra hlt; push_neg at hlt
    have hilt := i.isLt
    exact hi (by omega)
  set j0 : Fin p.n := succF h ⟨0, hn_pos⟩ with hj0_def
  -- i = j0 since both are the unique successor of depot.
  have hi_eq : i = j0 := succF_unique h ⟨0, hn_pos⟩ i (by simpa using hx0i)
  have hj0_ne : j0.val ≠ 0 := by rw [← hi_eq]; exact hi
  have hx0j0 : v.x 0 j0 = 1 := by rw [← hi_eq]; exact hx0i
  obtain ⟨k, hk_eq, hk_zero, hk_nd⟩ := chain_length_aux h j0 hj0_ne hx0j0
  have hj0_all_nd : ∀ s, s ≤ p.n - 2 → ((succF h)^[s] j0).val ≠ 0 :=
    fun s hs => hk_nd s (by omega)
  have hinc_j0_last := pos_iterate_increase h hj0_ne hj0_all_nd (k := p.n - 2)
  have hcast_nm2 : ((p.n - 2 : ℕ) : ℝ) = (p.n : ℝ) - 2 := by
    rw [Nat.cast_sub hn2]; norm_num
  have hj0_pos_ub : v.u j0 ≤ 2 := by
    have hu_last_ub := h.hu_hi ((succF h)^[p.n - 2] j0)
    rw [hcast_nm2] at hinc_j0_last
    linarith
  have hj0_pos_lb : (2 : ℝ) ≤ v.u j0 := h.hu_lo j0 hj0_ne
  have hj0_pos : v.u j0 = 2 := le_antisymm hj0_pos_ub hj0_pos_lb
  rw [hi_eq]; exact hj0_pos

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P12.a.Params) : P12.h.Params :=
  { n  := p.n
    c  := p.c
    hn := p.hn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (p : P12.a.Params) (v : P12.a.Vars p) : P12.h.Vars (paramMap p) :=
  { x := v.x
    u := v.u }

private lemma fwd_hec4 (p : P12.a.Params) (v : P12.a.Vars p)
    (h : P12.a.Feasible p v) :
    ∀ i : Fin (paramMap p).n, i.val ≠ 0 →
      haveI : NeZero (paramMap p).n := ⟨by have := (paramMap p).hn; omega⟩
      3 - ((fwd p v).x 0 i : ℝ) + (((paramMap p).n : ℝ) - 3) *
        ((fwd p v).x i 0 : ℝ) ≤ (fwd p v).u i := by
  intro i hi
  simp only [fwd, paramMap]
  haveI : NeZero p.n := ⟨by have := p.hn; omega⟩
  have hn_pos : 0 < p.n := Nat.pos_of_ne_zero (NeZero.ne p.n)
  have hi_lt : i.val < p.n := i.isLt
  have hn2 : 2 ≤ p.n := by
    by_contra hlt; push_neg at hlt
    exact hi (by omega)
  rcases h.hx_bin (0 : Fin p.n) i with hx0i | hx0i
  · rcases h.hx_bin i (0 : Fin p.n) with hxi0 | hxi0
    · -- (0, 0): need u_i ≥ 3. i has a non-depot predecessor j.
      rw [hx0i, hxi0]; push_cast
      -- Get incoming arc to i.
      obtain ⟨j, hj, _⟩ := exists_unique_in h i
      -- j ≠ depot because v.x 0 i = 0.
      have hj_ne : j.val ≠ 0 := by
        intro h0
        have hjeq : j = (0 : Fin p.n) := Fin.ext (by simpa using h0)
        rw [hjeq] at hj
        rw [hx0i] at hj
        exact absurd hj (by norm_num)
      have harc := arc_consec_nondepot h hi hj_ne hj
      have hulo_j := h.hu_lo j hj_ne
      linarith
    · -- (0, 1): i is last city, u_i = n.
      rw [hx0i, hxi0]; push_cast
      have hu_eq := u_eq_n_of_arc_to_depot h hi hxi0
      linarith
  · rcases h.hx_bin i (0 : Fin p.n) with hxi0 | hxi0
    · -- (1, 0): i is first city, u_i = 2.
      rw [hx0i, hxi0]; push_cast
      have hu_eq := u_eq_2_of_arc_from_depot h hi hx0i
      linarith
    · -- (1, 1): only when n = 2. Tour is 0 → i → 0.
      rw [hx0i, hxi0]; push_cast
      have hu_eq := u_eq_2_of_arc_from_depot h hi hx0i
      -- RHS = 3 - 1 + (n - 3) * 1 = n - 1. Need n - 1 ≤ 2. So need n ≤ 3.
      -- When n ≥ 3, (1,1) is impossible: u_i = 2 and u_i = n by both lemmas.
      have hu_eq_n := u_eq_n_of_arc_to_depot h hi hxi0
      -- u_i = 2 and u_i = n, so n = 2.
      have hn_eq : (p.n : ℝ) = 2 := by linarith
      linarith

private lemma fwd_feas (p : P12.a.Params) (v : P12.a.Vars p)
    (h : P12.a.Feasible p v) :
    P12.h.Feasible (paramMap p) (fwd p v) :=
  { hout       := h.hout
    hin        := h.hin
    hmtz       := h.hmtz
    hu_depot   := h.hu_depot
    hx_bin     := h.hx_bin
    hu_lo      := h.hu_lo
    hu_hi      := h.hu_hi
    hx_no_self := h.hx_no_self
    hec4       := fwd_hec4 p v h }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P12.a.Params) (v : P12.h.Vars (paramMap p)) : P12.a.Vars p :=
  { x := v.x
    u := v.u }

private lemma bwd_feas (p : P12.a.Params) (v : P12.h.Vars (paramMap p))
    (h : P12.h.Feasible (paramMap p) v) :
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

def aHReformulation : MILPReformulation P12.a.formulation P12.h.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj p v _ := by
    simp only [P12.a.formulation, P12.h.formulation, P12.a.obj, P12.h.obj,
      fwd, paramMap, id]
  bwd_obj p v _ := by
    simp only [P12.a.formulation, P12.h.formulation, P12.a.obj, P12.h.obj,
      bwd, paramMap, id]

end P12
