import Common
import dataset.problems.p8.formulations.a.Formulation
import dataset.problems.p8.formulations.c.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P8

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

/-- Local copy of formulation c's private `head`. -/
private def hd {n m : ℕ} (p : Fin n → Fin m → ℝ) (j : Fin n) (k : Fin m) : ℝ :=
  ∑ t : Fin m, if t.val < k.val then p j t else 0

/-- Local copy of formulation c's private `tail`. -/
private def tl {n m : ℕ} (p : Fin n → Fin m → ℝ) (j : Fin n) (k : Fin m) : ℝ :=
  ∑ t : Fin m, if k.val < t.val then p j t else 0

/-- Local copy of formulation c's private `machineOps`. -/
private def machineOps (p : P8.a.Params) (i : Fin p.m) : Finset (Fin p.n × Fin p.m) :=
  Finset.univ.filter (fun jk => p.Om jk.1 jk.2 = i)

/-- `machineOps p i` is nonempty (since Om j is surjective for any j). -/
private lemma machineOps_ne (p : P8.a.Params) (i : Fin p.m) : (machineOps p i).Nonempty := by
  have hn : 0 < p.n := Nat.pos_of_ne_zero p.hN.out
  obtain ⟨k, hk⟩ := (p.hOm_perm ⟨0, hn⟩).2 i
  exact ⟨⟨⟨0, hn⟩, k⟩, Finset.mem_filter.mpr ⟨Finset.mem_univ _, hk⟩⟩

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P8.a.Params) : P8.c.Params :=
  { n         := p.n
    m         := p.m
    p         := p.p
    Om        := p.Om
    hN        := p.hN
    hM        := p.hM
    hp_nn     := p.hp_nn
    hOm_perm  := p.hOm_perm }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

/-- Extension of the processing-time row for job `j` from `Fin m` to `ℕ`:
    zero outside the valid range. -/
private noncomputable def pext (p : P8.a.Params) (j : Fin p.n) (i : ℕ) : ℝ :=
  if hi : i < p.m then p.p j ⟨i, hi⟩ else 0

/-- `hd` as a `range` sum of `pext`. -/
private lemma hd_eq_range_sum (p : P8.a.Params) (j : Fin p.n) (k : Fin p.m) :
    hd p.p j k = ∑ i ∈ range k.val, pext p j i := by
  unfold hd
  have hk_lt : k.val < p.m := k.isLt
  have hstep1 :
      (∑ t : Fin p.m, if t.val < k.val then p.p j t else 0)
        = ∑ t : Fin p.m, if t.val < k.val then pext p j t.val else 0 := by
    apply Finset.sum_congr rfl
    intro t _
    by_cases ht : t.val < k.val
    · simp only [ht, if_true]
      unfold pext; simp [t.isLt]
    · simp [ht]
  rw [hstep1]
  rw [Fin.sum_univ_eq_sum_range (fun i => if i < k.val then pext p j i else 0) p.m]
  have hrange_split : range p.m = range k.val ∪ Ico k.val p.m := by
    ext x; simp only [mem_range, mem_union, mem_Ico]; omega
  have hdisj : Disjoint (range k.val) (Ico k.val p.m) := by
    rw [disjoint_left]; intro x hx1 hx2
    simp at hx1 hx2; omega
  rw [hrange_split, sum_union hdisj]
  have hfirst :
      (∑ i ∈ range k.val, if i < k.val then pext p j i else 0)
        = ∑ i ∈ range k.val, pext p j i := by
    apply Finset.sum_congr rfl; intro x hx
    rw [mem_range] at hx; simp [hx]
  have hsecond :
      (∑ i ∈ Ico k.val p.m, if i < k.val then pext p j i else 0) = 0 := by
    apply Finset.sum_eq_zero; intro x hx
    rw [mem_Ico] at hx; simp; omega
  rw [hfirst, hsecond, add_zero]

/-- `tl` as an `Ico` sum of `pext`. -/
private lemma tl_eq_Ico_sum (p : P8.a.Params) (j : Fin p.n) (k : Fin p.m) :
    tl p.p j k = ∑ i ∈ Ico (k.val + 1) p.m, pext p j i := by
  unfold tl
  have hk_lt : k.val < p.m := k.isLt
  have hstep1 :
      (∑ t : Fin p.m, if k.val < t.val then p.p j t else 0)
        = ∑ t : Fin p.m, if k.val < t.val then pext p j t.val else 0 := by
    apply Finset.sum_congr rfl
    intro t _
    by_cases ht : k.val < t.val
    · simp only [ht, if_true]
      unfold pext; simp [t.isLt]
    · simp [ht]
  rw [hstep1]
  rw [Fin.sum_univ_eq_sum_range
    (fun i => if k.val < i then pext p j i else 0) p.m]
  have hrange_split :
      range p.m = Ico 0 (k.val + 1) ∪ Ico (k.val + 1) p.m := by
    ext x; simp only [mem_range, mem_union, mem_Ico]; omega
  have hdisj : Disjoint (Ico 0 (k.val + 1)) (Ico (k.val + 1) p.m) := by
    rw [disjoint_left]; intro x hx1 hx2
    simp at hx1 hx2; omega
  rw [hrange_split, sum_union hdisj]
  have hfirst :
      (∑ i ∈ Ico 0 (k.val + 1), if k.val < i then pext p j i else 0) = 0 := by
    apply Finset.sum_eq_zero; intro x hx
    rw [mem_Ico] at hx; simp; omega
  have hsecond :
      (∑ i ∈ Ico (k.val + 1) p.m, if k.val < i then pext p j i else 0)
        = ∑ i ∈ Ico (k.val + 1) p.m, pext p j i := by
    apply Finset.sum_congr rfl; intro x hx
    rw [mem_Ico] at hx; simp; omega
  rw [hfirst, hsecond, zero_add]

section ForwardHelpers

variable {p : P8.a.Params} {v : P8.a.Vars} (h : P8.a.Feasible p v)
include h

/-- Telescoping (ascending): for every `n < p.m`, the start time of op `n` of
    job `j` is at least the sum of the processing times of the previous ops. -/
private lemma job_telescoping_asc (j : Fin p.n) :
    ∀ n : ℕ, n < p.m →
      (∑ i ∈ range n, pext p j i) ≤ v.S j.val n := by
  intro n hn
  induction n with
  | zero =>
      simp
      have hm_pos : 0 < p.m := hn
      simpa using h.hS_nn j ⟨0, hm_pos⟩
  | succ k ih =>
      have hk_lt : k < p.m := Nat.lt_of_succ_lt hn
      have ih' := ih hk_lt
      have hprec := h.hprec j ⟨k, hk_lt⟩ hn
      have hsplit :
          (∑ i ∈ range (k + 1), pext p j i)
            = (∑ i ∈ range k, pext p j i) + pext p j k := by
        rw [Finset.sum_range_succ]
      have hpext_k : pext p j k = p.p j ⟨k, hk_lt⟩ := by
        unfold pext; simp [hk_lt]
      rw [hsplit, hpext_k]
      linarith

/-- `hd p.p j k ≤ v.S j.val k.val`. -/
private lemma head_le_start (j : Fin p.n) (k : Fin p.m) :
    hd p.p j k ≤ v.S j.val k.val := by
  rw [hd_eq_range_sum]
  exact job_telescoping_asc h j k.val k.isLt

/-- Telescoping (descending): for every `k < p.m`,
    `v.S j.val k + (∑ i ∈ Ico k p.m, pext p j i) ≤ v.Cmax`. -/
private lemma job_telescoping_desc (j : Fin p.n) :
    ∀ k : ℕ, k < p.m →
      v.S j.val k + (∑ i ∈ Ico k p.m, pext p j i) ≤ v.Cmax := by
  haveI := p.hM
  have hm_pos : 0 < p.m := Nat.pos_of_ne_zero p.hM.out
  suffices hsuff : ∀ d : ℕ, d ≤ p.m - 1 →
      v.S j.val (p.m - 1 - d) +
        (∑ i ∈ Ico (p.m - 1 - d) p.m, pext p j i) ≤ v.Cmax by
    intro k hk
    have hd_le : p.m - 1 - k ≤ p.m - 1 := Nat.sub_le _ _
    have := hsuff (p.m - 1 - k) hd_le
    have hk_eq : p.m - 1 - (p.m - 1 - k) = k := by omega
    rw [hk_eq] at this
    exact this
  intro d hd
  induction d with
  | zero =>
      have hmm1_lt : p.m - 1 < p.m := Nat.sub_lt hm_pos Nat.one_pos
      have hmax := h.hmakespan j
      have hIco_singleton :
          (∑ i ∈ Ico (p.m - 1) p.m, pext p j i) = pext p j (p.m - 1) := by
        have : Ico (p.m - 1) p.m = {p.m - 1} := by
          ext x; simp [mem_Ico]; omega
        rw [this]; simp
      have hpext_last : pext p j (p.m - 1) = p.p j ⟨p.m - 1, hmm1_lt⟩ := by
        unfold pext; simp [hmm1_lt]
      simp only [Nat.sub_zero]
      rw [hIco_singleton, hpext_last]
      linarith
  | succ d ih =>
      have hd_le : d ≤ p.m - 1 := Nat.le_of_succ_le hd
      have ih' := ih hd_le
      have hk_new_lt : p.m - 1 - (d + 1) < p.m := by omega
      have hk_old_lt : p.m - 1 - d < p.m := by omega
      have hlt_between : p.m - 1 - (d + 1) < p.m - 1 - d := by omega
      have hsucc_eq : p.m - 1 - (d + 1) + 1 = p.m - 1 - d := by omega
      have hsucc_lt : p.m - 1 - (d + 1) + 1 < p.m := by
        rw [hsucc_eq]; exact hk_old_lt
      have hprec :=
        h.hprec j ⟨p.m - 1 - (d + 1), hk_new_lt⟩ hsucc_lt
      simp only at hprec
      rw [hsucc_eq] at hprec
      have hIco_split :
          Ico (p.m - 1 - (d + 1)) p.m
            = insert (p.m - 1 - (d + 1)) (Ico (p.m - 1 - d) p.m) := by
        ext x; simp [mem_Ico, mem_insert]; omega
      have hnot_mem :
          (p.m - 1 - (d + 1)) ∉ Ico (p.m - 1 - d) p.m := by
        simp [mem_Ico]; omega
      rw [hIco_split, sum_insert hnot_mem]
      have hpext_eq :
          pext p j (p.m - 1 - (d + 1)) = p.p j ⟨p.m - 1 - (d + 1), hk_new_lt⟩ := by
        unfold pext; simp [hk_new_lt]
      rw [hpext_eq]
      linarith

/-- `v.S j.val k.val + p.p j k + tl p.p j k ≤ v.Cmax`. -/
private lemma start_plus_tail_bound (j : Fin p.n) (k : Fin p.m) :
    v.S j.val k.val + p.p j k + tl p.p j k ≤ v.Cmax := by
  have hk_lt : k.val < p.m := k.isLt
  have htele := job_telescoping_desc h j k.val hk_lt
  have hIco_split :
      Ico k.val p.m = insert k.val (Ico (k.val + 1) p.m) := by
    ext x; simp [mem_Ico, mem_insert]; omega
  have hnot_mem : k.val ∉ Ico (k.val + 1) p.m := by simp [mem_Ico]
  rw [hIco_split, sum_insert hnot_mem] at htele
  have hpext_k : pext p j k.val = p.p j k := by
    unfold pext
    simp only [hk_lt, dite_true, Fin.eta]
  rw [hpext_k] at htele
  rw [tl_eq_Ico_sum]
  linarith

/-- Key combinatorial lemma: for any nonempty subset `T` of `machineOps p i`,
    the sum of processing times plus the minimum start time of `T` is bounded
    by the maximum completion time. Uses machine non-overlap. -/
private lemma nonoverlap_chain_sum
    (i : Fin p.m) (T : Finset (Fin p.n × Fin p.m))
    (hT_sub : T ⊆ machineOps p i) (hT_ne : T.Nonempty) :
    (T.sum (fun a : Fin p.n × Fin p.m => p.p a.1 a.2)) +
        T.inf' hT_ne (fun a : Fin p.n × Fin p.m => v.S a.1.val a.2.val)
      ≤ T.sup' hT_ne
          (fun a : Fin p.n × Fin p.m => v.S a.1.val a.2.val + p.p a.1 a.2) := by
  classical
  induction T using Finset.strongInduction with
  | _ T ih =>
    by_cases hT_sing : T.card ≤ 1
    · rcases hT_ne with ⟨a, ha⟩
      have hcard_pos : 1 ≤ T.card := Finset.card_pos.mpr ⟨a, ha⟩
      have hcard : T.card = 1 := le_antisymm hT_sing hcard_pos
      obtain ⟨x, hx⟩ := Finset.card_eq_one.mp hcard
      subst hx
      rw [Finset.mem_singleton] at ha
      subst ha
      simp
      linarith
    · push_neg at hT_sing
      have hcard_ge_two : 2 ≤ T.card := hT_sing
      obtain ⟨aS, haS_mem, haS_min⟩ :=
        T.exists_min_image
          (fun a : Fin p.n × Fin p.m => v.S a.1.val a.2.val) hT_ne
      set Tmin : Finset (Fin p.n × Fin p.m) :=
        T.filter (fun a => v.S a.1.val a.2.val = v.S aS.1.val aS.2.val) with hTmin_def
      have hTmin_ne : Tmin.Nonempty := ⟨aS, by simp [hTmin_def, haS_mem]⟩
      obtain ⟨a₀, ha₀_Tmin, ha₀_min_p⟩ :=
        Tmin.exists_min_image
          (fun a : Fin p.n × Fin p.m => p.p a.1 a.2) hTmin_ne
      have ha₀_mem : a₀ ∈ T := (Finset.mem_filter.mp ha₀_Tmin).1
      have ha₀_S : v.S a₀.1.val a₀.2.val = v.S aS.1.val aS.2.val :=
        (Finset.mem_filter.mp ha₀_Tmin).2
      have ha₀_min : ∀ b ∈ T, v.S a₀.1.val a₀.2.val ≤ v.S b.1.val b.2.val := by
        intro b hb
        rw [ha₀_S]; exact haS_min b hb
      have ha₀_min_p' : ∀ b ∈ T, v.S b.1.val b.2.val = v.S a₀.1.val a₀.2.val →
          p.p a₀.1 a₀.2 ≤ p.p b.1 b.2 := by
        intro b hb hS_eq
        have hb_Tmin : b ∈ Tmin := by
          simp [hTmin_def, hb]; rw [hS_eq, ha₀_S]
        exact ha₀_min_p b hb_Tmin
      set T' := T.erase a₀ with hT'_def
      have hT'_sub : T' ⊆ T := Finset.erase_subset _ _
      have hT'_sub_mops : T' ⊆ machineOps p i := hT'_sub.trans hT_sub
      have hT'_ne : T'.Nonempty := by
        rw [hT'_def]
        have : 1 < T.card := hcard_ge_two
        rw [← Finset.card_pos, Finset.card_erase_of_mem ha₀_mem]
        omega
      have hT'_ssub : T' ⊂ T := Finset.erase_ssubset ha₀_mem
      -- For every a ∈ T' (a ≠ a₀), both a and a₀ map to machine i,
      -- so non-overlap gives S(a₀) + p(a₀) ≤ S(a) (or vice versa, with tie-break).
      have hchain : ∀ a ∈ T', v.S a₀.1.val a₀.2.val + p.p a₀.1 a₀.2 ≤ v.S a.1.val a.2.val := by
        intro a ha'
        have ha_T : a ∈ T := hT'_sub ha'
        have ha_ne : a ≠ a₀ := by
          intro hab; rw [hab] at ha'
          simp [hT'_def] at ha'
        -- Both a₀ and a belong to machineOps p i, so p.Om a₀ = i = p.Om a.
        have ha₀_mops : a₀ ∈ machineOps p i := hT_sub ha₀_mem
        have ha_mops : a ∈ machineOps p i := hT_sub ha_T
        have ha₀_Om : p.Om a₀.1 a₀.2 = i :=
          (Finset.mem_filter.mp ha₀_mops).2
        have ha_Om : p.Om a.1 a.2 = i :=
          (Finset.mem_filter.mp ha_mops).2
        have hOm_eq : p.Om a₀.1 a₀.2 = p.Om a.1 a.2 := ha₀_Om.trans ha_Om.symm
        have hmin := ha₀_min a ha_T
        have hpa_nn := p.hp_nn a.1 a.2
        have hpa₀_nn := p.hp_nn a₀.1 a₀.2
        -- Non-overlap via hoverlap (a₀, a): they share machine i.
        have hne_pair : (a₀.1, a₀.2) ≠ (a.1, a.2) := by
          intro heq
          exact ha_ne.symm (Prod.ext (Prod.mk.inj heq).1 (Prod.mk.inj heq).2)
        rcases h.hoverlap a₀.1 a₀.2 a.1 a.2 hOm_eq hne_pair with hcase | hcase
        · exact hcase
        · have hSa_eq : v.S a.1.val a.2.val = v.S a₀.1.val a₀.2.val := by linarith
          have hpa_zero : p.p a.1 a.2 = 0 := by linarith
          have hpa₀_le := ha₀_min_p' a ha_T hSa_eq
          have hpa₀_zero : p.p a₀.1 a₀.2 = 0 := by linarith
          linarith
      have hih := ih T' hT'_ssub hT'_sub_mops hT'_ne
      have hinf_ge : v.S a₀.1.val a₀.2.val + p.p a₀.1 a₀.2
                      ≤ T'.inf' hT'_ne
                          (fun a : Fin p.n × Fin p.m => v.S a.1.val a.2.val) := by
        apply Finset.le_inf'
        intro a ha'; exact hchain a ha'
      have hsum_decomp :
          (∑ a ∈ T, p.p a.1 a.2) = p.p a₀.1 a₀.2 + ∑ a ∈ T', p.p a.1 a.2 := by
        rw [hT'_def, ← Finset.add_sum_erase _ _ ha₀_mem]
      have hT_inf_eq :
          T.inf' hT_ne (fun a : Fin p.n × Fin p.m => v.S a.1.val a.2.val)
            = v.S a₀.1.val a₀.2.val := by
        apply le_antisymm
        · exact Finset.inf'_le _ ha₀_mem
        · apply Finset.le_inf'
          intro a ha; exact ha₀_min a ha
      have hT_sup_ge_T'_sup :
          T'.sup' hT'_ne
              (fun a : Fin p.n × Fin p.m => v.S a.1.val a.2.val + p.p a.1 a.2)
            ≤ T.sup' hT_ne
                (fun a : Fin p.n × Fin p.m => v.S a.1.val a.2.val + p.p a.1 a.2) :=
        Finset.sup'_mono _ hT'_sub hT'_ne
      rw [hsum_decomp, hT_inf_eq]
      linarith

/-- Machine non-overlap + telescoping give the EC2 bound. -/
private lemma ec2_proof (i : Fin p.m) :
    v.Cmax ≥ (∑ jk ∈ machineOps p i, p.p jk.1 jk.2)
           + (machineOps p i).inf' (machineOps_ne p i) (fun a => hd p.p a.1 a.2)
           + (machineOps p i).inf' (machineOps_ne p i) (fun b => tl p.p b.1 b.2) := by
  set M : Finset (Fin p.n × Fin p.m) := machineOps p i with hM_def
  have hM_ne : M.Nonempty := machineOps_ne p i
  have hchain := nonoverlap_chain_sum h i M (by rw [hM_def]) hM_ne
  obtain ⟨first, hfirst_mem, hfirst_eq⟩ :=
    M.exists_mem_eq_inf' hM_ne
      (fun a : Fin p.n × Fin p.m => v.S a.1.val a.2.val)
  obtain ⟨last, hlast_mem, hlast_eq⟩ :=
    M.exists_mem_eq_sup' hM_ne
      (fun a : Fin p.n × Fin p.m => v.S a.1.val a.2.val + p.p a.1 a.2)
  rw [hfirst_eq, hlast_eq] at hchain
  have htail_bd : v.S last.1.val last.2.val + p.p last.1 last.2
                    + tl p.p last.1 last.2 ≤ v.Cmax :=
    start_plus_tail_bound h last.1 last.2
  have hhead_bd : hd p.p first.1 first.2 ≤ v.S first.1.val first.2.val :=
    head_le_start h first.1 first.2
  have hhd_inf :
      (machineOps p i).inf' (machineOps_ne p i) (fun a => hd p.p a.1 a.2)
        ≤ hd p.p first.1 first.2 :=
    Finset.inf'_le _ hfirst_mem
  have htl_inf :
      (machineOps p i).inf' (machineOps_ne p i) (fun b => tl p.p b.1 b.2)
        ≤ tl p.p last.1 last.2 :=
    Finset.inf'_le _ hlast_mem
  linarith

end ForwardHelpers

/-- P8.a → P8.c: identity on variables, derive EC2 from base constraints. -/
private def fwd (_ : P8.a.Params) (v : P8.a.Vars) : P8.c.Vars :=
  { S    := v.S
    Cmax := v.Cmax }

private lemma fwd_feas (p : P8.a.Params) (v : P8.a.Vars)
    (h : P8.a.Feasible p v) :
    P8.c.Feasible (paramMap p) (fwd p v) := by
  refine
    { hprec     := h.hprec
      hoverlap  := h.hoverlap
      hmakespan := h.hmakespan
      hS_nn     := h.hS_nn
      hCmax_nn  := h.hCmax_nn
      hec2      := ?_ }
  intro i
  -- `paramMap p` has the same n, m, p, Om fields as p, so
  -- `machineOps (paramMap p) i` (private in P8.c) equals `machineOps p i` here.
  -- Similarly head/tail in P8.c are definitionally equal to hd/tl here.
  -- Both sides reduce to ec2_proof h i by definitional equality.
  exact ec2_proof h i

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-- P8.c → P8.a: identity on variables, drop the EC2 constraint. -/
private def bwd (_ : P8.a.Params) (v : P8.c.Vars) : P8.a.Vars :=
  { S    := v.S
    Cmax := v.Cmax }

private lemma bwd_feas (p : P8.a.Params) (v : P8.c.Vars)
    (h : P8.c.Feasible (paramMap p) v) :
    P8.a.Feasible p (bwd p v) :=
  { hprec     := h.hprec
    hoverlap  := h.hoverlap
    hmakespan := h.hmakespan
    hS_nn     := h.hS_nn
    hCmax_nn  := h.hCmax_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aCEquiv : MILPReformulation P8.a.formulation P8.c.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P8
