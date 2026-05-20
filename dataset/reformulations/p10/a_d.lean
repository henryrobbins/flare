import Common
import problems.p10.formulations.a.Formulation
import problems.p10.formulations.d.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P10

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P10.a.Params) : P10.d.Params :=
  { K := p.K
    N := p.N
    d := p.d
    d0 := p.d0
    dH := p.dH
    v := p.v
    τ_min := p.τ_min
    τ_max := p.τ_max
    hK := p.hK
    hN := p.hN
    hd_pos := p.hd_pos
    htri0 := p.htri0
    htri := p.htri
    hv_nn := p.hv_nn
    hτ_min_nn := p.hτ_min_nn
    hτ_max_nn := p.hτ_max_nn }

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

/-- Embed job `i : Fin p.N` as the node `⟨p.K + i.val, _⟩`. -/
private def jobNode (p : P10.a.Params) (i : Fin p.N) : Fin (p.K + p.N) :=
  ⟨p.K + i.val, by have := i.isLt; omega⟩

/-- Embed truck `k : Fin p.K` as the node `⟨k.val, _⟩`. -/
private def truckNode (p : P10.a.Params) (k : Fin p.K) : Fin (p.K + p.N) :=
  ⟨k.val, by have := k.isLt; omega⟩

private lemma jobNode_injective (p : P10.a.Params) :
    Function.Injective (jobNode p) := by
  intro i j h
  apply Fin.ext
  unfold jobNode at h
  have hv : p.K + i.val = p.K + j.val := congrArg Fin.val h
  omega

/-- Earliest start time, mirrored from P10.d. -/
private noncomputable def EST (p : P10.a.Params) (i : Fin p.N) : ℝ :=
  haveI := p.hK
  max (p.τ_min i) (univ.inf' univ_nonempty (fun k : Fin p.K => p.v k + p.d0 k i))

private noncomputable def rank (p : P10.a.Params) (δ : Fin p.N → ℝ) (i : Fin p.N) : ℕ :=
  (univ.filter (fun j : Fin p.N => δ j < δ i)).card

/-- A routing path of accepted jobs from i to l (depends only on `x`). -/
private inductive RoutingPath (p : P10.a.Params) (x : Fin (p.K + p.N) → Fin (p.K + p.N) → ℤ) :
    Fin p.N → Fin p.N → Prop where
  | single (i j : Fin p.N) (hij : i ≠ j)
      (harc : x (jobNode p i) (jobNode p j) = 1)
      (hi_acc : x (jobNode p i) (jobNode p i) = 0) :
      RoutingPath p x i j
  | step (i j l : Fin p.N)
      (harc : x (jobNode p i) (jobNode p j) = 1)
      (hi_acc : x (jobNode p i) (jobNode p i) = 0)
      (hj_acc : x (jobNode p j) (jobNode p j) = 0)
      (hjl : RoutingPath p x j l) :
      RoutingPath p x i l

private lemma RoutingPath.snoc' {p : P10.a.Params}
    {x : Fin (p.K + p.N) → Fin (p.K + p.N) → ℤ} {a b c : Fin p.N}
    (hab : RoutingPath p x a b)
    (hbc : b ≠ c)
    (harc : x (jobNode p b) (jobNode p c) = 1)
    (hb_acc : x (jobNode p b) (jobNode p b) = 0) :
    RoutingPath p x a c := by
  induction hab with
  | single i j _ harc_ij hi_acc =>
    exact .step i j c harc_ij hi_acc hb_acc (.single j c hbc harc hb_acc)
  | step i j _ harc_ij hi_acc hj_acc _ ih =>
    exact .step i j c harc_ij hi_acc hj_acc (ih hbc harc hb_acc)

-- ============================================================================
-- § Forward Helpers
-- ============================================================================

section ForwardHelpers

variable {p : P10.a.Params} {v : P10.a.Vars p} (h : P10.a.Feasible p v)
include h

private lemma x_nn (u w : Fin (p.K + p.N)) : 0 ≤ v.x u w := by
  rcases h.hx_bin u w with hh | hh <;> omega

private lemma out_pair_le (u a b : Fin (p.K + p.N)) (hab : a ≠ b) :
    v.x u a + v.x u b ≤ 1 := by
  have hcalc :
      v.x u a + v.x u b
        = ∑ w ∈ ({a, b} : Finset (Fin (p.K + p.N))), v.x u w := by
    rw [sum_pair hab]
  have hsub :
      (∑ w ∈ ({a, b} : Finset (Fin (p.K + p.N))), v.x u w)
        ≤ ∑ w : Fin (p.K + p.N), v.x u w := by
    apply sum_le_sum_of_subset_of_nonneg (subset_univ _)
    intro w _ _; exact x_nn h u w
  have hsum := h.hout u
  have hbnd : v.x u a + v.x u b ≤ ∑ w : Fin (p.K + p.N), v.x u w := by linarith
  omega

private lemma in_pair_le (a b u : Fin (p.K + p.N)) (hab : a ≠ b) :
    v.x a u + v.x b u ≤ 1 := by
  have hcalc :
      v.x a u + v.x b u
        = ∑ w ∈ ({a, b} : Finset (Fin (p.K + p.N))), v.x w u := by
    rw [sum_pair hab]
  have hsub :
      (∑ w ∈ ({a, b} : Finset (Fin (p.K + p.N))), v.x w u)
        ≤ ∑ w : Fin (p.K + p.N), v.x w u := by
    apply sum_le_sum_of_subset_of_nonneg (subset_univ _)
    intro w _ _; exact x_nn h w u
  have hsum := h.hin u
  have hbnd : v.x a u + v.x b u ≤ ∑ w : Fin (p.K + p.N), v.x w u := by linarith
  omega

private lemma arc_forces_self_zero (u w : Fin (p.K + p.N))
    (huw : u ≠ w) (harc : v.x u w = 1) :
    v.x u u = 0 := by
  have h1 := out_pair_le h u w u huw.symm
  have h2 := x_nn h u u
  omega

omit h in
private lemma rank_lt_of_delta_lt {i j : Fin p.N}
    (hdlt : v.δ j < v.δ i) :
    rank p v.δ j < rank p v.δ i := by
  apply card_lt_card
  rw [_root_.ssubset_iff_subset_ne]
  refine ⟨?_, ?_⟩
  · intro k hk
    simp only [mem_filter, mem_univ, true_and] at hk ⊢
    exact lt_trans hk hdlt
  · intro heq
    have : j ∈ univ.filter (fun k : Fin p.N => v.δ k < v.δ i) := by
      simp only [mem_filter, mem_univ, true_and]; exact hdlt
    rw [← heq] at this
    simp only [mem_filter, mem_univ, true_and] at this
    exact lt_irrefl _ this

private lemma routing_path_delta_bound {i l : Fin p.N}
    (hi_acc : v.x (jobNode p i) (jobNode p i) = 0)
    (hpath : RoutingPath p v.x i l) :
    v.δ i + p.d i i + p.d i l ≤ v.δ l := by
  induction hpath with
  | single i j _hij harc hi_acc' =>
    have hseq := h.hseq i j harc hi_acc'
    linarith
  | step i j l harc hi_acc' hj_acc hjl ih =>
    have hseq_ij := h.hseq i j harc hi_acc'
    linarith [ih hj_acc, p.htri i l j, p.hd_pos j j]

private lemma reach_truck_path (i : Fin p.N)
    (hi : v.x (jobNode p i) (jobNode p i) = 0) :
    ∃ k : Fin p.K, p.v k + p.d0 k i ≤ v.δ i ∧
      (v.x (truckNode p k) (jobNode p i) = 1 ∨
       ∃ j₀ : Fin p.N, v.x (truckNode p k) (jobNode p j₀) = 1 ∧
         v.x (jobNode p j₀) (jobNode p j₀) = 0 ∧ RoutingPath p v.x j₀ i) := by
  haveI := p.hK
  haveI := p.hN
  suffices hind : ∀ n (i : Fin p.N), rank p v.δ i < n →
      v.x (jobNode p i) (jobNode p i) = 0 →
      ∃ k : Fin p.K, p.v k + p.d0 k i ≤ v.δ i ∧
        (v.x (truckNode p k) (jobNode p i) = 1 ∨
         ∃ j₀ : Fin p.N, v.x (truckNode p k) (jobNode p j₀) = 1 ∧
           v.x (jobNode p j₀) (jobNode p j₀) = 0 ∧ RoutingPath p v.x j₀ i) from
    hind (rank p v.δ i + 1) i (Nat.lt_succ_self _) hi
  intro n
  induction n with
  | zero => intro i hrk; exact absurd hrk (Nat.not_lt_zero _)
  | succ n ih =>
    intro i hrk hacc
    have hpred : ∃ u : Fin (p.K + p.N), v.x u (jobNode p i) = 1 := by
      by_contra hall
      push_neg at hall
      have hzero : ∀ u : Fin (p.K + p.N), v.x u (jobNode p i) = 0 := by
        intro u
        rcases h.hx_bin u (jobNode p i) with h0 | h1
        · exact h0
        · exfalso; exact hall u h1
      have hsum := h.hin (jobNode p i)
      have hsum' : ∑ w : Fin (p.K + p.N), v.x w (jobNode p i) = 0 := by
        apply Finset.sum_eq_zero
        intro w _; exact hzero w
      omega
    obtain ⟨u, hu⟩ := hpred
    have hpred_uniq : ∀ w : Fin (p.K + p.N), w ≠ u →
        v.x w (jobNode p i) = 0 := by
      intro w hw
      have hnn : 0 ≤ v.x w (jobNode p i) := x_nn h w (jobNode p i)
      have hpair : v.x w (jobNode p i) + v.x u (jobNode p i) ≤ 1 :=
        in_pair_le h w u (jobNode p i) hw
      omega
    rcases Nat.lt_or_ge u.val p.K with hlt | hge
    · -- Truck case
      refine ⟨⟨u.val, hlt⟩, ?_, Or.inl ?_⟩
      · have harrival := h.harrival i
        have hu_eq_truck : truckNode p ⟨u.val, hlt⟩ = u := by
          unfold truckNode; exact Fin.ext rfl
        have hk_one : v.x (truckNode p ⟨u.val, hlt⟩) (jobNode p i) = 1 := by
          rw [hu_eq_truck]; exact hu
        have hk_other : ∀ l : Fin p.K, l ≠ ⟨u.val, hlt⟩ →
            v.x (truckNode p l) (jobNode p i) = 0 := by
          intro l hl
          have hne : truckNode p l ≠ u := by
            intro heq; apply hl; apply Fin.ext
            have := congrArg Fin.val heq
            unfold truckNode at this; simpa using this
          exact hpred_uniq _ hne
        set kF : Fin p.K := ⟨u.val, hlt⟩ with hkF_def
        have hsum_eq :
            ∑ l : Fin p.K, (p.d0 l i + p.v l) *
              ((v.x ⟨l.val, by have := l.isLt; omega⟩
                    ⟨p.K + i.val, by have := i.isLt; omega⟩ : ℤ) : ℝ) =
            p.d0 kF i + p.v kF := by
          rw [sum_eq_single kF]
          · have h1 : v.x ⟨kF.val, by have := kF.isLt; omega⟩
                ⟨p.K + i.val, by have := i.isLt; omega⟩ = 1 := hk_one
            rw [h1]; push_cast; ring
          · intro l _ hlk
            have hl0 : v.x ⟨l.val, by have := l.isLt; omega⟩
                ⟨p.K + i.val, by have := i.isLt; omega⟩ = 0 := hk_other l hlk
            rw [hl0]; push_cast; ring
          · simp
        linarith
      · unfold truckNode; exact hu
    · -- Job case
      have hlt2 : u.val - p.K < p.N := by omega
      set j : Fin p.N := ⟨u.val - p.K, hlt2⟩ with hj_def
      have huj : u = jobNode p j := by
        apply Fin.ext; unfold jobNode
        show u.val = p.K + (u.val - p.K); omega
      have hji : j ≠ i := by
        intro heq
        have : u = jobNode p i := by rw [huj, heq]
        rw [this] at hu; omega
      have hji_arc : v.x (jobNode p j) (jobNode p i) = 1 := by
        rw [← huj]; exact hu
      have hne_ji : jobNode p j ≠ jobNode p i := fun e => hji ((jobNode_injective p) e)
      have hj_acc : v.x (jobNode p j) (jobNode p j) = 0 :=
        arc_forces_self_zero h (jobNode p j) (jobNode p i) hne_ji hji_arc
      have hseq_ji := h.hseq j i hji_arc hj_acc
      have hdlt : v.δ j < v.δ i := by linarith [p.hd_pos j j, p.hd_pos j i]
      have hrk_j : rank p v.δ j < rank p v.δ i := rank_lt_of_delta_lt (p := p) hdlt
      have hrk_jn : rank p v.δ j < n := by omega
      obtain ⟨k, hk_bound, hk_path⟩ := ih j hrk_jn hj_acc
      refine ⟨k, ?_, Or.inr ?_⟩
      · linarith [p.htri0 k i j, p.hd_pos j j]
      · rcases hk_path with hk_direct | ⟨j₀, hj₀_arc, hj₀_acc, hj₀_path⟩
        · exact ⟨j, hk_direct, hj_acc, .single j i hji hji_arc hj_acc⟩
        · exact ⟨j₀, hj₀_arc, hj₀_acc, hj₀_path.snoc' hji hji_arc hj_acc⟩

private noncomputable def truckOf (i : Fin p.N) : Fin p.K :=
  haveI := p.hK
  if hh : v.x (jobNode p i) (jobNode p i) = 0 then
    (reach_truck_path h i hh).choose
  else
    ⟨0, p.hK.out.bot_lt⟩

private lemma truckOf_spec {i : Fin p.N}
    (hi : v.x (jobNode p i) (jobNode p i) = 0) :
    p.v (truckOf h i) + p.d0 (truckOf h i) i ≤ v.δ i := by
  unfold truckOf; rw [dif_pos hi]
  exact (reach_truck_path h i hi).choose_spec.1

private lemma truckOf_path {i : Fin p.N}
    (hi : v.x (jobNode p i) (jobNode p i) = 0) :
    v.x (truckNode p (truckOf h i)) (jobNode p i) = 1 ∨
    ∃ j₀ : Fin p.N, v.x (truckNode p (truckOf h i)) (jobNode p j₀) = 1 ∧
      v.x (jobNode p j₀) (jobNode p j₀) = 0 ∧ RoutingPath p v.x j₀ i := by
  unfold truckOf; rw [dif_pos hi]
  exact (reach_truck_path h i hi).choose_spec.2

private lemma EST_le_delta (i : Fin p.N)
    (hi : v.x (jobNode p i) (jobNode p i) = 0) :
    EST p i ≤ v.δ i := by
  haveI := p.hK
  unfold EST
  apply max_le (h.htw_min i)
  obtain ⟨k, hk, _⟩ := reach_truck_path h i hi
  exact (inf'_le _ (mem_univ k)).trans hk

private lemma truckOf_mem_KC {C : Finset (Fin p.N)} {i : Fin p.N}
    (hi_C : i ∈ C)
    (hi_acc : v.x (jobNode p i) (jobNode p i) = 0) :
    truckOf h i ∈ P10.d.KC (paramMap p) C := by
  haveI := p.hK
  simp only [P10.d.KC, mem_filter, mem_univ, true_and]
  exact ⟨i, hi_C, (truckOf_spec h hi_acc).trans (h.htw_max i)⟩

private lemma unique_job_successor {a b c : Fin p.N}
    (hab : v.x (jobNode p a) (jobNode p b) = 1)
    (hac : v.x (jobNode p a) (jobNode p c) = 1) : b = c := by
  by_contra hbc
  have hne : jobNode p b ≠ jobNode p c := fun e => hbc ((jobNode_injective p) e)
  have hop := out_pair_le h (jobNode p a) (jobNode p b) (jobNode p c) hne
  omega

private lemma fork {a b c : Fin p.N}
    (hab : RoutingPath p v.x a b) (hac : RoutingPath p v.x a c) (hbc : b ≠ c) :
    RoutingPath p v.x b c ∨ RoutingPath p v.x c b := by
  induction hab generalizing c with
  | single i j _ harc_ij _ =>
    cases hac with
    | single _ _ _ harc_ic _ =>
      exact absurd (unique_job_successor h harc_ij harc_ic) hbc
    | step _ d _ harc_id _ _ hdc =>
      have := unique_job_successor h harc_ij harc_id; subst this
      exact Or.inl hdc
  | step i d _ harc_id _ _ hdb ih =>
    cases hac with
    | single _ _ _ harc_ic _ =>
      have := unique_job_successor h harc_ic harc_id; subst this
      exact Or.inr hdb
    | step _ e _ harc_ie _ _ hec =>
      have := unique_job_successor h harc_id harc_ie; subst this
      exact ih hec hbc

private lemma same_truck_path {i l : Fin p.N}
    (hi : v.x (jobNode p i) (jobNode p i) = 0)
    (hl : v.x (jobNode p l) (jobNode p l) = 0)
    (hne : i ≠ l)
    (hk : truckOf h i = truckOf h l) :
    RoutingPath p v.x i l ∨ RoutingPath p v.x l i := by
  set k := truckOf h i with hk_def
  have hk_l : truckOf h l = k := hk ▸ rfl
  have hi_path0 := truckOf_path h hi
  have hl_path0 := truckOf_path h hl
  have hi_path :
      v.x (truckNode p k) (jobNode p i) = 1 ∨
      ∃ j₀ : Fin p.N, v.x (truckNode p k) (jobNode p j₀) = 1 ∧
        v.x (jobNode p j₀) (jobNode p j₀) = 0 ∧ RoutingPath p v.x j₀ i := hi_path0
  have hl_path :
      v.x (truckNode p k) (jobNode p l) = 1 ∨
      ∃ j₀ : Fin p.N, v.x (truckNode p k) (jobNode p j₀) = 1 ∧
        v.x (jobNode p j₀) (jobNode p j₀) = 0 ∧ RoutingPath p v.x j₀ l := by
    rw [← hk_l]; exact hl_path0
  rcases hi_path with hi_direct | ⟨j_i, hj_i_arc, hj_i_acc, hpath_i⟩ <;>
  rcases hl_path with hl_direct | ⟨j_l, hj_l_arc, hj_l_acc, hpath_l⟩
  · -- Both direct: unique successor at truck k forces i = l, contradiction with hne.
    have hne_jij : jobNode p i ≠ jobNode p l :=
      fun e => hne ((jobNode_injective p) e)
    have hop := out_pair_le h (truckNode p k) (jobNode p i) (jobNode p l) hne_jij
    omega
  · by_cases heq : i = j_l
    · subst heq; exact Or.inl hpath_l
    · have hne' : jobNode p i ≠ jobNode p j_l :=
        fun e => heq ((jobNode_injective p) e)
      have hop := out_pair_le h (truckNode p k) (jobNode p i) (jobNode p j_l) hne'
      omega
  · by_cases heq : l = j_i
    · subst heq; exact Or.inr hpath_i
    · have hne' : jobNode p l ≠ jobNode p j_i :=
        fun e => heq ((jobNode_injective p) e)
      have hop := out_pair_le h (truckNode p k) (jobNode p l) (jobNode p j_i) hne'
      omega
  · by_cases heq : j_i = j_l
    · subst heq; exact fork h hpath_i hpath_l hne
    · have hne' : jobNode p j_i ≠ jobNode p j_l :=
        fun e => heq ((jobNode_injective p) e)
      have hop := out_pair_le h (truckNode p k) (jobNode p j_i) (jobNode p j_l) hne'
      omega

private lemma clique_accepted_le_KC (C : Finset (Fin p.N))
    (hclique : ∀ i ∈ C, ∀ j ∈ C, i ≠ j →
      (i, j) ∈ P10.d.A_minus (paramMap p) ∧ (j, i) ∈ P10.d.A_minus (paramMap p)) :
    (C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 0)).card ≤
      (P10.d.KC (paramMap p) C).card := by
  apply card_le_card_of_injOn (truckOf h)
  · intro i hi
    simp only [mem_coe, mem_filter] at hi
    exact truckOf_mem_KC h hi.1 hi.2
  · intro i hi l hl hil
    simp only [mem_coe, mem_filter] at hi hl
    obtain ⟨hi_C, hi_acc⟩ := hi
    obtain ⟨hl_C, hl_acc⟩ := hl
    by_contra hne
    rcases same_truck_path h hi_acc hl_acc hne hil with hpath | hpath
    · obtain ⟨-, hinfeas⟩ := (hclique i hi_C l hl_C hne).1
      have hEST := EST_le_delta h i hi_acc
      have hpd := routing_path_delta_bound h hi_acc hpath
      have htw := h.htw_max l
      have heq : P10.d.EST (paramMap p) i = EST p i := rfl
      rw [heq] at hinfeas
      -- (paramMap p).τ_max l < EST p i + (paramMap p).d i i + (paramMap p).d i l
      change p.τ_max l < EST p i + p.d i i + p.d i l at hinfeas
      linarith
    · obtain ⟨-, hinfeas⟩ := (hclique i hi_C l hl_C hne).2
      have hEST := EST_le_delta h l hl_acc
      have hpd := routing_path_delta_bound h hl_acc hpath
      have htw := h.htw_max i
      have heq : P10.d.EST (paramMap p) l = EST p l := rfl
      rw [heq] at hinfeas
      change p.τ_max i < EST p l + p.d l l + p.d l i at hinfeas
      linarith

private lemma hec3_proof (C : Finset (Fin p.N))
    (hclique : ∀ i ∈ C, ∀ j ∈ C, i ≠ j →
      (i, j) ∈ P10.d.A_minus (paramMap p) ∧ (j, i) ∈ P10.d.A_minus (paramMap p)) :
    (C.card - (P10.d.KC (paramMap p) C).card : ℤ) ≤
      ∑ i ∈ C, v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
                    ⟨p.K + i.val, by have := i.isLt; omega⟩ := by
  have hinj := clique_accepted_le_KC h C hclique
  have hsum_lb :
      ((C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 1)).card : ℤ) ≤
      ∑ i ∈ C, v.x (jobNode p i) (jobNode p i) := by
    calc ((C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 1)).card : ℤ)
        = ∑ _i ∈ C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 1), (1 : ℤ) := by simp
      _ = ∑ i ∈ C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 1),
            v.x (jobNode p i) (jobNode p i) := by
          apply sum_congr rfl
          intro i hi
          have h1 := (mem_filter.mp hi).2
          exact h1.symm
      _ ≤ ∑ i ∈ C, v.x (jobNode p i) (jobNode p i) := by
          apply sum_le_sum_of_subset_of_nonneg (filter_subset _ C)
          intro i _ _
          exact x_nn h (jobNode p i) (jobNode p i)
  have hcard : C.card =
      (C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 0)).card +
      (C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 1)).card := by
    have hpart : C =
        C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 0) ∪
        C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 1) := by
      ext a; simp only [mem_union, mem_filter]
      refine ⟨?_, ?_⟩
      · intro ha
        rcases h.hx_bin (jobNode p a) (jobNode p a) with h0 | h1
        · left; exact ⟨ha, h0⟩
        · right; exact ⟨ha, h1⟩
      · rintro (⟨ha, _⟩ | ⟨ha, _⟩) <;> exact ha
    have hdisj :
        Disjoint (C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 0))
          (C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 1)) := by
      simp [disjoint_filter]
      intro a _ h0 h1; omega
    conv_lhs => rw [hpart]
    exact card_union_of_disjoint hdisj
  have main : (C.card : ℤ) - (P10.d.KC (paramMap p) C).card ≤
      ∑ i ∈ C, v.x (jobNode p i) (jobNode p i) := by
    have h1 : (C.card : ℤ) =
        ((C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 0)).card : ℤ) +
        ((C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 1)).card : ℤ) := by
      exact_mod_cast hcard
    have h2 : ((C.filter (fun i => v.x (jobNode p i) (jobNode p i) = 0)).card : ℤ) ≤
        ((P10.d.KC (paramMap p) C).card : ℤ) := by exact_mod_cast hinj
    linarith
  convert main using 1

end ForwardHelpers

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

/-- **P10.a → P10.d**: identity on variables. The new EC3 constraint `hec3` is
derived by a `truckOf` injection from accepted clique jobs into K(C). -/
private def fwd (p : P10.a.Params) (v : P10.a.Vars p) : P10.d.Vars (paramMap p) :=
  { x := v.x
    δ := v.δ }

private lemma fwd_feas (p : P10.a.Params) (v : P10.a.Vars p)
    (h : P10.a.Feasible p v) :
    P10.d.Feasible (paramMap p) (fwd p v) := by
  exact
    { hout      := h.hout
      hin       := h.hin
      harrival  := h.harrival
      hseq      := h.hseq
      htw_min   := h.htw_min
      htw_max   := h.htw_max
      hx_bin    := h.hx_bin
      hec3      := hec3_proof h }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-- **P10.d → P10.a**: identity on variables. Drop the `hec3` constraint. -/
private def bwd (p : P10.a.Params) (v : P10.d.Vars (paramMap p)) : P10.a.Vars p :=
  { x := v.x
    δ := v.δ }

private lemma bwd_feas (p : P10.a.Params) (v : P10.d.Vars (paramMap p))
    (h : P10.d.Feasible (paramMap p) v) :
    P10.a.Feasible p (bwd p v) := by
  exact
    { hout     := h.hout
      hin      := h.hin
      harrival := h.harrival
      hseq     := h.hseq
      htw_min  := h.htw_min
      htw_max  := h.htw_max
      hx_bin   := h.hx_bin }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

noncomputable def aDReformulation : MILPReformulation P10.a.formulation P10.d.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P10
