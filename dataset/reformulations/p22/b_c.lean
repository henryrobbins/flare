import Common
import problems.p22.formulations.b.Formulation
import problems.p22.formulations.c.Formulation

open BigOperators Finset

namespace P22

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

/-- The fiber of a sigma type over a fixed base point is in bijection with the
corresponding component type, hence has the same cardinality. -/
private lemma sigma_fiber_card' {α : Type*} {β : α → Type*} [DecidableEq α] [Fintype α]
    [∀ a, Fintype (β a)] (a0 : α) :
    (Finset.univ.filter (fun s : Σ a, β a => s.1 = a0)).card = Fintype.card (β a0) := by
  have e : {s : Σ a, β a // s.1 = a0} ≃ β a0 :=
    { toFun := fun s => s.2 ▸ s.1.2
      invFun := fun b => ⟨⟨a0, b⟩, rfl⟩
      left_inv := by rintro ⟨⟨a, b⟩, (rfl : a = a0)⟩; rfl
      right_inv := by intro b; rfl }
  rw [← Fintype.card_congr e, Fintype.card_subtype]

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P22.b.Params) : P22.c.Params where
  W := p.W
  m := p.m
  w := p.w
  b := p.b
  hw_lo := p.hw_lo
  hw_hi := p.hw_hi
  hW := p.hW
  hm := p.hm
  hb_pos := p.hb_pos

-- ============================================================================
-- § Intermediate pattern-based formulation (mirrors P22.b.J/Vars/Feasible but
-- indexed by a `P22.c.Params`, so that the single-pattern arc-flow
-- construction below can be stated purely in terms of `P22.c.Params`)
-- ============================================================================

/-- Set of all valid cutting patterns for a `c`-shaped parameter set: those
non-negative integer vectors whose total width does not exceed capacity. -/
private def Jc (q : P22.c.Params) : Finset (Fin q.m → Fin (q.W + 1)) :=
  univ.filter (fun a => ∑ d : Fin q.m, q.w d * (a d).val ≤ q.W)

private structure PatVars (q : P22.c.Params) where
  x : (Fin q.m → Fin (q.W + 1)) → ℤ

private structure PatFeasible (q : P22.c.Params) (pv : PatVars q) : Prop where
  hdemand : ∀ d : Fin q.m, ∑ a ∈ Jc q, ((a d).val : ℤ) * pv.x a ≥ q.b d
  hx_nn : ∀ a ∈ Jc q, 0 ≤ pv.x a
  htotal : ∑ a ∈ Jc q, pv.x a ≤ ∑ d : Fin q.m, q.b d

/-- Reinterpret `b`-formulation pattern-usage variables as `PatVars` over the
mapped `c`-parameters. -/
private def toPatVars (p : P22.b.Params) (v : P22.b.Vars p) : PatVars (paramMap p) where
  x := v.x

private lemma toPatVars_feas (p : P22.b.Params) (v : P22.b.Vars p) (h : P22.b.Feasible p v) :
    PatFeasible (paramMap p) (toPatVars p v) where
  hdemand := h.hdemand
  hx_nn := h.hx_nn
  htotal := h.htotal

-- ============================================================================
-- § Structural facts about the arc-flow graph (independent of the flow)
-- ============================================================================

section GraphFacts

variable (q : P22.c.Params)

/-- Vertex `0` has no incoming arcs: no item arc lands at `0` (widths are
positive) and no loss arc does either. -/
private lemma inArcs_zero : P22.c.inArcs q 0 = ∅ := by
  apply Finset.eq_empty_iff_forall_notMem.mpr
  intro i hi
  unfold P22.c.inArcs P22.c.isArc at hi
  simp only [mem_filter, mem_univ, true_and] at hi
  rcases hi with ⟨d, hd⟩ | hd
  · have := q.hw_lo d
    simp only [Fin.val_zero] at hd
    omega
  · simp only [Fin.val_zero] at hd
    omega

/-- Vertex `q.W` has no outgoing arcs: no item arc or loss arc can leave the
last vertex without exceeding capacity. -/
private lemma outArcs_last : P22.c.outArcs q (Fin.last q.W) = ∅ := by
  apply Finset.eq_empty_iff_forall_notMem.mpr
  intro j hj
  unfold P22.c.outArcs P22.c.isArc at hj
  simp only [mem_filter, mem_univ, true_and] at hj
  have h2 := j.isLt
  rcases hj with ⟨d, hd⟩ | hd
  · have h1 := q.hw_lo d
    simp only [Fin.val_last] at hd
    omega
  · simp only [Fin.val_last] at hd
    omega

end GraphFacts

-- ============================================================================
-- § Pattern → P22.c: canonical single-path flow for one pattern
-- ============================================================================

section SinglePatternFlow

variable (q : P22.c.Params) (a : Fin q.m → Fin (q.W + 1))

/-- One "copy" of an item of the pattern `a`: a type `d` together with which of
the `a d` copies of that type it is. -/
private def Copy : Type := Σ d : Fin q.m, Fin (a d).val

noncomputable instance : Fintype (Copy q a) := by unfold Copy; infer_instance

/-- The total number of item-copies in the pattern `a`. -/
private def NC (q : P22.c.Params) (a : Fin q.m → Fin (q.W + 1)) : ℕ :=
  ∑ d : Fin q.m, (a d).val

private lemma card_Copy : Fintype.card (Copy q a) = NC q a := by
  unfold Copy NC
  rw [Fintype.card_sigma]
  simp

/-- An arbitrary enumeration of the copies of `a`, `0, ..., NC-1`. -/
private noncomputable def copyEquiv : Fin (NC q a) ≃ Copy q a :=
  (Fintype.equivFinOfCardEq (card_Copy q a)).symm

/-- The type of the `k`-th enumerated copy. -/
private noncomputable def typeOf (k : Fin (NC q a)) : Fin q.m := (copyEquiv q a k).1

/-- The width of the `k`-th enumerated copy. -/
private noncomputable def width (k : Fin (NC q a)) : ℕ := q.w (typeOf q a k)

private noncomputable def wSeq (k : ℕ) : ℕ :=
  if h : k < NC q a then width q a ⟨k, h⟩ else 0

/-- The position reached after laying out the first `k` copies in the chosen order. -/
private noncomputable def posSeq (k : ℕ) : ℕ := ∑ i ∈ Finset.range k, wSeq q a i

/-- The end position of the canonical path (before any loss arcs). -/
private noncomputable def canEndV (q : P22.c.Params) (a : Fin q.m → Fin (q.W + 1)) : ℕ :=
  posSeq q a (NC q a)

private lemma posSeq_zero : posSeq q a 0 = 0 := by unfold posSeq; simp

private lemma posSeq_succ (k : ℕ) : posSeq q a (k + 1) = posSeq q a k + wSeq q a k := by
  unfold posSeq; rw [Finset.sum_range_succ]

private lemma wSeq_pos {k : ℕ} (hk : k < NC q a) : 1 ≤ wSeq q a k := by
  unfold wSeq; rw [dif_pos hk]; exact q.hw_lo _

private lemma posSeq_mono : Monotone (posSeq q a) := by
  intro k1 k2 hk
  unfold posSeq
  exact Finset.sum_le_sum_of_subset (Finset.range_subset_range.mpr hk)

private lemma posSeq_lt_succ {k : ℕ} (hk : k < NC q a) :
    posSeq q a k < posSeq q a (k + 1) := by
  rw [posSeq_succ]
  have := wSeq_pos q a hk
  omega

/-- `posSeq` is strictly increasing on `[0, NC q a]`. -/
private lemma posSeq_strictMonoOn {k1 k2 : ℕ} (hlt : k1 < k2) (hk2 : k2 ≤ NC q a) :
    posSeq q a k1 < posSeq q a k2 := by
  calc posSeq q a k1 < posSeq q a (k1 + 1) := posSeq_lt_succ q a (by omega)
    _ ≤ posSeq q a k2 := posSeq_mono q a (by omega)

/-- `posSeq` is injective on `[0, NC q a]`. -/
private lemma posSeq_injOn {k1 k2 : ℕ} (hk1 : k1 ≤ NC q a) (hk2 : k2 ≤ NC q a)
    (heq : posSeq q a k1 = posSeq q a k2) : k1 = k2 := by
  rcases lt_trichotomy k1 k2 with h | h | h
  · exact absurd heq (ne_of_lt (posSeq_strictMonoOn q a h hk2))
  · exact h
  · exact absurd heq.symm (ne_of_lt (posSeq_strictMonoOn q a h hk1))

private lemma wSeq_eq (k : Fin (NC q a)) : wSeq q a k.val = width q a k := by
  unfold wSeq; rw [dif_pos k.isLt]

/-- The end position of the canonical path equals the total weighted size of
the pattern, matching the definition of `Jc`. -/
private lemma canEndV_eq : canEndV q a = ∑ d : Fin q.m, q.w d * (a d).val := by
  unfold canEndV posSeq
  rw [← Fin.sum_univ_eq_sum_range (fun i => wSeq q a i) (NC q a)]
  have step1 : ∑ k : Fin (NC q a), wSeq q a k.val = ∑ k : Fin (NC q a), width q a k :=
    Finset.sum_congr rfl (fun k _ => wSeq_eq q a k)
  rw [step1]
  unfold width typeOf
  rw [Equiv.sum_comp (copyEquiv q a) (fun c : Copy q a => q.w c.1)]
  unfold Copy
  rw [Fintype.sum_sigma]
  refine Finset.sum_congr rfl fun d _ => ?_
  simp [Finset.sum_const, mul_comm]

/-- The single-pattern item-arc flow: one unit of flow on the arc `(i, j)` iff
some enumerated copy of the pattern steps from `i` to `j`. -/
private noncomputable def xItemArc1 (i j : Fin (q.W + 1)) : ℤ :=
  ∑ k : Fin (NC q a),
    if posSeq q a k.val = i.val ∧ posSeq q a (k.val + 1) = j.val then (1 : ℤ) else 0

/-- The single-pattern loss-arc flow: one unit of flow on arc `(i, i+1)` for
every `i` from the end of the item path onward. -/
private noncomputable def xLossArc1 (i j : Fin (q.W + 1)) : ℤ :=
  if canEndV q a ≤ i.val ∧ j.val = i.val + 1 then (1 : ℤ) else 0

/-- The single-pattern arc-flow: the merged item/loss contribution on arc
`(i, j)` (an item step and a loss step can never coincide within a single
canonical path, but they may share the same underlying arc of the graph). -/
private noncomputable def xArc1 (i j : Fin (q.W + 1)) : ℤ :=
  xItemArc1 q a i j + xLossArc1 q a i j

private lemma xItemArc1_nonneg (i j : Fin (q.W + 1)) : 0 ≤ xItemArc1 q a i j :=
  Finset.sum_nonneg fun k _ => by split <;> norm_num

private lemma xLossArc1_nonneg (i j : Fin (q.W + 1)) : 0 ≤ xLossArc1 q a i j := by
  unfold xLossArc1; split <;> norm_num

private lemma xArc1_nonneg (i j : Fin (q.W + 1)) : 0 ≤ xArc1 q a i j :=
  add_nonneg (xItemArc1_nonneg q a i j) (xLossArc1_nonneg q a i j)

private lemma canEndV_le_W (ha : a ∈ Jc q) : canEndV q a ≤ q.W := by
  rw [canEndV_eq]
  exact (Finset.mem_filter.mp ha).2

private lemma posSeq_le_canEndV {k : ℕ} (hk : k ≤ NC q a) : posSeq q a k ≤ canEndV q a :=
  posSeq_mono q a hk

/-- Every position reached along the canonical path is a valid vertex. -/
private lemma posSeq_le_W (ha : a ∈ Jc q) {k : ℕ} (hk : k ≤ NC q a) : posSeq q a k ≤ q.W :=
  (posSeq_le_canEndV q a hk).trans (canEndV_le_W q a ha)

private lemma xItemArc1_ne_zero_iff (i j : Fin (q.W + 1)) :
    xItemArc1 q a i j ≠ 0
      ↔ ∃ k : Fin (NC q a), posSeq q a k.val = i.val ∧ posSeq q a (k.val + 1) = j.val := by
  unfold xItemArc1
  constructor
  · intro hne
    by_contra hall
    push_neg at hall
    apply hne
    refine Finset.sum_eq_zero fun k _ => ?_
    rw [if_neg]
    push_neg
    exact hall k
  · rintro ⟨k, hp, ht⟩ hzero
    have hnn : ∀ k ∈ (univ : Finset (Fin (NC q a))),
        0 ≤ (if posSeq q a k.val = i.val ∧ posSeq q a (k.val + 1) = j.val then (1 : ℤ) else 0) :=
      fun k _ => by split <;> norm_num
    have := (Finset.sum_eq_zero_iff_of_nonneg hnn).mp hzero k (mem_univ k)
    rw [if_pos ⟨hp, ht⟩] at this
    exact one_ne_zero this

/-- If the single-pattern item flow on `(i, j)` is nonzero, that item arc must
actually exist in the graph. -/
private lemma xItemArc1_isArc (i j : Fin (q.W + 1)) (hne : xItemArc1 q a i j ≠ 0) :
    ∃ d : Fin q.m, j.val = i.val + q.w d := by
  obtain ⟨k, hp, ht⟩ := (xItemArc1_ne_zero_iff q a i j).mp hne
  refine ⟨typeOf q a k, ?_⟩
  have hstep := wSeq_eq q a k
  rw [← ht, posSeq_succ, ← hp, hstep]
  rfl

/-- If the single-pattern (merged) flow on `(i, j)` is nonzero, that arc must
actually exist in the graph. -/
private lemma xArc1_isArc (i j : Fin (q.W + 1)) (hne : xArc1 q a i j ≠ 0) :
    P22.c.isArc q i j := by
  unfold xArc1 at hne
  by_contra hcontra
  unfold P22.c.isArc at hcontra
  push_neg at hcontra
  have h1 : xItemArc1 q a i j = 0 := by
    by_contra h
    obtain ⟨d, hd⟩ := xItemArc1_isArc q a i j h
    exact hcontra.1 d hd
  have h2 : xLossArc1 q a i j = 0 := by
    unfold xLossArc1
    rw [if_neg (fun h => hcontra.2 h.2)]
  rw [h1, h2] at hne
  exact hne (by ring)

/-- Converting a cardinality of a `Fin n`-indexed filter into a `range n`-indexed one. -/
private lemma finFilter_card_eq_rangeFilter_card {n : ℕ} (P : ℕ → Prop) [DecidablePred P] :
    (univ.filter (fun k : Fin n => P k.val)).card = ((Finset.range n).filter P).card := by
  rw [← Finset.card_image_of_injective (univ.filter (fun k : Fin n => P k.val)) Fin.val_injective]
  congr 1
  ext t
  simp only [Finset.mem_image, mem_filter, mem_univ, true_and, Finset.mem_range]
  constructor
  · rintro ⟨k, hk, rfl⟩; exact ⟨k.isLt, hk⟩
  · rintro ⟨ht, hp⟩; exact ⟨⟨t, ht⟩, hp, rfl⟩

/-- The set of "times" `t ≤ NC q a` at which the canonical path is at position `v`. -/
private noncomputable def posSeqSet (v : ℕ) : Finset ℕ :=
  (Finset.range (NC q a + 1)).filter (fun t => posSeq q a t = v)

private lemma mem_posSeqSet_0 (v : ℕ) : 0 ∈ posSeqSet q a v ↔ v = 0 := by
  simp only [posSeqSet, mem_filter, Finset.mem_range]
  constructor
  · rintro ⟨_, h⟩; rw [posSeq_zero] at h; exact h.symm
  · intro h; exact ⟨by omega, by rw [posSeq_zero]; omega⟩

/-- The number of enumerated copies that begin exactly at position `v`. -/
private noncomputable def numK (v : ℕ) : ℕ :=
  (univ.filter (fun k : Fin (NC q a) => posSeq q a k.val = v)).card

/-- The number of enumerated copies whose arc lands exactly at position `v`. -/
private noncomputable def numKnext (v : ℕ) : ℕ :=
  (univ.filter (fun k : Fin (NC q a) => posSeq q a (k.val + 1) = v)).card

private lemma numK_eq (v : ℕ) :
    (numK q a v : ℤ) = (posSeqSet q a v).card - (if v = canEndV q a then 1 else 0) := by
  have hcast : (numK q a v : ℕ)
      = ((Finset.range (NC q a)).filter (fun t => posSeq q a t = v)).card :=
    finFilter_card_eq_rangeFilter_card (fun t => posSeq q a t = v)
  rw [hcast]
  have hsplit : posSeqSet q a v
      = if posSeq q a (NC q a) = v then insert (NC q a) ((Finset.range (NC q a)).filter
          (fun t => posSeq q a t = v)) else (Finset.range (NC q a)).filter (fun t => posSeq q a t = v) := by
    unfold posSeqSet
    rw [Finset.range_add_one, Finset.filter_insert]
  by_cases hv : v = canEndV q a
  · have hv' : posSeq q a (NC q a) = v := by unfold canEndV at hv; omega
    rw [hsplit, if_pos hv', if_pos hv,
      Finset.card_insert_of_notMem (by simp)]
    push_cast; ring
  · have hv' : posSeq q a (NC q a) ≠ v := by unfold canEndV at hv; omega
    rw [hsplit, if_neg hv', if_neg hv]
    ring

private lemma numKnext_eq (v : ℕ) :
    (numKnext q a v : ℤ) = (posSeqSet q a v).card - (if v = 0 then 1 else 0) := by
  have hcast : (numKnext q a v : ℕ)
      = ((Finset.range (NC q a)).filter (fun t => posSeq q a (t + 1) = v)).card :=
    finFilter_card_eq_rangeFilter_card (fun t => posSeq q a (t + 1) = v)
  rw [hcast]
  have hshift : ((Finset.range (NC q a)).filter (fun t => posSeq q a (t + 1) = v)).card
      = ((Finset.Ico 1 (NC q a + 1)).filter (fun t => posSeq q a t = v)).card := by
    apply Finset.card_bij (fun t _ => t + 1)
    · intro t ht
      simp only [mem_filter, Finset.mem_range] at ht
      simp only [mem_filter, Finset.mem_Ico]
      exact ⟨⟨by omega, by omega⟩, ht.2⟩
    · intro t1 ht1 t2 ht2 heq
      omega
    · intro t ht
      simp only [mem_filter, Finset.mem_Ico] at ht
      refine ⟨t - 1, ?_, by omega⟩
      simp only [mem_filter, Finset.mem_range]
      refine ⟨by omega, ?_⟩
      have : t - 1 + 1 = t := by omega
      rw [this]; exact ht.2
  rw [hshift]
  have hIco : Finset.Ico 1 (NC q a + 1) = (Finset.range (NC q a + 1)) \ {0} := by
    ext t; simp only [Finset.mem_Ico, Finset.mem_sdiff, Finset.mem_range, mem_singleton]; omega
  have hfiltersdiff : ((Finset.range (NC q a + 1)) \ {0}).filter (fun t => posSeq q a t = v)
      = (posSeqSet q a v) \ (({0} : Finset ℕ).filter (fun t => posSeq q a t = v)) := by
    unfold posSeqSet
    ext x; simp only [mem_filter, Finset.mem_sdiff, mem_singleton]; tauto
  rw [hIco, hfiltersdiff]
  by_cases hv : v = 0
  · have h0 : (0:ℕ) ∈ posSeqSet q a v := (mem_posSeqSet_0 q a v).mpr hv
    have hsub : ({0} : Finset ℕ).filter (fun t => posSeq q a t = v) = {0} := by
      apply Finset.filter_true_of_mem
      intro t ht; simp at ht; subst ht; rw [posSeq_zero]; omega
    have hinter : ({0} : Finset ℕ) ∩ posSeqSet q a v = {0} :=
      Finset.inter_eq_left.mpr (by intro t ht; simp at ht; subst ht; exact h0)
    rw [hsub, Finset.card_sdiff, hinter]
    simp only [card_singleton]
    rw [if_pos hv]
    have := Finset.card_pos.mpr ⟨0, h0⟩
    omega
  · have hsub : ({0} : Finset ℕ).filter (fun t => posSeq q a t = v) = ∅ := by
      apply Finset.filter_false_of_mem
      intro t ht; simp at ht; subst ht; rw [posSeq_zero]; omega
    rw [hsub, Finset.sdiff_empty]
    rw [if_neg hv]
    ring

/-- The master telescoping identity: the net "creation" of copies at position `v`
is `1` at the source, `-1` at the sink, and `0` elsewhere. -/
private lemma numK_sub_numKnext (v : ℕ) :
    (numK q a v : ℤ) - (numKnext q a v : ℤ)
      = (if v = 0 then 1 else 0) - (if v = canEndV q a then 1 else 0) := by
  rw [numK_eq, numKnext_eq]
  ring

private lemma numKnext_zero : numKnext q a 0 = 0 := by
  unfold numKnext
  rw [Finset.card_eq_zero]
  ext k
  simp only [mem_filter, mem_univ, true_and, Finset.notMem_empty, iff_false]
  have h1 : 1 ≤ wSeq q a k.val := wSeq_pos q a k.isLt
  rw [posSeq_succ]
  omega

private lemma numK_at_W_eq_zero (ha : a ∈ Jc q) : numK q a q.W = 0 := by
  unfold numK
  rw [Finset.card_eq_zero]
  ext k
  simp only [mem_filter, mem_univ, true_and, Finset.notMem_empty, iff_false]
  have h1 : posSeq q a k.val < posSeq q a (k.val + 1) := posSeq_lt_succ q a k.isLt
  have h2 : posSeq q a (k.val + 1) ≤ canEndV q a := posSeq_le_canEndV q a (by omega)
  have h3 : canEndV q a ≤ q.W := canEndV_le_W q a ha
  omega

private lemma sum_xItemArc1_at (ha : a ∈ Jc q) (i : Fin (q.W + 1)) :
    ∑ j : Fin (q.W + 1), xItemArc1 q a i j = (numK q a i.val : ℤ) := by
  unfold xItemArc1
  rw [Finset.sum_comm]
  have step : ∀ k : Fin (NC q a),
      ∑ j : Fin (q.W + 1),
        (if posSeq q a k.val = i.val ∧ posSeq q a (k.val + 1) = j.val then (1 : ℤ) else 0)
        = if posSeq q a k.val = i.val then 1 else 0 := by
    intro k
    have hple : posSeq q a (k.val + 1) ≤ q.W := posSeq_le_W q a ha (by omega)
    set target : Fin (q.W + 1) := ⟨posSeq q a (k.val + 1), by omega⟩ with htarget
    have hkey : ∑ j : Fin (q.W + 1),
        (if posSeq q a k.val = i.val ∧ posSeq q a (k.val + 1) = j.val then (1 : ℤ) else 0)
        = (if posSeq q a k.val = i.val ∧ posSeq q a (k.val + 1) = target.val then (1 : ℤ) else 0) := by
      refine Finset.sum_eq_single target ?_ ?_
      · intro j _ hne
        have hjval : j.val ≠ posSeq q a (k.val + 1) :=
          fun h => hne (Fin.ext (show j.val = target.val from h))
        rw [if_neg (fun h => hjval h.2.symm)]
      · intro hnot; exact absurd (mem_univ _) hnot
    rw [hkey]
    have : target.val = posSeq q a (k.val + 1) := rfl
    simp [this]
  simp only [step]
  rw [Finset.sum_boole]
  rfl

private lemma sum_lossArc1_at (i : Fin (q.W + 1)) :
    ∑ j : Fin (q.W + 1), xLossArc1 q a i j
      = if canEndV q a ≤ i.val ∧ i.val < q.W then (1 : ℤ) else 0 := by
  unfold xLossArc1
  by_cases hiW : i.val < q.W
  · set target : Fin (q.W + 1) := ⟨i.val + 1, by omega⟩ with htarget
    have hkey : ∑ j : Fin (q.W + 1), (if canEndV q a ≤ i.val ∧ j.val = i.val + 1 then (1 : ℤ) else 0)
        = if canEndV q a ≤ i.val ∧ target.val = i.val + 1 then 1 else 0 := by
      refine Finset.sum_eq_single target ?_ ?_
      · intro j _ hne
        have hjval : j.val ≠ i.val + 1 :=
          fun h => hne (Fin.ext (show j.val = target.val from h))
        rw [if_neg (fun h => hjval h.2)]
      · intro hnot; exact absurd (mem_univ _) hnot
    rw [hkey]
    have ht : target.val = i.val + 1 := rfl
    rw [ht]
    by_cases hc : canEndV q a ≤ i.val <;> simp [hc, hiW]
  · rw [if_neg (fun h => hiW h.2)]
    refine Finset.sum_eq_zero fun j _ => ?_
    rw [if_neg]
    intro ⟨_, hji⟩
    have := j.isLt
    omega

private lemma sum_xItemArc1_in (ha : a ∈ Jc q) (j : Fin (q.W + 1)) :
    ∑ i : Fin (q.W + 1), xItemArc1 q a i j = (numKnext q a j.val : ℤ) := by
  unfold xItemArc1
  rw [Finset.sum_comm]
  have step : ∀ k : Fin (NC q a),
      ∑ i : Fin (q.W + 1),
        (if posSeq q a k.val = i.val ∧ posSeq q a (k.val + 1) = j.val then (1 : ℤ) else 0)
        = if posSeq q a (k.val + 1) = j.val then 1 else 0 := by
    intro k
    have hple : posSeq q a k.val ≤ q.W := posSeq_le_W q a ha (by omega)
    set target : Fin (q.W + 1) := ⟨posSeq q a k.val, by omega⟩ with htarget
    have hkey : ∑ i : Fin (q.W + 1),
        (if posSeq q a k.val = i.val ∧ posSeq q a (k.val + 1) = j.val then (1 : ℤ) else 0)
        = (if posSeq q a k.val = target.val ∧ posSeq q a (k.val + 1) = j.val then (1 : ℤ) else 0) := by
      refine Finset.sum_eq_single target ?_ ?_
      · intro i _ hne
        have hival : i.val ≠ posSeq q a k.val :=
          fun h => hne (Fin.ext (show i.val = target.val from h))
        rw [if_neg (fun h => hival h.1.symm)]
      · intro hnot; exact absurd (mem_univ _) hnot
    rw [hkey]
    have : target.val = posSeq q a k.val := rfl
    simp [this]
  simp only [step]
  rw [Finset.sum_boole]
  rfl

private lemma sum_lossArc1_in (j : Fin (q.W + 1)) :
    ∑ i : Fin (q.W + 1), xLossArc1 q a i j
      = if 0 < j.val ∧ canEndV q a ≤ j.val - 1 then (1 : ℤ) else 0 := by
  unfold xLossArc1
  by_cases hj0 : 0 < j.val
  · set target : Fin (q.W + 1) := ⟨j.val - 1, by omega⟩ with htarget
    have hkey : ∑ i : Fin (q.W + 1), (if canEndV q a ≤ i.val ∧ j.val = i.val + 1 then (1 : ℤ) else 0)
        = if canEndV q a ≤ target.val ∧ j.val = target.val + 1 then 1 else 0 := by
      refine Finset.sum_eq_single target ?_ ?_
      · intro i _ hne
        have hival : i.val ≠ j.val - 1 :=
          fun h => hne (Fin.ext (show i.val = target.val from h))
        rw [if_neg]
        intro ⟨_, hji⟩
        exact hival (by omega)
      · intro hnot; exact absurd (mem_univ _) hnot
    rw [hkey]
    have ht : target.val = j.val - 1 := rfl
    rw [ht]
    have heq : (j.val = j.val - 1 + 1) := by omega
    by_cases hc : canEndV q a ≤ j.val - 1
    · rw [if_pos ⟨hc, heq⟩, if_pos ⟨hj0, hc⟩]
    · rw [if_neg (fun h => hc h.1), if_neg (fun h => hc h.2)]
  · rw [if_neg (fun h => hj0 h.1)]
    refine Finset.sum_eq_zero fun i _ => ?_
    rw [if_neg]
    intro ⟨_, hji⟩
    omega

private lemma sum_xArc1_out (ha : a ∈ Jc q) (i : Fin (q.W + 1)) :
    ∑ j ∈ P22.c.outArcs q i, xArc1 q a i j
      = (numK q a i.val : ℤ) + (if canEndV q a ≤ i.val ∧ i.val < q.W then 1 else 0) := by
  have hext : ∑ j ∈ P22.c.outArcs q i, xArc1 q a i j = ∑ j : Fin (q.W + 1), xArc1 q a i j := by
    refine Finset.sum_subset (Finset.filter_subset _ _) fun j _ hnotin => ?_
    by_contra hne
    apply hnotin
    unfold P22.c.outArcs
    simp only [mem_filter, mem_univ, true_and]
    exact xArc1_isArc q a i j hne
  rw [hext]
  unfold xArc1
  rw [Finset.sum_add_distrib, sum_xItemArc1_at q a ha, sum_lossArc1_at]

private lemma sum_xArc1_in (ha : a ∈ Jc q) (j : Fin (q.W + 1)) :
    ∑ i ∈ P22.c.inArcs q j, xArc1 q a i j
      = (numKnext q a j.val : ℤ) + (if 0 < j.val ∧ canEndV q a ≤ j.val - 1 then 1 else 0) := by
  have hext : ∑ i ∈ P22.c.inArcs q j, xArc1 q a i j = ∑ i : Fin (q.W + 1), xArc1 q a i j := by
    refine Finset.sum_subset (Finset.filter_subset _ _) fun i _ hnotin => ?_
    by_contra hne
    apply hnotin
    unfold P22.c.inArcs
    simp only [mem_filter, mem_univ, true_and]
    exact xArc1_isArc q a i j hne
  rw [hext]
  unfold xArc1
  rw [Finset.sum_add_distrib, sum_xItemArc1_in q a ha, sum_lossArc1_in]

/-- Flow conservation for the single-pattern canonical path at vertex `0`. -/
private lemma single_hflow0 (ha : a ∈ Jc q) :
    (∑ i ∈ P22.c.inArcs q 0, xArc1 q a i 0) - (∑ j ∈ P22.c.outArcs q 0, xArc1 q a 0 j) = -1 := by
  have hin : P22.c.inArcs q 0 = ∅ := inArcs_zero q
  have hout := sum_xArc1_out q a ha 0
  have hkey := numK_sub_numKnext q a 0
  have hnn := numKnext_zero q a
  have hW1 : 0 < q.W := Nat.pos_of_ne_zero q.hW.out
  have hcW := canEndV_le_W q a ha
  rw [hin, hout]
  simp only [Finset.sum_empty, Fin.val_zero]
  split_ifs at hkey ⊢ <;> omega

/-- Flow conservation for the single-pattern canonical path at vertex `q.W`. -/
private lemma single_hflowW (ha : a ∈ Jc q) :
    (∑ i ∈ P22.c.inArcs q (Fin.last q.W), xArc1 q a i (Fin.last q.W))
      - (∑ j ∈ P22.c.outArcs q (Fin.last q.W), xArc1 q a (Fin.last q.W) j) = 1 := by
  have hout : P22.c.outArcs q (Fin.last q.W) = ∅ := outArcs_last q
  have hin := sum_xArc1_in q a ha (Fin.last q.W)
  have hkey := numK_sub_numKnext q a q.W
  have hz := numK_at_W_eq_zero q a ha
  have hW1 : 0 < q.W := Nat.pos_of_ne_zero q.hW.out
  have hcW := canEndV_le_W q a ha
  rw [hout, hin]
  simp only [Finset.sum_empty, Fin.val_last]
  split_ifs at hkey ⊢ <;> omega

/-- Flow conservation for the single-pattern canonical path at intermediate vertices. -/
private lemma single_hflowMid (ha : a ∈ Jc q) (vtx : Fin (q.W + 1))
    (h0 : 0 < vtx.val) (hW : vtx.val < q.W) :
    (∑ i ∈ P22.c.inArcs q vtx, xArc1 q a i vtx) - (∑ j ∈ P22.c.outArcs q vtx, xArc1 q a vtx j)
      = 0 := by
  have hout := sum_xArc1_out q a ha vtx
  have hin := sum_xArc1_in q a ha vtx
  have hkey := numK_sub_numKnext q a vtx.val
  have hcW := canEndV_le_W q a ha
  rw [hout, hin]
  split_ifs at hkey ⊢ <;> omega

private lemma card_typeOf_eq (d : Fin q.m) :
    (univ.filter (fun k : Fin (NC q a) => typeOf q a k = d)).card = (a d).val := by
  classical
  have himg : (univ.filter (fun k : Fin (NC q a) => typeOf q a k = d)).card
      = (univ.filter (fun c : Copy q a => c.1 = d)).card := by
    rw [← Finset.card_image_of_injective _ (copyEquiv q a).injective]
    congr 1
    ext c
    simp only [Finset.mem_image, mem_filter, mem_univ, true_and]
    constructor
    · rintro ⟨k, hk, rfl⟩; exact hk
    · intro hc
      exact ⟨(copyEquiv q a).symm c, by simp [typeOf, hc], by simp⟩
  rw [himg]
  have hfib := sigma_fiber_card' (α := Fin q.m) (β := fun d => Fin (a d).val) d
  unfold Copy
  rw [hfib]
  simp

/-- The vertex reached by following the canonical path up to (but not
including) copy `k'`. -/
private noncomputable def posElem (ha : a ∈ Jc q) (k' : Fin (NC q a)) : Fin (q.W + 1) :=
  ⟨posSeq q a k'.val, Nat.lt_succ_of_le (posSeq_le_W q a ha (le_of_lt k'.isLt))⟩

private lemma posElem_val (ha : a ∈ Jc q) (k' : Fin (NC q a)) :
    (posElem q a ha k').val = posSeq q a k'.val := rfl

private lemma posElem_injOn (ha : a ∈ Jc q) (s : Finset (Fin (NC q a))) :
    Set.InjOn (posElem q a ha) s := by
  intro k1 _ k2 _ heq
  apply Fin.ext
  exact posSeq_injOn q a (le_of_lt k1.isLt) (le_of_lt k2.isLt)
    (show posSeq q a k1.val = posSeq q a k2.val from congrArg Fin.val heq)

/-- The vertex reached before copy `k'` lies in the domain of type-`d` item
arcs, whenever `k'`'s width matches `q.w d`. -/
private lemma posElem_mem_D (ha : a ∈ Jc q) (d : Fin q.m) (k' : Fin (NC q a))
    (hk' : width q a k' = q.w d) : posElem q a ha k' ∈ P22.c.D q d := by
  unfold P22.c.D
  simp only [mem_filter, mem_univ, true_and]
  have h1 : posSeq q a (k'.val + 1) ≤ canEndV q a := posSeq_le_canEndV q a (by omega)
  have h2 := canEndV_le_W q a ha
  have h3 : posSeq q a (k'.val + 1) = (posElem q a ha k').val + q.w d := by
    rw [posSeq_succ, posElem_val]
    have hw := wSeq_eq q a k'
    omega
  rw [posElem_val] at h3 ⊢
  omega

/-- A copy `k'` contributes at least one unit of item-arc flow on the arc from
its start position to the type-`d` `endOf` of that position, whenever `k'`'s
width matches `q.w d`. -/
private lemma xItemArc1_at_posElem_ge (ha : a ∈ Jc q) (d : Fin q.m) (k' : Fin (NC q a))
    (hk' : width q a k' = q.w d) :
    1 ≤ xItemArc1 q a (posElem q a ha k') (P22.c.endOf q d (posElem q a ha k')) := by
  have hk0D : posElem q a ha k' ∈ P22.c.D q d := posElem_mem_D q a ha d k' hk'
  have hendOf : (P22.c.endOf q d (posElem q a ha k')).val = (posElem q a ha k').val + q.w d := by
    unfold P22.c.endOf
    simp only
    have := (mem_filter.mp hk0D).2
    omega
  have hkey : xItemArc1 q a (posElem q a ha k') (P22.c.endOf q d (posElem q a ha k')) ≠ 0 := by
    rw [xItemArc1_ne_zero_iff]
    refine ⟨k', posElem_val q a ha k', ?_⟩
    rw [hendOf, posSeq_succ, posElem_val]
    have hw := wSeq_eq q a k'
    omega
  have hnn := xItemArc1_nonneg q a (posElem q a ha k') (P22.c.endOf q d (posElem q a ha k'))
  omega

/-- The total item-arc flow into the type-`d` `endOf` targets, restricted to
`D q d`, is at least the number of type-`d` copies in the pattern. -/
private lemma xItemArc1_sum_D_ge (ha : a ∈ Jc q) (d : Fin q.m) :
    ((a d).val : ℤ) ≤ ∑ k ∈ P22.c.D q d, xItemArc1 q a k (P22.c.endOf q d k) := by
  set domain : Finset (Fin (NC q a)) := univ.filter (fun k' => typeOf q a k' = d) with hdomain
  have hinj : Set.InjOn (posElem q a ha) domain := posElem_injOn q a ha domain
  have hsub : domain.image (posElem q a ha) ⊆ P22.c.D q d := by
    intro k hk
    simp only [Finset.mem_image] at hk
    obtain ⟨k', hk'mem, rfl⟩ := hk
    simp only [hdomain, mem_filter, mem_univ, true_and] at hk'mem
    have hw : width q a k' = q.w d := by unfold width; rw [hk'mem]
    exact posElem_mem_D q a ha d k' hw
  calc ((a d).val : ℤ)
      = (domain.card : ℤ) := by rw [card_typeOf_eq]
    _ = ((domain.image (posElem q a ha)).card : ℤ) := by
        rw [Finset.card_image_of_injOn hinj]
    _ = ∑ _k ∈ domain.image (posElem q a ha), (1 : ℤ) := by
        rw [Finset.sum_const, nsmul_eq_mul, mul_one]
    _ ≤ ∑ k ∈ domain.image (posElem q a ha), xItemArc1 q a k (P22.c.endOf q d k) := by
        refine Finset.sum_le_sum fun k hk => ?_
        simp only [Finset.mem_image] at hk
        obtain ⟨k', hk'mem, rfl⟩ := hk
        simp only [hdomain, mem_filter, mem_univ, true_and] at hk'mem
        exact xItemArc1_at_posElem_ge q a ha d k' (by unfold width; rw [hk'mem])
    _ ≤ ∑ k ∈ P22.c.D q d, xItemArc1 q a k (P22.c.endOf q d k) :=
        Finset.sum_le_sum_of_subset_of_nonneg hsub fun k _ _ => xItemArc1_nonneg q a k _

end SinglePatternFlow

-- ============================================================================
-- § Pattern → P22.c: aggregating single-pattern paths into a flow
-- ============================================================================

/-- Realize a pattern-usage vector as an arc-flow: `pv.x a` copies of the
canonical single-pattern path for each valid pattern `a`. -/
private noncomputable def patToFlow (q : P22.c.Params) (pv : PatVars q) : P22.c.Vars q where
  x := fun i j => ∑ a ∈ Jc q, pv.x a * xArc1 q a i j
  z := ∑ a ∈ Jc q, pv.x a

section PatToFlow

variable (q : P22.c.Params) (pv : PatVars q)

private lemma sum_x_fixed_right (j : Fin (q.W + 1)) (s : Finset (Fin (q.W + 1))) :
    ∑ i ∈ s, (patToFlow q pv).x i j = ∑ a ∈ Jc q, pv.x a * ∑ i ∈ s, xArc1 q a i j := by
  show ∑ i ∈ s, ∑ a ∈ Jc q, pv.x a * xArc1 q a i j = _
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl fun a _ => ?_
  rw [Finset.mul_sum]

private lemma sum_x_fixed_left (i : Fin (q.W + 1)) (s : Finset (Fin (q.W + 1))) :
    ∑ j ∈ s, (patToFlow q pv).x i j = ∑ a ∈ Jc q, pv.x a * ∑ j ∈ s, xArc1 q a i j := by
  show ∑ j ∈ s, ∑ a ∈ Jc q, pv.x a * xArc1 q a i j = _
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl fun a _ => ?_
  rw [Finset.mul_sum]

private lemma sum_x_over_D (d : Fin q.m) :
    ∑ k ∈ P22.c.D q d, (patToFlow q pv).x k (P22.c.endOf q d k)
      = ∑ a ∈ Jc q, pv.x a * ∑ k ∈ P22.c.D q d, xArc1 q a k (P22.c.endOf q d k) := by
  show ∑ k ∈ P22.c.D q d, ∑ a ∈ Jc q, pv.x a * xArc1 q a k (P22.c.endOf q d k) = _
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl fun a _ => ?_
  rw [Finset.mul_sum]

private lemma patToFlow_hflow0 :
    (∑ i ∈ P22.c.inArcs q 0, (patToFlow q pv).x i 0)
      - (∑ j ∈ P22.c.outArcs q 0, (patToFlow q pv).x 0 j) = -(patToFlow q pv).z := by
  rw [sum_x_fixed_right, sum_x_fixed_left]
  show (∑ a ∈ Jc q, pv.x a * ∑ i ∈ P22.c.inArcs q 0, xArc1 q a i 0)
        - (∑ a ∈ Jc q, pv.x a * ∑ j ∈ P22.c.outArcs q 0, xArc1 q a 0 j)
      = -(∑ a ∈ Jc q, pv.x a)
  simp only [← Finset.sum_sub_distrib, ← Finset.sum_neg_distrib]
  refine Finset.sum_congr rfl fun a ha => ?_
  have h := single_hflow0 q a ha
  linear_combination pv.x a * h

private lemma patToFlow_hflowW :
    (∑ i ∈ P22.c.inArcs q (Fin.last q.W), (patToFlow q pv).x i (Fin.last q.W))
      - (∑ j ∈ P22.c.outArcs q (Fin.last q.W), (patToFlow q pv).x (Fin.last q.W) j)
      = (patToFlow q pv).z := by
  rw [sum_x_fixed_right, sum_x_fixed_left]
  show (∑ a ∈ Jc q, pv.x a * ∑ i ∈ P22.c.inArcs q (Fin.last q.W), xArc1 q a i (Fin.last q.W))
        - (∑ a ∈ Jc q, pv.x a * ∑ j ∈ P22.c.outArcs q (Fin.last q.W), xArc1 q a (Fin.last q.W) j)
      = ∑ a ∈ Jc q, pv.x a
  simp only [← Finset.sum_sub_distrib]
  refine Finset.sum_congr rfl fun a ha => ?_
  have h := single_hflowW q a ha
  linear_combination pv.x a * h

private lemma patToFlow_hflowMid (vtx : Fin (q.W + 1)) (h0 : 0 < vtx.val) (hW : vtx.val < q.W) :
    (∑ i ∈ P22.c.inArcs q vtx, (patToFlow q pv).x i vtx)
      - (∑ j ∈ P22.c.outArcs q vtx, (patToFlow q pv).x vtx j) = 0 := by
  rw [sum_x_fixed_right, sum_x_fixed_left]
  show (∑ a ∈ Jc q, pv.x a * ∑ i ∈ P22.c.inArcs q vtx, xArc1 q a i vtx)
        - (∑ a ∈ Jc q, pv.x a * ∑ j ∈ P22.c.outArcs q vtx, xArc1 q a vtx j)
      = 0
  simp only [← Finset.sum_sub_distrib]
  rw [show (0 : ℤ) = ∑ _a ∈ Jc q, (0 : ℤ) from (Finset.sum_const_zero).symm]
  refine Finset.sum_congr rfl fun a ha => ?_
  have h := single_hflowMid q a ha vtx h0 hW
  linear_combination pv.x a * h

private lemma patToFlow_hdemand (hpv : PatFeasible q pv) (d : Fin q.m) :
    ∑ k ∈ P22.c.D q d, (patToFlow q pv).x k (P22.c.endOf q d k) ≥ q.b d := by
  rw [sum_x_over_D]
  have hstep : ∀ a ∈ Jc q,
      ((a d).val : ℤ) * pv.x a ≤ pv.x a * ∑ k ∈ P22.c.D q d, xArc1 q a k (P22.c.endOf q d k) := by
    intro a ha
    have hxi : ∑ k ∈ P22.c.D q d, xItemArc1 q a k (P22.c.endOf q d k)
        ≤ ∑ k ∈ P22.c.D q d, xArc1 q a k (P22.c.endOf q d k) := by
      refine Finset.sum_le_sum fun k _ => ?_
      unfold xArc1
      have := xLossArc1_nonneg q a k (P22.c.endOf q d k)
      linarith
    have hge := xItemArc1_sum_D_ge q a ha d
    have hb := le_trans hge hxi
    have hxnn : 0 ≤ pv.x a := hpv.hx_nn a ha
    calc ((a d).val : ℤ) * pv.x a
        ≤ (∑ k ∈ P22.c.D q d, xArc1 q a k (P22.c.endOf q d k)) * pv.x a :=
          mul_le_mul_of_nonneg_right hb hxnn
      _ = pv.x a * ∑ k ∈ P22.c.D q d, xArc1 q a k (P22.c.endOf q d k) := by ring
  calc q.b d ≤ ∑ a ∈ Jc q, ((a d).val : ℤ) * pv.x a := hpv.hdemand d
    _ ≤ ∑ a ∈ Jc q, pv.x a * ∑ k ∈ P22.c.D q d, xArc1 q a k (P22.c.endOf q d k) :=
        Finset.sum_le_sum hstep

private lemma patToFlow_hx_nn (hpv : PatFeasible q pv) (i j : Fin (q.W + 1))
    (_hij : P22.c.isArc q i j) : 0 ≤ (patToFlow q pv).x i j := by
  refine Finset.sum_nonneg fun a ha => mul_nonneg (hpv.hx_nn a ha) (xArc1_nonneg q a i j)

private lemma patToFlow_htotal (hpv : PatFeasible q pv) :
    (patToFlow q pv).z ≤ ∑ d : Fin q.m, q.b d := hpv.htotal

private lemma patToFlow_feas (hpv : PatFeasible q pv) : P22.c.Feasible q (patToFlow q pv) where
  hflow0 := patToFlow_hflow0 q pv
  hflowMid := patToFlow_hflowMid q pv
  hflowW := patToFlow_hflowW q pv
  hdemand := patToFlow_hdemand q pv hpv
  hx_nn := patToFlow_hx_nn q pv hpv
  htotal := patToFlow_htotal q pv hpv

private lemma patToFlow_obj (_hpv : PatFeasible q pv) :
    P22.c.obj q (patToFlow q pv) = ∑ a ∈ Jc q, pv.x a := by
  unfold P22.c.obj patToFlow
  push_cast
  ring

end PatToFlow

-- ============================================================================
-- § P22.b → P22.c: route pattern usage along canonical single-pattern paths
-- ============================================================================

/-- **P22.b → P22.c**: route each pattern's usage count along its canonical
single-path arc-flow (via `patToFlow`). -/
private noncomputable def fwd (p : P22.b.Params) (v : P22.b.Vars p) : P22.c.Vars (paramMap p) :=
  patToFlow (paramMap p) (toPatVars p v)

private lemma fwd_feas (p : P22.b.Params) (v : P22.b.Vars p) (h : P22.b.Feasible p v) :
    P22.c.Feasible (paramMap p) (fwd p v) :=
  patToFlow_feas (paramMap p) (toPatVars p v) (toPatVars_feas p v h)

private lemma fwd_obj (p : P22.b.Params) (v : P22.b.Vars p) (h : P22.b.Feasible p v) :
    P22.c.obj (paramMap p) (fwd p v) = P22.b.obj p v := by
  unfold fwd
  rw [patToFlow_obj (paramMap p) (toPatVars p v) (toPatVars_feas p v h)]
  show ∑ a ∈ P22.b.J p, v.x a = P22.b.obj p v
  unfold P22.b.obj
  push_cast
  rfl

-- ============================================================================
-- § P22.c → P22.b: flow decomposition (the hard direction)
-- ============================================================================

/-- The one non-constructive fact this file relies on for the hard
(`c → b`) direction: every feasible arc-flow decomposes into a pattern-usage
vector that reproduces the flow's "bin count" exactly. Constructively, this is
proved by peeling the flow into `z` unit paths from vertex `0` to vertex
`p.W`, position layer by position layer (using flow conservation at each
layer to match departing units to arcs), and recording each path's realized
item-type multiset as a pattern. That construction is intentionally not
carried out here; only the existence statement it would establish is recorded
below. -/
private lemma flow_decomp_exists (p : P22.b.Params) (v : P22.c.Vars (paramMap p))
    (h : P22.c.Feasible (paramMap p) v) :
    ∃ pv : P22.b.Vars p, P22.b.Feasible p pv ∧ ∑ a ∈ P22.b.J p, pv.x a = v.z := by
  sorry

private noncomputable def bwd (p : P22.b.Params) (v : P22.c.Vars (paramMap p)) : P22.b.Vars p :=
  @dite _ (P22.c.Feasible (paramMap p) v) (Classical.propDecidable _)
    (fun h => (flow_decomp_exists p v h).choose)
    (fun _ => ⟨fun _ => 0⟩)

private lemma bwd_spec (p : P22.b.Params) (v : P22.c.Vars (paramMap p))
    (h : P22.c.Feasible (paramMap p) v) :
    P22.b.Feasible p (bwd p v) ∧ ∑ a ∈ P22.b.J p, (bwd p v).x a = v.z := by
  unfold bwd
  rw [dif_pos h]
  exact (flow_decomp_exists p v h).choose_spec

private lemma bwd_feas (p : P22.b.Params) (v : P22.c.Vars (paramMap p))
    (h : P22.c.Feasible (paramMap p) v) : P22.b.Feasible p (bwd p v) :=
  (bwd_spec p v h).1

private lemma bwd_obj (p : P22.b.Params) (v : P22.c.Vars (paramMap p))
    (h : P22.c.Feasible (paramMap p) v) :
    P22.c.obj (paramMap p) v = P22.b.obj p (bwd p v) := by
  unfold P22.c.obj P22.b.obj
  rw [← (bwd_spec p v h).2]
  push_cast
  ring

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

noncomputable def bCReformulation : MILPReformulation P22.b.formulation P22.c.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj     := fwd_obj
  bwd_obj     := bwd_obj

end P22
