import Common
import problems.p22.formulations.a.Formulation
import problems.p22.formulations.b.Formulation

open BigOperators Finset

namespace P22

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

/-- Summing a weight over a target set `t`, weighted by the number of
`s`-elements mapping to each target value under `f`, equals summing the
weight of `f i` over those `i ∈ s` whose image lies in `t`. -/
private lemma sum_weight_fiber {ι : Type*} {κ : Type*} [DecidableEq κ]
    (s : Finset ι) (t : Finset κ) (f : ι → κ) (weight : κ → ℤ) :
    ∑ a ∈ t, weight a * ((s.filter (fun i => f i = a)).card : ℤ)
      = ∑ i ∈ s.filter (fun i => f i ∈ t), weight (f i) := by
  have key : ∀ a ∈ t, weight a * ((s.filter (fun i => f i = a)).card : ℤ)
      = ∑ i ∈ s, if f i = a then weight (f i) else 0 := by
    intro a _
    rw [Finset.card_filter]
    push_cast
    rw [Finset.mul_sum]
    refine Finset.sum_congr rfl fun i _ => ?_
    split
    · rename_i hfa; rw [hfa, mul_one]
    · ring
  rw [Finset.sum_congr rfl key, Finset.sum_comm, Finset.sum_filter]
  refine Finset.sum_congr rfl fun i _ => ?_
  rw [Finset.sum_ite_eq t (f i) (fun _ => weight (f i))]

/-- The fiber of a sigma type over a fixed base point is in bijection with the
corresponding component type, hence has the same cardinality. -/
private lemma sigma_fiber_card {α : Type*} {β : α → Type*} [DecidableEq α] [Fintype α]
    [∀ a, Fintype (β a)] (a0 : α) :
    (Finset.univ.filter (fun s : Σ a, β a => s.1 = a0)).card = Fintype.card (β a0) := by
  have e : {s : Σ a, β a // s.1 = a0} ≃ β a0 :=
    { toFun := fun s => s.2 ▸ s.1.2
      invFun := fun b => ⟨⟨a0, b⟩, rfl⟩
      left_inv := by rintro ⟨⟨a, b⟩, (rfl : a = a0)⟩; rfl
      right_inv := by intro b; rfl }
  rw [← Fintype.card_congr e, Fintype.card_subtype]

/-- Casting a sum of `Int.toNat`-truncated nonnegative integers back to `ℤ`
recovers the original sum. -/
private lemma natCast_sum_toNat_eq {ι : Type*} (s : Finset ι) (f : ι → ℤ)
    (hf : ∀ i ∈ s, 0 ≤ f i) :
    ((∑ i ∈ s, (f i).toNat : ℕ) : ℤ) = ∑ i ∈ s, f i := by
  push_cast
  exact Finset.sum_congr rfl fun i hi => Int.toNat_of_nonneg (hf i hi)

/-- Casting a sum of `Int.toNat`-truncated nonnegative integers, each scaled by
a natural-number weight, back to `ℤ` recovers the weighted sum. -/
private lemma natCast_sum_mul_toNat_eq {ι : Type*} (s : Finset ι) (c : ι → ℕ) (f : ι → ℤ)
    (hf : ∀ i ∈ s, 0 ≤ f i) :
    ((∑ i ∈ s, c i * (f i).toNat : ℕ) : ℤ) = ∑ i ∈ s, (c i : ℤ) * f i := by
  push_cast
  refine Finset.sum_congr rfl fun i hi => ?_
  rw [Int.toNat_of_nonneg (hf i hi)]

-- ============================================================================
-- § Parameter Mapping (flattening item types into individual items)
-- ============================================================================

section Flattening

variable (q : P22.b.Params)

/-- The number of items of type `d` (positive since demand is at least `1`). -/
private def N (d : Fin q.m) : ℕ := (q.b d).toNat

/-- The total number of individual items across all types. -/
private def nItems : ℕ := ∑ d : Fin q.m, N q d

/-- The sigma type of (type, copy-index) pairs has cardinality `nItems`. -/
private lemma card_sigma_eq :
    Fintype.card (Σ d : Fin q.m, Fin (N q d)) = nItems q := by
  rw [Fintype.card_sigma]
  simp only [Fintype.card_fin]
  rfl

/-- An enumeration of the flattened items as (type, copy-index) pairs. -/
private noncomputable def e : Fin (nItems q) ≃ (Σ d : Fin q.m, Fin (N q d)) :=
  (Fintype.equivFinOfCardEq (card_sigma_eq q)).symm

end Flattening

private noncomputable def paramMap (q : P22.b.Params) : P22.a.Params where
  n := nItems q
  W := (q.W : ℤ)
  l := fun j => (q.w (e q j).1 : ℤ)
  hl_lo := fun j => by exact_mod_cast q.hw_lo (e q j).1
  hl_hi := fun j => by exact_mod_cast q.hw_hi (e q j).1
  hW_pos := by
    have h : 1 ≤ q.W := Nat.one_le_iff_ne_zero.mpr q.hW.out
    exact_mod_cast h
  hn := ⟨by
    show nItems q ≠ 0
    unfold nItems
    have d0 : Fin q.m := ⟨0, Nat.pos_of_ne_zero q.hm.out⟩
    have hN : 1 ≤ N q d0 := by have := q.hb_pos d0; unfold N; omega
    have hle : N q d0 ≤ ∑ d, N q d :=
      Finset.single_le_sum (fun d _ => Nat.zero_le _) (mem_univ d0)
    omega⟩

/-- The construction-time type index of item `j`. -/
private noncomputable def idx' (q : P22.b.Params) (j : Fin (nItems q)) : Fin q.m :=
  (e q j).1

/-- The size of item `j` in the mapped `a`-parameters is its type's size. -/
private lemma paramMap_l (q : P22.b.Params) (j : Fin (nItems q)) :
    (paramMap q).l j = (q.w (idx' q j) : ℤ) := rfl

/-- The mapped bin capacity is the cast of the original nat capacity. -/
private lemma paramMap_W_eq (q : P22.b.Params) : (paramMap q).W = (q.W : ℤ) := rfl

/-- The number of items assigned to type-class `d`. -/
private noncomputable def bCount' (q : P22.b.Params) (d : Fin q.m) : ℤ :=
  ((univ.filter (fun j : Fin (nItems q) => idx' q j = d)).card : ℤ)

/-- The fiber of `idx'` over type `d` has exactly `N q d` items. -/
private lemma fiber_card (q : P22.b.Params) (d : Fin q.m) :
    (univ.filter (fun j : Fin (nItems q) => idx' q j = d)).card = N q d := by
  rw [← Fintype.card_subtype (fun j : Fin (nItems q) => idx' q j = d)]
  rw [Fintype.card_congr (Equiv.subtypeEquiv (e q)
      (p := fun j => idx' q j = d) (q := fun s => s.1 = d) (fun _ => Iff.rfl))]
  rw [Fintype.card_subtype (fun s : Σ d : Fin q.m, Fin (N q d) => s.1 = d)]
  rw [sigma_fiber_card (β := fun d => Fin (N q d)) d]
  exact Fintype.card_fin _

/-- The number of type-`d` items equals the demand `q.b d`. -/
private lemma bCount'_eq_b (q : P22.b.Params) (d : Fin q.m) : bCount' q d = q.b d := by
  have h1 : bCount' q d = (N q d : ℤ) := by unfold bCount'; rw [fiber_card]
  rw [h1]
  show ((q.b d).toNat : ℤ) = q.b d
  exact Int.toNat_of_nonneg (by linarith [q.hb_pos d])

/-- Every type-class contains at least one item. -/
private lemma bCount'_pos (q : P22.b.Params) (d : Fin q.m) : 1 ≤ bCount' q d := by
  rw [bCount'_eq_b]; exact q.hb_pos d

/-- The item counts across all types sum to the total number of items. -/
private lemma sum_bCount'_eq_n (q : P22.b.Params) :
    ∑ d : Fin q.m, bCount' q d = (nItems q : ℤ) := by
  unfold bCount'
  rw [← Nat.cast_sum, ← Finset.card_eq_sum_card_fiberwise (f := idx' q) (t := univ)
    (fun j _ => mem_univ (idx' q j))]
  simp

-- ============================================================================
-- § Map a → b: realized bin patterns
-- ============================================================================

/-- The (integer) number of items of type `d` assigned to bin `i`. -/
private noncomputable def countType (q : P22.b.Params) (v : P22.a.Vars (paramMap q))
    (i : Fin (nItems q)) (d : Fin q.m) : ℤ :=
  ∑ j : Fin (nItems q), if idx' q j = d then v.x i j else 0

section ForwardHelpers

variable {q : P22.b.Params} {v : P22.a.Vars (paramMap q)} (h : P22.a.Feasible (paramMap q) v)
include h

private lemma countType_nonneg (i : Fin (nItems q)) (d : Fin q.m) :
    0 ≤ countType q v i d := by
  refine Finset.sum_nonneg fun j _ => ?_
  split
  · rcases h.hx_bin i j with h0 | h1 <;> omega
  · omega

omit h in
/-- Grouping items by type recovers the total assigned load of a bin. -/
private lemma sum_w_countType (i : Fin (nItems q)) :
    ∑ d : Fin q.m, (q.w d : ℤ) * countType q v i d
      = ∑ j : Fin (nItems q), (paramMap q).l j * v.x i j := by
  unfold countType
  have key : ∀ d : Fin q.m,
      (q.w d : ℤ) * ∑ j : Fin (nItems q), (if idx' q j = d then v.x i j else 0)
        = ∑ j : Fin (nItems q), (if idx' q j = d then (q.w (idx' q j) : ℤ) * v.x i j else 0) := by
    intro d
    rw [Finset.mul_sum]
    refine Finset.sum_congr rfl fun j _ => ?_
    split
    · rename_i hd; subst hd; rfl
    · ring
  simp_rw [key]
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl fun j _ => ?_
  simp only [paramMap_l]
  rw [Finset.sum_ite_eq univ (idx' q j) (fun _ => (q.w (idx' q j) : ℤ) * v.x i j)]
  simp

/-- The total (weighted) load of a bin is bounded by `W`. -/
private lemma sum_w_countType_le (i : Fin (nItems q)) :
    ∑ d : Fin q.m, (q.w d : ℤ) * countType q v i d ≤ (paramMap q).W := by
  rw [sum_w_countType i]
  have hy : v.y i ≤ 1 := by rcases h.hy_bin i with h0 | h1 <;> omega
  calc ∑ j : Fin (nItems q), (paramMap q).l j * v.x i j ≤ (paramMap q).W * v.y i := h.hcap i
    _ ≤ (paramMap q).W * 1 := mul_le_mul_of_nonneg_left hy (by linarith [(paramMap q).hW_pos])
    _ = (paramMap q).W := by ring

/-- Each individual type's count in a bin is bounded by the bin capacity. -/
private lemma countType_le_W (i : Fin (nItems q)) (d : Fin q.m) :
    countType q v i d ≤ (paramMap q).W := by
  have hle := sum_w_countType_le h i
  have hsingle : (q.w d : ℤ) * countType q v i d
      ≤ ∑ d' : Fin q.m, (q.w d' : ℤ) * countType q v i d' :=
    Finset.single_le_sum (f := fun d' => (q.w d' : ℤ) * countType q v i d')
      (fun d' _ => mul_nonneg (by positivity) (countType_nonneg h i d')) (mem_univ d)
  have hw1 : (1 : ℤ) ≤ (q.w d : ℤ) := by exact_mod_cast q.hw_lo d
  nlinarith [countType_nonneg h i d]

/-- If a bin is unused, no items are assigned to it, so its type-`d` count is `0`. -/
private lemma countType_zero_of_unused (i : Fin (nItems q)) (hy : v.y i = 0) (d : Fin q.m) :
    countType q v i d = 0 := by
  have hcap := h.hcap i
  rw [hy, mul_zero] at hcap
  have hxz : ∀ j : Fin (nItems q), v.x i j = 0 := by
    intro j
    have hnn : ∀ j' : Fin (nItems q), 0 ≤ (paramMap q).l j' * v.x i j' := by
      intro j'
      rcases h.hx_bin i j' with h0 | h1
      · rw [h0]; simp
      · rw [h1]; linarith [(paramMap q).hl_lo j']
    have hzero : (paramMap q).l j * v.x i j = 0 :=
      le_antisymm
        (calc (paramMap q).l j * v.x i j ≤ ∑ j' : Fin (nItems q), (paramMap q).l j' * v.x i j' :=
              Finset.single_le_sum (fun j' _ => hnn j') (mem_univ j)
          _ ≤ 0 := hcap)
        (hnn j)
    rcases mul_eq_zero.mp hzero with h0 | h0
    · linarith [(paramMap q).hl_lo j]
    · exact h0
  unfold countType
  refine Finset.sum_eq_zero fun j _ => ?_
  split
  · exact hxz j
  · rfl

end ForwardHelpers

/-- The set of bins actually used. -/
private def usedSet (q : P22.b.Params) (v : P22.a.Vars (paramMap q)) : Finset (Fin (nItems q)) :=
  univ.filter (fun i => v.y i = 1)

/-- The pattern realized by bin `i`: for each type `d`, the number of items of
that type assigned to bin `i`, capped at `W`. -/
private noncomputable def realizedPattern (q : P22.b.Params) (v : P22.a.Vars (paramMap q))
    (i : Fin (nItems q)) : Fin q.m → Fin (q.W + 1) :=
  fun d => ⟨min (countType q v i d).toNat q.W, Nat.lt_succ_of_le (min_le_right _ _)⟩

section ForwardHelpers2

variable {q : P22.b.Params} {v : P22.a.Vars (paramMap q)} (h : P22.a.Feasible (paramMap q) v)
include h

/-- Under feasibility, the cap in `realizedPattern` is never active. -/
private lemma realizedPattern_val (i : Fin (nItems q)) (d : Fin q.m) :
    (realizedPattern q v i d).val = (countType q v i d).toNat := by
  unfold realizedPattern
  simp only
  have hle := countType_le_W h i d
  have hnn := countType_nonneg h i d
  rw [paramMap_W_eq] at hle
  have hcapineq : (countType q v i d).toNat ≤ q.W := by omega
  exact min_eq_left hcapineq

/-- Every realized pattern is a valid cutting pattern. -/
private lemma realizedPattern_mem_J (i : Fin (nItems q)) :
    realizedPattern q v i ∈ P22.b.J q := by
  unfold P22.b.J
  simp only [mem_filter, mem_univ, true_and]
  have heq : ∑ d : Fin q.m, q.w d * (realizedPattern q v i d).val
      = ∑ d : Fin q.m, q.w d * (countType q v i d).toNat := by
    refine Finset.sum_congr rfl fun d _ => ?_
    rw [realizedPattern_val h i d]
  show ∑ d : Fin q.m, q.w d * (realizedPattern q v i d).val ≤ q.W
  rw [heq]
  have hcast := natCast_sum_mul_toNat_eq univ q.w (countType q v i)
    (fun d _ => countType_nonneg h i d)
  have hle := sum_w_countType_le h i
  have hcastle : ((∑ d : Fin q.m, q.w d * (countType q v i d).toNat : ℕ) : ℤ) ≤ (paramMap q).W := by
    rw [hcast]; exact hle
  have hWeq := paramMap_W_eq q
  omega

end ForwardHelpers2

/--
**P22.a → P22.b**: for each valid cutting pattern `a`, count the number of
used bins whose realized item-type multiset is exactly `a`.
-/
private noncomputable def mapAB (q : P22.b.Params) (v : P22.a.Vars (paramMap q)) : P22.b.Vars q where
  x := fun a => (((usedSet q v).filter (fun i => realizedPattern q v i = a)).card : ℤ)

private lemma mapAB_filter_triv (q : P22.b.Params) (v : P22.a.Vars (paramMap q))
    (h : P22.a.Feasible (paramMap q) v) :
    (usedSet q v).filter (fun i => realizedPattern q v i ∈ P22.b.J q) = usedSet q v :=
  Finset.filter_true_of_mem (fun i _ => realizedPattern_mem_J h i)

private lemma mapAB_count_ext (q : P22.b.Params) (v : P22.a.Vars (paramMap q))
    (h : P22.a.Feasible (paramMap q) v) (d : Fin q.m) :
    ∑ i ∈ usedSet q v, countType q v i d = ∑ i : Fin (nItems q), countType q v i d := by
  refine Finset.sum_subset (Finset.filter_subset _ _) fun i _ hnotin => ?_
  simp only [usedSet, mem_filter, mem_univ, true_and] at hnotin
  have hy0 : v.y i = 0 := by rcases h.hy_bin i with h0 | h1 <;> [exact h0; exact absurd h1 hnotin]
  exact countType_zero_of_unused h i hy0 d

private lemma mapAB_demand_eq (q : P22.b.Params) (v : P22.a.Vars (paramMap q))
    (h : P22.a.Feasible (paramMap q) v) (d : Fin q.m) :
    ∑ a ∈ P22.b.J q, ((a d).val : ℤ) * (mapAB q v).x a = bCount' q d := by
  have hsw := sum_weight_fiber (usedSet q v) (P22.b.J q) (realizedPattern q v)
    (fun a => ((a d).val : ℤ))
  show ∑ a ∈ P22.b.J q, ((a d).val : ℤ) *
    (((usedSet q v).filter (fun i => realizedPattern q v i = a)).card : ℤ) = bCount' q d
  rw [hsw, mapAB_filter_triv q v h]
  have step1 : ∑ i ∈ usedSet q v, ((realizedPattern q v i d).val : ℤ)
      = ∑ i ∈ usedSet q v, countType q v i d := by
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [realizedPattern_val h i d, Int.toNat_of_nonneg (countType_nonneg h i d)]
  rw [step1, mapAB_count_ext q v h d]
  unfold countType
  rw [Finset.sum_comm]
  have step2 : ∀ j : Fin (nItems q),
      ∑ i : Fin (nItems q), (if idx' q j = d then v.x i j else 0)
        = if idx' q j = d then 1 else 0 := by
    intro j
    split
    · exact h.hassign j
    · simp
  simp_rw [step2]
  rw [Finset.sum_boole]
  rfl

private lemma mapAB_total_eq (q : P22.b.Params) (v : P22.a.Vars (paramMap q))
    (h : P22.a.Feasible (paramMap q) v) :
    ∑ a ∈ P22.b.J q, (mapAB q v).x a = (usedSet q v).card := by
  have hsw := sum_weight_fiber (usedSet q v) (P22.b.J q) (realizedPattern q v)
    (fun _ => (1 : ℤ))
  show ∑ a ∈ P22.b.J q,
    ((((usedSet q v).filter (fun i => realizedPattern q v i = a)).card : ℤ)) = _
  have hsw' : ∑ a ∈ P22.b.J q, (1 : ℤ) *
      (((usedSet q v).filter (fun i => realizedPattern q v i = a)).card : ℤ)
        = ∑ i ∈ (usedSet q v).filter (fun i => realizedPattern q v i ∈ P22.b.J q),
            (1 : ℤ) := hsw
  simp only [one_mul] at hsw'
  rw [hsw', mapAB_filter_triv q v h, Finset.sum_const, nsmul_eq_mul, mul_one]

private lemma mapAB_feas (q : P22.b.Params) (v : P22.a.Vars (paramMap q))
    (h : P22.a.Feasible (paramMap q) v) :
    P22.b.Feasible q (mapAB q v) := by
  refine
    { hdemand := fun d => (mapAB_demand_eq q v h d).trans (bCount'_eq_b q d)
      hx_nn := fun a _ => Int.natCast_nonneg _
      htotal := ?_ }
  rw [mapAB_total_eq q v h]
  show ((usedSet q v).card : ℤ) ≤ ∑ d : Fin q.m, q.b d
  have hle : (usedSet q v).card ≤ nItems q := by
    have hcf := Finset.card_filter_le univ (fun i : Fin (nItems q) => v.y i = 1)
    simpa [usedSet] using hcf
  have hle' : ((usedSet q v).card : ℤ) ≤ (nItems q : ℤ) := by exact_mod_cast hle
  have hsum : ((nItems q : ℤ)) = ∑ d : Fin q.m, bCount' q d := (sum_bCount'_eq_n q).symm
  have hb : ∑ d : Fin q.m, bCount' q d = ∑ d : Fin q.m, q.b d :=
    Finset.sum_congr rfl (fun d _ => bCount'_eq_b q d)
  rw [← hb, ← hsum]
  exact hle'

private lemma mapAB_obj (q : P22.b.Params) (v : P22.a.Vars (paramMap q))
    (h : P22.a.Feasible (paramMap q) v) :
    P22.b.obj q (mapAB q v) = P22.a.obj (paramMap q) v := by
  unfold P22.b.obj P22.a.obj
  have hZ : ∑ a ∈ P22.b.J q, (mapAB q v).x a = ∑ i : Fin (nItems q), v.y i := by
    rw [mapAB_total_eq q v h]
    unfold usedSet
    rw [Finset.card_filter]
    push_cast
    refine Finset.sum_congr rfl fun i _ => ?_
    rcases h.hy_bin i with h0 | h1
    · simp [h0]
    · simp [h1]
  calc ∑ a ∈ P22.b.J q, ((mapAB q v).x a : ℝ)
      = ((∑ a ∈ P22.b.J q, (mapAB q v).x a : ℤ) : ℝ) := by push_cast; ring
    _ = ((∑ i : Fin (nItems q), v.y i : ℤ) : ℝ) := by rw [hZ]
    _ = ∑ i : Fin (nItems q), (v.y i : ℝ) := by push_cast; ring

-- ============================================================================
-- § Map b → a: assign items to bins via matchings
-- ============================================================================

section BackwardDefs

variable (q : P22.b.Params) (v : P22.b.Vars q)

/-- One "virtual bin copy" for every unit of usage `v.x a` of every valid
pattern `a`. -/
private noncomputable def Copies :
    Finset (Σ a : Fin q.m → Fin (q.W + 1), Fin (v.x a).toNat) :=
  (P22.b.J q).sigma (fun a => (univ : Finset (Fin (v.x a).toNat)))

private def CopiesSub : Type := {c // c ∈ Copies q v}

noncomputable instance : Fintype (CopiesSub q v) := by unfold CopiesSub; infer_instance

/-- Choose an injection from copies into actual bin indices, when one exists. -/
private noncomputable def binOf : CopiesSub q v → Fin (nItems q) :=
  @dite _ (Nonempty (CopiesSub q v ↪ Fin (nItems q))) (Classical.propDecidable _)
    (fun hex => (Classical.choice hex : CopiesSub q v ↪ Fin (nItems q)))
    (fun _ => fun _ => ⟨0, Nat.pos_of_ne_zero (paramMap q).hn.out⟩)

/-- The items of type-class `d`. -/
private def TypeItems (d : Fin q.m) : Type := {j : Fin (nItems q) // idx' q j = d}

noncomputable instance (d : Fin q.m) : Fintype (TypeItems q d) := by
  unfold TypeItems; infer_instance

/-- The available capacity-slots of type `d`, across all copies. -/
private def TypeSlots (d : Fin q.m) : Type := Σ c : CopiesSub q v, Fin ((c.1.1 d).val)

noncomputable instance (d : Fin q.m) : Fintype (TypeSlots q v d) := by
  unfold TypeSlots; infer_instance

/-- Choose an injection from items into slots of the same type, when one
exists; `none` indicates "unassigned" (only relevant when `v` is infeasible). -/
private noncomputable def slotOf (d : Fin q.m) :
    TypeItems q d → Option (TypeSlots q v d) :=
  @dite _ (Nonempty (TypeItems q d ↪ TypeSlots q v d)) (Classical.propDecidable _)
    (fun hex => fun t => some ((Classical.choice hex : TypeItems q d ↪ TypeSlots q v d) t))
    (fun _ => fun _ => none)

end BackwardDefs

/-- The (candidate) bin that item `j` is assigned to, or `none` if unassigned. -/
private noncomputable def itemTarget (q : P22.b.Params) (v : P22.b.Vars q)
    (j : Fin (nItems q)) : Option (Fin (nItems q)) :=
  (slotOf q v (idx' q j) ⟨j, rfl⟩).map (fun s => binOf q v s.1)

/--
**P22.b → P22.a**: realize each unit of usage of each valid pattern as a
distinct bin (via `binOf`), and assign each item to the bin of the copy whose
type-slot it was matched with (via `slotOf`).
-/
private noncomputable def mapBA (q : P22.b.Params) (v : P22.b.Vars q) : P22.a.Vars (paramMap q) where
  y := fun i => if ∃ c : CopiesSub q v, binOf q v c = i then 1 else 0
  x := fun i j => if itemTarget q v j = some i then 1 else 0

section BackwardHelpers

variable {q : P22.b.Params} {v : P22.b.Vars q} (h : P22.b.Feasible q v)
include h

omit h in
/-- The number of virtual copies equals the total pattern usage. -/
private lemma copies_card_eq : (Copies q v).card = ∑ a ∈ P22.b.J q, (v.x a).toNat := by
  unfold Copies
  rw [Finset.card_sigma]
  simp only [card_univ, Fintype.card_fin]

private lemma copies_card_le : (Copies q v).card ≤ nItems q := by
  rw [copies_card_eq]
  have hcast := natCast_sum_toNat_eq (P22.b.J q) v.x h.hx_nn
  have hstep : ((∑ a ∈ P22.b.J q, (v.x a).toNat : ℕ) : ℤ) ≤ ∑ d : Fin q.m, bCount' q d := by
    rw [hcast]
    calc ∑ a ∈ P22.b.J q, v.x a
        ≤ ∑ d : Fin q.m, q.b d := h.htotal
      _ = ∑ d : Fin q.m, bCount' q d := (Finset.sum_congr rfl (fun d _ => (bCount'_eq_b q d).symm))
  have hsum : ((nItems q : ℤ)) = ∑ d : Fin q.m, bCount' q d := (sum_bCount'_eq_n q).symm
  have hgoal : ((∑ a ∈ P22.b.J q, (v.x a).toNat : ℕ) : ℤ) ≤ (nItems q : ℤ) := by
    rw [hsum]; exact hstep
  exact_mod_cast hgoal

private lemma binOf_nonempty_emb : Nonempty (CopiesSub q v ↪ Fin (nItems q)) := by
  apply Function.Embedding.nonempty_of_card_le
  unfold CopiesSub
  rw [Fintype.card_coe, Fintype.card_fin]
  exact copies_card_le h

private lemma binOf_eq_emb :
    binOf q v = ⇑(Classical.choice (binOf_nonempty_emb h)) := by
  unfold binOf
  rw [dif_pos (binOf_nonempty_emb h)]

private lemma binOf_injective : Function.Injective (binOf q v) := by
  rw [binOf_eq_emb h]
  exact (Classical.choice (binOf_nonempty_emb h)).injective

omit h in
private lemma typeSlots_card_eq (d : Fin q.m) :
    Fintype.card (TypeSlots q v d)
      = ∑ a ∈ P22.b.J q, (v.x a).toNat * (a d).val := by
  unfold TypeSlots
  rw [Fintype.card_sigma]
  show ∑ c : CopiesSub q v, Fintype.card (Fin ((c.1.1 d).val)) = _
  simp_rw [Fintype.card_fin]
  show ∑ c ∈ (Copies q v).attach, ((c : Σ a : Fin q.m → Fin (q.W + 1),
    Fin (v.x a).toNat).1 d).val = _
  rw [Finset.sum_attach (Copies q v) (fun c => (c.1 d).val)]
  unfold Copies
  rw [Finset.sum_sigma]
  refine Finset.sum_congr rfl fun a _ => ?_
  simp [Nat.mul_comm]

omit h in
private lemma typeItems_card_eq (d : Fin q.m) :
    Fintype.card (TypeItems q d) = (bCount' q d).toNat := by
  unfold TypeItems
  rw [Fintype.card_subtype]
  unfold bCount'
  rw [Int.toNat_natCast]

omit h in
private lemma typeItems_nonempty (d : Fin q.m) : Nonempty (TypeItems q d) := by
  rw [← Fintype.card_pos_iff, typeItems_card_eq]
  have h1 := bCount'_pos q d
  omega

private lemma typeItems_le_typeSlots (d : Fin q.m) :
    Fintype.card (TypeItems q d) ≤ Fintype.card (TypeSlots q v d) := by
  rw [typeItems_card_eq, typeSlots_card_eq]
  have hdem := h.hdemand d
  have hcast : ∑ a ∈ P22.b.J q, ((a d).val : ℤ) * v.x a
      = ((∑ a ∈ P22.b.J q, (v.x a).toNat * (a d).val : ℕ) : ℤ) := by
    rw [← natCast_sum_mul_toNat_eq (P22.b.J q) (fun a => (a d).val) v.x h.hx_nn]
    congr 1
    exact Finset.sum_congr rfl fun a _ => Nat.mul_comm _ _
  rw [hcast] at hdem
  have hgoal : ((bCount' q d).toNat : ℤ)
      ≤ ((∑ a ∈ P22.b.J q, (v.x a).toNat * (a d).val : ℕ) : ℤ) := by
    rw [Int.toNat_of_nonneg (by linarith [bCount'_pos q d]), bCount'_eq_b]
    exact hdem.ge
  exact_mod_cast hgoal

private lemma slotOf_nonempty_emb (d : Fin q.m) :
    Nonempty (TypeItems q d ↪ TypeSlots q v d) :=
  Function.Embedding.nonempty_of_card_le (typeItems_le_typeSlots h d)

private lemma slotOf_eq_emb (d : Fin q.m) :
    slotOf q v d = fun t => some ((Classical.choice (slotOf_nonempty_emb h d)) t) := by
  unfold slotOf
  rw [dif_pos (slotOf_nonempty_emb h d)]

/-- Under feasibility, every item is matched to some slot, hence some bin. -/
private lemma itemTarget_eq_some (j : Fin (nItems q)) :
    itemTarget q v j
      = some (binOf q v ((Classical.choice (slotOf_nonempty_emb h (idx' q j))) ⟨j, rfl⟩).1) := by
  unfold itemTarget
  rw [slotOf_eq_emb h]
  simp

private lemma itemTarget_isSome (j : Fin (nItems q)) : (itemTarget q v j).isSome := by
  rw [itemTarget_eq_some h]
  rfl

/-- If item `j` targets bin `i`, and `c0` is the (unique, under feasibility)
copy mapping to bin `i`, then `j`'s matched slot belongs to `c0`. -/
private lemma slot_fst_eq_of_itemTarget (j i : Fin (nItems q)) (c0 : CopiesSub q v)
    (hc0 : binOf q v c0 = i) (hj : itemTarget q v j = some i) :
    (Classical.choice (slotOf_nonempty_emb h (idx' q j)) ⟨j, rfl⟩).1 = c0 := by
  rw [itemTarget_eq_some h] at hj
  have heq : binOf q v ((Classical.choice (slotOf_nonempty_emb h (idx' q j))) ⟨j, rfl⟩).1
      = i := Option.some.inj hj
  rw [← hc0] at heq
  exact binOf_injective h heq

/-- The items of type `d` assigned to bin `i` are at most the type-`d`
capacity of the (unique) copy realizing bin `i`. -/
private lemma countTypeB_le (i : Fin (nItems q)) (d : Fin q.m) (c0 : CopiesSub q v)
    (hc0 : binOf q v c0 = i) :
    (univ.filter (fun j : Fin (nItems q) => idx' q j = d ∧ itemTarget q v j = some i)).card
      ≤ (c0.1.1 d).val := by
  classical
  have hcard_fiber : (univ.filter (fun s : TypeSlots q v d => s.1 = c0)).card = (c0.1.1 d).val := by
    exact (sigma_fiber_card (α := CopiesSub q v) (β := fun c => Fin ((c.1.1 d).val)) c0).trans
      (Fintype.card_fin _)
  rw [← hcard_fiber]
  set Ed := Classical.choice (slotOf_nonempty_emb h d) with hEd
  set default0 : TypeItems q d := Classical.choice (typeItems_nonempty d) with hdefault0
  apply Finset.card_le_card_of_injOn
    (fun j => if hj : idx' q j = d then Ed ⟨j, hj⟩ else Ed default0)
  · intro j hj
    simp only [Finset.coe_filter, Set.mem_setOf_eq, mem_univ, true_and] at hj
    obtain ⟨hjd, hjt⟩ := hj
    show (if hj : idx' q j = d then Ed ⟨j, hj⟩ else Ed default0) ∈ (↑(univ.filter
      (fun s : TypeSlots q v d => s.1 = c0)) : Set (TypeSlots q v d))
    rw [dif_pos hjd]
    simp only [Finset.coe_filter, Set.mem_setOf_eq]
    have hthis := slot_fst_eq_of_itemTarget h j i c0 hc0 hjt
    subst hjd
    exact ⟨mem_univ _, hthis⟩
  · intro j1 hj1 j2 hj2 heqf
    simp only [Finset.coe_filter, Set.mem_setOf_eq, mem_univ, true_and] at hj1 hj2
    dsimp only at heqf
    rw [dif_pos hj1.1, dif_pos hj2.1] at heqf
    have hval := Ed.injective heqf
    exact congrArg Subtype.val hval

/-- Every item is assigned to exactly one bin. -/
private lemma mapBA_hassign (j : Fin (nItems q)) : ∑ i : Fin (nItems q), (mapBA q v).x i j = 1 := by
  obtain ⟨t, ht⟩ := Option.isSome_iff_exists.mp (itemTarget_isSome h j)
  have hrw : ∀ i : Fin (nItems q),
      (mapBA q v).x i j = (if t = i then (1 : ℤ) else 0) := by
    intro i
    show (if itemTarget q v j = some i then (1 : ℤ) else 0) = _
    rw [ht]
    by_cases hti : t = i
    · simp [hti]
    · simp [hti]
  simp_rw [hrw]
  rw [Finset.sum_ite_eq univ t (fun _ => (1 : ℤ))]
  simp

omit h in
/-- The pattern underlying any copy is a valid cutting pattern. -/
private lemma copy_pattern_mem_J (c : CopiesSub q v) :
    c.1.1 ∈ P22.b.J q := (Finset.mem_sigma.mp c.2).1

omit h in
/-- `countType` of `mapBA q v` counts exactly the items of type `d` assigned to
bin `i`. -/
private lemma countType_mapBA_eq_card (i : Fin (nItems q)) (d : Fin q.m) :
    countType q (mapBA q v) i d
      = ((univ.filter (fun j : Fin (nItems q) => idx' q j = d ∧ itemTarget q v j = some i)).card : ℤ) := by
  unfold countType
  rw [Finset.card_filter]
  push_cast
  refine Finset.sum_congr rfl fun j _ => ?_
  show (if idx' q j = d then (if itemTarget q v j = some i then (1 : ℤ) else 0) else 0) = _
  by_cases hd : idx' q j = d <;> by_cases ht : itemTarget q v j = some i <;> simp [hd, ht]

/-- The load of any bin under `mapBA q v` does not exceed the bin capacity. -/
private lemma mapBA_hcap (i : Fin (nItems q)) :
    ∑ j : Fin (nItems q), (paramMap q).l j * (mapBA q v).x i j ≤ (paramMap q).W * (mapBA q v).y i := by
  by_cases hex : ∃ c : CopiesSub q v, binOf q v c = i
  · obtain ⟨c0, hc0⟩ := hex
    have hy1 : (mapBA q v).y i = 1 := by
      show (if (∃ c : CopiesSub q v, binOf q v c = i) then (1 : ℤ) else 0) = 1
      rw [if_pos ⟨c0, hc0⟩]
    rw [hy1, mul_one]
    have hload : ∑ j : Fin (nItems q), (paramMap q).l j * (mapBA q v).x i j
        = ∑ d : Fin q.m, (q.w d : ℤ) * countType q (mapBA q v) i d :=
      (sum_w_countType i).symm
    rw [hload]
    have hstep : ∑ d : Fin q.m, (q.w d : ℤ) * countType q (mapBA q v) i d
        ≤ ∑ d : Fin q.m, (q.w d : ℤ) * ((c0.1.1 d).val : ℤ) := by
      refine Finset.sum_le_sum fun d _ => ?_
      rw [countType_mapBA_eq_card i d]
      have hle := countTypeB_le h i d c0 hc0
      have hwnn : (0 : ℤ) ≤ (q.w d : ℤ) := Int.natCast_nonneg _
      exact mul_le_mul_of_nonneg_left (by exact_mod_cast hle) hwnn
    have hJ := copy_pattern_mem_J c0
    unfold P22.b.J at hJ
    simp only [mem_filter, mem_univ, true_and] at hJ
    have hJ' : ∑ d : Fin q.m, q.w d * ((c0.1.1 d).val : ℕ) ≤ q.W := hJ
    have hJ'' : ((∑ d : Fin q.m, q.w d * ((c0.1.1 d).val : ℕ) : ℕ) : ℤ)
        ≤ ((q.W : ℕ) : ℤ) := by exact_mod_cast hJ'
    rw [paramMap_W_eq] at *
    have hcast : ((∑ d : Fin q.m, q.w d * ((c0.1.1 d).val : ℕ) : ℕ) : ℤ)
        = ∑ d : Fin q.m, (q.w d : ℤ) * ((c0.1.1 d).val : ℤ) := by
      push_cast
      rfl
    rw [hcast] at hJ''
    linarith
  · have hy0 : (mapBA q v).y i = 0 := by
      show (if (∃ c : CopiesSub q v, binOf q v c = i) then (1 : ℤ) else 0) = 0
      rw [if_neg hex]
    rw [hy0, mul_zero]
    have hzero : ∀ j : Fin (nItems q), (mapBA q v).x i j = 0 := by
      intro j
      show (if itemTarget q v j = some i then (1 : ℤ) else 0) = 0
      rw [if_neg]
      intro hcontra
      rw [itemTarget_eq_some h] at hcontra
      exact hex ⟨(Classical.choice (slotOf_nonempty_emb h (idx' q j)) ⟨j, rfl⟩).1,
        Option.some.inj hcontra⟩
    simp [hzero]

omit h in
/-- `mapBA q v`'s bin-usage variables are binary. -/
private lemma mapBA_hy_bin (i : Fin (nItems q)) : (mapBA q v).y i = 0 ∨ (mapBA q v).y i = 1 := by
  by_cases hex : ∃ c : CopiesSub q v, binOf q v c = i
  · right
    show (if (∃ c : CopiesSub q v, binOf q v c = i) then (1 : ℤ) else 0) = 1
    rw [if_pos hex]
  · left
    show (if (∃ c : CopiesSub q v, binOf q v c = i) then (1 : ℤ) else 0) = 0
    rw [if_neg hex]

omit h in
/-- `mapBA q v`'s item-assignment variables are binary. -/
private lemma mapBA_hx_bin (i j : Fin (nItems q)) : (mapBA q v).x i j = 0 ∨ (mapBA q v).x i j = 1 := by
  by_cases ht : itemTarget q v j = some i
  · right
    show (if itemTarget q v j = some i then (1 : ℤ) else 0) = 1
    rw [if_pos ht]
  · left
    show (if itemTarget q v j = some i then (1 : ℤ) else 0) = 0
    rw [if_neg ht]

omit h in
private lemma mapBA_y_eq_one_iff (i : Fin (nItems q)) :
    (mapBA q v).y i = 1 ↔ ∃ c : CopiesSub q v, binOf q v c = i := by
  by_cases hex : ∃ c : CopiesSub q v, binOf q v c = i
  · simp only [hex, iff_true]
    show (if (∃ c : CopiesSub q v, binOf q v c = i) then (1 : ℤ) else 0) = 1
    rw [if_pos hex]
  · simp only [hex, iff_false]
    show (if (∃ c : CopiesSub q v, binOf q v c = i) then (1 : ℤ) else 0) ≠ 1
    rw [if_neg hex]; norm_num

omit h in
private lemma mapBA_used_eq_image :
    univ.filter (fun i : Fin (nItems q) => (mapBA q v).y i = 1) = Finset.image (binOf q v) univ := by
  ext i
  simp only [mem_filter, mem_univ, true_and, Finset.mem_image, mapBA_y_eq_one_iff]

end BackwardHelpers

private lemma mapBA_feas (q : P22.b.Params) (v : P22.b.Vars q)
    (h : P22.b.Feasible q v) :
    P22.a.Feasible (paramMap q) (mapBA q v) where
  hcap := mapBA_hcap h
  hassign := mapBA_hassign h
  hy_bin := mapBA_hy_bin
  hx_bin := mapBA_hx_bin

private lemma mapBA_obj (q : P22.b.Params) (v : P22.b.Vars q)
    (h : P22.b.Feasible q v) :
    P22.b.obj q v = P22.a.obj (paramMap q) (mapBA q v) := by
  unfold P22.b.obj P22.a.obj
  have hcoe : Fintype.card (CopiesSub q v) = (Copies q v).card := by
    unfold CopiesSub; exact Fintype.card_coe _
  have hcardNat : (univ.filter (fun i : Fin (nItems q) => (mapBA q v).y i = 1)).card
      = ∑ a ∈ P22.b.J q, (v.x a).toNat := by
    rw [mapBA_used_eq_image, Finset.card_image_of_injective _ (binOf_injective h),
      Finset.card_univ, hcoe, copies_card_eq]
  have hcast := natCast_sum_toNat_eq (P22.b.J q) v.x h.hx_nn
  have hY : ∑ i : Fin (nItems q), (mapBA q v).y i = ∑ a ∈ P22.b.J q, v.x a := by
    have h1 : ∑ i : Fin (nItems q), (mapBA q v).y i
        = ((univ.filter (fun i : Fin (nItems q) => (mapBA q v).y i = 1)).card : ℤ) := by
      rw [Finset.card_filter]
      push_cast
      refine Finset.sum_congr rfl fun i _ => ?_
      rcases mapBA_hy_bin (q := q) (v := v) i with hy0 | hy1
      · simp [hy0]
      · simp [hy1]
    rw [h1, hcardNat, hcast]
  calc ∑ a ∈ P22.b.J q, (v.x a : ℝ)
      = ((∑ a ∈ P22.b.J q, v.x a : ℤ) : ℝ) := by push_cast; ring
    _ = ((∑ i : Fin (nItems q), (mapBA q v).y i : ℤ) : ℝ) := by rw [hY]
    _ = ∑ i : Fin (nItems q), ((mapBA q v).y i : ℝ) := by push_cast; ring

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

noncomputable def bAReformulation : MILPReformulation P22.b.formulation P22.a.formulation where
  paramMap    := paramMap
  fwd         := mapBA
  bwd         := mapAB
  fwd_feas    := mapBA_feas
  bwd_feas    := mapAB_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj     := fun q x h => (mapBA_obj q x h).symm
  bwd_obj     := fun q x' h => (mapAB_obj q x' h).symm

end P22
