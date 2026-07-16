import Common
import problems.p21.formulations.a.Formulation
import problems.p21.formulations.d.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P21

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

/-- For each vertex `i`, there is a unique cluster `q` with `p.C i q = 1`. -/
private lemma exists_unique_cluster {p : P21.d.Params} (i : Fin p.n) :
    ∃! q : Fin p.P, p.C i q = 1 := by
  have hex : ∃ q0 : Fin p.P, p.C i q0 = 1 := by
    by_contra hall
    push_neg at hall
    have hzero : ∀ q : Fin p.P, p.C i q = 0 := fun q => by
      rcases p.hC_bin i q with h | h
      · exact h
      · exact absurd h (hall q)
    have := p.hC_partition i
    rw [Finset.sum_eq_zero (fun q _ => hzero q)] at this
    norm_num at this
  obtain ⟨q0, hq0⟩ := hex
  refine ⟨q0, hq0, ?_⟩
  intro q hq
  by_contra hne
  have hnn : ∀ q : Fin p.P, (0:ℤ) ≤ p.C i q := fun q => by
    rcases p.hC_bin i q with h | h <;> omega
  have hle : p.C i q0 + p.C i q ≤ ∑ qq : Fin p.P, p.C i qq := by
    have hsub : ({q0, q} : Finset (Fin p.P)) ⊆ Finset.univ := Finset.subset_univ _
    have := Finset.sum_le_sum_of_subset_of_nonneg hsub (fun qq _ _ => hnn qq)
    rwa [Finset.sum_pair (Ne.symm hne)] at this
  rw [hq0, hq, p.hC_partition i] at hle
  norm_num at hle

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P21.d.Params) : P21.a.Params :=
  { n                 := p.n
    m                 := p.m
    P                 := p.P
    E                 := p.E
    C                 := p.C
    hn_pos            := p.hn_pos
    hC_bin            := p.hC_bin
    hpartition        := p.hC_partition
    hcluster_nonempty := p.hC_nonempty
    hedge_lt          := p.hedge_lt
    hperfect          := p.hperfect }

-- ============================================================================
-- § Forward Mapping and Feasibility  (P21.d → P21.a)
-- ============================================================================

section ForwardHelpers

variable {p : P21.d.Params} {v' : P21.d.Vars p}
  (hv' : P21.d.Feasible p v')

/-- The set of selected vertices under `v'`. -/
private def selSet (p : P21.d.Params) (v' : P21.d.Vars p) :
    Finset (Fin p.n) :=
  Finset.univ.filter (fun i => v'.x i = 1)

include hv'

/-- For each cluster `q`, there is a unique vertex `i` with `C i q = 1 ∧ x' i = 1`
(i.e. the unique selected vertex of that cluster). -/
private lemma exists_unique_selected (q : Fin p.P) :
    ∃! i : Fin p.n, p.C i q = 1 ∧ v'.x i = 1 := by
  have hterm_bin : ∀ i : Fin p.n, p.C i q * v'.x i = 0 ∨ p.C i q * v'.x i = 1 := by
    intro i
    rcases p.hC_bin i q with hC | hC <;> rcases hv'.hx_bin i with hx | hx <;>
      simp [hC, hx]
  have hnn : ∀ i : Fin p.n, (0:ℤ) ≤ p.C i q * v'.x i := fun i => by
    rcases hterm_bin i with h | h <;> omega
  have hsum : ∑ i : Fin p.n, p.C i q * v'.x i = 1 := hv'.hcluster q
  have hexists : ∃ i0 : Fin p.n, p.C i0 q * v'.x i0 = 1 := by
    by_contra hall
    push_neg at hall
    have hall0 : ∀ i : Fin p.n, p.C i q * v'.x i = 0 :=
      fun i => (hterm_bin i).resolve_right (hall i)
    rw [Finset.sum_eq_zero (fun i _ => hall0 i)] at hsum
    norm_num at hsum
  obtain ⟨i0, hi0⟩ := hexists
  have hCi0 : p.C i0 q = 1 ∧ v'.x i0 = 1 := by
    rcases p.hC_bin i0 q with hC0 | hC1
    · rw [hC0] at hi0; norm_num at hi0
    · rcases hv'.hx_bin i0 with hx0 | hx1
      · rw [hx0] at hi0; norm_num at hi0
      · exact ⟨hC1, hx1⟩
  refine ⟨i0, hCi0, ?_⟩
  intro j ⟨hCj, hxj⟩
  by_contra hji
  have hle : p.C i0 q * v'.x i0 + p.C j q * v'.x j ≤
      ∑ i : Fin p.n, p.C i q * v'.x i := by
    have hsub : ({i0, j} : Finset (Fin p.n)) ⊆ Finset.univ := Finset.subset_univ _
    have := Finset.sum_le_sum_of_subset_of_nonneg hsub (fun i _ _ => hnn i)
    rwa [Finset.sum_pair (Ne.symm hji)] at this
  rw [hCi0.1, hCi0.2, hCj, hxj, hsum] at hle
  norm_num at hle

/-- Exactly one vertex per cluster is selected, so `selSet` has cardinality `P`. -/
private lemma selSet_card :
    (selSet p v').card = p.P := by
  classical
  choose f hf huniq using exists_unique_selected hv'
  have hcard : (Finset.univ : Finset (Fin p.P)).card = (selSet p v').card := by
    apply Finset.card_bij (fun q _ => f q)
    · intro q _
      simp only [selSet, Finset.mem_filter, Finset.mem_univ, true_and]
      exact (hf q).2
    · intro q1 _ q2 _ heq
      have h1 := hf q1
      have h2 := hf q2
      rw [heq] at h1
      have hC1 : p.C (f q2) q1 = 1 := h1.1
      have hC2 : p.C (f q2) q2 = 1 := h2.1
      obtain ⟨q0, _, huniqc⟩ := exists_unique_cluster (f q2)
      rw [huniqc q1 hC1, huniqc q2 hC2]
    · intro i hi
      simp only [selSet, Finset.mem_filter, Finset.mem_univ, true_and] at hi
      obtain ⟨q0, hq0, _⟩ := exists_unique_cluster i
      exact ⟨q0, Finset.mem_univ q0, (huniq q0 i ⟨hq0, hi⟩).symm⟩
  simpa using hcard.symm

/-- Every clique contained in `selSet` has cardinality at most `v'.t.toNat`. -/
private lemma clique_card_le_tToNat (Cl : Finset (Fin p.n)) (hCl : Cl ⊆ selSet p v')
    (hclique : P21.d.IsClique p.E Cl) :
    Cl.card ≤ v'.t.toNat := by
  have hmem : ∀ i ∈ Cl, v'.x i = 1 := by
    intro i hi
    have := hCl hi
    simp only [selSet, Finset.mem_filter, Finset.mem_univ, true_and] at this
    exact this
  have hsum : ∑ i ∈ Cl, v'.x i = Cl.card := by
    rw [Finset.sum_congr rfl (fun i hi => hmem i hi)]
    simp
  have hle : (Cl.card : ℤ) ≤ v'.t := by
    rw [← hsum]
    exact hv'.hclique Cl hclique
  have ht_nn := hv'.ht_nn
  omega

/-- Applying perfectness of the graph to `selSet` (using the clique bound above)
yields a proper coloring of `selSet` using fewer than `v'.t.toNat` colors. -/
private lemma exists_coloring :
    ∃ c : Fin p.n → ℕ, (∀ i ∈ selSet p v', c i < v'.t.toNat) ∧
      ∀ i ∈ selSet p v', ∀ j ∈ selSet p v', i ≠ j →
        P21.d.Adjacent p.E i j → c i ≠ c j :=
  p.hperfect (selSet p v') v'.t.toNat
    (fun Cl hCl hclique => clique_card_le_tToNat hv' Cl hCl hclique)

end ForwardHelpers

/--
Extract a proper coloring of `selSet p v'` using fewer than `v'.t.toNat`
colors when `v'` is feasible; otherwise return the junk all-zero coloring
(never used, since `fwd`/`fwd_feas` are only invoked at feasible `v'`).
-/
private noncomputable def coloringOf (p : P21.d.Params) (v' : P21.d.Vars p) :
    Fin p.n → ℕ :=
  open Classical in
  if hv' : P21.d.Feasible p v' then
    Classical.choose (exists_coloring hv')
  else
    fun _ => 0

private lemma coloringOf_spec (p : P21.d.Params) (v' : P21.d.Vars p)
    (hv' : P21.d.Feasible p v') :
    (∀ i ∈ selSet p v', coloringOf p v' i < v'.t.toNat) ∧
      ∀ i ∈ selSet p v', ∀ j ∈ selSet p v', i ≠ j →
        P21.d.Adjacent p.E i j → coloringOf p v' i ≠ coloringOf p v' j := by
  classical
  unfold coloringOf
  rw [dif_pos hv']
  exact Classical.choose_spec (exists_coloring hv')

/--
**P21.d → P21.a**: given selection `x'` and integer bound `t'` (with
`χ(G[x']) ≤ t' ≤ P`), apply perfectness to the selected vertex set to obtain
a proper coloring `c` using fewer than `t'.toNat` colors, then pad with
unused colors up to exactly `t'`:
- `w i k = 1` iff `i` is selected and `c i = k`
- `y k = 1` iff `k.val < t'.toNat`
-/
private noncomputable def fwd (p : P21.d.Params) (v' : P21.d.Vars p) :
    P21.a.Vars (paramMap p) :=
  open Classical in
  { y := fun k => if k.val < v'.t.toNat then 1 else 0
    w := fun i k => if i ∈ selSet p v' ∧ coloringOf p v' i = k.val then 1 else 0 }

private lemma fwd_feas (p : P21.d.Params) (v' : P21.d.Vars p)
    (hv' : P21.d.Feasible p v') :
    P21.a.Feasible (paramMap p) (fwd p v') := by
  classical
  obtain ⟨hc_lt, hc_proper⟩ := coloringOf_spec p v' hv'
  have ht_nn := hv'.ht_nn
  have ht_le : v'.t ≤ (p.P : ℤ) := hv'.ht_le_P
  have ht_toNat_le : v'.t.toNat ≤ p.P := by omega
  refine
    { hlink := ?_
      hedge := ?_
      hselect := ?_
      hy_bin := ?_
      hw_bin := ?_ }
  · -- hlink: w i k ≤ y k
    intro i k
    show (if i ∈ selSet p v' ∧ coloringOf p v' i = k.val then (1:ℤ) else 0) ≤
      (if k.val < v'.t.toNat then (1:ℤ) else 0)
    by_cases hcond : i ∈ selSet p v' ∧ coloringOf p v' i = k.val
    · rw [if_pos hcond]
      have hklt : k.val < v'.t.toNat := hcond.2 ▸ hc_lt i hcond.1
      rw [if_pos hklt]
    · rw [if_neg hcond]
      split <;> norm_num
  · -- hedge: w (E e).1 k + w (E e).2 k ≤ 1
    intro e k
    show (if (p.E e).1 ∈ selSet p v' ∧ coloringOf p v' (p.E e).1 = k.val then (1:ℤ) else 0) +
      (if (p.E e).2 ∈ selSet p v' ∧ coloringOf p v' (p.E e).2 = k.val then (1:ℤ) else 0) ≤ 1
    by_cases h1 : (p.E e).1 ∈ selSet p v' ∧ coloringOf p v' (p.E e).1 = k.val
    · by_cases h2 : (p.E e).2 ∈ selSet p v' ∧ coloringOf p v' (p.E e).2 = k.val
      · exfalso
        have hne : (p.E e).1 ≠ (p.E e).2 := ne_of_lt (p.hedge_lt e)
        have hadj : P21.d.Adjacent p.E (p.E e).1 (p.E e).2 := Or.inl ⟨e, rfl⟩
        have := hc_proper (p.E e).1 h1.1 (p.E e).2 h2.1 hne hadj
        exact this (h1.2.trans h2.2.symm)
      · rw [if_pos h1, if_neg h2]; norm_num
    · rw [if_neg h1]
      split <;> norm_num
  · -- hselect: exactly one (i,k) per cluster
    intro pp
    obtain ⟨i0, ⟨hCi0, hxi0⟩, hi0_uniq⟩ := exists_unique_selected hv' pp
    have hi0_sel : i0 ∈ selSet p v' := by
      simp only [selSet, Finset.mem_filter, Finset.mem_univ, true_and]
      exact hxi0
    set k0 : Fin p.P := ⟨coloringOf p v' i0, by
      have := hc_lt i0 hi0_sel
      omega⟩ with hk0_def
    -- The double sum reduces to the single term (i0, k0), which is 1.
    have hterm : ∀ i : Fin p.n, ∀ k : Fin p.P,
        p.C i pp * (if i ∈ selSet p v' ∧ coloringOf p v' i = k.val then (1:ℤ) else 0) =
        (if i = i0 ∧ k = k0 then (1:ℤ) else 0) := by
      intro i k
      by_cases hisel : i ∈ selSet p v' ∧ coloringOf p v' i = k.val
      · have hxi1 : v'.x i = 1 := by
          have := hisel.1
          simp only [selSet, Finset.mem_filter, Finset.mem_univ, true_and] at this
          exact this
        rcases p.hC_bin i pp with hC0 | hC1
        · rw [hC0]
          have hine : i ≠ i0 := by
            intro hie
            rw [hie, hCi0] at hC0
            norm_num at hC0
          simp [hine]
        · have hie : i = i0 := (hi0_uniq i ⟨hC1, hxi1⟩)
          have hke : k = k0 := by
            apply Fin.ext
            rw [hk0_def]
            simp only
            rw [← hie]
            exact hisel.2.symm
          rw [hC1, one_mul, if_pos hisel, if_pos ⟨hie, hke⟩]
      · rw [if_neg hisel, mul_zero]
        by_cases hik : i = i0 ∧ k = k0
        · exfalso
          obtain ⟨hie, hke⟩ := hik
          apply hisel
          rw [hie]
          refine ⟨hi0_sel, ?_⟩
          rw [hke, hk0_def]
        · rw [if_neg hik]
    show ∑ i : Fin p.n, ∑ k : Fin p.P,
        p.C i pp * (if i ∈ selSet p v' ∧ coloringOf p v' i = k.val then (1:ℤ) else 0) = 1
    rw [show (∑ i : Fin p.n, ∑ k : Fin p.P,
        p.C i pp * (if i ∈ selSet p v' ∧ coloringOf p v' i = k.val then (1:ℤ) else 0))
        = ∑ i : Fin p.n, ∑ k : Fin p.P, (if i = i0 ∧ k = k0 then (1:ℤ) else 0) from
      Finset.sum_congr rfl (fun i _ => Finset.sum_congr rfl (fun k _ => hterm i k))]
    rw [Finset.sum_eq_single i0]
    · rw [Finset.sum_eq_single k0]
      · rw [if_pos ⟨rfl, rfl⟩]
      · intro k _ hk
        rw [if_neg (fun h => hk h.2)]
      · intro h; exact absurd (Finset.mem_univ k0) h
    · intro i _ hi
      apply Finset.sum_eq_zero
      intro k _
      rw [if_neg (fun h => hi h.1)]
    · intro h; exact absurd (Finset.mem_univ i0) h
  · -- hy_bin
    intro k
    show (if k.val < v'.t.toNat then (1:ℤ) else 0) = 0 ∨
      (if k.val < v'.t.toNat then (1:ℤ) else 0) = 1
    split <;> [right; left] <;> rfl
  · -- hw_bin
    intro i k
    show (if i ∈ selSet p v' ∧ coloringOf p v' i = k.val then (1:ℤ) else 0) = 0 ∨
      (if i ∈ selSet p v' ∧ coloringOf p v' i = k.val then (1:ℤ) else 0) = 1
    split <;> [right; left] <;> rfl

-- ============================================================================
-- § Backward Mapping and Feasibility  (P21.a → P21.d)
-- ============================================================================

section BackwardHelpers

variable {p : P21.d.Params} {v : P21.a.Vars (paramMap p)}
  (h : P21.a.Feasible (paramMap p) v)
include h

/--
For a fixed color `k`, at most one vertex of a clique `S` can be assigned
color `k`: if two distinct vertices `i j ∈ S` both had `w i k = w j k = 1`,
they would be adjacent (since `S` is a clique), and `hedge` on the connecting
edge would force `w i k + w j k ≤ 1`, a contradiction.
-/
private lemma clique_card_le_one (S : Finset (Fin p.n)) (hS : P21.d.IsClique p.E S)
    (k : Fin p.P) :
    (S.filter (fun i => v.w i k = 1)).card ≤ 1 := by
  rw [Finset.card_le_one]
  intro a ha b hb
  simp only [Finset.mem_filter] at ha hb
  by_contra hab
  have hadj := hS a ha.1 b hb.1 hab
  rcases hadj with ⟨e, he⟩ | ⟨e, he⟩ <;> {
    have hedge : v.w (p.E e).1 k + v.w (p.E e).2 k ≤ 1 := h.hedge e k
    rw [he] at hedge
    linarith [ha.2, hb.2] }

/--
For a fixed color `k`, the sum of `w i k` over a clique `S` is at most `y k`.
If `y k = 0`, `hlink` forces every term to be `≤ 0`. If `y k = 1`,
`clique_card_le_one` bounds the number of `1`-terms in the sum (over a
binary-valued function) by `1`.
-/
private lemma clique_sum_le_y (S : Finset (Fin p.n)) (hS : P21.d.IsClique p.E S)
    (k : Fin p.P) :
    ∑ i ∈ S, v.w i k ≤ v.y k := by
  rcases h.hy_bin k with hy0 | hy1
  · rw [hy0]
    apply Finset.sum_nonpos
    intro i _
    have := h.hlink i k
    rw [hy0] at this
    exact this
  · rw [hy1]
    have hcard := clique_card_le_one h S hS k
    -- Rewrite each binary term as an indicator, so the sum counts the `1`-terms.
    have hval : ∑ i ∈ S, v.w i k = ∑ i ∈ S, (if v.w i k = 1 then (1:ℤ) else 0) := by
      apply Finset.sum_congr rfl
      intro i _
      rcases h.hw_bin i k with h0 | h1
      · simp [h0]
      · simp [h1]
    rw [hval, Finset.sum_boole]
    exact_mod_cast hcard

end BackwardHelpers

/--
**P21.a → P21.d**: A vertex is selected (`x_i = 1`) iff it is assigned some
color (`∑_k w_{i,k} = 1`). The color-count bound `t` is set to the number of
colors actually used (`∑_k y_k`), valued in `ℤ` to match `Vars.t : ℤ`.
-/
private def bwd (p : P21.d.Params) (v : P21.a.Vars (paramMap p)) : P21.d.Vars p :=
  { x := fun i => ∑ k : Fin p.P, v.w i k
    t := ∑ k : Fin p.P, v.y k }

private lemma bwd_feas (p : P21.d.Params) (v : P21.a.Vars (paramMap p))
    (hv : P21.a.Feasible (paramMap p) v) :
    P21.d.Feasible p (bwd p v) := by
  have hw_nn : ∀ (i : Fin p.n) (k : Fin p.P), (0 : ℤ) ≤ v.w i k := fun i k => by
    rcases hv.hw_bin i k with h | h <;> omega
  have hy_nn : ∀ k : Fin p.P, (0 : ℤ) ≤ v.y k := fun k => by
    rcases hv.hy_bin k with h | h <;> omega
  have hy_le1 : ∀ k : Fin p.P, v.y k ≤ 1 := fun k => by
    rcases hv.hy_bin k with h | h <;> omega
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · -- hcluster: ∑ i, C i p * x i = 1
    intro pp
    show ∑ i : Fin p.n, p.C i pp * ∑ k : Fin p.P, v.w i k = 1
    simp_rw [Finset.mul_sum]
    exact hv.hselect pp
  · -- hclique: ∑_{i∈S} x_i ≤ t for any clique S
    intro S hS
    show ∑ i ∈ S, (∑ k : Fin p.P, v.w i k : ℤ) ≤ ∑ k : Fin p.P, v.y k
    rw [Finset.sum_comm]
    exact Finset.sum_le_sum (fun k _ => clique_sum_le_y hv S hS k)
  · -- ht_nn: t ≥ 0
    show (0 : ℤ) ≤ ∑ k : Fin p.P, v.y k
    exact Finset.sum_nonneg (fun k _ => hy_nn k)
  · -- ht_le_P: t ≤ P
    show (∑ k : Fin p.P, v.y k) ≤ (p.P : ℤ)
    calc ∑ k : Fin p.P, v.y k ≤ ∑ _k : Fin p.P, (1 : ℤ) := Finset.sum_le_sum (fun k _ => hy_le1 k)
      _ = (p.P : ℤ) := by simp
  · -- hx_bin: x i ∈ {0, 1} for all i
    intro i
    show (∑ k : Fin p.P, v.w i k) = 0 ∨ (∑ k : Fin p.P, v.w i k) = 1
    have hnn : 0 ≤ ∑ k : Fin p.P, v.w i k :=
      Finset.sum_nonneg (fun k _ => hw_nn i k)
    have hle : ∑ k : Fin p.P, v.w i k ≤ 1 := by
      have hexists : ∃ q0 : Fin p.P, p.C i q0 = 1 := by
        by_contra hall
        push_neg at hall
        have hzero : ∀ q : Fin p.P, p.C i q = 0 := fun q => by
          rcases p.hC_bin i q with h | h
          · exact h
          · exact absurd h (hall q)
        linarith [p.hC_partition i,
          show ∑ q : Fin p.P, p.C i q = 0 from
            Finset.sum_eq_zero (fun q _ => hzero q)]
      obtain ⟨q0, hq0⟩ := hexists
      have hterm : ∑ k : Fin p.P, p.C i q0 * v.w i k = ∑ k : Fin p.P, v.w i k := by
        simp_rw [hq0, one_mul]
      have hsel0 : ∑ i' : Fin p.n, ∑ k : Fin p.P, p.C i' q0 * v.w i' k = 1 :=
        hv.hselect q0
      have hle_sum : ∑ k : Fin p.P, v.w i k ≤
          ∑ i' : Fin p.n, ∑ k : Fin p.P, p.C i' q0 * v.w i' k :=
        hterm.symm ▸ Finset.single_le_sum
          (f := fun i' => ∑ k : Fin p.P, p.C i' q0 * v.w i' k)
          (fun i' _ => Finset.sum_nonneg (fun k _ =>
            mul_nonneg (by rcases p.hC_bin i' q0 with h | h <;> omega) (hw_nn i' k)))
          (Finset.mem_univ i)
      linarith [hsel0]
    omega

-- ============================================================================
-- § Objective Mapping
-- ============================================================================

/--
`P21.a.obj (paramMap p) (fwd p v') = ∑_k y_k`, which counts the number of
`k : Fin p.P` with `k.val < v'.t.toNat`. Since `0 ≤ v'.t ≤ p.P`, this count
equals `v'.t.toNat`, which casts back to `v'.t`, matching
`P21.d.obj p v' = v'.t`.
-/
private lemma fwd_obj (p : P21.d.Params) (v' : P21.d.Vars p)
    (hv' : P21.d.Feasible p v') :
    P21.a.obj (paramMap p) (fwd p v') = P21.d.obj p v' := by
  classical
  have ht_nn := hv'.ht_nn
  have ht_le : v'.t ≤ (p.P : ℤ) := hv'.ht_le_P
  have ht_toNat_le : v'.t.toNat ≤ p.P := by omega
  show (∑ k : Fin p.P,
      ((if k.val < v'.t.toNat then (1:ℤ) else 0 : ℤ) : ℝ)) = (v'.t : ℝ)
  have hcount : (Finset.univ.filter (fun k : Fin p.P => k.val < v'.t.toNat)).card =
      v'.t.toNat := by
    have := Fin.card_filter_val_lt (n := p.P) (m := v'.t.toNat)
    simpa [min_eq_right ht_toNat_le, Finset.filter] using this
  have hsum : ∑ k : Fin p.P, (if k.val < v'.t.toNat then (1:ℤ) else 0 : ℤ) =
      ((Finset.univ.filter (fun k : Fin p.P => k.val < v'.t.toNat)).card : ℤ) :=
    Finset.sum_boole (fun k : Fin p.P => k.val < v'.t.toNat) Finset.univ
  have hsumR : ∑ k : Fin p.P, ((if k.val < v'.t.toNat then (1:ℤ) else 0 : ℤ) : ℝ) =
      (v'.t.toNat : ℝ) := by
    rw [← Int.cast_sum, hsum, hcount]
    norm_cast
  rw [hsumR]
  have ht_toNat_cast : ((v'.t.toNat : ℤ) : ℝ) = (v'.t : ℝ) := by
    have : (v'.t.toNat : ℤ) = v'.t := Int.toNat_of_nonneg ht_nn
    exact_mod_cast this
  push_cast at ht_toNat_cast ⊢
  linarith [ht_toNat_cast]

/-- `(bwd p v).t = ∑_k y_k = P21.a.obj p v` after casting to ℝ, so the
objectives match under `objMap = id`. -/
private lemma bwd_obj (p : P21.d.Params) (v : P21.a.Vars (paramMap p))
    (_hv : P21.a.Feasible (paramMap p) v) :
    P21.a.obj (paramMap p) v = P21.d.obj p (bwd p v) := by
  show (∑ k : Fin p.P, (v.y k : ℝ)) = ((∑ k : Fin p.P, v.y k : ℤ) : ℝ)
  push_cast
  ring

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

noncomputable def daReformulation : MILPReformulation P21.d.formulation P21.a.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj     := fwd_obj
  bwd_obj     := bwd_obj

-- ============================================================================
-- § Round-trip Verification (d → a → d)
-- ============================================================================

/--
The lossless direction of the reformulation: collapsing the reconstructed
coloring `fwd p v'` back via `bwd` recovers the original selection/bound `v'`
exactly. Feasibility is genuinely needed: it guarantees each selected vertex
gets a color strictly below `v'.t.toNat ≤ p.P`, so exactly one color index
matches, and it pins `v'.t = v'.t.toNat`.

Note: the reverse composition `fwd (bwd v) = v` does NOT hold in general —
`bwd` is lossy (it forgets which specific color each vertex received) — and is
not required by the `MILPReformulation` definition.
-/
theorem roundtrip (p : P21.d.Params) (v' : P21.d.Vars p)
    (hv' : P21.d.Feasible p v') :
    bwd p (fwd p v') = v' := by
  classical
  obtain ⟨hc_lt, _hc_proper⟩ := coloringOf_spec p v' hv'
  have ht_nn := hv'.ht_nn
  have ht_le : v'.t ≤ (p.P : ℤ) := hv'.ht_le_P
  have ht_toNat_le : v'.t.toNat ≤ p.P := by omega
  -- t-component: counting colors recovers v'.t.
  have ht_eq : (∑ k : Fin p.P, (fwd p v').y k) = v'.t := by
    show (∑ k : Fin p.P, (if k.val < v'.t.toNat then (1:ℤ) else 0)) = v'.t
    have hcount : (Finset.univ.filter (fun k : Fin p.P => k.val < v'.t.toNat)).card =
        v'.t.toNat := by
      have := Fin.card_filter_val_lt (n := p.P) (m := v'.t.toNat)
      simpa [min_eq_right ht_toNat_le, Finset.filter] using this
    have hsum : (∑ k : Fin p.P, (if k.val < v'.t.toNat then (1:ℤ) else 0)) =
        ((Finset.univ.filter (fun k : Fin p.P => k.val < v'.t.toNat)).card : ℤ) :=
      Finset.sum_boole (fun k : Fin p.P => k.val < v'.t.toNat) Finset.univ
    rw [hsum, hcount]
    exact Int.toNat_of_nonneg ht_nn
  -- x-component: exactly the assigned color contributes, recovering v'.x.
  have hx_eq : (fun i => ∑ k : Fin p.P, (fwd p v').w i k) = v'.x := by
    funext i
    show (∑ k : Fin p.P,
      (if i ∈ selSet p v' ∧ coloringOf p v' i = k.val then (1:ℤ) else 0)) = v'.x i
    by_cases hi : i ∈ selSet p v'
    · -- selected vertex: its unique color index contributes 1, matching x i = 1.
      have hxi : v'.x i = 1 := by simpa [selSet] using hi
      rw [hxi]
      have hc_ltP : coloringOf p v' i < p.P :=
        lt_of_lt_of_le (hc_lt i hi) ht_toNat_le
      rw [Finset.sum_eq_single (⟨coloringOf p v' i, hc_ltP⟩ : Fin p.P)]
      · rw [if_pos ⟨hi, rfl⟩]
      · intro k _ hk
        rw [if_neg]
        rintro ⟨_, hcolor⟩
        exact hk (Fin.ext hcolor.symm)
      · intro hcon; exact absurd (Finset.mem_univ _) hcon
    · -- unselected vertex: no color contributes, matching x i = 0.
      have hxi : v'.x i = 0 := by
        rcases hv'.hx_bin i with h0 | h1
        · exact h0
        · exact absurd (by simp [selSet, h1] : i ∈ selSet p v') hi
      rw [hxi]
      apply Finset.sum_eq_zero
      intro k _
      rw [if_neg]
      rintro ⟨hsel, _⟩
      exact hi hsel
  -- Assemble the two components via structure eta (through the projections,
  -- which match `hx_eq`/`ht_eq` up to definitional unfolding of `bwd`/`fwd`).
  have hx' : (bwd p (fwd p v')).x = v'.x := hx_eq
  have ht' : (bwd p (fwd p v')).t = v'.t := ht_eq
  calc bwd p (fwd p v')
      = ⟨(bwd p (fwd p v')).x, (bwd p (fwd p v')).t⟩ := rfl
    _ = ⟨v'.x, v'.t⟩ := by rw [hx', ht']
    _ = v' := rfl

end P21
