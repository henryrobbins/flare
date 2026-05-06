/-
# ORLib: Operations Research Library

A collection of reusable formalizations supporting the EquivaProof
dataset of MILP reformulation proofs.

## Flow decomposition (this file)

The central object is an abstract flow-decomposition theorem:

> Given a finite directed graph `(V, E)` with rank witness, source set
> `S` and sink set `B`, and a non-negative flow `F : V → V → α`
> satisfying conservation at interior nodes (no inflow at `S`, no
> outflow at `B`, balance elsewhere), there exists a list of vertex
> sequences (each an `S → B` path in `E`) together with positive
> weights such that the weighted indicator sums recover `F` on every
> edge.

The current file develops the *prelude*: definitions and provable
basic lemmas. The statement of the main theorem is recorded as
`Statement_flow_decomposition`. The proof itself is the goal of a
follow-up commit.

The abstraction is intended to be applied by

* `dataset/reformulations/p20/a_b.lean` with `α = ℝ`,
  `V = Fin pa.nN`, edges from the binary matrix `E`, sources from
  `pa.S`, sinks from `pa.B`.
* `dataset/reformulations/p13/a_b.lean` with `α = ℤ`,
  `V = Fin nA × Fin nT` (time-expanded), edges combining travel arcs
  and implicit stay arcs, sources `{(a, 0)}`, sinks `{(a, nT-1)}`.
  Each flight corresponds to a unit-weight path; the "every weight
  equals 1" specialization follows from the general statement together
  with integrality of the input flow.
-/

import Mathlib.Tactic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.Order.Ring.Defs
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.List.Chain
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open scoped Classical
open BigOperators Finset

set_option linter.unusedSectionVars false

namespace ORLib
namespace FlowDecomp

/-! ## Setup -/

section Prelude

variable {V : Type*} [Fintype V] [DecidableEq V]
variable {α : Type*} [Ring α] [LinearOrder α] [IsStrictOrderedRing α]

/-- Weak feasibility of a flow `F` on a directed graph `(V, E)` with
source set `S` and sink set `B`:

* non-negative on every pair,
* zero off the edge set,
* zero inflow at every source,
* zero outflow at every sink,
* balance (inflow = outflow) at every interior node.

This is the predicate that survives bottleneck subtraction during the
flow-decomposition induction. -/
structure WeakFeasible (E : V → V → Prop) (S B : Finset V)
    (F : V → V → α) : Prop where
  hNN          : ∀ i j, 0 ≤ F i j
  hOffEdge     : ∀ i j, ¬ E i j → F i j = 0
  hNoInflowS   : ∀ s ∈ S, ∀ i, F i s = 0
  hNoOutflowB  : ∀ b ∈ B, ∀ j, F b j = 0
  hConserv     : ∀ v, v ∉ S → v ∉ B → ∑ i, F i v = ∑ j, F v j

/-! ## Positive-flow support -/

/-- The support of a flow: edges carrying strictly positive flow. -/
noncomputable def posSupport (E : V → V → Prop) (F : V → V → α) :
    Finset (V × V) :=
  (univ : Finset (V × V)).filter (fun p => E p.1 p.2 ∧ 0 < F p.1 p.2)

lemma mem_posSupport {E : V → V → Prop} {F : V → V → α} {i j : V} :
    (i, j) ∈ posSupport E F ↔ E i j ∧ 0 < F i j := by
  simp [posSupport]

/-- If the support of `F` is empty then `F` is zero on every edge. -/
lemma flow_zero_on_edges_of_support_empty
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) (hsupp : posSupport E F = ∅) :
    ∀ i j, E i j → F i j = 0 := by
  intro i j hE
  by_contra hne
  have hpos : 0 < F i j := lt_of_le_of_ne (h.hNN i j) (Ne.symm hne)
  have hmem : (i, j) ∈ posSupport E F := by
    rw [mem_posSupport]; exact ⟨hE, hpos⟩
  rw [hsupp] at hmem
  exact absurd hmem (by simp)

/-- Combined with `hOffEdge`, an empty support means `F` is identically
zero. -/
lemma flow_zero_of_support_empty
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) (hsupp : posSupport E F = ∅) :
    ∀ i j, F i j = 0 := by
  intro i j
  by_cases hE : E i j
  · exact flow_zero_on_edges_of_support_empty h hsupp i j hE
  · exact h.hOffEdge i j hE

/-! ## Inflow and outflow -/

/-- Total inflow at `v`. -/
def inflow (F : V → V → α) (v : V) : α := ∑ i, F i v

/-- Total outflow at `v`. -/
def outflow (F : V → V → α) (v : V) : α := ∑ j, F v j

lemma inflow_nonneg
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) (v : V) : 0 ≤ inflow F v :=
  Finset.sum_nonneg (fun i _ => h.hNN i v)

lemma outflow_nonneg
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) (v : V) : 0 ≤ outflow F v :=
  Finset.sum_nonneg (fun j _ => h.hNN v j)

/-- A node with positive outflow cannot lie in the sink set. -/
lemma not_sink_of_pos_outflow
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) {v : V}
    (hpos : 0 < outflow F v) : v ∉ B := by
  intro hmem
  have hzero : outflow F v = 0 := by
    unfold outflow
    apply Finset.sum_eq_zero
    intro j _
    exact h.hNoOutflowB v hmem j
  exact hpos.ne' hzero

/-- A node with positive inflow cannot lie in the source set. -/
lemma not_source_of_pos_inflow
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) {v : V}
    (hpos : 0 < inflow F v) : v ∉ S := by
  intro hmem
  have hzero : inflow F v = 0 := by
    unfold inflow
    apply Finset.sum_eq_zero
    intro i _
    exact h.hNoInflowS v hmem i
  exact hpos.ne' hzero

/-- Positive outflow yields a positive out-edge. -/
lemma exists_pos_out_edge_of_pos_outflow
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) {v : V}
    (hpos : 0 < outflow F v) :
    ∃ j, E v j ∧ 0 < F v j := by
  by_contra hne
  push_neg at hne
  have hzero : outflow F v = 0 := by
    unfold outflow
    apply Finset.sum_eq_zero
    intro j _
    by_cases hE : E v j
    · have hF0 : F v j ≤ 0 := hne j hE
      exact le_antisymm hF0 (h.hNN v j)
    · exact h.hOffEdge v j hE
  exact hpos.ne' hzero

/-- Positive inflow yields a positive in-edge. -/
lemma exists_pos_in_edge_of_pos_inflow
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) {v : V}
    (hpos : 0 < inflow F v) :
    ∃ i, E i v ∧ 0 < F i v := by
  by_contra hne
  push_neg at hne
  have hzero : inflow F v = 0 := by
    unfold inflow
    apply Finset.sum_eq_zero
    intro i _
    by_cases hE : E i v
    · have hF0 : F i v ≤ 0 := hne i hE
      exact le_antisymm hF0 (h.hNN i v)
    · exact h.hOffEdge i v hE
  exact hpos.ne' hzero

/-- A positive out-edge witnesses positive outflow. -/
lemma pos_outflow_of_pos_out_edge
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) {v j : V}
    (hpos : 0 < F v j) :
    0 < outflow F v := by
  refine Finset.sum_pos' (fun k _ => h.hNN v k) ⟨j, mem_univ j, hpos⟩

/-- A positive in-edge witnesses positive inflow. -/
lemma pos_inflow_of_pos_in_edge
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) {i v : V}
    (hpos : 0 < F i v) :
    0 < inflow F v := by
  refine Finset.sum_pos' (fun k _ => h.hNN k v) ⟨i, mem_univ i, hpos⟩

/-- At an interior node, positive outflow forces positive inflow. -/
lemma pos_inflow_of_pos_outflow_interior
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) {v : V}
    (hS : v ∉ S) (hB : v ∉ B)
    (hpos : 0 < outflow F v) :
    0 < inflow F v := by
  have heq : ∑ i, F i v = ∑ j, F v j := h.hConserv v hS hB
  show 0 < ∑ i, F i v
  rw [heq]
  exact hpos

/-- At an interior node, positive inflow forces positive outflow. -/
lemma pos_outflow_of_pos_inflow_interior
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) {v : V}
    (hS : v ∉ S) (hB : v ∉ B)
    (hpos : 0 < inflow F v) :
    0 < outflow F v := by
  have heq : ∑ i, F i v = ∑ j, F v j := h.hConserv v hS hB
  show 0 < ∑ j, F v j
  rw [← heq]
  exact hpos

/-! ## Paths in the graph -/

/-- A *graph path* in `E`: a non-empty, nodup list of vertices with
consecutive pairs forming edges of `E`. -/
def IsGraphPath (E : V → V → Prop) (L : List V) : Prop :=
  L ≠ [] ∧ L.Nodup ∧ L.IsChain E

/-- An `S → B` graph path: a graph path whose head lies in `S` and
whose last vertex lies in `B`. -/
def IsSBPath (E : V → V → Prop) (S B : Finset V) (L : List V) : Prop :=
  ∃ h : L ≠ [], L.Nodup ∧ L.IsChain E ∧ L.head h ∈ S ∧ L.getLast h ∈ B

/-- The directed pair `(i, j)` appears consecutively in `L`. -/
def IsConsec (L : List V) (i j : V) : Prop :=
  ∃ pre suf : List V, L = pre ++ i :: j :: suf

/-- Indicator (in `α`) for whether `(i, j)` is a consecutive pair of
`L`. -/
noncomputable def consecIndicator (L : List V) (i j : V) : α :=
  if IsConsec L i j then (1 : α) else (0 : α)

end Prelude

/-! ## Path bookkeeping helpers

Generic list lemmas about consecutive pairs `IsConsec` and the
indicator `consecIndicator`. These are the building blocks used to
reason about an extracted walk during the flow-decomposition
induction. They are stated polymorphically over the vertex type. -/

section PathBookkeeping

variable {V : Type*} [Fintype V] [DecidableEq V]
variable {α : Type*} [Ring α] [LinearOrder α] [IsStrictOrderedRing α]

lemma consec_left_mem {L : List V} {u w : V}
    (h : IsConsec L u w) : u ∈ L := by
  obtain ⟨pre, suf, rfl⟩ := h; simp

lemma consec_right_mem {L : List V} {u w : V}
    (h : IsConsec L u w) : w ∈ L := by
  obtain ⟨pre, suf, rfl⟩ := h; simp

/-- The chain predicate forces the relation to hold on every consecutive pair. -/
lemma consec_chain {R : V → V → Prop} {L : List V} {u w : V}
    (hch : L.IsChain R) (h : IsConsec L u w) : R u w := by
  obtain ⟨pre, suf, rfl⟩ := h
  rw [List.isChain_append] at hch
  rcases hch with ⟨_, hch2, _⟩
  rw [List.isChain_cons_cons] at hch2
  exact hch2.1

/-- In a list `pre ++ u :: w :: suf`, the position of `u` is
`pre.length`, and the position of `w` is `pre.length + 1`. We use this
to derive uniqueness facts. -/
lemma getElem?_consec_left (pre suf : List V) (u w : V) :
    (pre ++ u :: w :: suf)[pre.length]? = some u := by
  have hL : pre ++ u :: w :: suf = pre ++ [u] ++ (w :: suf) := by simp
  rw [hL]
  rw [List.getElem?_append_left (by simp)]
  rw [List.getElem?_append_right (by simp)]
  simp

lemma getElem?_consec_right (pre suf : List V) (u w : V) :
    (pre ++ u :: w :: suf)[pre.length + 1]? = some w := by
  have hL : pre ++ u :: w :: suf = (pre ++ [u]) ++ (w :: suf) := by simp
  rw [hL]
  rw [List.getElem?_append_right (by simp)]
  simp

/-- Helper: in a `Nodup` list, an element occurs at a unique index. -/
lemma getElem?_eq_some_iff_unique_of_nodup {L : List V}
    (hnd : L.Nodup) {u : V} {n : ℕ}
    (hn : L[n]? = some u) {m : ℕ} (hm : L[m]? = some u) : n = m := by
  by_contra hne
  rw [List.getElem?_eq_some_iff] at hn hm
  obtain ⟨hnL, h1⟩ := hn
  obtain ⟨hmL, h2⟩ := hm
  exact hne (List.Nodup.getElem_inj_iff hnd |>.mp (h1.trans h2.symm))

lemma consec_pred_unique {L : List V} (hnd : L.Nodup)
    {u₁ u₂ w : V} (h₁ : IsConsec L u₁ w) (h₂ : IsConsec L u₂ w) :
    u₁ = u₂ := by
  obtain ⟨p₁, s₁, hL₁⟩ := h₁
  obtain ⟨p₂, s₂, hL₂⟩ := h₂
  have hw1 : L[p₁.length + 1]? = some w := by
    rw [hL₁]; exact getElem?_consec_right _ _ _ _
  have hw2 : L[p₂.length + 1]? = some w := by
    rw [hL₂]; exact getElem?_consec_right _ _ _ _
  have heq : p₁.length + 1 = p₂.length + 1 :=
    getElem?_eq_some_iff_unique_of_nodup hnd hw1 hw2
  have hpeq : p₁.length = p₂.length := by omega
  have hu1 : L[p₁.length]? = some u₁ := by
    rw [hL₁]; exact getElem?_consec_left _ _ _ _
  have hu2 : L[p₂.length]? = some u₂ := by
    rw [hL₂]; exact getElem?_consec_left _ _ _ _
  rw [hpeq] at hu1
  rw [hu1] at hu2
  exact (Option.some.inj hu2)

lemma consec_succ_unique {L : List V} (hnd : L.Nodup)
    {u w₁ w₂ : V} (h₁ : IsConsec L u w₁) (h₂ : IsConsec L u w₂) :
    w₁ = w₂ := by
  obtain ⟨p₁, s₁, hL₁⟩ := h₁
  obtain ⟨p₂, s₂, hL₂⟩ := h₂
  have hu1 : L[p₁.length]? = some u := by
    rw [hL₁]; exact getElem?_consec_left _ _ _ _
  have hu2 : L[p₂.length]? = some u := by
    rw [hL₂]; exact getElem?_consec_left _ _ _ _
  have hpeq : p₁.length = p₂.length :=
    getElem?_eq_some_iff_unique_of_nodup hnd hu1 hu2
  have hw1 : L[p₁.length + 1]? = some w₁ := by
    rw [hL₁]; exact getElem?_consec_right _ _ _ _
  have hw2 : L[p₂.length + 1]? = some w₂ := by
    rw [hL₂]; exact getElem?_consec_right _ _ _ _
  rw [hpeq] at hw1
  rw [hw1] at hw2
  exact (Option.some.inj hw2)

/-- The head of a `Nodup` list has no predecessor consecutive to it. -/
lemma consec_no_pred_head {a : V} {as : List V}
    (hnd : (a :: as).Nodup) : ∀ u, ¬ IsConsec (a :: as) u a := by
  intro u ⟨pre, suf, hL⟩
  rw [List.nodup_cons] at hnd
  have h0 : (a :: as)[0]? = some a := by simp
  have h1 : (a :: as)[pre.length + 1]? = some a := by
    rw [hL]; exact getElem?_consec_right _ _ _ _
  have hnd' : (a :: as).Nodup := by rw [List.nodup_cons]; exact hnd
  have heq : 0 = pre.length + 1 :=
    getElem?_eq_some_iff_unique_of_nodup hnd' h0 h1
  omega

/-- The last element of a `Nodup` list has no successor consecutive
to it. -/
lemma consec_no_succ_last {L : List V} (hne : L ≠ [])
    (hnd : L.Nodup) : ∀ w, ¬ IsConsec L (L.getLast hne) w := by
  intro w ⟨pre, suf, hL⟩
  set u := L.getLast hne with hu_def
  have hLlen : L.length = pre.length + 2 + suf.length := by
    rw [hL]; simp; ring
  have h_last : L[L.length - 1]? = some u := by
    rw [hu_def]
    have := List.getLast?_eq_getElem? (l := L)
    rw [List.getLast?_eq_some_getLast hne] at this
    exact this.symm
  have h_pre : L[pre.length]? = some u := by
    rw [hL]; exact getElem?_consec_left _ _ _ _
  have heq : L.length - 1 = pre.length :=
    getElem?_eq_some_iff_unique_of_nodup hnd h_last h_pre
  omega

/-- If two consecutive elements are at positions `n` and `n+1` of
`L`, then they form an `IsConsec` pair. -/
lemma consec_at_pos {L : List V} {a b : V} {n : ℕ}
    (hn : L[n]? = some a) (hsn : L[n + 1]? = some b) : IsConsec L a b := by
  rw [List.getElem?_eq_some_iff] at hn hsn
  obtain ⟨hnL, ha⟩ := hn
  obtain ⟨hsnL, hb⟩ := hsn
  refine ⟨L.take n, L.drop (n + 2), ?_⟩
  have h1 : L = L.take n ++ L.drop n := (List.take_append_drop n L).symm
  have h2 : L.drop n = a :: L.drop (n + 1) := by
    rw [← List.getElem_cons_drop hnL, ha]
  have h3 : L.drop (n + 1) = b :: L.drop (n + 2) := by
    rw [← List.getElem_cons_drop hsnL, hb]
  calc L = L.take n ++ L.drop n := h1
    _ = L.take n ++ a :: L.drop (n + 1) := by rw [h2]
    _ = L.take n ++ a :: b :: L.drop (n + 2) := by rw [h3]

/-- If `v ∈ L` and `v ≠ L.head`, then `v` has a predecessor in `L`. -/
lemma exists_consec_pred {L : List V} (hne : L ≠ [])
    {v : V} (hv : v ∈ L) (hvhead : v ≠ L.head hne) :
    ∃ u, IsConsec L u v := by
  obtain ⟨n, hnL, hn⟩ := List.mem_iff_getElem.mp hv
  rcases n with _ | n
  · exfalso
    apply hvhead
    rw [← hn]
    rcases L with _ | ⟨a, as⟩
    · exact absurd rfl hne
    · simp
  · have hnL' : n < L.length := Nat.lt_of_succ_lt hnL
    refine ⟨L[n], ?_⟩
    apply consec_at_pos (n := n)
    · rw [List.getElem?_eq_some_iff]; exact ⟨hnL', rfl⟩
    · rw [List.getElem?_eq_some_iff]; exact ⟨hnL, hn⟩

/-- If `v ∈ L` and `v ≠ L.getLast`, then `v` has a successor in `L`. -/
lemma exists_consec_succ {L : List V} (hne : L ≠ [])
    {v : V} (hv : v ∈ L) (hvlast : v ≠ L.getLast hne) :
    ∃ w, IsConsec L v w := by
  obtain ⟨n, hnL, hn⟩ := List.mem_iff_getElem.mp hv
  by_cases hnlast : n + 1 < L.length
  · refine ⟨L[n + 1], ?_⟩
    apply consec_at_pos (n := n)
    · rw [List.getElem?_eq_some_iff]; exact ⟨hnL, hn⟩
    · rw [List.getElem?_eq_some_iff]; exact ⟨hnlast, rfl⟩
  · push_neg at hnlast
    exfalso
    apply hvlast
    have hneq : n = L.length - 1 := by omega
    have hgl : L.getLast hne = L[L.length - 1]'(by
      have : 0 < L.length := List.length_pos_iff.mpr hne
      omega) := by
      have hL := List.getLast?_eq_some_getLast hne
      rw [List.getLast?_eq_getElem?] at hL
      rw [List.getElem?_eq_some_iff] at hL
      obtain ⟨_, hg⟩ := hL
      exact hg.symm
    rw [hgl, ← hn]
    congr

/-! ### Indicator and rank -/

/-- Position of `v` in `L`. -/
noncomputable def pathRank (L : List V) (v : V) : ℕ :=
  L.idxOf v

lemma consecIndicator_eq_one_iff (L : List V) (u w : V) :
    consecIndicator (α := α) L u w = 1 ↔ IsConsec L u w := by
  classical
  unfold consecIndicator
  by_cases h : IsConsec L u w
  · simp [h]
  · simp [h]

lemma consecIndicator_eq_zero_iff (L : List V) (u w : V) :
    consecIndicator (α := α) L u w = 0 ↔ ¬ IsConsec L u w := by
  classical
  unfold consecIndicator
  by_cases h : IsConsec L u w
  · simp [h]
  · simp [h]

/-- `consecIndicator` is binary. -/
lemma consecIndicator_binary (L : List V) (u w : V) :
    consecIndicator (α := α) L u w = 0 ∨
      consecIndicator (α := α) L u w = 1 := by
  classical
  unfold consecIndicator
  by_cases h : IsConsec L u w
  · right; simp [h]
  · left; simp [h]

/-- Sum of `consecIndicator L · v` over predecessors equals `1` iff
`v` has a predecessor in `L`. -/
lemma sum_consecIndicator_in_eq (L : List V) (hnd : L.Nodup) (v : V) :
    ∑ i : V, consecIndicator (α := α) L i v =
      (@ite α (∃ u, IsConsec L u v) (Classical.dec _) 1 0) := by
  classical
  by_cases h : ∃ u, IsConsec L u v
  · obtain ⟨u, hu⟩ := h
    rw [if_pos (⟨u, hu⟩ : ∃ u, IsConsec L u v)]
    have hfilter : (Finset.univ : Finset V).filter
        (fun i => IsConsec L i v) = {u} := by
      ext x
      simp only [Finset.mem_filter, Finset.mem_univ, true_and,
        Finset.mem_singleton]
      exact ⟨fun hx => consec_pred_unique hnd hx hu, fun hx => hx ▸ hu⟩
    have heq : ∑ i : V, consecIndicator (α := α) L i v
        = ∑ i ∈ (Finset.univ : Finset V).filter (fun i => IsConsec L i v),
            (1 : α) := by
      unfold consecIndicator
      rw [← Finset.sum_filter]
    rw [heq, hfilter]; simp
  · rw [if_neg h]
    push_neg at h
    have hzero : ∀ i : V, consecIndicator (α := α) L i v = 0 := fun i => by
      unfold consecIndicator; simp [h i]
    simp [hzero]

lemma sum_consecIndicator_out_eq (L : List V) (hnd : L.Nodup) (v : V) :
    ∑ j : V, consecIndicator (α := α) L v j =
      (@ite α (∃ w, IsConsec L v w) (Classical.dec _) 1 0) := by
  classical
  by_cases h : ∃ w, IsConsec L v w
  · obtain ⟨w, hw⟩ := h
    rw [if_pos (⟨w, hw⟩ : ∃ w, IsConsec L v w)]
    have hfilter : (Finset.univ : Finset V).filter
        (fun j => IsConsec L v j) = {w} := by
      ext x
      simp only [Finset.mem_filter, Finset.mem_univ, true_and,
        Finset.mem_singleton]
      exact ⟨fun hx => consec_succ_unique hnd hx hw, fun hx => hx ▸ hw⟩
    have heq : ∑ j : V, consecIndicator (α := α) L v j
        = ∑ j ∈ (Finset.univ : Finset V).filter (fun j => IsConsec L v j),
            (1 : α) := by
      unfold consecIndicator
      rw [← Finset.sum_filter]
    rw [heq, hfilter]; simp
  · rw [if_neg h]
    push_neg at h
    have hzero : ∀ j : V, consecIndicator (α := α) L v j = 0 := fun j => by
      unfold consecIndicator; simp [h j]
    simp [hzero]

/-- In-degree at most 1. -/
lemma sum_consecIndicator_in_le_one (L : List V) (hnd : L.Nodup) (v : V) :
    ∑ i : V, consecIndicator (α := α) L i v ≤ 1 := by
  rw [sum_consecIndicator_in_eq L hnd v]
  by_cases h : ∃ u, IsConsec L u v <;> simp [h]

lemma sum_consecIndicator_out_le_one (L : List V) (hnd : L.Nodup) (v : V) :
    ∑ j : V, consecIndicator (α := α) L v j ≤ 1 := by
  rw [sum_consecIndicator_out_eq L hnd v]
  by_cases h : ∃ w, IsConsec L v w <;> simp [h]

/-- `IsConsec` implies the rank (= `idxOf`) increases by 1. -/
lemma pathRank_consec (L : List V) (hnd : L.Nodup)
    {u w : V} (hc : IsConsec L u w) :
    pathRank L w = pathRank L u + 1 := by
  obtain ⟨pre, suf, hL⟩ := hc
  unfold pathRank
  have hu_pos : L[pre.length]? = some u := by
    rw [hL]; exact getElem?_consec_left _ _ _ _
  have hw_pos : L[pre.length + 1]? = some w := by
    rw [hL]; exact getElem?_consec_right _ _ _ _
  rw [List.getElem?_eq_some_iff] at hu_pos hw_pos
  obtain ⟨huL, hu⟩ := hu_pos
  obtain ⟨hwL, hw⟩ := hw_pos
  have hidx_u : L.idxOf u = pre.length := by
    rw [← hu]; exact List.Nodup.idxOf_getElem hnd _ huL
  have hidx_w : L.idxOf w = pre.length + 1 := by
    rw [← hw]; exact List.Nodup.idxOf_getElem hnd _ hwL
  omega

end PathBookkeeping

/-! ## Walks in the positive-flow support

Given a `WeakFeasible` flow `F` and a *rank witness* on its positive
support — i.e., a function `rank : V → ℕ` with `rank i < rank j`
whenever `E i j ∧ 0 < F i j` — we can extract, through any positive
edge `(i, j)`, an `S → B` path whose consecutive pairs are all in the
positive-flow support.

The construction is by two well-founded recursions:

* `forwardWalk` extends `j` rightward to a sink in `B`, using
  `fwdMeasure := maxRank - rank` as termination measure;
* `backwardWalk` extends `i` leftward to a source in `S`, using
  `rank` itself as the measure (stored in *reverse traversal order*).

The headline lemma is `exists_SBPath_through_pos_edge`. -/

section Walks

variable {V : Type*} [Fintype V] [DecidableEq V]
variable {α : Type*} [Ring α] [LinearOrder α] [IsStrictOrderedRing α]

/-- Maximum rank value over all nodes (plus 1). Used as a strict upper
bound for the rank-decreasing well-founded recursion. -/
noncomputable def maxRank (rank : V → ℕ) : ℕ :=
  (Finset.univ : Finset V).sup rank + 1

lemma rank_lt_maxRank (rank : V → ℕ) (i : V) :
    rank i < maxRank (V := V) rank := by
  unfold maxRank
  have : rank i ≤ (Finset.univ : Finset V).sup rank :=
    Finset.le_sup (f := rank) (Finset.mem_univ i)
  omega

/-- "Forward measure": `maxRank - rank v`. Strictly decreases when we
step forward along a positive-flow edge. -/
noncomputable def fwdMeasure (rank : V → ℕ) (i : V) : ℕ :=
  maxRank (V := V) rank - rank i

lemma fwdMeasure_lt
    (rank : V → ℕ) (i j : V) (hr : rank i < rank j) :
    fwdMeasure (V := V) rank j < fwdMeasure (V := V) rank i := by
  unfold fwdMeasure
  have hi := rank_lt_maxRank (V := V) rank i
  have hj := rank_lt_maxRank (V := V) rank j
  omega

/-- The edge predicate carried along walks: a positive-flow edge in
the support of `F`. -/
def WalkEdge (E : V → V → Prop) (F : V → V → α) (u w : V) : Prop :=
  E u w ∧ 0 < F u w

/-- In a list with pairwise strictly-increasing `rank`, every
element's rank is ≤ that of the last element. -/
lemma rank_le_last_of_pairwise {β : Type*} (rank : β → ℕ)
    (L : List β) (hne : L ≠ [])
    (hp : L.Pairwise (fun u w => rank u < rank w)) :
    ∀ x ∈ L, rank x ≤ rank (L.getLast hne) := by
  induction L with
  | nil => exact absurd rfl hne
  | cons a as ih =>
    by_cases h : as = []
    · subst h
      intro x hxmem
      simp at hxmem
      subst hxmem
      simp
    · intro x hxmem
      rw [List.getLast_cons h]
      rw [List.pairwise_cons] at hp
      rcases List.mem_cons.mp hxmem with hxa | hxas
      · subst hxa
        exact (hp.1 _ (List.getLast_mem h)).le
      · exact ih h hp.2 x hxas

/-- The bundled invariant for a forward walk starting at `i`. -/
def IsForwardWalk (E : V → V → Prop) (B : Finset V) (F : V → V → α)
    (rank : V → ℕ) (i : V) (L : List V) : Prop :=
  L ≠ [] ∧
  L.head? = some i ∧
  (∀ hne : L ≠ [], L.getLast hne ∈ B) ∧
  L.IsChain (WalkEdge E F) ∧
  L.Pairwise (fun u w => rank u < rank w)

/-- The bundled invariant for a *reversed* backward walk ending at
`j`. The list is stored in reverse-traversal order: `head = j`,
`last = source`, and consecutive `(u, w)` in the list satisfy
`WalkEdge w u`. -/
def IsBackwardWalk (E : V → V → Prop) (S : Finset V) (F : V → V → α)
    (rank : V → ℕ) (j : V) (L : List V) : Prop :=
  L ≠ [] ∧
  L.head? = some j ∧
  (∀ hne : L ≠ [], L.getLast hne ∈ S) ∧
  L.IsChain (fun u w => WalkEdge E F w u) ∧
  L.Pairwise (fun u w => rank w < rank u)

/-- **Forward walk.** Given a rank witness and a starting node `i`
that is either a sink or has positive outflow, returns a list
satisfying `IsForwardWalk`. Well-founded via `fwdMeasure`. -/
noncomputable def forwardWalk
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F)
    (rank : V → ℕ)
    (hRank : ∀ i j : V, E i j → 0 < F i j → rank i < rank j)
    (i : V)
    (hi : i ∈ B ∨ 0 < outflow F i) :
    { L : List V // IsForwardWalk E B F rank i L } :=
  if hB : i ∈ B then
    ⟨[i], by
      refine ⟨List.cons_ne_nil _ _, rfl, ?_, List.isChain_singleton _,
        List.pairwise_singleton _ _⟩
      intro _; simpa using hB⟩
  else by
    have hout : 0 < outflow F i := by
      cases hi with
      | inl hB' => exact absurd hB' hB
      | inr h'  => exact h'
    have hex : ∃ j : V, E i j ∧ 0 < F i j :=
      exists_pos_out_edge_of_pos_outflow h hout
    let j : V := hex.choose
    have hEij : E i j := hex.choose_spec.1
    have hFij : 0 < F i j := hex.choose_spec.2
    have hr : rank i < rank j := hRank i j hEij hFij
    have hdec : fwdMeasure (V := V) rank j < fwdMeasure (V := V) rank i :=
      fwdMeasure_lt (V := V) rank i j hr
    have hjnext : j ∈ B ∨ 0 < outflow F j := by
      by_cases hjB : j ∈ B
      · exact Or.inl hjB
      · have hjin : 0 < inflow F j := pos_inflow_of_pos_in_edge h hFij
        have hjS : j ∉ S := not_source_of_pos_inflow h hjin
        exact Or.inr (pos_outflow_of_pos_inflow_interior h hjS hjB hjin)
    let rest := forwardWalk h rank hRank j hjnext
    refine ⟨i :: rest.val, ?_⟩
    obtain ⟨hne_rest, hhead_rest, hlast_rest, hchain_rest, hpair_rest⟩ :=
      rest.property
    refine ⟨List.cons_ne_nil _ _, rfl, ?_, ?_, ?_⟩
    · intro _
      have hgl : (i :: rest.val).getLast (List.cons_ne_nil _ _) =
             rest.val.getLast hne_rest :=
        List.getLast_cons hne_rest
      rw [hgl]
      exact hlast_rest hne_rest
    · rw [List.isChain_cons]
      refine ⟨?_, hchain_rest⟩
      intro y hy
      have hy' : rest.val.head? = some y := hy
      rw [hhead_rest] at hy'
      have hyj : y = j := (Option.some.inj hy').symm
      subst hyj
      exact ⟨hEij, hFij⟩
    · rw [List.pairwise_cons]
      refine ⟨?_, hpair_rest⟩
      intro y hymem
      have hjy : rank j ≤ rank y := by
        rcases hL : rest.val with _ | ⟨a, as⟩
        · exact absurd hL hne_rest
        · have ha : a = j := by
            rw [hL] at hhead_rest
            simpa [List.head?] using hhead_rest
          subst ha
          rw [hL] at hymem
          rcases List.mem_cons.mp hymem with rfl | hyas
          · exact le_refl _
          · have hp : rest.val.Pairwise (fun u w => rank u < rank w) :=
              hpair_rest
            rw [hL, List.pairwise_cons] at hp
            exact (hp.1 _ hyas).le
      exact lt_of_lt_of_le hr hjy
termination_by fwdMeasure (V := V) rank i

/-- **Backward walk (reversed orientation).** Symmetric to
`forwardWalk`. Stored in reverse traversal order: head = `j`, last is
some source. Well-founded via `rank j`. -/
noncomputable def backwardWalk
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F)
    (rank : V → ℕ)
    (hRank : ∀ i j : V, E i j → 0 < F i j → rank i < rank j)
    (j : V)
    (hj : j ∈ S ∨ 0 < inflow F j) :
    { L : List V // IsBackwardWalk E S F rank j L } :=
  if hS : j ∈ S then
    ⟨[j], by
      refine ⟨List.cons_ne_nil _ _, rfl, ?_, List.isChain_singleton _,
        List.pairwise_singleton _ _⟩
      intro _; simpa using hS⟩
  else by
    have hin : 0 < inflow F j := by
      cases hj with
      | inl hS' => exact absurd hS' hS
      | inr h'  => exact h'
    have hex : ∃ i : V, E i j ∧ 0 < F i j :=
      exists_pos_in_edge_of_pos_inflow h hin
    let i : V := hex.choose
    have hEij : E i j := hex.choose_spec.1
    have hFij : 0 < F i j := hex.choose_spec.2
    have hr : rank i < rank j := hRank i j hEij hFij
    have hinext : i ∈ S ∨ 0 < inflow F i := by
      by_cases hiS : i ∈ S
      · exact Or.inl hiS
      · have hiout : 0 < outflow F i := pos_outflow_of_pos_out_edge h hFij
        have hiB : i ∉ B := not_sink_of_pos_outflow h hiout
        exact Or.inr (pos_inflow_of_pos_outflow_interior h hiS hiB hiout)
    let rest := backwardWalk h rank hRank i hinext
    refine ⟨j :: rest.val, ?_⟩
    obtain ⟨hne_rest, hhead_rest, hlast_rest, hchain_rest, hpair_rest⟩ :=
      rest.property
    refine ⟨List.cons_ne_nil _ _, rfl, ?_, ?_, ?_⟩
    · intro _
      have hgl : (j :: rest.val).getLast (List.cons_ne_nil _ _) =
             rest.val.getLast hne_rest :=
        List.getLast_cons hne_rest
      rw [hgl]
      exact hlast_rest hne_rest
    · rw [List.isChain_cons]
      refine ⟨?_, hchain_rest⟩
      intro y hy
      have hy' : rest.val.head? = some y := hy
      rw [hhead_rest] at hy'
      have hyi : y = i := (Option.some.inj hy').symm
      subst hyi
      exact ⟨hEij, hFij⟩
    · rw [List.pairwise_cons]
      refine ⟨?_, hpair_rest⟩
      intro y hymem
      have hyi : rank y ≤ rank i := by
        rcases hL : rest.val with _ | ⟨a, as⟩
        · exact absurd hL hne_rest
        · have ha : a = i := by
            rw [hL] at hhead_rest
            simpa [List.head?] using hhead_rest
          subst ha
          rw [hL] at hymem
          rcases List.mem_cons.mp hymem with rfl | hyas
          · exact le_refl _
          · have hp : rest.val.Pairwise (fun u w => rank w < rank u) :=
              hpair_rest
            rw [hL, List.pairwise_cons] at hp
            exact (hp.1 _ hyas).le
      exact lt_of_le_of_lt hyi hr
termination_by rank j

/-- For a positive-flow edge `(i, j)`, the source endpoint `i` is
either a source or has positive inflow. -/
lemma pos_edge_source_is_source_or_pos_inflow
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) {i j : V}
    (hE : E i j) (hF : 0 < F i j) :
    i ∈ S ∨ 0 < inflow F i := by
  classical
  by_cases hiS : i ∈ S
  · exact Or.inl hiS
  · have hiout : 0 < outflow F i := pos_outflow_of_pos_out_edge h hF
    have hiB : i ∉ B := not_sink_of_pos_outflow h hiout
    exact Or.inr (pos_inflow_of_pos_outflow_interior h hiS hiB hiout)

/-- For a positive-flow edge `(i, j)`, the destination endpoint `j`
is either a sink or has positive outflow. -/
lemma pos_edge_dest_is_sink_or_pos_outflow
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F) {i j : V}
    (hE : E i j) (hF : 0 < F i j) :
    j ∈ B ∨ 0 < outflow F j := by
  classical
  by_cases hjB : j ∈ B
  · exact Or.inl hjB
  · have hjin : 0 < inflow F j := pos_inflow_of_pos_in_edge h hF
    have hjS : j ∉ S := not_source_of_pos_inflow h hjin
    exact Or.inr (pos_outflow_of_pos_inflow_interior h hjS hjB hjin)

/-- **Headline lemma.** Given a positive-flow edge `(i, j)`, there is
an `S → B` path through `(i, j)` whose consecutive pairs are all in
the positive-flow support. -/
lemma exists_SBPath_through_pos_edge
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F)
    (rank : V → ℕ)
    (hRank : ∀ i j : V, E i j → 0 < F i j → rank i < rank j)
    {i j : V} (hij : (i, j) ∈ posSupport E F) :
    ∃ L : List V, IsSBPath E S B L ∧ IsConsec L i j ∧
      L.IsChain (fun u w => E u w ∧ 0 < F u w) := by
  classical
  have hE : E i j := (mem_posSupport.mp hij).1
  have hF : 0 < F i j := (mem_posSupport.mp hij).2
  set bwd := backwardWalk h rank hRank i
    (pos_edge_source_is_source_or_pos_inflow h hE hF) with hbwd_def
  set fwd := forwardWalk h rank hRank j
    (pos_edge_dest_is_sink_or_pos_outflow h hE hF) with hfwd_def
  obtain ⟨bne, bhead, blast, bchain, bpair⟩ := bwd.property
  obtain ⟨fne, fhead, flast, fchain, fpair⟩ := fwd.property
  let L := bwd.val.reverse ++ fwd.val
  have hL_ne : L ≠ [] := by
    intro hh
    simp [L] at hh
    exact fne hh.2
  have hbwd_rev_ne : bwd.val.reverse ≠ [] := by
    intro hh
    exact bne (List.reverse_eq_nil_iff.mp hh)
  -- Chain on `WalkEdge E F`.
  have hWalkChain : L.IsChain (WalkEdge E F) := by
    have hbwd_rev : bwd.val.reverse.IsChain (WalkEdge E F) := by
      rw [List.isChain_reverse]
      exact bchain
    have hbwd_head_eq : bwd.val.head bne = i := by
      have hh : bwd.val.head? = some i := bhead
      rw [List.head?_eq_some_head bne] at hh
      exact Option.some.inj hh
    have hfwd_head_eq : fwd.val.head fne = j := by
      have hh : fwd.val.head? = some j := fhead
      rw [List.head?_eq_some_head fne] at hh
      exact Option.some.inj hh
    rw [List.isChain_append]
    refine ⟨hbwd_rev, fchain, ?_⟩
    intro x hx y hy
    have hxi : x = i := by
      rw [List.getLast?_reverse] at hx
      rw [bhead] at hx
      exact (Option.some.inj hx).symm
    have hyj : y = j := by
      rw [fhead] at hy
      exact (Option.some.inj hy).symm
    subst hxi; subst hyj
    exact ⟨hE, hF⟩
  -- Pairwise strictly-increasing rank along L (gives `Nodup`).
  have hri_lt_rj : rank i < rank j := hRank i j hE hF
  have hPair : L.Pairwise (fun u w => rank u < rank w) := by
    have hbwd_rev_pair : bwd.val.reverse.Pairwise (fun u w => rank u < rank w) :=
      List.pairwise_reverse.mpr bpair
    rw [List.pairwise_append]
    refine ⟨hbwd_rev_pair, fpair, ?_⟩
    intro x hx y hy
    have hx' : x ∈ bwd.val := List.mem_reverse.mp hx
    have hxi_le : rank x ≤ rank i := by
      rcases hbv : bwd.val with _ | ⟨a, as⟩
      · rw [hbv] at hx'; simp at hx'
      · have ha : a = i := by
          have hh := bhead
          rw [hbv] at hh; simp at hh; exact hh
        subst ha
        rw [hbv] at hx'
        rcases List.mem_cons.mp hx' with h0 | h1
        · subst h0; exact le_refl _
        · have hp := bpair
          rw [hbv, List.pairwise_cons] at hp
          exact (hp.1 _ h1).le
    have hjy_le : rank j ≤ rank y := by
      rcases hfv : fwd.val with _ | ⟨a, as⟩
      · rw [hfv] at hy; simp at hy
      · have ha : a = j := by
          have hh := fhead
          rw [hfv] at hh; simp at hh; exact hh
        subst ha
        rw [hfv] at hy
        rcases List.mem_cons.mp hy with h0 | h1
        · subst h0; exact le_refl _
        · have hp := fpair
          rw [hfv, List.pairwise_cons] at hp
          exact (hp.1 _ h1).le
    calc rank x ≤ rank i := hxi_le
      _ < rank j := hri_lt_rj
      _ ≤ rank y := hjy_le
  have hL_nd : L.Nodup := by
    rw [List.nodup_iff_pairwise_ne]
    apply List.Pairwise.imp (fun {a b} hab => ?_) hPair
    intro habab; exact absurd (habab ▸ hab) (lt_irrefl _)
  -- Head and last of L.
  have hL_head : L.head hL_ne ∈ S := by
    have hgl := blast bne
    show (bwd.val.reverse ++ fwd.val).head hL_ne ∈ S
    rw [List.head_append_of_ne_nil hbwd_rev_ne]
    rw [List.head_reverse hbwd_rev_ne]
    exact hgl
  have hL_last : L.getLast hL_ne ∈ B := by
    have hgl := flast fne
    show (bwd.val.reverse ++ fwd.val).getLast hL_ne ∈ B
    rw [List.getLast_append_right fne]
    exact hgl
  -- IsConsec L i j: i is the last of bwd.val.reverse, j is the head of fwd.val.
  have hConsec : IsConsec L i j := by
    refine ⟨bwd.val.reverse.dropLast, fwd.val.tail, ?_⟩
    -- bwd.val.reverse = bwd.val.reverse.dropLast ++ [i]
    have hbwd_rev_split :
        bwd.val.reverse = bwd.val.reverse.dropLast ++ [bwd.val.reverse.getLast hbwd_rev_ne] :=
      (List.dropLast_append_getLast hbwd_rev_ne).symm
    have hbwd_rev_last : bwd.val.reverse.getLast hbwd_rev_ne = i := by
      rw [List.getLast_reverse hbwd_rev_ne]
      have hh : bwd.val.head? = some i := bhead
      rw [List.head?_eq_some_head bne] at hh
      exact Option.some.inj hh
    rw [hbwd_rev_last] at hbwd_rev_split
    -- fwd.val = j :: fwd.val.tail
    have hfwd_split : fwd.val = j :: fwd.val.tail := by
      rcases hfv : fwd.val with _ | ⟨a, as⟩
      · exact absurd hfv fne
      · have ha : a = j := by
          have hh := fhead
          rw [hfv] at hh; simp at hh; exact hh
        subst ha
        rfl
    show bwd.val.reverse ++ fwd.val =
      bwd.val.reverse.dropLast ++ i :: j :: fwd.val.tail
    conv_lhs => rw [hbwd_rev_split, hfwd_split]
    simp
  -- Chain on (E u w ∧ 0 < F u w) is exactly `WalkEdge E F`.
  refine ⟨L, ?_, hConsec, hWalkChain⟩
  refine ⟨hL_ne, hL_nd, ?_, hL_head, hL_last⟩
  -- Need IsChain on `E`. Imply from `WalkEdge`.
  exact List.IsChain.imp (fun _ _ hwe => hwe.1) hWalkChain

end Walks

/-! ## Bottleneck and flow subtraction

Given an `S → B` path `L` whose consecutive pairs all carry positive
flow, the *bottleneck* is the minimum flow along its arcs, and the
*subtracted flow* `subtractFlow L F δ` reduces `F` by `δ` along each
arc of `L`. The headline lemma
`subtractFlow_weakFeasible` says that this operation preserves
`WeakFeasible` whenever `0 ≤ δ ≤ bottleneck L F`. -/

section Bottleneck

variable {V : Type*} [Fintype V] [DecidableEq V]
variable {α : Type*} [Ring α] [LinearOrder α] [IsStrictOrderedRing α]

/-- The arcs of a list `L`: the finset of consecutive pairs. -/
noncomputable def pathArcs (L : List V) : Finset (V × V) :=
  (Finset.univ : Finset (V × V)).filter (fun ij => IsConsec L ij.1 ij.2)

lemma mem_pathArcs {L : List V} {i j : V} :
    (i, j) ∈ pathArcs L ↔ IsConsec L i j := by
  simp [pathArcs]

/-- A path of length at least 2 has nonempty arcs. -/
lemma pathArcs_nonempty {L : List V} (h : 2 ≤ L.length) :
    (pathArcs L).Nonempty := by
  classical
  rcases L with _ | ⟨a, _ | ⟨b, rest⟩⟩
  · simp at h
  · simp at h
  · refine ⟨(a, b), ?_⟩
    rw [mem_pathArcs]
    exact ⟨[], rest, rfl⟩

-- Without S ∩ B disjointness, an SB-path could be a singleton list
-- [v] with v ∈ S ∩ B. The bottleneck machinery only applies when the
-- path actually has arcs, so we always pass `(pathArcs L).Nonempty`.

/-- The arcs of a graph path are contained in `E`. -/
lemma pathArcs_subset_E {E : V → V → Prop} {L : List V}
    (hch : L.IsChain E) {i j : V} (hij : (i, j) ∈ pathArcs L) :
    E i j := by
  rw [mem_pathArcs] at hij
  exact consec_chain hch hij

/-- The bottleneck flow value: minimum of `F i j` over arcs of `L`. -/
noncomputable def bottleneck (L : List V) (F : V → V → α)
    (hL : (pathArcs L).Nonempty) : α :=
  ((pathArcs L).image (fun ij => F ij.1 ij.2)).min'
    (Finset.image_nonempty.mpr hL)

/-- Every path arc carries flow at least the bottleneck. -/
lemma bottleneck_le {L : List V} {F : V → V → α}
    (hL : (pathArcs L).Nonempty)
    {i j : V} (hij : (i, j) ∈ pathArcs L) :
    bottleneck L F hL ≤ F i j := by
  classical
  unfold bottleneck
  apply Finset.min'_le
  exact Finset.mem_image.mpr ⟨(i, j), hij, rfl⟩

/-- The bottleneck is attained at some arc. -/
lemma exists_bottleneck_arc {L : List V} {F : V → V → α}
    (hL : (pathArcs L).Nonempty) :
    ∃ ij : V × V, ij ∈ pathArcs L ∧ F ij.1 ij.2 = bottleneck L F hL := by
  classical
  set S := (pathArcs L).image (fun ij => F ij.1 ij.2)
  have hSne : S.Nonempty := Finset.image_nonempty.mpr hL
  have hmem : S.min' hSne ∈ S := Finset.min'_mem _ _
  obtain ⟨ij, hij, heq⟩ := Finset.mem_image.mp hmem
  exact ⟨ij, hij, heq⟩

/-- If every path arc carries strictly positive flow, the bottleneck
is positive. -/
lemma bottleneck_pos {L : List V} {F : V → V → α}
    (hL : (pathArcs L).Nonempty)
    (hpos : ∀ i j : V, (i, j) ∈ pathArcs L → 0 < F i j) :
    0 < bottleneck L F hL := by
  classical
  obtain ⟨ij, hij, heq⟩ := exists_bottleneck_arc (F := F) hL
  rw [← heq]; exact hpos ij.1 ij.2 hij

/-- The subtracted flow: subtracts `δ` along each arc of `L`. -/
noncomputable def subtractFlow (L : List V) (F : V → V → α) (δ : α) :
    V → V → α :=
  fun i j => F i j - δ * consecIndicator L i j

lemma subtractFlow_F (L : List V) (F : V → V → α) (δ : α) (i j : V) :
    subtractFlow L F δ i j = F i j - δ * consecIndicator L i j := rfl

/-- Off-arc entries are unchanged. -/
lemma subtractFlow_F_off (L : List V) (F : V → V → α) (δ : α)
    {i j : V} (h : ¬ IsConsec L i j) :
    subtractFlow L F δ i j = F i j := by
  unfold subtractFlow
  have hi : consecIndicator (α := α) L i j = 0 :=
    (consecIndicator_eq_zero_iff L i j).mpr h
  rw [hi, mul_zero, sub_zero]

/-- On-arc entries are reduced by `δ`. -/
lemma subtractFlow_F_on (L : List V) (F : V → V → α) (δ : α)
    {i j : V} (h : IsConsec L i j) :
    subtractFlow L F δ i j = F i j - δ := by
  unfold subtractFlow
  have hi : consecIndicator (α := α) L i j = 1 :=
    (consecIndicator_eq_one_iff L i j).mpr h
  rw [hi, mul_one]

/-- Subtraction preserves non-negativity provided `0 ≤ δ ≤ bottleneck`. -/
lemma subtractFlow_F_nn {L : List V} {F : V → V → α}
    (hL : (pathArcs L).Nonempty)
    (hF_nn : ∀ i j, 0 ≤ F i j)
    {δ : α} (_hδ_nn : 0 ≤ δ) (hδ_le : δ ≤ bottleneck L F hL) :
    ∀ i j : V, 0 ≤ subtractFlow L F δ i j := by
  intro i j
  by_cases hcond : IsConsec L i j
  · rw [subtractFlow_F_on _ _ _ hcond]
    have hmem : (i, j) ∈ pathArcs L := by rw [mem_pathArcs]; exact hcond
    have hbot := bottleneck_le (F := F) hL hmem
    have hδ_le_F : δ ≤ F i j := le_trans hδ_le hbot
    exact sub_nonneg.mpr hδ_le_F
  · rw [subtractFlow_F_off _ _ _ hcond]
    exact hF_nn i j

/-- The headline lemma: bottleneck subtraction preserves `WeakFeasible`.

Hypotheses:
* `h` — `WeakFeasible E S B F`.
* `hL` — `L` is an `S → B` graph path.
* `hLpos` — `L` is a chain on `WalkEdge E F`, i.e. all consecutive
  pairs of `L` carry positive flow on edges of `E`.
* `0 ≤ δ ≤ bottleneck L F`.

Conclusion: `WeakFeasible E S B (subtractFlow L F δ)`. -/
lemma subtractFlow_weakFeasible
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F)
    {L : List V} (hL : IsSBPath E S B L)
    (hLpos : L.IsChain (WalkEdge E F))
    (hLarcs : (pathArcs L).Nonempty)
    {δ : α} (hδ_nn : 0 ≤ δ) (hδ_le : δ ≤ bottleneck L F hLarcs) :
    WeakFeasible E S B (subtractFlow L F δ) := by
  classical
  obtain ⟨hne, hnd, hch, hhead, hlast⟩ := hL
  -- Every arc has positive flow.
  have harc_pos : ∀ i j : V, (i, j) ∈ pathArcs L → 0 < F i j := by
    intro i j hij
    rw [mem_pathArcs] at hij
    exact (consec_chain hLpos hij).2
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · -- hNN
    exact subtractFlow_F_nn hLarcs h.hNN hδ_nn hδ_le
  · -- hOffEdge
    intro i j hE
    have hnotconsec : ¬ IsConsec L i j := by
      intro hc
      have := consec_chain hch hc
      exact hE this
    rw [subtractFlow_F_off _ _ _ hnotconsec]
    exact h.hOffEdge i j hE
  · -- hNoInflowS: ∀ s ∈ S, ∀ i, subtractFlow L F δ i s = 0.
    intro s hsS i
    have h0 : F i s = 0 := h.hNoInflowS s hsS i
    -- Show consecIndicator L i s = 0, i.e. ¬ IsConsec L i s.
    have hnotconsec : ¬ IsConsec L i s := by
      intro hc
      -- Then F i s > 0 (positive chain), contradicting F i s = 0.
      have hpos := (consec_chain hLpos hc).2
      rw [h0] at hpos
      exact lt_irrefl _ hpos
    rw [subtractFlow_F_off _ _ _ hnotconsec, h0]
  · -- hNoOutflowB
    intro b hbB j
    have h0 : F b j = 0 := h.hNoOutflowB b hbB j
    have hnotconsec : ¬ IsConsec L b j := by
      intro hc
      have hpos := (consec_chain hLpos hc).2
      rw [h0] at hpos
      exact lt_irrefl _ hpos
    rw [subtractFlow_F_off _ _ _ hnotconsec, h0]
  · -- hConserv: ∀ v, v ∉ S → v ∉ B → ∑ i, subtract i v = ∑ j, subtract v j.
    intro v hvS hvB
    have hold : ∑ i, F i v = ∑ j, F v j := h.hConserv v hvS hvB
    -- ∑ i, subtract i v = (∑ i, F i v) - δ * ∑ i, consecIndicator L i v.
    have hin_eq :
        ∑ i, subtractFlow L F δ i v =
          (∑ i, F i v) - δ * ∑ i, consecIndicator (α := α) L i v := by
      rw [Finset.mul_sum, ← Finset.sum_sub_distrib]
      apply Finset.sum_congr rfl
      intro i _
      rw [subtractFlow_F]
    have hout_eq :
        ∑ j, subtractFlow L F δ v j =
          (∑ j, F v j) - δ * ∑ j, consecIndicator (α := α) L v j := by
      rw [Finset.mul_sum, ← Finset.sum_sub_distrib]
      apply Finset.sum_congr rfl
      intro j _
      rw [subtractFlow_F]
    rw [hin_eq, hout_eq, hold]
    -- Need: ∑ i, consecIndicator L i v = ∑ j, consecIndicator L v j.
    rw [sum_consecIndicator_in_eq (α := α) L hnd v,
        sum_consecIndicator_out_eq (α := α) L hnd v]
    -- Two ites: equal iff the two propositions agree.
    have hpred : (∃ u, IsConsec L u v) ↔ (∃ w, IsConsec L v w) := by
      constructor
      · rintro ⟨u, hu⟩
        -- u → v consecutive, so v ∈ L. v ≠ getLast (else v ∈ B). So v has succ.
        have hv_in : v ∈ L := consec_right_mem hu
        have hv_ne_last : v ≠ L.getLast hne := by
          intro hveq
          apply hvB
          rw [hveq]; exact hlast
        exact exists_consec_succ hne hv_in hv_ne_last
      · rintro ⟨w, hw⟩
        have hv_in : v ∈ L := consec_left_mem hw
        have hv_ne_head : v ≠ L.head hne := by
          intro hveq
          apply hvS
          rw [hveq]; exact hhead
        exact exists_consec_pred hne hv_in hv_ne_head
    by_cases hexists : ∃ u, IsConsec L u v
    · rw [if_pos hexists, if_pos (hpred.mp hexists)]
    · rw [if_neg hexists, if_neg (fun h' => hexists (hpred.mpr h'))]

end Bottleneck

/-! ## Support strictly shrinks

After bottleneck subtraction along an `S → B` path whose arcs all carry
positive flow, the positive-flow support strictly shrinks: the bottleneck
arc itself drops out (its flow is exactly zeroed), while every other
positive-flow arc remains positive (subtraction with `δ ≥ 0` only
decreases values). This is the key well-founded measure for the
flow-decomposition induction. -/

section SupportShrinks

variable {V : Type*} [Fintype V] [DecidableEq V]
variable {α : Type*} [Ring α] [LinearOrder α] [IsStrictOrderedRing α]

lemma subtractFlow_support_lt
    {E : V → V → Prop} {S B : Finset V} {F : V → V → α}
    (h : WeakFeasible E S B F)
    {L : List V} (hL : IsSBPath E S B L)
    (hLpos : L.IsChain (WalkEdge E F))
    (hLarcs : (pathArcs L).Nonempty) :
    (posSupport E (subtractFlow L F (bottleneck L F hLarcs))).card <
      (posSupport E F).card := by
  classical
  set δ := bottleneck L F hLarcs with hδ_def
  -- Positivity of every arc.
  have harc_pos : ∀ i j : V, (i, j) ∈ pathArcs L → 0 < F i j := by
    intro i j hij
    rw [mem_pathArcs] at hij
    exact (consec_chain hLpos hij).2
  -- Bottleneck nonneg / positive.
  have hδ_pos : 0 < δ := bottleneck_pos hLarcs harc_pos
  have hδ_nn : 0 ≤ δ := le_of_lt hδ_pos
  -- Pick the bottleneck arc.
  obtain ⟨ij, hij_mem, hij_eq⟩ := exists_bottleneck_arc (F := F) hLarcs
  obtain ⟨u, v⟩ := ij
  rw [mem_pathArcs] at hij_mem
  -- Edge predicate at the bottleneck arc.
  obtain ⟨hne, _hnd, hch, _hhead, _hlast⟩ := hL
  have hEuv : E u v := consec_chain hch hij_mem
  -- (u, v) ∈ posSupport E F.
  have huv_in_old : (u, v) ∈ posSupport E F := by
    rw [mem_posSupport]
    refine ⟨hEuv, ?_⟩
    rw [hij_eq]; exact hδ_pos
  -- (u, v) ∉ posSupport E (subtractFlow L F δ).
  have huv_not_in_new :
      (u, v) ∉ posSupport E (subtractFlow L F δ) := by
    rw [mem_posSupport]
    intro ⟨_, hpos⟩
    rw [subtractFlow_F_on _ _ _ hij_mem] at hpos
    have hzero : F u v - δ = 0 := by rw [hij_eq]; exact sub_self _
    rw [hzero] at hpos
    exact lt_irrefl _ hpos
  -- New support ⊆ old support.
  have hsubset : posSupport E (subtractFlow L F δ) ⊆ posSupport E F := by
    intro p hp
    rcases p with ⟨a, b⟩
    rw [mem_posSupport] at hp ⊢
    refine ⟨hp.1, ?_⟩
    -- subtractFlow L F δ a b ≤ F a b, and the former is positive.
    have hind_nn : 0 ≤ δ * consecIndicator (α := α) L a b := by
      rcases consecIndicator_binary (α := α) L a b with hzero | hone
      · rw [hzero, mul_zero]
      · rw [hone, mul_one]; exact hδ_nn
    have hle : subtractFlow L F δ a b ≤ F a b := by
      show F a b - δ * consecIndicator (α := α) L a b ≤ F a b
      exact sub_le_self _ hind_nn
    exact lt_of_lt_of_le hp.2 hle
  -- Strict subset, hence strict cardinality.
  apply Finset.card_lt_card
  refine ⟨hsubset, ?_⟩
  intro hreverse
  exact huv_not_in_new (hreverse huv_in_old)

end SupportShrinks

/-! ## Statement of the main theorem -/

section Statement

variable {V : Type*} [Fintype V] [DecidableEq V]
variable {α : Type*} [Ring α] [LinearOrder α] [IsStrictOrderedRing α]

/-- A *flow decomposition* of `F` with respect to `(E, S, B)`: a list
of (path, weight) pairs such that

1. each path is an `S → B` graph path,
2. each weight is strictly positive,
3. for every directed pair `(i, j)`, the sum over decomposition
   entries of `weight * indicator((i, j) is consecutive in path)`
   recovers `F i j`.

For the integer-unit specialization (every weight is `1`) the third
condition becomes: `F i j` equals the number of paths in which
`(i, j)` is consecutive. -/
def IsFlowDecomposition
    (E : V → V → Prop) (S B : Finset V) (F : V → V → α)
    (decomp : List (List V × α)) : Prop :=
  (∀ pw ∈ decomp, IsSBPath E S B pw.1 ∧ 0 < pw.2) ∧
  ∀ i j, F i j =
    (decomp.map (fun pw => pw.2 * consecIndicator pw.1 i j)).sum

end Statement

/-! ## Statement of the main theorem (forthcoming proof)

We package the main theorem as a `Prop`-valued definition so the file
compiles before the proof is in place. The eventual
`theorem flow_decomposition` will have exactly this type. -/

/-- The statement of the abstract flow-decomposition theorem.

The hypothesis `(rank, hRank)` is a *rank witness* for acyclicity of
the positive-flow support: a function `rank : V → ℕ` that strictly
increases along every positive-flow edge. `WeakFeasible` does not
imply such a witness on its own (the support could in principle have
cycles), but every concrete instance considered in this dataset (p20
on a topologically sortable graph; p13 on a time-expanded graph using
the time index) supplies one. The walk construction in
`exists_SBPath_through_pos_edge` requires this rank, and the
inductive subtraction step preserves it (subtraction can only
decrease flow values, so a positive arc of the new flow was already
positive in the old flow). -/
def Statement_flow_decomposition
    (V : Type*) [Fintype V] [DecidableEq V]
    (α : Type*) [Ring α] [LinearOrder α] [IsStrictOrderedRing α] : Prop :=
  ∀ (E : V → V → Prop) (S B : Finset V) (F : V → V → α)
    (rank : V → ℕ),
    (∀ i j : V, E i j → 0 < F i j → rank i < rank j) →
    WeakFeasible E S B F →
    ∃ decomp : List (List V × α), IsFlowDecomposition E S B F decomp

/-! ## Proof of the main theorem -/

section MainProof

/-- **Abstract flow decomposition.** Strong induction on the
cardinality of the positive-flow support, peeling off one `S → B`
path at a time and subtracting its bottleneck flow.

* The bottleneck arc is zeroed out, so the support strictly shrinks
  (`subtractFlow_support_lt`).
* The rank witness is preserved across subtraction (any positive
  arc of `F'` had positive flow in `F`).
* The decomposition equation `F i j = Σ wₖ * indicator Lₖ i j`
  follows by combining the inductive equation for `F'` with the
  identity `F i j = F' i j + δ * consecIndicator L i j`. -/
theorem flow_decomposition (V : Type*) [Fintype V] [DecidableEq V]
    (α : Type*) [Ring α] [LinearOrder α] [IsStrictOrderedRing α] :
    Statement_flow_decomposition V α := by
  classical
  intro E S B F rank hRank hF
  -- Strong induction on (posSupport E F).card.
  generalize hn : (posSupport E F).card = n
  induction n using Nat.strong_induction_on generalizing F with
  | _ n IH =>
    by_cases hempty : posSupport E F = ∅
    · -- Base case: F ≡ 0.
      refine ⟨[], ?_, ?_⟩
      · intro pw hpw; cases hpw
      · intro i j
        rw [flow_zero_of_support_empty hF hempty i j]
        simp
    · -- Inductive step: pick any positive edge.
      have hsupp_ne : (posSupport E F).Nonempty :=
        Finset.nonempty_iff_ne_empty.mpr hempty
      obtain ⟨ij, hij_mem⟩ := hsupp_ne
      obtain ⟨i, j⟩ := ij
      -- Build an S→B path through (i, j) chained on WalkEdge.
      obtain ⟨L, hLpath, _hLconsec, hLpos⟩ :=
        exists_SBPath_through_pos_edge hF rank hRank hij_mem
      -- pathArcs L is nonempty: the arc (i,j) is in it.
      have hLarcs : (pathArcs L).Nonempty := by
        refine ⟨(i, j), ?_⟩
        rw [mem_pathArcs]; exact _hLconsec
      -- Bottleneck.
      set δ := bottleneck L F hLarcs with hδ_def
      have harc_pos : ∀ a b : V, (a, b) ∈ pathArcs L → 0 < F a b := by
        intro a b hab
        rw [mem_pathArcs] at hab
        exact (consec_chain hLpos hab).2
      have hδ_pos : 0 < δ := bottleneck_pos hLarcs harc_pos
      have hδ_nn : 0 ≤ δ := le_of_lt hδ_pos
      have hδ_le : δ ≤ bottleneck L F hLarcs := le_refl _
      -- The new flow F'.
      set F' := subtractFlow L F δ with hF'_def
      -- F' is WeakFeasible.
      have hF' : WeakFeasible E S B F' :=
        subtractFlow_weakFeasible hF hLpath hLpos hLarcs hδ_nn hδ_le
      -- F' satisfies the same rank witness.
      have hRank' : ∀ a b : V, E a b → 0 < F' a b → rank a < rank b := by
        intro a b hEab hposab
        have hge : 0 ≤ δ * consecIndicator (α := α) L a b := by
          rcases consecIndicator_binary (α := α) L a b with hz | ho
          · rw [hz, mul_zero]
          · rw [ho, mul_one]; exact hδ_nn
        have hF'le : F' a b ≤ F a b := by
          show F a b - δ * consecIndicator (α := α) L a b ≤ F a b
          exact sub_le_self _ hge
        have hposab_old : 0 < F a b := lt_of_lt_of_le hposab hF'le
        exact hRank a b hEab hposab_old
      -- Support strictly shrinks.
      have hcard_lt :
          (posSupport E F').card < (posSupport E F).card :=
        subtractFlow_support_lt hF hLpath hLpos hLarcs
      rw [hn] at hcard_lt
      -- Apply IH on F'.
      set m := (posSupport E F').card with hm_def
      have hmn : m < n := hcard_lt
      obtain ⟨decomp', hdecomp'⟩ :=
        IH m hmn F' hRank' hF' rfl
      -- Recombine.
      refine ⟨(L, δ) :: decomp', ?_, ?_⟩
      · -- All entries are valid SB-paths with positive weights.
        intro pw hpw
        rcases List.mem_cons.mp hpw with hcur | hrest
        · subst hcur
          exact ⟨hLpath, hδ_pos⟩
        · exact hdecomp'.1 pw hrest
      · -- Decomposition equation.
        intro a b
        have hF_eq : F a b = F' a b + δ * consecIndicator (α := α) L a b := by
          show F a b = (F a b - δ * consecIndicator (α := α) L a b)
            + δ * consecIndicator (α := α) L a b
          rw [sub_add_cancel]
        have hF'_eq : F' a b =
            (decomp'.map (fun pw => pw.2 * consecIndicator pw.1 a b)).sum :=
          hdecomp'.2 a b
        rw [hF_eq, hF'_eq]
        simp [List.map_cons, List.sum_cons, add_comm]

end MainProof

end FlowDecomp
end ORLib
