import Common
import dataset.problems.p20.formulations.a.Formulation
import dataset.problems.p20.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P20

/-!
# P20: Flow Decomposition Scaffold (a → b direction)

This file lays the groundwork for an eventual `MILPEquiv` between the
arc-based formulation `P20.a.formulation` and the path-based
formulation `P20.b.formulation` of the World Food Program problem.

Only the base-case ingredients of flow decomposition are proved here.
The full inductive proof — and consequently the `MILPEquiv` itself —
is left as future work and is deliberately **not** committed under a
`sorry` (per project policy). The path-extraction sub-lemma at the
heart of the induction is *stated* as a `def`-shaped `Prop` so a
follow-up PR can attack it directly.
-/

-- ============================================================================
-- § Weak feasibility (drops `hdemand`, `hnutrition`)
-- ============================================================================

/-- A weakened feasibility predicate that omits the demand and nutrition
constraints. This is what's preserved under bottleneck subtraction during
flow decomposition. -/
structure WeakFeasible (p : P20.a.Params) (v : P20.a.Vars) : Prop where
  hS_noinflow : ∀ s : Fin p.nS, ∀ k : Fin p.nK,
    ∑ i : Fin p.nN, (p.E i (p.S s) : ℝ) * v.F i (p.S s) k = 0
  hflow : ∀ j : Fin p.nT, ∀ k : Fin p.nK,
    ∑ i : Fin p.nN, (p.E i (p.T j) : ℝ) * v.F i (p.T j) k =
    ∑ i : Fin p.nN, (p.E (p.T j) i : ℝ) * v.F (p.T j) i k
  hB_nooutflow : ∀ b : Fin p.nB, ∀ k : Fin p.nK,
    ∑ j : Fin p.nN, (p.E (p.B b) j : ℝ) * v.F (p.B b) j k = 0
  hF_acyclic : ∀ k : Fin p.nK, ∃ rank : Fin p.nN → ℕ,
    ∀ i j : Fin p.nN, p.E i j = 1 → 0 < v.F i j k → rank i < rank j
  hF_offedge : ∀ i j : Fin p.nN, ∀ k : Fin p.nK,
    p.E i j = 0 → v.F i j k = 0
  hF_nn : ∀ i j : Fin p.nN, ∀ k : Fin p.nK, 0 ≤ v.F i j k
  hR_nn : ∀ k : Fin p.nK, 0 ≤ v.R k

/-- Every `Feasible` is `WeakFeasible`. -/
lemma Feasible.toWeak {p : P20.a.Params} {v : P20.a.Vars}
    (h : P20.a.Feasible p v) : WeakFeasible p v :=
  { hS_noinflow := h.hS_noinflow
    hflow := h.hflow
    hB_nooutflow := h.hB_nooutflow
    hF_acyclic := h.hF_acyclic
    hF_offedge := h.hF_offedge
    hF_nn := h.hF_nn
    hR_nn := h.hR_nn }

-- ============================================================================
-- § Positive-flow support
-- ============================================================================

namespace FlowDecomp

variable (pa : P20.a.Params) (v : P20.a.Vars)

/-- The positive-flow support for commodity `k`: pairs `(i, j)` such
that `E i j = 1` and `0 < F i j k`. Used for strong induction in the
flow-decomposition argument. -/
noncomputable def posSupport (k : Fin pa.nK) : Finset (Fin pa.nN × Fin pa.nN) :=
  (univ : Finset (Fin pa.nN × Fin pa.nN)).filter
    (fun ij => pa.E ij.1 ij.2 = 1 ∧ 0 < v.F ij.1.val ij.2.val k.val)

lemma mem_posSupport {k : Fin pa.nK} {i j : Fin pa.nN} :
    (i, j) ∈ posSupport pa v k ↔
      pa.E i j = 1 ∧ 0 < v.F i.val j.val k.val := by
  simp [posSupport]

/-- If the positive-flow support for commodity `k` is empty, then
`F i j k = 0` on every edge `(i, j)`. -/
lemma flow_zero_on_edges_of_support_empty
    (h : WeakFeasible pa v) (k : Fin pa.nK)
    (hsupp : posSupport pa v k = ∅) :
    ∀ i j : Fin pa.nN, pa.E i j = 1 → v.F i.val j.val k.val = 0 := by
  intro i j hE
  by_contra hne
  have hpos : 0 < v.F i.val j.val k.val :=
    lt_of_le_of_ne (h.hF_nn i j k) (Ne.symm hne)
  have hmem : (i, j) ∈ posSupport pa v k := by
    rw [mem_posSupport]; exact ⟨hE, hpos⟩
  rw [hsupp] at hmem
  exact absurd hmem (by simp)

/-- Combined with the off-edge zero-flow constraint `hF_offedge`,
support emptiness implies `F i j k = 0` everywhere. -/
lemma flow_zero_of_support_empty
    (h : WeakFeasible pa v) (k : Fin pa.nK)
    (hsupp : posSupport pa v k = ∅) :
    ∀ i j : Fin pa.nN, v.F i.val j.val k.val = 0 := by
  intro i j
  rcases pa.hE_bin i j with hE0 | hE1
  · exact h.hF_offedge i j k hE0
  · exact flow_zero_on_edges_of_support_empty pa v h k hsupp i j hE1

end FlowDecomp

-- ============================================================================
-- § Forward / backward step lemmas on the positive-flow support
-- ============================================================================

namespace FlowDecomp

variable (pa : P20.a.Params) (v : P20.a.Vars)

/-- Total inflow at node `j` on commodity `k`, over edges. -/
noncomputable def inflow (k : Fin pa.nK) (j : Fin pa.nN) : ℝ :=
  ∑ i : Fin pa.nN, (pa.E i j : ℝ) * v.F i.val j.val k.val

/-- Total outflow at node `i` on commodity `k`, over edges. -/
noncomputable def outflow (k : Fin pa.nK) (i : Fin pa.nN) : ℝ :=
  ∑ j : Fin pa.nN, (pa.E i j : ℝ) * v.F i.val j.val k.val

/-- A node with positive outflow on commodity `k` cannot be a beneficiary. -/
lemma not_beneficiary_of_pos_outflow
    (h : WeakFeasible pa v) (k : Fin pa.nK) (i : Fin pa.nN)
    (hpos : 0 < outflow pa v k i) : ∀ b : Fin pa.nB, i ≠ pa.B b := by
  intro b heq
  have h0 : outflow pa v k i = 0 := by
    unfold outflow
    rw [heq]
    exact h.hB_nooutflow b k
  linarith

/-- A node with positive inflow on commodity `k` cannot be a supplier. -/
lemma not_supplier_of_pos_inflow
    (h : WeakFeasible pa v) (k : Fin pa.nK) (j : Fin pa.nN)
    (hpos : 0 < inflow pa v k j) : ∀ s : Fin pa.nS, j ≠ pa.S s := by
  intro s heq
  have h0 : inflow pa v k j = 0 := by
    unfold inflow
    rw [heq]
    exact h.hS_noinflow s k
  linarith

/-- Each summand in `inflow` is non-negative. -/
lemma inflow_summand_nn
    (h : WeakFeasible pa v) (k : Fin pa.nK) (j i : Fin pa.nN) :
    0 ≤ (pa.E i j : ℝ) * v.F i.val j.val k.val := by
  rcases pa.hE_bin i j with hE0 | hE1
  · rw [hE0]; simp
  · rw [hE1]; simp; exact h.hF_nn i j k

/-- Each summand in `outflow` is non-negative. -/
lemma outflow_summand_nn
    (h : WeakFeasible pa v) (k : Fin pa.nK) (i j : Fin pa.nN) :
    0 ≤ (pa.E i j : ℝ) * v.F i.val j.val k.val :=
  inflow_summand_nn pa v h k j i

/-- If outflow at node `i` on commodity `k` is positive, then there is some
edge `(i, j)` carrying positive flow on `k`. -/
lemma exists_pos_out_edge_of_pos_outflow
    (h : WeakFeasible pa v) (k : Fin pa.nK) (i : Fin pa.nN)
    (hpos : 0 < outflow pa v k i) :
    ∃ j : Fin pa.nN, pa.E i j = 1 ∧ 0 < v.F i.val j.val k.val := by
  classical
  by_contra hne
  push_neg at hne
  have hzero : outflow pa v k i = 0 := by
    unfold outflow
    apply Finset.sum_eq_zero
    intro j _
    rcases pa.hE_bin i j with hE0 | hE1
    · rw [hE0]; simp
    · -- E i j = 1; hne gives v.F i j k ≤ 0
      have hF0 : v.F i.val j.val k.val ≤ 0 := hne j hE1
      have : v.F i.val j.val k.val = 0 :=
        le_antisymm hF0 (h.hF_nn i j k)
      rw [hE1, this]; simp
  linarith

/-- If inflow at node `j` on commodity `k` is positive, then there is some
edge `(i, j)` carrying positive flow on `k`. -/
lemma exists_pos_in_edge_of_pos_inflow
    (h : WeakFeasible pa v) (k : Fin pa.nK) (j : Fin pa.nN)
    (hpos : 0 < inflow pa v k j) :
    ∃ i : Fin pa.nN, pa.E i j = 1 ∧ 0 < v.F i.val j.val k.val := by
  classical
  by_contra hne
  push_neg at hne
  have hzero : inflow pa v k j = 0 := by
    unfold inflow
    apply Finset.sum_eq_zero
    intro i _
    rcases pa.hE_bin i j with hE0 | hE1
    · rw [hE0]; simp
    · have hF0 : v.F i.val j.val k.val ≤ 0 := hne i hE1
      have : v.F i.val j.val k.val = 0 :=
        le_antisymm hF0 (h.hF_nn i j k)
      rw [hE1, this]; simp
  linarith

/-- A positive-flow edge `(i, j)` produces positive outflow at `i`. -/
lemma pos_outflow_of_pos_edge
    (h : WeakFeasible pa v) (k : Fin pa.nK) (i j : Fin pa.nN)
    (hE : pa.E i j = 1) (hF : 0 < v.F i.val j.val k.val) :
    0 < outflow pa v k i := by
  classical
  unfold outflow
  apply Finset.sum_pos' (fun j' _ => outflow_summand_nn pa v h k i j')
  refine ⟨j, Finset.mem_univ _, ?_⟩
  rw [hE]; simpa using hF

/-- A positive-flow edge `(i, j)` produces positive inflow at `j`. -/
lemma pos_inflow_of_pos_edge
    (h : WeakFeasible pa v) (k : Fin pa.nK) (i j : Fin pa.nN)
    (hE : pa.E i j = 1) (hF : 0 < v.F i.val j.val k.val) :
    0 < inflow pa v k j := by
  classical
  unfold inflow
  apply Finset.sum_pos' (fun i' _ => inflow_summand_nn pa v h k j i')
  refine ⟨i, Finset.mem_univ _, ?_⟩
  rw [hE]; simpa using hF

/-- **Forward step (transshipment case).** At a transshipment node with
positive inflow on commodity `k`, there is an outgoing edge with positive
flow. Uses transshipment conservation `hflow`. -/
lemma forward_step_transshipment
    (h : WeakFeasible pa v) (k : Fin pa.nK) (t : Fin pa.nT)
    (hin : 0 < inflow pa v k (pa.T t)) :
    ∃ j' : Fin pa.nN, pa.E (pa.T t) j' = 1 ∧
        0 < v.F (pa.T t).val j'.val k.val := by
  classical
  have hin_eq_out : inflow pa v k (pa.T t) = outflow pa v k (pa.T t) := by
    unfold inflow outflow
    exact h.hflow t k
  have houtpos : 0 < outflow pa v k (pa.T t) := hin_eq_out ▸ hin
  exact exists_pos_out_edge_of_pos_outflow pa v h k (pa.T t) houtpos

/-- **Backward step (transshipment case).** At a transshipment node with
positive outflow on commodity `k`, there is an incoming edge with positive
flow. Uses transshipment conservation `hflow`. -/
lemma backward_step_transshipment
    (h : WeakFeasible pa v) (k : Fin pa.nK) (t : Fin pa.nT)
    (hout : 0 < outflow pa v k (pa.T t)) :
    ∃ i' : Fin pa.nN, pa.E i' (pa.T t) = 1 ∧
        0 < v.F i'.val (pa.T t).val k.val := by
  classical
  have hin_eq_out : inflow pa v k (pa.T t) = outflow pa v k (pa.T t) := by
    unfold inflow outflow
    exact h.hflow t k
  have hinpos : 0 < inflow pa v k (pa.T t) := hin_eq_out ▸ hout
  exact exists_pos_in_edge_of_pos_inflow pa v h k (pa.T t) hinpos

/-- **Forward step (general).** At a node `i` with positive outflow on
commodity `k` that is not a beneficiary, there is an outgoing positive-flow
edge. By partition, `i` is supplier or transshipment; the supplier case is
fine (just produce the edge directly), and the transshipment case is handled
by `forward_step_transshipment` (or, equivalently, directly by the outflow). -/
lemma forward_step
    (h : WeakFeasible pa v) (k : Fin pa.nK) (i : Fin pa.nN)
    (hout : 0 < outflow pa v k i) :
    ∃ j : Fin pa.nN, pa.E i j = 1 ∧ 0 < v.F i.val j.val k.val :=
  exists_pos_out_edge_of_pos_outflow pa v h k i hout

/-- **Backward step (general).** At a node `j` with positive inflow on
commodity `k`, there is an incoming positive-flow edge. -/
lemma backward_step
    (h : WeakFeasible pa v) (k : Fin pa.nK) (j : Fin pa.nN)
    (hin : 0 < inflow pa v k j) :
    ∃ i : Fin pa.nN, pa.E i j = 1 ∧ 0 < v.F i.val j.val k.val :=
  exists_pos_in_edge_of_pos_inflow pa v h k j hin

/-- A non-beneficiary, non-supplier node is a transshipment node. -/
lemma transshipment_of_not_S_not_B
    (i : Fin pa.nN)
    (hnotS : ∀ s : Fin pa.nS, i ≠ pa.S s)
    (hnotB : ∀ b : Fin pa.nB, i ≠ pa.B b) :
    ∃ t : Fin pa.nT, pa.T t = i := by
  rcases pa.hSTB_partition i with ⟨s, hs⟩ | ⟨t, ht⟩ | ⟨b, hb⟩
  · exact absurd hs.symm (hnotS s)
  · exact ⟨t, ht⟩
  · exact absurd hb.symm (hnotB b)

/-- If a node has positive outflow on commodity `k`, then it has positive
inflow if it is not a supplier (using transshipment conservation). -/
lemma pos_inflow_of_pos_outflow_not_S
    (h : WeakFeasible pa v) (k : Fin pa.nK) (i : Fin pa.nN)
    (hout : 0 < outflow pa v k i) (hnotS : ∀ s : Fin pa.nS, i ≠ pa.S s) :
    ∃ i' : Fin pa.nN, pa.E i' i = 1 ∧ 0 < v.F i'.val i.val k.val := by
  -- i is not a supplier; by hSTB_partition either transshipment or beneficiary
  -- but beneficiary has zero outflow.
  have hnotB : ∀ b : Fin pa.nB, i ≠ pa.B b :=
    not_beneficiary_of_pos_outflow pa v h k i hout
  obtain ⟨t, ht⟩ := transshipment_of_not_S_not_B pa i hnotS hnotB
  subst ht
  exact backward_step_transshipment pa v h k t hout

/-- If a node has positive inflow on commodity `k`, then it has positive
outflow if it is not a beneficiary (using transshipment conservation). -/
lemma pos_outflow_of_pos_inflow_not_B
    (h : WeakFeasible pa v) (k : Fin pa.nK) (j : Fin pa.nN)
    (hin : 0 < inflow pa v k j) (hnotB : ∀ b : Fin pa.nB, j ≠ pa.B b) :
    ∃ j' : Fin pa.nN, pa.E j j' = 1 ∧ 0 < v.F j.val j'.val k.val := by
  have hnotS : ∀ s : Fin pa.nS, j ≠ pa.S s :=
    not_supplier_of_pos_inflow pa v h k j hin
  obtain ⟨t, ht⟩ := transshipment_of_not_S_not_B pa j hnotS hnotB
  subst ht
  exact forward_step_transshipment pa v h k t hin

end FlowDecomp

-- ============================================================================
-- § Flow-decomposition predicate (single commodity)
-- ============================================================================

/--
**Flow decomposition (single commodity).**

Given matched a-side and b-side parameters `pa` and `pb` with `nN`
identified via `hN`, an a-side variable assignment `v`, and a
commodity `k`, this predicate asserts that there exist nonneg path
flows `x : Fin pb.nP → ℝ` reproducing `v.F · k` on every arc:

  `∀ i j, ∑ p, pE p i j · x p = F i j k`.

This is the core ingredient for the eventual `MILPEquiv.fwd` map.
-/
def IsFlowDecomposition
    (pa : P20.a.Params) (pb : P20.b.Params)
    (hN : pa.nN = pb.nN)
    (v : P20.a.Vars) (k : Fin pa.nK) : Prop :=
  ∃ x : Fin pb.nP → ℝ,
    (∀ p, 0 ≤ x p) ∧
    (∀ i j : Fin pa.nN,
      ∑ p : Fin pb.nP,
        (pb.pE p (Fin.cast hN i) (Fin.cast hN j) : ℝ) * x p
      = v.F i.val j.val k.val)

-- ============================================================================
-- § Base case of flow decomposition
-- ============================================================================

namespace FlowDecomp

/-- **Base case.** If the positive-flow support of commodity `k` is
empty, taking `x ≡ 0` is a flow decomposition. -/
lemma flow_decomposition_empty_support
    (pa : P20.a.Params) (pb : P20.b.Params)
    (hN : pa.nN = pb.nN)
    (v : P20.a.Vars) (h : WeakFeasible pa v) (k : Fin pa.nK)
    (hsupp : posSupport pa v k = ∅) :
    IsFlowDecomposition pa pb hN v k := by
  refine ⟨fun _ => 0, ?_, ?_⟩
  · intro _; exact le_refl _
  · intro i j
    have hLHS : ∑ p : Fin pb.nP,
        (pb.pE p (Fin.cast hN i) (Fin.cast hN j) : ℝ) * 0 = 0 := by simp
    rw [hLHS]
    exact (flow_zero_of_support_empty pa v h k hsupp i j).symm

end FlowDecomp

-- ============================================================================
-- § Outstanding work (inductive step)
-- ============================================================================

/-!
## Status of the inductive step

The following pieces remain unproved. They are *not* committed in this
file (no `sorry` is used); this section documents the design plan so a
follow-up PR can resume.

**Plan.** Strong induction on `(posSupport pa v k).card`. The base
case (`card = 0`) is `flow_decomposition_empty_support` above.

### Progress so far

* `posSupport`, `mem_posSupport` — positive-flow support set.
* `flow_zero_on_edges_of_support_empty`, `flow_zero_of_support_empty` —
  emptiness of `posSupport` implies `F i j k = 0` everywhere.
* `flow_decomposition_empty_support` — base case.
* `inflow`, `outflow` — total inflow/outflow at a node on commodity `k`.
* `inflow_summand_nn`, `outflow_summand_nn` — non-negativity of
  per-edge contributions.
* `not_beneficiary_of_pos_outflow`, `not_supplier_of_pos_inflow` —
  type-exclusion lemmas via `hB_nooutflow` / `hS_noinflow`.
* `exists_pos_out_edge_of_pos_outflow`,
  `exists_pos_in_edge_of_pos_inflow` — positive total flow at a node
  produces a witnessing edge.
* `pos_outflow_of_pos_edge`, `pos_inflow_of_pos_edge` — converse: a
  positive-flow edge contributes positively to its endpoints' totals.
* `forward_step_transshipment` — at a transshipment node with positive
  inflow on `k`, there is a positive-flow outgoing edge (uses `hflow`).
* `backward_step_transshipment` — symmetric for backward walking.

### Blocker for path extraction

**The current `P20.a` formulation does not require that every node is a
supplier, transshipment, or beneficiary.** That is, the maps
`S, T, B : Fin n_ → Fin nN` are not asserted to cover `Fin nN`. As a
consequence, a node `v : Fin nN` that lies outside the images of `S`,
`T`, `B` carries no flow conservation, supply, or demand constraint, so
the feasibility predicate permits flow to "disappear" at such a ghost
node (positive inflow with zero outflow). A forward walk along
positive-flow edges may then terminate at a ghost node rather than at a
beneficiary, in which case no `IsValidPath` can be extracted.

To make path extraction provable, the a-side `Params` should be
strengthened with a coverage axiom such as
```
hN_partition : ∀ v : Fin nN,
  (∃ s : Fin nS, v = S s) ∨ (∃ t : Fin nT, v = T t) ∨ (∃ b : Fin nB, v = B b)
```
(and ideally also disjointness of the three classes, plus injectivity
of `S`, `T`, `B`, to obtain clean unique source / sink claims when
discharging `IsValidPath`). With such an axiom the forward and backward
step lemmas above generalise to a fully general one-step extension, and
the walk can be defined by well-founded recursion on the rank witness
of `hF_acyclic k`.

### Remaining inductive-step plan (post-formulation-fix)

1. **General one-step extension** (depending on the coverage axiom):
   ✅ DONE — see `forward_step`, `backward_step`,
   `transshipment_of_not_S_not_B`,
   `pos_inflow_of_pos_outflow_not_S`,
   `pos_outflow_of_pos_inflow_not_B`. The partition assumption added to
   `P20.a.Params` lets us conclude that any non-supplier node with
   positive outflow has positive inflow (by transshipment conservation,
   ruling out beneficiary by `hB_nooutflow`); symmetric for inflow.

2. **Walk construction**: well-founded recursion keyed on `M - rank v`
   where `rank` is `Classical.choose (h.hF_acyclic k)` and
   `M = (Finset.univ.sup rank) + 1`. Forward walk from any node
   with positive outflow terminates at a beneficiary; backward walk
   from any node with positive inflow terminates at a supplier.
   Helper measures `maxRank`, `fwdMeasure`, `fwdMeasure_lt`,
   `bwdMeasure_lt` are provided below.

   **Status**: helper measures done; the walk-as-list construction and
   path-finalization to `pE'` / `pRank'` remain. The natural shape is

   ```
   noncomputable def forwardWalk (rank : ...)
       (hRank : ∀ i j, pa.E i j = 1 → 0 < v.F i j k → rank i < rank j)
       (i : Fin pa.nN) (hout : 0 < outflow pa v k i) :
       { L : List (Fin pa.nN) //
         L.head? = some i ∧
         (∃ b : Fin pa.nB, L.getLast (by ...) = pa.B b) ∧
         (consecutive pairs are positive-flow edges) ∧
         L.Nodup }
   ```
   defined by well-founded recursion on `fwdMeasure pa rank i`. At each
   step: if `i = B b` for some `b`, return `[i]`; otherwise use
   `pos_outflow_of_pos_inflow_not_B` ... wait, we need to start from
   positive *outflow*, recurse via `forward_step`, and re-establish
   positive outflow at the successor by `pos_outflow_of_pos_inflow_not_B`
   (since the successor has positive inflow and is not a beneficiary —
   actually it *might* be a beneficiary, in which case we stop).
   Symmetric for backward.

3. **Path indicator and `IsValidPath`**: build `pE'` as the indicator
   of edges traversed by the concatenated walk; build `pRank'` from
   the position index along the walk. Discharge the seven `IsValidPath`
   conjuncts; injectivity of `S`/`T`/`B` (or just `S` and `B`) is
   needed for the unique source / sink characterization.

   **Status**: `forwardWalk` and `backwardWalk` are defined as
   `noncomputable` lists via well-founded recursion; the remaining work
   is the substantial bookkeeping to prove their structural properties
   (head/last/edges/nodup) and to build `pE'` and `pRank'` and discharge
   the seven `IsValidPath` conjuncts.

4. **`pb.hpE_complete`** then yields a path index `p : Fin pb.nP`.

5. **Bottleneck subtraction**: `δ := min { F i j k | (i,j) on path }`.
   Subtract `δ * pb.pE p` from the path commodity; flow stays
   feasible (conservation maintained at every internal node, demand
   for `B b` reduced by exactly `δ`); rank witness is inherited.
   Inductive hypothesis applied to `(F', R)` yields `x'`; set
   `x := x' + δ · 𝟙_{p}`.

6. **Multi-commodity lift**: apply the single-commodity result for
   each `k : Fin pb.nK` independently.
-/

-- ============================================================================
-- § Walk construction via rank-based well-founded recursion
-- ============================================================================

namespace FlowDecomp

variable (pa : P20.a.Params) (v : P20.a.Vars)

/-- Maximum rank value over all nodes (plus 1). Used as a strict upper
bound for the rank-decreasing well-founded recursion. -/
noncomputable def maxRank (rank : Fin pa.nN → ℕ) : ℕ :=
  (Finset.univ : Finset (Fin pa.nN)).sup rank + 1

lemma rank_lt_maxRank (rank : Fin pa.nN → ℕ) (i : Fin pa.nN) :
    rank i < maxRank pa rank := by
  unfold maxRank
  have : rank i ≤ (Finset.univ : Finset (Fin pa.nN)).sup rank :=
    Finset.le_sup (f := rank) (Finset.mem_univ i)
  omega

/-- "Forward measure": `maxRank - rank v`. Strictly decreases when we step
forward along a positive-flow edge (since `rank` strictly increases). -/
noncomputable def fwdMeasure (rank : Fin pa.nN → ℕ) (i : Fin pa.nN) : ℕ :=
  maxRank pa rank - rank i

lemma fwdMeasure_lt
    (rank : Fin pa.nN → ℕ) (i j : Fin pa.nN) (hr : rank i < rank j) :
    fwdMeasure pa rank j < fwdMeasure pa rank i := by
  unfold fwdMeasure
  have hi := rank_lt_maxRank pa rank i
  have hj := rank_lt_maxRank pa rank j
  omega

/-- "Backward measure": `rank v`. Strictly decreases when we step
backward along a positive-flow edge. (Just `rank i` itself.) -/
lemma bwdMeasure_lt
    (rank : Fin pa.nN → ℕ) (i j : Fin pa.nN) (hr : rank i < rank j) :
    rank i < rank j := hr

/-- The edge predicate carried along walks: a positive-flow edge in the
support of commodity `k`. -/
def WalkEdge (pa : P20.a.Params) (v : P20.a.Vars) (k : Fin pa.nK)
    (u w : Fin pa.nN) : Prop :=
  pa.E u w = 1 ∧ 0 < v.F u.val w.val k.val

/-- In a list with pairwise strictly-increasing `rank`, every element's
rank is ≤ that of the last element. -/
lemma rank_le_last_of_pairwise {α : Type*} (rank : α → ℕ)
    (L : List α) (hne : L ≠ [])
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
def IsForwardWalk (pa : P20.a.Params) (v : P20.a.Vars) (k : Fin pa.nK)
    (rank : Fin pa.nN → ℕ) (i : Fin pa.nN) (L : List (Fin pa.nN)) : Prop :=
  L ≠ [] ∧
  L.head? = some i ∧
  (∀ hne : L ≠ [], ∃ b : Fin pa.nB, L.getLast hne = pa.B b) ∧
  L.IsChain (WalkEdge pa v k) ∧
  L.Pairwise (fun u w => rank u < rank w)

/-- The bundled invariant for a *reversed* backward walk ending at `j`.
The list is stored in reverse-traversal order: `head = j`, `last = supplier`,
and `IsChain (WalkEdge ·.swap)` holds (i.e., consecutive `(u, w)` in the
list satisfy `WalkEdge w u`, meaning `w → u` is a positive-flow edge).
The user reverses it via `.reverse` to obtain a forward-oriented walk. -/
def IsBackwardWalk (pa : P20.a.Params) (v : P20.a.Vars) (k : Fin pa.nK)
    (rank : Fin pa.nN → ℕ) (j : Fin pa.nN) (L : List (Fin pa.nN)) : Prop :=
  L ≠ [] ∧
  L.head? = some j ∧
  (∀ hne : L ≠ [], ∃ s : Fin pa.nS, L.getLast hne = pa.S s) ∧
  L.IsChain (fun u w => WalkEdge pa v k w u) ∧
  L.Pairwise (fun u w => rank w < rank u)

/-- **Forward walk (subtype-bundled).** Given a rank witness and a starting
node `i` that is either a beneficiary OR has positive outflow, returns a
list bundled with all structural invariants. The walk:
* starts at `i` (head),
* ends at some beneficiary `pa.B b` (last element),
* has positive-flow edges between consecutive elements (`Chain'`),
* has strictly increasing rank along the list (`Pairwise`), hence `Nodup`.

Well-founded via `fwdMeasure pa rank` (strictly decreases per step). -/
noncomputable def forwardWalk
    (h : WeakFeasible pa v) (k : Fin pa.nK)
    (rank : Fin pa.nN → ℕ)
    (hRank : ∀ i j : Fin pa.nN, pa.E i j = 1 → 0 < v.F i.val j.val k.val →
      rank i < rank j)
    (i : Fin pa.nN)
    (hi : (∃ b : Fin pa.nB, i = pa.B b) ∨ 0 < outflow pa v k i) :
    { L : List (Fin pa.nN) // IsForwardWalk pa v k rank i L } :=
  if hB : ∃ b : Fin pa.nB, i = pa.B b then
    ⟨[i], by
      refine ⟨List.cons_ne_nil _ _, rfl, ?_, List.isChain_singleton _,
        List.pairwise_singleton _ _⟩
      intro _
      obtain ⟨b, hb⟩ := hB
      exact ⟨b, by simp [hb]⟩⟩
  else by
    -- i is not a beneficiary, hence by hi must have positive outflow
    have hout : 0 < outflow pa v k i := by
      cases hi with
      | inl hB' => exact absurd hB' hB
      | inr h'  => exact h'
    have hex : ∃ j : Fin pa.nN, pa.E i j = 1 ∧ 0 < v.F i.val j.val k.val :=
      forward_step pa v h k i hout
    let j : Fin pa.nN := hex.choose
    have hEij : pa.E i j = 1 := hex.choose_spec.1
    have hFij : 0 < v.F i.val j.val k.val := hex.choose_spec.2
    have hr : rank i < rank j := hRank i j hEij hFij
    have hdec : fwdMeasure pa rank j < fwdMeasure pa rank i :=
      fwdMeasure_lt pa rank i j hr
    -- j is either a beneficiary, or has positive inflow → positive outflow.
    have hjnext : (∃ b : Fin pa.nB, j = pa.B b) ∨ 0 < outflow pa v k j := by
      by_cases hjB : ∃ b : Fin pa.nB, j = pa.B b
      · exact Or.inl hjB
      · push_neg at hjB
        have hjnotB : ∀ b : Fin pa.nB, j ≠ pa.B b := hjB
        have hjin : 0 < inflow pa v k j :=
          pos_inflow_of_pos_edge pa v h k i j hEij hFij
        obtain ⟨j', hEjj', hFjj'⟩ :=
          pos_outflow_of_pos_inflow_not_B pa v h k j hjin hjnotB
        exact Or.inr (pos_outflow_of_pos_edge pa v h k j j' hEjj' hFjj')
    let rest := forwardWalk h k rank hRank j hjnext
    refine ⟨i :: rest.val, ?_⟩
    obtain ⟨hne_rest, hhead_rest, hlast_rest, hchain_rest, hpair_rest⟩ :=
      rest.property
    refine ⟨List.cons_ne_nil _ _, rfl, ?_, ?_, ?_⟩
    · -- last element of (i :: rest.val) is a beneficiary
      intro _
      -- since rest.val ≠ [], getLast (i :: rest.val) = getLast rest.val
      have : (i :: rest.val).getLast (List.cons_ne_nil _ _) =
             rest.val.getLast hne_rest :=
        List.getLast_cons hne_rest
      rw [this]
      exact hlast_rest hne_rest
    · -- IsChain (i :: rest.val)
      rw [List.isChain_cons]
      refine ⟨?_, hchain_rest⟩
      -- head? of rest.val = some j (from hhead_rest), so we need WalkEdge i j
      intro y hy
      have hy' : rest.val.head? = some y := hy
      rw [hhead_rest] at hy'
      have hyj : y = j := (Option.some.inj hy').symm
      subst hyj
      exact ⟨hEij, hFij⟩
    · -- Pairwise rank-increasing on (i :: rest.val):
      -- need ∀ y ∈ rest.val, rank i < rank y, and Pairwise rest.val
      rw [List.pairwise_cons]
      refine ⟨?_, hpair_rest⟩
      intro y hymem
      -- Goal: rank i < rank y. Use rank i < rank j and rank j ≤ rank y.
      -- The first element of rest.val is j (by hhead_rest).
      -- For non-head elements of rest, pairwise gives rank j < rank y.
      -- For y = j (head), rank j ≤ rank j trivially.
      have hjy : rank j ≤ rank y := by
        -- destruct rest.val into head/tail
        rcases hL : rest.val with _ | ⟨a, as⟩
        · exact absurd hL hne_rest
        · -- head? gives a = j
          have ha : a = j := by
            rw [hL] at hhead_rest
            simpa [List.head?] using hhead_rest
          subst ha
          rw [hL] at hymem
          rcases List.mem_cons.mp hymem with rfl | hyas
          · exact le_refl _
          · have hp : rest.val.Pairwise (fun u w => rank u < rank w) := hpair_rest
            rw [hL, List.pairwise_cons] at hp
            exact (hp.1 _ hyas).le
      exact lt_of_lt_of_le hr hjy
termination_by fwdMeasure pa rank i

/-- **Backward walk (subtype-bundled, reversed orientation).** Symmetric
to `forwardWalk`. The list is stored in *reverse traversal order*: head
is `j`, last is the supplier, and the chain predicate is `WalkEdge w u`
(i.e., the actual flow edge goes `w → u`). Take `.reverse` of the list
to obtain forward orientation.

Given a rank witness and a node `j` that is either a supplier OR has
positive inflow, returns a list bundled with all structural invariants:
* head is `j`,
* last is some supplier `pa.S s`,
* has positive-flow edges (in reverse direction) between consecutive
  elements,
* has strictly *decreasing* rank along the list, hence `Nodup`.

Well-founded via `rank j` (strictly decreases per step). -/
noncomputable def backwardWalk
    (h : WeakFeasible pa v) (k : Fin pa.nK)
    (rank : Fin pa.nN → ℕ)
    (hRank : ∀ i j : Fin pa.nN, pa.E i j = 1 → 0 < v.F i.val j.val k.val →
      rank i < rank j)
    (j : Fin pa.nN)
    (hj : (∃ s : Fin pa.nS, j = pa.S s) ∨ 0 < inflow pa v k j) :
    { L : List (Fin pa.nN) // IsBackwardWalk pa v k rank j L } :=
  if hS : ∃ s : Fin pa.nS, j = pa.S s then
    ⟨[j], by
      refine ⟨List.cons_ne_nil _ _, rfl, ?_, List.isChain_singleton _,
        List.pairwise_singleton _ _⟩
      intro _
      obtain ⟨s, hs⟩ := hS
      exact ⟨s, by simp [hs]⟩⟩
  else by
    -- j is not a supplier, hence by hj must have positive inflow
    have hin : 0 < inflow pa v k j := by
      cases hj with
      | inl hS' => exact absurd hS' hS
      | inr h'  => exact h'
    have hex : ∃ i : Fin pa.nN, pa.E i j = 1 ∧ 0 < v.F i.val j.val k.val :=
      backward_step pa v h k j hin
    let i : Fin pa.nN := hex.choose
    have hEij : pa.E i j = 1 := hex.choose_spec.1
    have hFij : 0 < v.F i.val j.val k.val := hex.choose_spec.2
    have hr : rank i < rank j := hRank i j hEij hFij
    -- i is either a supplier, or has positive outflow → positive inflow.
    have hinext : (∃ s : Fin pa.nS, i = pa.S s) ∨ 0 < inflow pa v k i := by
      by_cases hiS : ∃ s : Fin pa.nS, i = pa.S s
      · exact Or.inl hiS
      · push_neg at hiS
        have hinotS : ∀ s : Fin pa.nS, i ≠ pa.S s := hiS
        have hiout : 0 < outflow pa v k i :=
          pos_outflow_of_pos_edge pa v h k i j hEij hFij
        obtain ⟨i', hEi'i, hFi'i⟩ :=
          pos_inflow_of_pos_outflow_not_S pa v h k i hiout hinotS
        exact Or.inr (pos_inflow_of_pos_edge pa v h k i' i hEi'i hFi'i)
    let rest := backwardWalk h k rank hRank i hinext
    refine ⟨j :: rest.val, ?_⟩
    obtain ⟨hne_rest, hhead_rest, hlast_rest, hchain_rest, hpair_rest⟩ :=
      rest.property
    refine ⟨List.cons_ne_nil _ _, rfl, ?_, ?_, ?_⟩
    · -- last element of (j :: rest.val) is a supplier
      intro _
      have hgl : (j :: rest.val).getLast (List.cons_ne_nil _ _) =
             rest.val.getLast hne_rest :=
        List.getLast_cons hne_rest
      rw [hgl]
      exact hlast_rest hne_rest
    · -- IsChain (j :: rest.val) for (fun u w => WalkEdge pa v k w u)
      rw [List.isChain_cons]
      refine ⟨?_, hchain_rest⟩
      intro y hy
      have hy' : rest.val.head? = some y := hy
      rw [hhead_rest] at hy'
      have hyi : y = i := (Option.some.inj hy').symm
      subst hyi
      -- Need WalkEdge i j (i.e., E i j = 1 ∧ pos flow)
      exact ⟨hEij, hFij⟩
    · -- Pairwise rank-decreasing on (j :: rest.val):
      -- need ∀ y ∈ rest.val, rank y < rank j, and Pairwise rest.val
      rw [List.pairwise_cons]
      refine ⟨?_, hpair_rest⟩
      intro y hymem
      -- rank y ≤ rank i < rank j
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

-- ============================================================================
-- § Path concatenation and extraction (forward + backward walk)
-- ============================================================================

/-- For a positive-flow edge `(i, j)`, the source endpoint `i` is
either a supplier or has positive inflow. (If not a supplier, then by
flow conservation at `i` — which is a transshipment node since `i` has
positive outflow and so cannot be a beneficiary — `i` has positive
inflow.) -/
lemma pos_edge_source_is_supplier_or_pos_inflow
    (h : WeakFeasible pa v) (k : Fin pa.nK) (i j : Fin pa.nN)
    (hE : pa.E i j = 1) (hF : 0 < v.F i.val j.val k.val) :
    (∃ s : Fin pa.nS, i = pa.S s) ∨ 0 < inflow pa v k i := by
  classical
  by_cases hiS : ∃ s : Fin pa.nS, i = pa.S s
  · exact Or.inl hiS
  · push_neg at hiS
    have hinotS : ∀ s : Fin pa.nS, i ≠ pa.S s := hiS
    have hiout : 0 < outflow pa v k i :=
      pos_outflow_of_pos_edge pa v h k i j hE hF
    obtain ⟨i', hEi'i, hFi'i⟩ :=
      pos_inflow_of_pos_outflow_not_S pa v h k i hiout hinotS
    exact Or.inr (pos_inflow_of_pos_edge pa v h k i' i hEi'i hFi'i)

/-- For a positive-flow edge `(i, j)`, the destination endpoint `j` is
either a beneficiary or has positive outflow. (If not a beneficiary,
then by flow conservation at `j` — a transshipment node — `j` has
positive outflow.) -/
lemma pos_edge_dest_is_beneficiary_or_pos_outflow
    (h : WeakFeasible pa v) (k : Fin pa.nK) (i j : Fin pa.nN)
    (hE : pa.E i j = 1) (hF : 0 < v.F i.val j.val k.val) :
    (∃ b : Fin pa.nB, j = pa.B b) ∨ 0 < outflow pa v k j := by
  classical
  by_cases hjB : ∃ b : Fin pa.nB, j = pa.B b
  · exact Or.inl hjB
  · push_neg at hjB
    have hjnotB : ∀ b : Fin pa.nB, j ≠ pa.B b := hjB
    have hjin : 0 < inflow pa v k j :=
      pos_inflow_of_pos_edge pa v h k i j hE hF
    obtain ⟨j', hEjj', hFjj'⟩ :=
      pos_outflow_of_pos_inflow_not_B pa v h k j hjin hjnotB
    exact Or.inr (pos_outflow_of_pos_edge pa v h k j j' hEjj' hFjj')

/-- Concatenated walk from a supplier to a beneficiary, obtained by
prepending the reverse of a backward walk to a forward walk. Given a
positive-flow edge `(i, j)`, we backward-walk from `i` to a supplier
`S s` (yielding a reversed list with head `i`), and forward-walk from
`j` to a beneficiary `B b` (yielding a list with head `j`); the
concatenation is `(bwd).reverse ++ fwd`. -/
noncomputable def concatenatedWalk
    (h : WeakFeasible pa v) (k : Fin pa.nK)
    (rank : Fin pa.nN → ℕ)
    (hRank : ∀ i j : Fin pa.nN, pa.E i j = 1 → 0 < v.F i.val j.val k.val →
      rank i < rank j)
    (i j : Fin pa.nN)
    (hE : pa.E i j = 1) (hF : 0 < v.F i.val j.val k.val) :
    List (Fin pa.nN) :=
  let bwd := backwardWalk pa v h k rank hRank i
    (pos_edge_source_is_supplier_or_pos_inflow pa v h k i j hE hF)
  let fwd := forwardWalk pa v h k rank hRank j
    (pos_edge_dest_is_beneficiary_or_pos_outflow pa v h k i j hE hF)
  bwd.val.reverse ++ fwd.val

end FlowDecomp

-- ============================================================================
-- § Path extraction: build `pE'`, `pRank'`, discharge `IsValidPath`
-- ============================================================================

namespace FlowDecomp

/-- `(u, w)` is a consecutive pair in `L`. -/
def Consec {α : Type*} (L : List α) (u w : α) : Prop :=
  ∃ pre suf : List α, L = pre ++ u :: w :: suf

lemma consec_left_mem {α : Type*} {L : List α} {u w : α}
    (h : Consec L u w) : u ∈ L := by
  obtain ⟨pre, suf, rfl⟩ := h; simp

lemma consec_right_mem {α : Type*} {L : List α} {u w : α}
    (h : Consec L u w) : w ∈ L := by
  obtain ⟨pre, suf, rfl⟩ := h; simp

/-- The chain predicate forces the relation to hold on every consecutive pair. -/
lemma consec_chain {α : Type*} {R : α → α → Prop} {L : List α} {u w : α}
    (hch : L.IsChain R) (h : Consec L u w) : R u w := by
  obtain ⟨pre, suf, rfl⟩ := h
  rw [List.isChain_append] at hch
  rcases hch with ⟨_, hch2, _⟩
  rw [List.isChain_cons_cons] at hch2
  exact hch2.1

/-- In a list `pre ++ u :: w :: suf`, the position of `u` is `pre.length`,
and the position of `w` is `pre.length + 1`. We use this to derive
uniqueness facts. -/
lemma getElem?_consec_left {α : Type*} (pre suf : List α) (u w : α) :
    (pre ++ u :: w :: suf)[pre.length]? = some u := by
  have hL : pre ++ u :: w :: suf = pre ++ [u] ++ (w :: suf) := by simp
  rw [hL]
  rw [List.getElem?_append_left (by simp)]
  rw [List.getElem?_append_right (by simp)]
  simp

lemma getElem?_consec_right {α : Type*} (pre suf : List α) (u w : α) :
    (pre ++ u :: w :: suf)[pre.length + 1]? = some w := by
  have hL : pre ++ u :: w :: suf = (pre ++ [u]) ++ (w :: suf) := by simp
  rw [hL]
  rw [List.getElem?_append_right (by simp)]
  simp

/-- Helper: if `L = pre ++ u :: w :: suf` and `L.Nodup`, then the unique
position of `u` in `L` is `pre.length`. -/
lemma getElem?_eq_some_iff_unique_of_nodup {α : Type*} {L : List α}
    (hnd : L.Nodup) {u : α} {n : ℕ}
    (hn : L[n]? = some u) {m : ℕ} (hm : L[m]? = some u) : n = m := by
  by_contra hne
  -- Two distinct indices both pointing at u contradict Nodup.
  rw [List.getElem?_eq_some_iff] at hn hm
  obtain ⟨hnL, h1⟩ := hn
  obtain ⟨hmL, h2⟩ := hm
  exact hne (List.Nodup.getElem_inj_iff hnd |>.mp (h1.trans h2.symm))

lemma consec_pred_unique {α : Type*} {L : List α} (hnd : L.Nodup)
    {u₁ u₂ w : α} (h₁ : Consec L u₁ w) (h₂ : Consec L u₂ w) : u₁ = u₂ := by
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

lemma consec_succ_unique {α : Type*} {L : List α} (hnd : L.Nodup)
    {u w₁ w₂ : α} (h₁ : Consec L u w₁) (h₂ : Consec L u w₂) : w₁ = w₂ := by
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
lemma consec_no_pred_head {α : Type*} {a : α} {as : List α}
    (hnd : (a :: as).Nodup) : ∀ u, ¬ Consec (a :: as) u a := by
  intro u ⟨pre, suf, hL⟩
  rw [List.nodup_cons] at hnd
  -- a appears at position 0; also at position pre.length + 1 in pre ++ u :: a :: suf
  have h0 : (a :: as)[0]? = some a := by simp
  have h1 : (a :: as)[pre.length + 1]? = some a := by
    rw [hL]; exact getElem?_consec_right _ _ _ _
  have heq : 0 = pre.length + 1 := by
    -- need Nodup for the index lemma
    apply getElem?_eq_some_iff_unique_of_nodup
    · rw [List.nodup_cons]; exact hnd
    · exact h0
    · exact h1
  omega

/-- The last element of a `Nodup` list has no successor consecutive to it. -/
lemma consec_no_succ_last {α : Type*} {L : List α} (hne : L ≠ [])
    (hnd : L.Nodup) : ∀ w, ¬ Consec L (L.getLast hne) w := by
  intro w ⟨pre, suf, hL⟩
  set u := L.getLast hne with hu_def
  -- u appears at L.length - 1, and also at pre.length in pre ++ u :: w :: suf.
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

/-- If two consecutive elements are at positions `n` and `n+1` of `L`,
then they form a `Consec` pair. -/
lemma consec_at_pos {α : Type*} {L : List α} {a b : α} {n : ℕ}
    (hn : L[n]? = some a) (hsn : L[n + 1]? = some b) : Consec L a b := by
  rw [List.getElem?_eq_some_iff] at hn hsn
  obtain ⟨hnL, ha⟩ := hn
  obtain ⟨hsnL, hb⟩ := hsn
  refine ⟨L.take n, L.drop (n + 2), ?_⟩
  -- L = L.take n ++ a :: b :: L.drop (n+2)
  have h1 : L = L.take n ++ L.drop n := (List.take_append_drop n L).symm
  have h2 : L.drop n = a :: L.drop (n + 1) := by
    rw [← List.getElem_cons_drop hnL, ha]
  have h3 : L.drop (n + 1) = b :: L.drop (n + 2) := by
    rw [← List.getElem_cons_drop hsnL, hb]
  calc L = L.take n ++ L.drop n := h1
    _ = L.take n ++ a :: L.drop (n + 1) := by rw [h2]
    _ = L.take n ++ a :: b :: L.drop (n + 2) := by rw [h3]

/-- If `v ∈ L` and `v ≠ L.head`, then `v` has a predecessor in `L`. -/
lemma exists_consec_pred {α : Type*} {L : List α} (hne : L ≠ [])
    {v : α} (hv : v ∈ L) (hvhead : v ≠ L.head hne) :
    ∃ u, Consec L u v := by
  obtain ⟨n, hnL, hn⟩ := List.mem_iff_getElem.mp hv
  -- n must be ≥ 1: if n = 0, then v = L[0] = L.head.
  rcases n with _ | n
  · exfalso
    apply hvhead
    rw [← hn]
    rcases L with _ | ⟨a, as⟩
    · exact absurd rfl hne
    · simp
  · -- n+1 ≥ 1, predecessor is at position n.
    have hnL' : n < L.length := Nat.lt_of_succ_lt hnL
    refine ⟨L[n], ?_⟩
    apply consec_at_pos (n := n)
    · rw [List.getElem?_eq_some_iff]; exact ⟨hnL', rfl⟩
    · rw [List.getElem?_eq_some_iff]; exact ⟨hnL, hn⟩

/-- If `v ∈ L` and `v ≠ L.getLast`, then `v` has a successor in `L`. -/
lemma exists_consec_succ {α : Type*} {L : List α} (hne : L ≠ [])
    {v : α} (hv : v ∈ L) (hvlast : v ≠ L.getLast hne) :
    ∃ w, Consec L v w := by
  obtain ⟨n, hnL, hn⟩ := List.mem_iff_getElem.mp hv
  -- n < L.length - 1: if n = L.length - 1, then v = L.getLast.
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

-- ============================================================================
-- § Building `pE'` and `pRank'` from a walk and discharging `IsValidPath`
-- ============================================================================

variable {nN nS nB : ℕ}

open scoped Classical in
/-- `pE' u w := 1` iff `(u,w)` is consecutive in `L`, else `0`. -/
noncomputable def pathIndicator (L : List (Fin nN)) (u w : Fin nN) : ℤ :=
  if Consec L u w then 1 else 0

/-- Position of `v` in `L`. -/
noncomputable def pathRank (L : List (Fin nN)) (v : Fin nN) : ℕ :=
  L.idxOf v

lemma pathIndicator_eq_one_iff (L : List (Fin nN)) (u w : Fin nN) :
    pathIndicator L u w = 1 ↔ Consec L u w := by
  classical
  unfold pathIndicator
  by_cases h : Consec L u w
  · simp [h]
  · simp [h]

lemma pathIndicator_eq_zero_iff (L : List (Fin nN)) (u w : Fin nN) :
    pathIndicator L u w = 0 ↔ ¬ Consec L u w := by
  classical
  unfold pathIndicator
  by_cases h : Consec L u w
  · simp [h]
  · simp [h]

/-- `pathIndicator` is binary. -/
lemma pathIndicator_binary (L : List (Fin nN)) (u w : Fin nN) :
    pathIndicator L u w = 0 ∨ pathIndicator L u w = 1 := by
  classical
  unfold pathIndicator
  by_cases h : Consec L u w
  · right; simp [h]
  · left; simp [h]

/-- Sum over predecessors equals 1 iff there is a predecessor. -/
lemma sum_pathIndicator_in_eq (L : List (Fin nN)) (hnd : L.Nodup)
    (v : Fin nN) :
    ∑ i : Fin nN, pathIndicator L i v =
      (@ite ℤ (∃ u, Consec L u v) (Classical.dec _) 1 0) := by
  classical
  classical
  by_cases h : ∃ u, Consec L u v
  · obtain ⟨u, hu⟩ := h
    rw [if_pos (⟨u, hu⟩ : ∃ u, Consec L u v)]
    have hfilter : (Finset.univ : Finset (Fin nN)).filter
        (fun i => Consec L i v) = {u} := by
      ext x
      simp only [Finset.mem_filter, Finset.mem_univ, true_and, Finset.mem_singleton]
      exact ⟨fun hx => consec_pred_unique hnd hx hu, fun hx => hx ▸ hu⟩
    have heq : ∑ i : Fin nN, pathIndicator L i v
        = ∑ i ∈ (Finset.univ : Finset (Fin nN)).filter (fun i => Consec L i v),
            (1 : ℤ) := by
      unfold pathIndicator
      rw [← Finset.sum_filter]
    rw [heq, hfilter]; simp
  · rw [if_neg h]
    push_neg at h
    have hzero : ∀ i : Fin nN, pathIndicator L i v = 0 := fun i => by
      unfold pathIndicator; simp [h i]
    simp [hzero]

lemma sum_pathIndicator_out_eq (L : List (Fin nN)) (hnd : L.Nodup)
    (v : Fin nN) :
    ∑ j : Fin nN, pathIndicator L v j =
      (@ite ℤ (∃ w, Consec L v w) (Classical.dec _) 1 0) := by
  classical
  classical
  by_cases h : ∃ w, Consec L v w
  · obtain ⟨w, hw⟩ := h
    rw [if_pos (⟨w, hw⟩ : ∃ w, Consec L v w)]
    have hfilter : (Finset.univ : Finset (Fin nN)).filter
        (fun j => Consec L v j) = {w} := by
      ext x
      simp only [Finset.mem_filter, Finset.mem_univ, true_and, Finset.mem_singleton]
      exact ⟨fun hx => consec_succ_unique hnd hx hw, fun hx => hx ▸ hw⟩
    have heq : ∑ j : Fin nN, pathIndicator L v j
        = ∑ j ∈ (Finset.univ : Finset (Fin nN)).filter (fun j => Consec L v j),
            (1 : ℤ) := by
      unfold pathIndicator
      rw [← Finset.sum_filter]
    rw [heq, hfilter]; simp
  · rw [if_neg h]
    push_neg at h
    have hzero : ∀ j : Fin nN, pathIndicator L v j = 0 := fun j => by
      unfold pathIndicator; simp [h j]
    simp [hzero]

/-- In-degree at most 1. -/
lemma sum_pathIndicator_in_le_one (L : List (Fin nN)) (hnd : L.Nodup)
    (v : Fin nN) :
    ∑ i : Fin nN, pathIndicator L i v ≤ 1 := by
  rw [sum_pathIndicator_in_eq L hnd v]
  by_cases h : ∃ u, Consec L u v <;> simp [h]

lemma sum_pathIndicator_out_le_one (L : List (Fin nN)) (hnd : L.Nodup)
    (v : Fin nN) :
    ∑ j : Fin nN, pathIndicator L v j ≤ 1 := by
  rw [sum_pathIndicator_out_eq L hnd v]
  by_cases h : ∃ w, Consec L v w <;> simp [h]

/-- `Consec` implies the rank (= idxOf) increases by 1. -/
lemma pathRank_consec (L : List (Fin nN)) (hnd : L.Nodup)
    {u w : Fin nN} (hc : Consec L u w) :
    pathRank L w = pathRank L u + 1 := by
  obtain ⟨pre, suf, hL⟩ := hc
  unfold pathRank
  -- idxOf u in L = pre.length, idxOf w in L = pre.length + 1
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

/-- **Path extraction (abstract).** Given a `Nodup` list `L : List (Fin nN)`
with first element a supplier `S s`, last element a beneficiary `B b`,
and a chain predicate making consecutive elements positive-graph-edges
(`E u w = 1`), we can build `pE'` and `pRank'` satisfying `IsValidPath`. -/
lemma exists_valid_path_of_walk
    {nN nS nB : ℕ}
    (S : Fin nS → Fin nN) (B : Fin nB → Fin nN)
    (E : Fin nN → Fin nN → ℤ)
    (hE_bin : ∀ i j : Fin nN, E i j = 0 ∨ E i j = 1)
    (hSTB_disj_SB : ∀ (s : Fin nS) (b : Fin nB), S s ≠ B b)
    (L : List (Fin nN))
    (hne : L ≠ [])
    (hnd : L.Nodup)
    (hchain : L.IsChain (fun u w => E u w = 1))
    (s : Fin nS) (hs : L.head hne = S s)
    (b : Fin nB) (hb : L.getLast hne = B b) :
    P20.b.IsValidPath S B E (pathIndicator L) (pathRank L) := by
  classical
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · -- (1) binary
    intro i j
    rcases pathIndicator_binary L i j with h | h
    · exact Or.inl h
    · exact Or.inr h
  · -- (2) pE' i j ≤ E i j
    intro i j
    by_cases hc : Consec L i j
    · have h1 : pathIndicator L i j = 1 := (pathIndicator_eq_one_iff L i j).mpr hc
      have hE1 : E i j = 1 := consec_chain (R := fun u w => E u w = 1) hchain hc
      rw [h1, hE1]
    · have h0 : pathIndicator L i j = 0 := (pathIndicator_eq_zero_iff L i j).mpr hc
      rw [h0]
      rcases hE_bin i j with hE0 | hE1
      · rw [hE0]
      · rw [hE1]; norm_num
  · -- (3) in-degree ≤ 1
    intro v; exact sum_pathIndicator_in_le_one L hnd v
  · -- (4) out-degree ≤ 1
    intro v; exact sum_pathIndicator_out_le_one L hnd v
  · -- (5) unique source: head of L = S s.
    refine ⟨s, ?_, ?_, ?_⟩
    · -- pOut(S s) = 1 (S s has a successor in L)
      rw [sum_pathIndicator_out_eq L hnd]
      have hsucc : ∃ w, Consec L (S s) w := by
        apply exists_consec_succ hne
        · rw [← hs]; exact List.head_mem hne
        · -- S s ≠ getLast L because getLast = B b and S s ≠ B b
          rw [hb]; exact hSTB_disj_SB s b
      rw [if_pos hsucc]
    · -- pIn(S s) = 0 (head has no predecessor)
      rw [sum_pathIndicator_in_eq L hnd]
      have hno : ¬ ∃ u, Consec L u (S s) := by
        rintro ⟨u, hu⟩
        -- Use indices: S s = L[0] (head). hu says S s appears at position ≥ 1.
        -- Together with Nodup, contradiction.
        obtain ⟨pre, suf, hL⟩ := hu
        have h_head : L[0]? = some (S s) := by
          rw [List.getElem?_eq_some_iff]
          refine ⟨List.length_pos_iff.mpr hne, ?_⟩
          rw [← hs]
          rw [List.head_eq_getElem]
        have h_pos : L[pre.length + 1]? = some (S s) := by
          rw [hL]; exact getElem?_consec_right _ _ _ _
        have heq : 0 = pre.length + 1 :=
          getElem?_eq_some_iff_unique_of_nodup hnd h_head h_pos
        omega
      rw [if_neg hno]
    · -- uniqueness
      intro v ⟨hpout, hpin⟩
      -- v has pOut = 1 and pIn = 0. The latter means no predecessor.
      -- v ∈ L (otherwise pOut = 0 since no consecutive can start at v).
      have hpos_succ : ∃ w, Consec L v w := by
        rw [sum_pathIndicator_out_eq L hnd] at hpout
        by_cases h : ∃ w, Consec L v w
        · exact h
        · rw [if_neg h] at hpout; exact absurd hpout (by norm_num)
      have hno_pred : ¬ ∃ u, Consec L u v := by
        rw [sum_pathIndicator_in_eq L hnd] at hpin
        intro h
        rw [if_pos h] at hpin
        norm_num at hpin
      have hv_mem : v ∈ L := (by obtain ⟨w, hw⟩ := hpos_succ; exact consec_left_mem hw)
      -- v has no predecessor; if v ≠ head, exists_consec_pred gives contradiction.
      by_contra hne_v
      have hv_not_head : v ≠ L.head hne := by
        rw [hs]; exact hne_v
      exact hno_pred (exists_consec_pred hne hv_mem hv_not_head)
  · -- (6) unique sink: last of L = B b.
    refine ⟨b, ?_, ?_, ?_⟩
    · -- pIn(B b) = 1 (B b has a predecessor)
      rw [sum_pathIndicator_in_eq L hnd]
      have hpred : ∃ u, Consec L u (B b) := by
        apply exists_consec_pred hne
        · rw [← hb]; exact List.getLast_mem hne
        · -- B b is the last; we need to show B b ≠ head = S s
          rw [hs]
          exact (hSTB_disj_SB s b).symm
      rw [if_pos hpred]
    · -- pOut(B b) = 0 (last has no successor)
      rw [sum_pathIndicator_out_eq L hnd]
      have hno : ¬ ∃ w, Consec L (B b) w := by
        rintro ⟨w, hw⟩
        rw [← hb] at hw
        exact consec_no_succ_last hne hnd w hw
      rw [if_neg hno]
    · -- uniqueness
      intro v ⟨hpin, hpout⟩
      have hpos_pred : ∃ u, Consec L u v := by
        rw [sum_pathIndicator_in_eq L hnd] at hpin
        by_cases h : ∃ u, Consec L u v
        · exact h
        · rw [if_neg h] at hpin; exact absurd hpin (by norm_num)
      have hno_succ : ¬ ∃ w, Consec L v w := by
        rw [sum_pathIndicator_out_eq L hnd] at hpout
        intro h
        rw [if_pos h] at hpout
        norm_num at hpout
      have hv_mem : v ∈ L := (by obtain ⟨u, hu⟩ := hpos_pred; exact consec_right_mem hu)
      by_contra hne_v
      have hv_not_last : v ≠ L.getLast hne := by
        rw [hb]; exact hne_v
      exact hno_succ (exists_consec_succ hne hv_mem hv_not_last)
  · -- (7) rank monotonicity
    intro i j hij
    have hc : Consec L i j := (pathIndicator_eq_one_iff L i j).mp hij
    exact pathRank_consec L hnd hc

-- ============================================================================
-- § Main lemma: extracting a valid path from a positive-flow edge
-- ============================================================================

variable (pa : P20.a.Params) (v : P20.a.Vars)

/-- The concatenation of a (reversed) backward walk and a forward walk forms
a list `(bwd).reverse ++ fwd` whose head is the supplier (last of the
backward walk pre-reverse), whose last is the beneficiary (last of the
forward walk), and which is `Nodup` with positive-flow-edges connecting
consecutive elements.

This is the central technical lemma used to discharge `IsValidPath`. -/
lemma exists_valid_path_in_pos_support
    (h : WeakFeasible pa v) (k : Fin pa.nK)
    (rank : Fin pa.nN → ℕ)
    (hRank : ∀ i j : Fin pa.nN, pa.E i j = 1 → 0 < v.F i.val j.val k.val →
      rank i < rank j)
    (i j : Fin pa.nN)
    (hE : pa.E i j = 1) (hF : 0 < v.F i.val j.val k.val) :
    ∃ (pE' : Fin pa.nN → Fin pa.nN → ℤ) (pRank' : Fin pa.nN → ℕ),
      P20.b.IsValidPath pa.S pa.B pa.E pE' pRank' ∧
      (∀ i j : Fin pa.nN, pE' i j = 1 → 0 < v.F i.val j.val k.val) := by
  classical
  -- Build the backward walk from i (ending at a supplier) and the forward
  -- walk from j (ending at a beneficiary).
  set bwd := backwardWalk pa v h k rank hRank i
    (pos_edge_source_is_supplier_or_pos_inflow pa v h k i j hE hF) with hbwd_def
  set fwd := forwardWalk pa v h k rank hRank j
    (pos_edge_dest_is_beneficiary_or_pos_outflow pa v h k i j hE hF) with hfwd_def
  obtain ⟨bne, bhead, blast, bchain, bpair⟩ := bwd.property
  obtain ⟨fne, fhead, flast, fchain, fpair⟩ := fwd.property
  -- The concatenated walk.
  let L := bwd.val.reverse ++ fwd.val
  -- Invariants of L.
  have hL_ne : L ≠ [] := by
    intro hh
    simp [L] at hh
    exact fne hh.2
  -- Chain: positive-flow edges on consecutive elements of L → (E = 1).
  -- Build chain on the `WalkEdge` predicate first.
  have hWalkChain : L.IsChain (WalkEdge pa v k) := by
    -- bwd.reverse has IsChain (WalkEdge pa v k) by reversing the swapped chain.
    have hbwd_rev : bwd.val.reverse.IsChain (WalkEdge pa v k) := by
      rw [List.isChain_reverse]
      exact bchain
    have hfwd_chain : fwd.val.IsChain (WalkEdge pa v k) := fchain
    -- The connecting edge: last of bwd.val.reverse = i; head of fwd.val = j.
    -- (Since bwd has head=i, bwd.reverse has last=i; fwd has head=j.)
    have hbwd_head : bwd.val.head bne = i := by
      have hh : bwd.val.head? = some i := bhead
      rw [List.head?_eq_some_head bne] at hh
      exact Option.some.inj hh
    have hfwd_head' : fwd.val.head fne = j := by
      have hh : fwd.val.head? = some j := fhead
      rw [List.head?_eq_some_head fne] at hh
      exact Option.some.inj hh
    -- Now combine using isChain_append.
    rw [List.isChain_append]
    refine ⟨hbwd_rev, hfwd_chain, ?_⟩
    intro x hx y hy
    -- x is bwd.reverse.getLast? = some i; y is fwd.head? = some j.
    have hxi : x = i := by
      rw [List.getLast?_reverse] at hx
      rw [bhead] at hx
      exact (Option.some.inj hx).symm
    have hyj : y = j := by
      rw [fhead] at hy
      exact (Option.some.inj hy).symm
    subst hxi; subst hyj
    exact ⟨hE, hF⟩
  -- Convert to chain on (E u w = 1).
  have hEChain : L.IsChain (fun u w => pa.E u w = 1) := by
    apply List.IsChain.imp _ hWalkChain
    intro u w hwe
    exact hwe.1
  -- Pairwise rank-strict-monotone along L (giving Nodup).
  -- L has the structure: bwd.reverse (which is rank-increasing) ++ fwd (rank-increasing)
  -- and the join point i → j has rank i < rank j.
  have hPair : L.Pairwise (fun u w => rank u < rank w) := by
    -- bwd.val has decreasing rank; bwd.val.reverse has increasing rank.
    have hbwd_rev_pair : bwd.val.reverse.Pairwise (fun u w => rank u < rank w) := by
      have := bpair  -- bwd.val.Pairwise (fun u w => rank w < rank u)
      have := List.pairwise_reverse.mpr this
      exact this
    -- fwd.val has increasing rank.
    have hfwd_pair : fwd.val.Pairwise (fun u w => rank u < rank w) := fpair
    -- The connecting condition: every x in bwd.reverse, every y in fwd, rank x < rank y.
    -- For x ∈ bwd.reverse (= elements of bwd), rank x ≤ rank i (bwd has rank-decreasing
    -- starting from i, so all elements have rank ≤ rank i).
    -- For y ∈ fwd, rank y ≥ rank j (fwd has rank-increasing starting from j).
    -- And rank i < rank j.
    have hri_lt_rj : rank i < rank j := hRank i j hE hF
    rw [List.pairwise_append]
    refine ⟨hbwd_rev_pair, hfwd_pair, ?_⟩
    intro x hx y hy
    have hx' : x ∈ bwd.val := List.mem_reverse.mp hx
    -- rank x ≤ rank i: bwd.val has head i, and is rank-decreasing (Pairwise: rank w < rank u
    -- where u is earlier than w means rank later < rank earlier, i.e., earlier has larger rank).
    have hxi : rank x ≤ rank i := by
      rcases hbv : bwd.val with _ | ⟨a, as⟩
      · rw [hbv] at hx'; simp at hx'
      · -- a = i (head)
        have ha : a = i := by
          have hh := bhead
          rw [hbv] at hh; simp at hh; exact hh
        subst ha
        rw [hbv] at hx'
        rcases List.mem_cons.mp hx' with h0 | h1
        · subst h0; exact le_refl _
        · -- x ∈ as; pairwise on (i :: as) gives rank x < rank i, so ≤
          have hp := bpair
          rw [hbv, List.pairwise_cons] at hp
          exact (hp.1 _ h1).le
    -- rank y ≥ rank j: fwd.val has head j, rank-increasing.
    have hjy : rank j ≤ rank y := by
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
    calc rank x ≤ rank i := hxi
      _ < rank j := hri_lt_rj
      _ ≤ rank y := hjy
  have hL_nd : L.Nodup := by
    rw [List.nodup_iff_pairwise_ne]
    apply List.Pairwise.imp (fun {a b} hab => ?_) hPair
    intro habab; exact absurd (habab ▸ hab) (lt_irrefl _)
  -- Head and last of L.
  have hbwd_rev_ne : bwd.val.reverse ≠ [] := by
    intro hh
    exact bne (List.reverse_eq_nil_iff.mp hh)
  -- Compute L.head?, L.getLast? and show they hit S s, B b respectively.
  have hL_head_eq : L.head hL_ne =
      (bwd.val.reverse ++ fwd.val).head hL_ne := rfl
  have hL_last_eq : L.getLast hL_ne =
      (bwd.val.reverse ++ fwd.val).getLast hL_ne := rfl
  have hL_head : ∃ s : Fin pa.nS, L.head hL_ne = pa.S s := by
    obtain ⟨s, hs⟩ := blast bne
    refine ⟨s, ?_⟩
    rw [hL_head_eq]
    rw [List.head_append_of_ne_nil hbwd_rev_ne]
    rw [List.head_reverse hbwd_rev_ne]
    exact hs
  have hL_last : ∃ b : Fin pa.nB, L.getLast hL_ne = pa.B b := by
    obtain ⟨b, hb⟩ := flast fne
    refine ⟨b, ?_⟩
    rw [hL_last_eq]
    rw [List.getLast_append_right fne]
    exact hb
  -- Apply the abstract lemma.
  obtain ⟨s, hs⟩ := hL_head
  obtain ⟨b, hb⟩ := hL_last
  refine ⟨pathIndicator L, pathRank L, ?_, ?_⟩
  · exact exists_valid_path_of_walk pa.S pa.B pa.E pa.hE_bin pa.hSTB_disj_SB
      L hL_ne hL_nd hEChain s hs b hb
  · intro u w huw
    have hc : Consec L u w := (pathIndicator_eq_one_iff L u w).mp huw
    have hwe : WalkEdge pa v k u w := consec_chain hWalkChain hc
    exact hwe.2

end FlowDecomp

-- ============================================================================
-- § Parameter matching (a-side ↔ b-side)
-- ============================================================================

/-- Bundled correspondence between an a-side parameter set `pa` and a
b-side parameter set `pb`. The `nN`, `nS`, `nB`, `nK` cardinalities and
the supplier/beneficiary/edge/E maps must agree. (We don't constrain
`nT`, `T`, `nP`, `pE`, etc., here; those are handled where needed.)

This is used to translate `IsValidPath`-style facts proved on `pa` to
facts on `pb`, in particular to apply `pb.hpE_complete`. -/
structure ParamsMatch (pa : P20.a.Params) (pb : P20.b.Params) : Prop where
  hN : pa.nN = pb.nN
  hS : pa.nS = pb.nS
  hB : pa.nB = pb.nB
  hK : pa.nK = pb.nK
  /-- Suppliers agree, modulo `Fin.cast`. -/
  hSeq : ∀ s : Fin pa.nS, Fin.cast hN (pa.S s) = pb.S (Fin.cast hS s)
  /-- Beneficiaries agree. -/
  hBeq : ∀ b : Fin pa.nB, Fin.cast hN (pa.B b) = pb.B (Fin.cast hB b)
  /-- Edges agree. -/
  hEeq : ∀ i j : Fin pa.nN,
    pa.E i j = pb.E (Fin.cast hN i) (Fin.cast hN j)

namespace FlowDecomp

variable (pa : P20.a.Params) (v : P20.a.Vars)

-- ============================================================================
-- § Path index extraction via `hpE_complete`
-- ============================================================================

/-- Translate a positive edge from a-side to b-side via a `ParamsMatch`. -/
private lemma pb_E_eq_one_of_pa
    {pb : P20.b.Params} (M : ParamsMatch pa pb)
    {i j : Fin pa.nN} (hE : pa.E i j = 1) :
    pb.E (Fin.cast M.hN i) (Fin.cast M.hN j) = 1 := by
  rw [← M.hEeq]; exact hE

/-- Auxiliary: transport an a-side `IsValidPath` `(pE', pRank')` to b-side
indices via `Fin.cast`. -/
noncomputable def transportPathE
    {pa : P20.a.Params} {pb : P20.b.Params} (M : ParamsMatch pa pb)
    (pE' : Fin pa.nN → Fin pa.nN → ℤ) :
    Fin pb.nN → Fin pb.nN → ℤ :=
  fun i j => pE' (Fin.cast M.hN.symm i) (Fin.cast M.hN.symm j)

noncomputable def transportPathRank
    {pa : P20.a.Params} {pb : P20.b.Params} (M : ParamsMatch pa pb)
    (pRank' : Fin pa.nN → ℕ) :
    Fin pb.nN → ℕ :=
  fun i => pRank' (Fin.cast M.hN.symm i)

lemma transportPath_isValidPath
    {pa : P20.a.Params} {pb : P20.b.Params} (M : ParamsMatch pa pb)
    {pE' : Fin pa.nN → Fin pa.nN → ℤ} {pRank' : Fin pa.nN → ℕ}
    (hVP : P20.b.IsValidPath pa.S pa.B pa.E pE' pRank') :
    P20.b.IsValidPath pb.S pb.B pb.E
      (transportPathE M pE') (transportPathRank M pRank') := by
  classical
  obtain ⟨hbin, hle, hin1, hout1, ⟨s, hsout, hsin, hsuniq⟩,
          ⟨b, hbin1, hbout, hbuniq⟩, hrank⟩ := hVP
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · -- binary
    intro i j
    exact hbin (Fin.cast M.hN.symm i) (Fin.cast M.hN.symm j)
  · -- pE' ≤ E
    intro i j
    have h := hle (Fin.cast M.hN.symm i) (Fin.cast M.hN.symm j)
    have hEeq := M.hEeq (Fin.cast M.hN.symm i) (Fin.cast M.hN.symm j)
    -- Transport: pa.E (cast.symm i) (cast.symm j) = pb.E (cast (cast.symm i)) (cast (cast.symm j)) = pb.E i j
    simp only [Fin.cast_cast, Fin.cast_eq_self] at hEeq
    unfold transportPathE
    rw [hEeq] at h; exact h
  · -- in-degree ≤ 1: ∑_i pE_T i v ≤ 1
    intro w
    -- Reindex: ∑ i : Fin pb.nN, transport pE' i w = ∑ i : Fin pa.nN, pE' i (cast.symm w)
    have : ∑ i : Fin pb.nN, transportPathE M pE' i w
         = ∑ i : Fin pa.nN, pE' i (Fin.cast M.hN.symm w) := by
      apply Fintype.sum_equiv (Fin.castOrderIso M.hN.symm).toEquiv
      intro i
      simp [transportPathE]
    rw [this]; exact hin1 _
  · -- out-degree ≤ 1
    intro w
    have : ∑ j : Fin pb.nN, transportPathE M pE' w j
         = ∑ j : Fin pa.nN, pE' (Fin.cast M.hN.symm w) j := by
      apply Fintype.sum_equiv (Fin.castOrderIso M.hN.symm).toEquiv
      intro j; simp [transportPathE]
    rw [this]; exact hout1 _
  · -- unique source
    refine ⟨Fin.cast M.hS s, ?_, ?_, ?_⟩
    · -- pOut at pb.S (cast s) = 1
      have hSeq := M.hSeq s
      -- pb.S (Fin.cast M.hS s) = Fin.cast M.hN (pa.S s)
      rw [← hSeq]
      have : ∑ j : Fin pb.nN, transportPathE M pE' (Fin.cast M.hN (pa.S s)) j
           = ∑ j : Fin pa.nN, pE' (pa.S s) j := by
        apply Fintype.sum_equiv (Fin.castOrderIso M.hN.symm).toEquiv
        intro j
        simp [transportPathE]
      rw [this]; exact hsout
    · have hSeq := M.hSeq s
      rw [← hSeq]
      have : ∑ i : Fin pb.nN, transportPathE M pE' i (Fin.cast M.hN (pa.S s))
           = ∑ i : Fin pa.nN, pE' i (pa.S s) := by
        apply Fintype.sum_equiv (Fin.castOrderIso M.hN.symm).toEquiv
        intro i
        simp [transportPathE]
      rw [this]; exact hsin
    · -- uniqueness
      intro w ⟨hwout, hwin⟩
      -- Translate to pa side using cast.symm w.
      set w' : Fin pa.nN := Fin.cast M.hN.symm w with hw'def
      have hwout' : ∑ j : Fin pa.nN, pE' w' j = 1 := by
        have : ∑ j : Fin pb.nN, transportPathE M pE' w j
             = ∑ j : Fin pa.nN, pE' w' j := by
          apply Fintype.sum_equiv (Fin.castOrderIso M.hN.symm).toEquiv
          intro j; simp [transportPathE, hw'def]
        rw [this] at hwout; exact hwout
      have hwin' : ∑ i : Fin pa.nN, pE' i w' = 0 := by
        have : ∑ i : Fin pb.nN, transportPathE M pE' i w
             = ∑ i : Fin pa.nN, pE' i w' := by
          apply Fintype.sum_equiv (Fin.castOrderIso M.hN.symm).toEquiv
          intro i; simp [transportPathE, hw'def]
        rw [this] at hwin; exact hwin
      have hw'_eq : w' = pa.S s := hsuniq w' ⟨hwout', hwin'⟩
      -- Convert back: w = cast (pa.S s) = pb.S (cast s).
      have : w = Fin.cast M.hN (pa.S s) := by
        rw [← hw'_eq]
        simp [hw'def]
      rw [this, M.hSeq]
  · -- unique sink
    refine ⟨Fin.cast M.hB b, ?_, ?_, ?_⟩
    · have hBeq := M.hBeq b
      rw [← hBeq]
      have : ∑ i : Fin pb.nN, transportPathE M pE' i (Fin.cast M.hN (pa.B b))
           = ∑ i : Fin pa.nN, pE' i (pa.B b) := by
        apply Fintype.sum_equiv (Fin.castOrderIso M.hN.symm).toEquiv
        intro i; simp [transportPathE]
      rw [this]; exact hbin1
    · have hBeq := M.hBeq b
      rw [← hBeq]
      have : ∑ j : Fin pb.nN, transportPathE M pE' (Fin.cast M.hN (pa.B b)) j
           = ∑ j : Fin pa.nN, pE' (pa.B b) j := by
        apply Fintype.sum_equiv (Fin.castOrderIso M.hN.symm).toEquiv
        intro j; simp [transportPathE]
      rw [this]; exact hbout
    · intro w ⟨hwin, hwout⟩
      set w' : Fin pa.nN := Fin.cast M.hN.symm w with hw'def
      have hwin' : ∑ i : Fin pa.nN, pE' i w' = 1 := by
        have : ∑ i : Fin pb.nN, transportPathE M pE' i w
             = ∑ i : Fin pa.nN, pE' i w' := by
          apply Fintype.sum_equiv (Fin.castOrderIso M.hN.symm).toEquiv
          intro i; simp [transportPathE, hw'def]
        rw [this] at hwin; exact hwin
      have hwout' : ∑ j : Fin pa.nN, pE' w' j = 0 := by
        have : ∑ j : Fin pb.nN, transportPathE M pE' w j
             = ∑ j : Fin pa.nN, pE' w' j := by
          apply Fintype.sum_equiv (Fin.castOrderIso M.hN.symm).toEquiv
          intro j; simp [transportPathE, hw'def]
        rw [this] at hwout; exact hwout
      have hw'_eq : w' = pa.B b := hbuniq w' ⟨hwin', hwout'⟩
      have : w = Fin.cast M.hN (pa.B b) := by
        rw [← hw'_eq]; simp [hw'def]
      rw [this, M.hBeq]
  · -- rank monotonicity
    intro i j hij
    unfold transportPathE transportPathRank at *
    exact hrank _ _ hij

/-- **Path index extraction.** Given a positive-flow edge in commodity `k`,
extract a path index `p : Fin pb.nP` whose edge-set on b-side matches the
extracted abstract path. We also get back the underlying `(pE', pRank')`
on the a-side for downstream use. -/
lemma exists_path_index_of_pos_edge
    (pa : P20.a.Params) (pb : P20.b.Params) (M : ParamsMatch pa pb)
    (v : P20.a.Vars) (h : WeakFeasible pa v) (k : Fin pa.nK)
    (rank : Fin pa.nN → ℕ)
    (hRank : ∀ i j : Fin pa.nN, pa.E i j = 1 → 0 < v.F i.val j.val k.val →
      rank i < rank j)
    (i j : Fin pa.nN) (hE : pa.E i j = 1) (hF : 0 < v.F i.val j.val k.val) :
    ∃ (p : Fin pb.nP) (pE' : Fin pa.nN → Fin pa.nN → ℤ)
      (pRank' : Fin pa.nN → ℕ),
      P20.b.IsValidPath pa.S pa.B pa.E pE' pRank' ∧
      (∀ i j : Fin pa.nN,
        pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = pE' i j) ∧
      (∀ i j : Fin pa.nN, pE' i j = 1 → 0 < v.F i.val j.val k.val) := by
  classical
  obtain ⟨pE', pRank', hVP, hpos_arc⟩ :=
    exists_valid_path_in_pos_support pa v h k rank hRank i j hE hF
  -- Lift to b-side via M.
  have hVP_b : P20.b.IsValidPath pb.S pb.B pb.E
      (transportPathE M pE') (transportPathRank M pRank') :=
    transportPath_isValidPath M hVP
  obtain ⟨p, hp⟩ := pb.hpE_complete _ _ hVP_b
  refine ⟨p, pE', pRank', hVP, ?_, hpos_arc⟩
  intro i' j'
  have := hp (Fin.cast M.hN i') (Fin.cast M.hN j')
  unfold transportPathE at this
  simpa using this

/-- Variant: extract path index given non-empty `posSupport`. -/
lemma exists_path_index_of_pos_support
    (pa : P20.a.Params) (pb : P20.b.Params) (M : ParamsMatch pa pb)
    (v : P20.a.Vars) (h : WeakFeasible pa v) (k : Fin pa.nK)
    (hne : (posSupport pa v k).Nonempty) :
    ∃ (p : Fin pb.nP) (pE' : Fin pa.nN → Fin pa.nN → ℤ)
      (pRank' : Fin pa.nN → ℕ),
      P20.b.IsValidPath pa.S pa.B pa.E pE' pRank' ∧
      (∀ i j : Fin pa.nN,
        pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = pE' i j) ∧
      (∀ i j : Fin pa.nN, pE' i j = 1 → 0 < v.F i.val j.val k.val) := by
  classical
  obtain ⟨⟨i, j⟩, hij⟩ := hne
  rw [mem_posSupport] at hij
  obtain ⟨rank, hRank⟩ := h.hF_acyclic k
  exact exists_path_index_of_pos_edge pa pb M v h k rank hRank i j hij.1 hij.2

end FlowDecomp

-- ============================================================================
-- § Bottleneck subtraction
-- ============================================================================

namespace FlowDecomp

variable (pa : P20.a.Params) (pb : P20.b.Params)

/-- The arcs of path `p`, expressed on the a-side index set via the
parameter match `M`. An arc is in the path iff `pb.pE p` (transported
via `Fin.cast`) equals 1. -/
noncomputable def pathArcs (M : ParamsMatch pa pb) (p : Fin pb.nP) :
    Finset (Fin pa.nN × Fin pa.nN) :=
  (univ : Finset (Fin pa.nN × Fin pa.nN)).filter
    (fun ij => pb.pE p (Fin.cast M.hN ij.1) (Fin.cast M.hN ij.2) = 1)

lemma mem_pathArcs {M : ParamsMatch pa pb} {p : Fin pb.nP}
    {i j : Fin pa.nN} :
    (i, j) ∈ pathArcs pa pb M p ↔
      pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1 := by
  simp [pathArcs]

/-- The path arcs are nonempty, since every valid path has a unique source
edge `(S s, _)` with `pE = 1`. -/
lemma pathArcs_nonempty (M : ParamsMatch pa pb) (p : Fin pb.nP) :
    (pathArcs pa pb M p).Nonempty := by
  classical
  have hVP := pb.hpE_valid p
  unfold P20.b.IsValidPath at hVP
  obtain ⟨hbin, _, _, _, ⟨s, hsout, _, _⟩, _, _⟩ := hVP
  -- ∑_j pE p (S s) j = 1; so some j has pE p (S s) j = 1.
  have : ∃ j : Fin pb.nN, pb.pE p (pb.S s) j = 1 := by
    by_contra hne
    push_neg at hne
    have hAll : ∀ j : Fin pb.nN, pb.pE p (pb.S s) j = 0 := by
      intro j
      rcases hbin (pb.S s) j with h0 | h1
      · exact h0
      · exact absurd h1 (hne j)
    have : ∑ j : Fin pb.nN, pb.pE p (pb.S s) j = 0 := by
      simp [hAll]
    rw [this] at hsout; exact absurd hsout (by norm_num)
  obtain ⟨j, hj⟩ := this
  refine ⟨(Fin.cast M.hN.symm (pb.S s), Fin.cast M.hN.symm j), ?_⟩
  rw [mem_pathArcs]
  simp; exact hj

/-- The bottleneck flow value: minimum of `v.F i j k` over arcs `(i,j)` of
path `p`. Defined via `Finset.min'` on the (nonempty) arc set. -/
noncomputable def bottleneck (M : ParamsMatch pa pb)
    (v : P20.a.Vars) (k : Fin pa.nK) (p : Fin pb.nP) : ℝ :=
  ((pathArcs pa pb M p).image (fun ij => v.F ij.1.val ij.2.val k.val)).min'
    (by
      apply Finset.image_nonempty.mpr
      exact pathArcs_nonempty pa pb M p)

/-- The bottleneck is achieved at some path arc. -/
lemma bottleneck_le (M : ParamsMatch pa pb) (v : P20.a.Vars)
    (k : Fin pa.nK) (p : Fin pb.nP)
    {i j : Fin pa.nN} (hij : (i, j) ∈ pathArcs pa pb M p) :
    bottleneck pa pb M v k p ≤ v.F i.val j.val k.val := by
  classical
  unfold bottleneck
  apply Finset.min'_le
  exact Finset.mem_image.mpr ⟨(i, j), hij, rfl⟩

/-- The bottleneck is achieved: some path arc attains it. -/
lemma exists_bottleneck_arc (M : ParamsMatch pa pb) (v : P20.a.Vars)
    (k : Fin pa.nK) (p : Fin pb.nP) :
    ∃ ij : Fin pa.nN × Fin pa.nN, ij ∈ pathArcs pa pb M p ∧
      v.F ij.1.val ij.2.val k.val = bottleneck pa pb M v k p := by
  classical
  set S := (pathArcs pa pb M p).image (fun ij => v.F ij.1.val ij.2.val k.val)
  have hSne : S.Nonempty := Finset.image_nonempty.mpr (pathArcs_nonempty pa pb M p)
  have hmem : S.min' hSne ∈ S := Finset.min'_mem _ _
  obtain ⟨ij, hij, heq⟩ := Finset.mem_image.mp hmem
  exact ⟨ij, hij, heq⟩

/-- If every path arc carries strictly positive flow on commodity `k`,
the bottleneck is strictly positive. -/
lemma bottleneck_pos (M : ParamsMatch pa pb) (v : P20.a.Vars)
    (k : Fin pa.nK) (p : Fin pb.nP)
    (hpos : ∀ i j : Fin pa.nN, (i, j) ∈ pathArcs pa pb M p →
      0 < v.F i.val j.val k.val) :
    0 < bottleneck pa pb M v k p := by
  classical
  obtain ⟨ij, hij, heq⟩ := exists_bottleneck_arc pa pb M v k p
  rw [← heq]; exact hpos ij.1 ij.2 hij

/-- The subtracted flow: along arcs of path `p` on commodity `k`, subtract
`δ`; elsewhere unchanged. -/
noncomputable def subtractFlow (M : ParamsMatch pa pb)
    (v : P20.a.Vars) (k : Fin pa.nK) (p : Fin pb.nP) (δ : ℝ) : P20.a.Vars :=
  { F := fun i j k' =>
      if h : i < pa.nN ∧ j < pa.nN ∧ k' = k.val then
        if pb.pE p (Fin.cast M.hN ⟨i, h.1⟩) (Fin.cast M.hN ⟨j, h.2.1⟩) = 1 then
          v.F i j k' - δ
        else v.F i j k'
      else v.F i j k'
    R := v.R }

/-- The subtracted flow on a Fin-Fin-Fin triple, in convenient form. -/
lemma subtractFlow_F (M : ParamsMatch pa pb) (v : P20.a.Vars)
    (k : Fin pa.nK) (p : Fin pb.nP) (δ : ℝ)
    (i j : Fin pa.nN) (k' : Fin pa.nK) :
    (subtractFlow pa pb M v k p δ).F i.val j.val k'.val =
      if k' = k ∧ pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1 then
        v.F i.val j.val k'.val - δ
      else v.F i.val j.val k'.val := by
  unfold subtractFlow
  simp only
  by_cases hkk : k' = k
  · subst hkk
    have hcond : i.val < pa.nN ∧ j.val < pa.nN ∧ k'.val = k'.val :=
      ⟨i.isLt, j.isLt, rfl⟩
    rw [dif_pos hcond]
    by_cases hpE : pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1
    · have h1 : pb.pE p (Fin.cast M.hN ⟨i.val, i.isLt⟩) (Fin.cast M.hN ⟨j.val, j.isLt⟩) = 1 := by
        convert hpE using 3
      rw [if_pos h1]
      simp [hpE]
    · have h1 : ¬ pb.pE p (Fin.cast M.hN ⟨i.val, i.isLt⟩) (Fin.cast M.hN ⟨j.val, j.isLt⟩) = 1 := by
        intro h; apply hpE
        convert h using 3
      rw [if_neg h1]
      simp [hpE]
  · have hcond : ¬ (i.val < pa.nN ∧ j.val < pa.nN ∧ k'.val = k.val) := by
      intro ⟨_, _, hk⟩
      apply hkk
      exact Fin.ext hk
    rw [dif_neg hcond]
    have : ¬ (k' = k ∧ pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1) := by
      intro ⟨h, _⟩; exact hkk h
    rw [if_neg this]

/-- Off-arc, off-commodity entries are unchanged. -/
lemma subtractFlow_F_off (M : ParamsMatch pa pb) (v : P20.a.Vars)
    (k : Fin pa.nK) (p : Fin pb.nP) (δ : ℝ)
    (i j : Fin pa.nN) (k' : Fin pa.nK)
    (h : ¬ (k' = k ∧ pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1)) :
    (subtractFlow pa pb M v k p δ).F i.val j.val k'.val =
      v.F i.val j.val k'.val := by
  rw [subtractFlow_F, if_neg h]

/-- On-arc entries on commodity `k` get reduced by `δ`. -/
lemma subtractFlow_F_on (M : ParamsMatch pa pb) (v : P20.a.Vars)
    (k : Fin pa.nK) (p : Fin pb.nP) (δ : ℝ)
    (i j : Fin pa.nN)
    (hpE : pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1) :
    (subtractFlow pa pb M v k p δ).F i.val j.val k.val =
      v.F i.val j.val k.val - δ := by
  rw [subtractFlow_F]
  rw [if_pos ⟨rfl, hpE⟩]

/-- The R component is unchanged by subtraction. -/
@[simp] lemma subtractFlow_R (M : ParamsMatch pa pb) (v : P20.a.Vars)
    (k : Fin pa.nK) (p : Fin pb.nP) (δ : ℝ) :
    (subtractFlow pa pb M v k p δ).R = v.R := rfl

/-- Subtraction preserves non-negativity provided `δ ≤ bottleneck`. -/
lemma subtractFlow_F_nn (M : ParamsMatch pa pb) (v : P20.a.Vars)
    (h : WeakFeasible pa v) (k : Fin pa.nK) (p : Fin pb.nP) (δ : ℝ)
    (_hδ_nn : 0 ≤ δ) (hδ_le : δ ≤ bottleneck pa pb M v k p) :
    ∀ i j : Fin pa.nN, ∀ k' : Fin pa.nK,
      0 ≤ (subtractFlow pa pb M v k p δ).F i.val j.val k'.val := by
  intro i j k'
  rw [subtractFlow_F]
  by_cases hcond : k' = k ∧ pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1
  · rw [if_pos hcond]
    obtain ⟨hk, hpE⟩ := hcond
    subst hk
    have : (i, j) ∈ pathArcs pa pb M p := (mem_pathArcs pa pb).mpr hpE
    have := bottleneck_le pa pb M v k' p this
    linarith
  · rw [if_neg hcond]; exact h.hF_nn i j k'

/-- Subtraction with positive `δ` strictly decreases the support of
commodity `k`: the bottleneck arc leaves the support. -/
lemma subtractFlow_support_lt (M : ParamsMatch pa pb) (v : P20.a.Vars)
    (_h : WeakFeasible pa v) (k : Fin pa.nK) (p : Fin pb.nP)
    (hpos : ∀ i j : Fin pa.nN, (i, j) ∈ pathArcs pa pb M p →
      0 < v.F i.val j.val k.val)
    (hpE_le_E : ∀ i j : Fin pa.nN, (i, j) ∈ pathArcs pa pb M p → pa.E i j = 1) :
    (posSupport pa (subtractFlow pa pb M v k p (bottleneck pa pb M v k p)) k).card
      < (posSupport pa v k).card := by
  classical
  set δ := bottleneck pa pb M v k p
  set v' := subtractFlow pa pb M v k p δ
  -- Bottleneck arc.
  obtain ⟨ij, hij_mem, hij_eq⟩ := exists_bottleneck_arc pa pb M v k p
  -- Show posSupport v' k ⊆ posSupport v k, and the bottleneck arc is in the latter not the former.
  have hsubset : posSupport pa v' k ⊆ posSupport pa v k := by
    intro ab hab
    rw [mem_posSupport] at hab ⊢
    refine ⟨hab.1, ?_⟩
    -- v'.F = if on path then v.F - δ else v.F. Both cases give v.F > 0.
    have hv'_eq := subtractFlow_F (pa := pa) (pb := pb) (M := M) (v := v) (k := k)
        (p := p) (δ := δ) ab.1 ab.2 k
    by_cases hcond : k = k ∧ pb.pE p (Fin.cast M.hN ab.1) (Fin.cast M.hN ab.2) = 1
    · -- on path
      have hpE_eq : pb.pE p (Fin.cast M.hN ab.1) (Fin.cast M.hN ab.2) = 1 := hcond.2
      have hmem : (ab.1, ab.2) ∈ pathArcs pa pb M p := (mem_pathArcs pa pb).mpr hpE_eq
      exact hpos ab.1 ab.2 hmem
    · push_neg at hcond
      have hpE_ne : ¬ pb.pE p (Fin.cast M.hN ab.1) (Fin.cast M.hN ab.2) = 1 := by
        by_contra hh; exact hcond rfl hh
      simp only [show v'.F ab.1.val ab.2.val k.val =
                v.F ab.1.val ab.2.val k.val from by
                  rw [show v'.F = (subtractFlow pa pb M v k p δ).F from rfl,
                    subtractFlow_F]
                  rw [if_neg]
                  intro ⟨_, h2⟩; exact hpE_ne h2] at hab
      exact hab.2
  -- The bottleneck arc is in posSupport v k.
  have hbot_in_v : ij ∈ posSupport pa v k := by
    rw [mem_posSupport]
    refine ⟨hpE_le_E ij.1 ij.2 hij_mem, ?_⟩
    have hpE := (mem_pathArcs pa pb).mp hij_mem
    exact hpos ij.1 ij.2 hij_mem
  -- The bottleneck arc is NOT in posSupport v' k (its v'.F is 0).
  have hbot_not_in_v' : ij ∉ posSupport pa v' k := by
    intro hin
    rw [mem_posSupport] at hin
    have hpE := (mem_pathArcs pa pb).mp hij_mem
    have heq2 : v'.F ij.1.val ij.2.val k.val = 0 := by
      have h1 : v'.F ij.1.val ij.2.val k.val = v.F ij.1.val ij.2.val k.val - δ :=
        subtractFlow_F_on pa pb M v k p δ ij.1 ij.2 hpE
      rw [h1, hij_eq]; ring
    rw [heq2] at hin
    exact absurd hin.2 (lt_irrefl _)
  exact Finset.card_lt_card (Finset.ssubset_iff_subset_ne.mpr
    ⟨hsubset, fun heq => hbot_not_in_v' (heq ▸ hbot_in_v)⟩)

end FlowDecomp

-- ============================================================================
-- § Preservation of WeakFeasible under bottleneck subtraction
-- ============================================================================

namespace FlowDecomp

variable (pa : P20.a.Params) (pb : P20.b.Params)

/-- Path arcs are graph edges. -/
lemma pathArcs_subset_E (M : ParamsMatch pa pb) (p : Fin pb.nP)
    {i j : Fin pa.nN} (hij : (i, j) ∈ pathArcs pa pb M p) :
    pa.E i j = 1 := by
  classical
  rw [mem_pathArcs] at hij
  have hVP := pb.hpE_valid p
  obtain ⟨_, hle, _⟩ := hVP
  have h1 : pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) ≤
            pb.E (Fin.cast M.hN i) (Fin.cast M.hN j) := hle _ _
  rw [hij] at h1
  rw [M.hEeq]
  rcases pb.hE_bin (Fin.cast M.hN i) (Fin.cast M.hN j) with h0 | h1'
  · rw [h0] at h1; exact absurd h1 (by norm_num)
  · exact h1'

/-- If all entering edges of a node `u` have `v.F i u k = 0` (e.g. by
`hS_noinflow`), then no path arc enters `u`. -/
lemma no_path_arc_into_zero_inflow (M : ParamsMatch pa pb)
    (v : P20.a.Vars) (k : Fin pa.nK) (p : Fin pb.nP) (u : Fin pa.nN)
    (hzero : ∀ i : Fin pa.nN, pa.E i u = 1 → v.F i.val u.val k.val = 0)
    (hpos : ∀ i j : Fin pa.nN, (i, j) ∈ pathArcs pa pb M p →
      0 < v.F i.val j.val k.val) :
    ∀ i : Fin pa.nN, ¬ (i, u) ∈ pathArcs pa pb M p := by
  intro i hmem
  have hE : pa.E i u = 1 := pathArcs_subset_E pa pb M p hmem
  have hF : v.F i.val u.val k.val = 0 := hzero i hE
  have : 0 < v.F i.val u.val k.val := hpos i u hmem
  linarith

/-- Symmetric: if all leaving edges have zero flow, no path arc leaves. -/
lemma no_path_arc_outof_zero_outflow (M : ParamsMatch pa pb)
    (v : P20.a.Vars) (k : Fin pa.nK) (p : Fin pb.nP) (u : Fin pa.nN)
    (hzero : ∀ j : Fin pa.nN, pa.E u j = 1 → v.F u.val j.val k.val = 0)
    (hpos : ∀ i j : Fin pa.nN, (i, j) ∈ pathArcs pa pb M p →
      0 < v.F i.val j.val k.val) :
    ∀ j : Fin pa.nN, ¬ (u, j) ∈ pathArcs pa pb M p := by
  intro j hmem
  have hE : pa.E u j = 1 := pathArcs_subset_E pa pb M p hmem
  have hF : v.F u.val j.val k.val = 0 := hzero j hE
  have : 0 < v.F u.val j.val k.val := hpos u j hmem
  linarith

/-- From `hS_noinflow`: every edge into a supplier carries zero flow. -/
lemma zero_inflow_at_supplier {pa : P20.a.Params} {v : P20.a.Vars}
    (h : WeakFeasible pa v) (s : Fin pa.nS) (k : Fin pa.nK)
    (i : Fin pa.nN) (hE : pa.E i (pa.S s) = 1) :
    v.F i.val (pa.S s).val k.val = 0 := by
  classical
  have hsum := h.hS_noinflow s k
  have hnn : ∀ j ∈ (Finset.univ : Finset (Fin pa.nN)),
      0 ≤ (pa.E j (pa.S s) : ℝ) * v.F j.val (pa.S s).val k.val := by
    intro j _
    rcases pa.hE_bin j (pa.S s) with h0 | h1
    · rw [h0]; simp
    · rw [h1]; simp; exact h.hF_nn _ _ _
  have hzero_each :
      (pa.E i (pa.S s) : ℝ) * v.F i.val (pa.S s).val k.val = 0 := by
    have := (Finset.sum_eq_zero_iff_of_nonneg hnn).mp hsum i (Finset.mem_univ _)
    exact this
  rw [hE] at hzero_each
  simpa using hzero_each

/-- From `hB_nooutflow`: every edge out of a beneficiary carries zero flow. -/
lemma zero_outflow_at_beneficiary {pa : P20.a.Params} {v : P20.a.Vars}
    (h : WeakFeasible pa v) (b : Fin pa.nB) (k : Fin pa.nK)
    (j : Fin pa.nN) (hE : pa.E (pa.B b) j = 1) :
    v.F (pa.B b).val j.val k.val = 0 := by
  classical
  have hsum := h.hB_nooutflow b k
  have hnn : ∀ j' ∈ (Finset.univ : Finset (Fin pa.nN)),
      0 ≤ (pa.E (pa.B b) j' : ℝ) * v.F (pa.B b).val j'.val k.val := by
    intro j' _
    rcases pa.hE_bin (pa.B b) j' with h0 | h1
    · rw [h0]; simp
    · rw [h1]; simp; exact h.hF_nn _ _ _
  have hzero_each :
      (pa.E (pa.B b) j : ℝ) * v.F (pa.B b).val j.val k.val = 0 := by
    exact (Finset.sum_eq_zero_iff_of_nonneg hnn).mp hsum j (Finset.mem_univ _)
  rw [hE] at hzero_each
  simpa using hzero_each

/-- Bottleneck subtraction preserves WeakFeasible, given the path's arcs
all carry positive flow on commodity `k`. -/
lemma subtractFlow_weakFeasible (M : ParamsMatch pa pb) (v : P20.a.Vars)
    (h : WeakFeasible pa v) (k : Fin pa.nK) (p : Fin pb.nP)
    (hpos : ∀ i j : Fin pa.nN, (i, j) ∈ pathArcs pa pb M p →
      0 < v.F i.val j.val k.val) :
    WeakFeasible pa (subtractFlow pa pb M v k p (bottleneck pa pb M v k p)) := by
  classical
  set δ := bottleneck pa pb M v k p with hδ_def
  set v' := subtractFlow pa pb M v k p δ with hv'_def
  have hδ_nn : 0 ≤ δ := le_of_lt (bottleneck_pos pa pb M v k p hpos)
  have hδ_le : δ ≤ bottleneck pa pb M v k p := le_refl _
  -- Helper: F'.F i j k' relates to F.F.
  have hF'_eq : ∀ (i j : Fin pa.nN) (k' : Fin pa.nK),
      v'.F i.val j.val k'.val =
        if k' = k ∧ pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1 then
          v.F i.val j.val k'.val - δ
        else v.F i.val j.val k'.val := by
    intro i j k'; exact subtractFlow_F pa pb M v k p δ i j k'
  refine
    { hS_noinflow := ?_
      hflow := ?_
      hB_nooutflow := ?_
      hF_acyclic := ?_
      hF_offedge := ?_
      hF_nn := ?_
      hR_nn := ?_ }
  · -- hS_noinflow: zero inflow at every supplier on every commodity.
    intro s k'
    have hold := h.hS_noinflow s k'
    -- Show ∑ i, E i (S s) * v'.F i (S s) k' = ∑ i, E i (S s) * v.F i (S s) k'
    have hpt : ∀ i : Fin pa.nN,
        (pa.E i (pa.S s) : ℝ) * v'.F i.val (pa.S s).val k'.val =
        (pa.E i (pa.S s) : ℝ) * v.F i.val (pa.S s).val k'.val := by
      intro i
      rw [hF'_eq]
      by_cases hcond : k' = k ∧ pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN (pa.S s)) = 1
      · -- This case is impossible: a path arc into a supplier requires positive
        -- flow there, contradicting hS_noinflow.
        exfalso
        obtain ⟨hkk, hpE⟩ := hcond
        subst hkk
        have hmem : (i, pa.S s) ∈ pathArcs pa pb M p :=
          (mem_pathArcs pa pb).mpr hpE
        have hE := pathArcs_subset_E pa pb M p hmem
        have hzero := zero_inflow_at_supplier h s k' i hE
        have hpos' := hpos i (pa.S s) hmem
        linarith
      · rw [if_neg hcond]
    calc ∑ i : Fin pa.nN, (pa.E i (pa.S s) : ℝ) * v'.F i.val (pa.S s).val k'.val
        = ∑ i : Fin pa.nN, (pa.E i (pa.S s) : ℝ) * v.F i.val (pa.S s).val k'.val := by
              apply Finset.sum_congr rfl; intro i _; exact hpt i
      _ = 0 := hold
  · -- hflow at transshipment: inflow = outflow.
    -- Both sides drop by exactly δ * (path-uses-T-as-interior indicator) when k'=k.
    -- Path's intermediate nodes (if T t is one) have indegree=outdegree=1 in pE.
    -- For k' ≠ k, F is unchanged.
    intro t k'
    have hold := h.hflow t k'
    by_cases hkk : k' = k
    · rw [hkk]
      -- Now goal is in terms of k.
      -- Compute new inflow and outflow at T t.
      -- new inflow = old inflow - δ * (∑_i pE p (cast i) (cast (T t)))
      -- new outflow = old outflow - δ * (∑_j pE p (cast (T t)) (cast j))
      -- These two indegree/outdegree path sums are equal at any internal node.
      -- Specifically, IsValidPath ensures both ≤ 1; at T t they're either both 0
      -- (T t not on path) or both 1 (T t interior — needs separate argument).
      -- We use a direct algebraic argument: the difference (new inflow) -
      -- (new outflow) equals (old inflow) - (old outflow) - δ * (in_deg - out_deg)
      -- where in_deg/out_deg of T t in path agree (interior) since T t is not
      -- the source supplier nor the sink beneficiary (by partition disjointness).
      -- Old inflow = old outflow, so new inflow = new outflow iff in_deg = out_deg.
      have hVP := pb.hpE_valid p
      obtain ⟨_, _, _, _, ⟨ssrc, _, _, _⟩, ⟨bsink, _, _, _⟩, _⟩ := hVP
      -- Express new inflow.
      have hin_eq :
          ∑ i : Fin pa.nN, (pa.E i (pa.T t) : ℝ) * v'.F i.val (pa.T t).val k.val =
          (∑ i : Fin pa.nN, (pa.E i (pa.T t) : ℝ) * v.F i.val (pa.T t).val k.val)
            - δ * ∑ i : Fin pa.nN,
                (pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN (pa.T t)) : ℝ) := by
        rw [Finset.mul_sum, ← Finset.sum_sub_distrib]
        apply Finset.sum_congr rfl
        intro i _
        rw [hF'_eq]
        by_cases hcond : k = k ∧ pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN (pa.T t)) = 1
        · rw [if_pos hcond]
          obtain ⟨_, hpE⟩ := hcond
          have hmem : (i, pa.T t) ∈ pathArcs pa pb M p :=
            (mem_pathArcs pa pb).mpr hpE
          have hE := pathArcs_subset_E pa pb M p hmem
          rw [hE, hpE]; push_cast; ring
        · rw [if_neg hcond]
          have hpE0 :
              pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN (pa.T t)) = 0 := by
            have hVP' := pb.hpE_valid p
            obtain ⟨hbin, _⟩ := hVP'
            rcases hbin (Fin.cast M.hN i) (Fin.cast M.hN (pa.T t)) with h0 | h1
            · exact h0
            · exfalso; apply hcond; exact ⟨rfl, h1⟩
          rw [hpE0]; push_cast; ring
      have hout_eq :
          ∑ i : Fin pa.nN, (pa.E (pa.T t) i : ℝ) * v'.F (pa.T t).val i.val k.val =
          (∑ i : Fin pa.nN, (pa.E (pa.T t) i : ℝ) * v.F (pa.T t).val i.val k.val)
            - δ * ∑ i : Fin pa.nN,
                (pb.pE p (Fin.cast M.hN (pa.T t)) (Fin.cast M.hN i) : ℝ) := by
        rw [Finset.mul_sum, ← Finset.sum_sub_distrib]
        apply Finset.sum_congr rfl
        intro i _
        rw [hF'_eq]
        by_cases hcond : k = k ∧ pb.pE p (Fin.cast M.hN (pa.T t)) (Fin.cast M.hN i) = 1
        · rw [if_pos hcond]
          obtain ⟨_, hpE⟩ := hcond
          have hmem : (pa.T t, i) ∈ pathArcs pa pb M p :=
            (mem_pathArcs pa pb).mpr hpE
          have hE := pathArcs_subset_E pa pb M p hmem
          rw [hE, hpE]; push_cast; ring
        · rw [if_neg hcond]
          have hpE0 :
              pb.pE p (Fin.cast M.hN (pa.T t)) (Fin.cast M.hN i) = 0 := by
            have hVP' := pb.hpE_valid p
            obtain ⟨hbin, _⟩ := hVP'
            rcases hbin (Fin.cast M.hN (pa.T t)) (Fin.cast M.hN i) with h0 | h1
            · exact h0
            · exfalso; apply hcond; exact ⟨rfl, h1⟩
          rw [hpE0]; push_cast; ring
      -- Now: it suffices to show in-degree of (cast (T t)) = out-degree in path p.
      -- Use the fact that if any inflow path arc into T t exists, T t has both.
      -- We rely on: T t is neither source supplier nor sink beneficiary (partition).
      -- The unique source/sink properties of IsValidPath require any node `v`
      -- with (∑ in) = 1 and (∑ out) = 0 to be the sink, and any with
      -- (∑ in) = 0 and (∑ out) = 1 to be the source. So T t can only have
      -- (in_deg, out_deg) ∈ {(0,0), (1,1)}.
      -- Equally, we can use v'.F = ... as algebra. Let's reduce via:
      -- show ∑_i pE p (cast i) (cast (T t)) = ∑_i pE p (cast (T t)) (cast i).
      have hpath_deg :
          (∑ i : Fin pa.nN,
              (pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN (pa.T t)) : ℝ)) =
          (∑ i : Fin pa.nN,
              (pb.pE p (Fin.cast M.hN (pa.T t)) (Fin.cast M.hN i) : ℝ)) := by
        -- Translate to sums over Fin pb.nN.
        have hVP' := pb.hpE_valid p
        obtain ⟨hbin, _, hin1, hout1, ⟨s', hsout, hsin, hsuniq⟩,
                ⟨b', hbin1, hbout, hbuniq⟩, _⟩ := hVP'
        -- ∑ i pE p i (cast T t)  ≤ 1 (in-degree).
        -- Cases on its value (∈ ℕ from binary entries).
        -- We use the integer in/out degree at the b-side index `Fin.cast M.hN (T t)`.
        let u : Fin pb.nN := Fin.cast M.hN (pa.T t)
        -- Re-index sums on the a-side as sums on the b-side via Fin.cast.
        have hLHS_reindex :
            (∑ i : Fin pa.nN,
              (pb.pE p (Fin.cast M.hN i) u : ℝ)) =
            (∑ i' : Fin pb.nN, (pb.pE p i' u : ℝ)) := by
          rw [← Equiv.sum_comp (Fin.castOrderIso M.hN).toEquiv
                  (fun i' => (pb.pE p i' u : ℝ))]
          rfl
        have hRHS_reindex :
            (∑ i : Fin pa.nN,
              (pb.pE p u (Fin.cast M.hN i) : ℝ)) =
            (∑ i' : Fin pb.nN, (pb.pE p u i' : ℝ)) := by
          rw [← Equiv.sum_comp (Fin.castOrderIso M.hN).toEquiv
                  (fun i' => (pb.pE p u i' : ℝ))]
          rfl
        rw [hLHS_reindex, hRHS_reindex]
        -- The integer-valued sums.
        have hin_int : (∑ i' : Fin pb.nN, pb.pE p i' u) = 0 ∨
                       (∑ i' : Fin pb.nN, pb.pE p i' u) = 1 := by
          -- 0 ≤ sum ≤ 1; sum is integer.
          have hle1 : (∑ i' : Fin pb.nN, pb.pE p i' u) ≤ 1 := hin1 u
          have hnn : 0 ≤ (∑ i' : Fin pb.nN, pb.pE p i' u) := by
            apply Finset.sum_nonneg
            intro i' _
            rcases hbin i' u with h0 | h1
            · rw [h0]
            · rw [h1]; norm_num
          interval_cases (∑ i' : Fin pb.nN, pb.pE p i' u)
          · left; rfl
          · right; rfl
        have hout_int : (∑ i' : Fin pb.nN, pb.pE p u i') = 0 ∨
                        (∑ i' : Fin pb.nN, pb.pE p u i') = 1 := by
          have hle1 : (∑ i' : Fin pb.nN, pb.pE p u i') ≤ 1 := hout1 u
          have hnn : 0 ≤ (∑ i' : Fin pb.nN, pb.pE p u i') := by
            apply Finset.sum_nonneg
            intro i' _
            rcases hbin u i' with h0 | h1
            · rw [h0]
            · rw [h1]; norm_num
          interval_cases (∑ i' : Fin pb.nN, pb.pE p u i')
          · left; rfl
          · right; rfl
        -- Goal: cast in-int sum = cast out-int sum (as ℝ).
        -- Show in_int = out_int. Cases.
        have hu_neq_S : ∀ s : Fin pb.nS, u ≠ pb.S s := by
          intro s heq
          -- u = cast (T t) = pb.S s ⇒ pa.T t = cast.symm (pb.S s).
          -- Combined with M.hSeq, (S, T) disjoint on pb side, leads to contradiction.
          -- Direct route: Fin.cast on pa side: pa.T t cast = pb.S s ⇒
          -- ∃ s' (M.hSeq), pb.S (cast s') = pb.S s ⇒ via hS_inj, cast s' = s,
          -- ⇒ pb.T (cast t) = pb.S s; but partition disjoints S/T on pb side.
          -- We don't have pb.T explicit, so use a different approach: use that
          -- on a-side T and S are disjoint by hSTB_disj_ST at index level.
          -- Recall heq : Fin.cast M.hN (pa.T t) = pb.S s.
          -- s comes from b-side; pull back: ∃ sa, pb.S s = Fin.cast M.hN (pa.S sa).
          -- Use the fact: M.hSeq says cast (pa.S sa) = pb.S (cast sa).
          -- So pb.S s = cast (pa.S (cast.symm s)). Then heq gives
          -- cast (pa.T t) = cast (pa.S (cast.symm s)), hence pa.T t = pa.S (...).
          have hsa : pb.S s = Fin.cast M.hN (pa.S (Fin.cast M.hS.symm s)) := by
            rw [M.hSeq]; simp
          rw [hsa] at heq
          have h2 : pa.T t = pa.S (Fin.cast M.hS.symm s) :=
            Fin.cast_injective M.hN heq
          exact (pa.hSTB_disj_ST _ _) h2.symm
        have hu_neq_B : ∀ b : Fin pb.nB, u ≠ pb.B b := by
          intro b' heq
          have hba : pb.B b' = Fin.cast M.hN (pa.B (Fin.cast M.hB.symm b')) := by
            rw [M.hBeq]; simp
          rw [hba] at heq
          have h2 : pa.T t = pa.B (Fin.cast M.hB.symm b') :=
            Fin.cast_injective M.hN heq
          exact (pa.hSTB_disj_TB _ _) h2
        -- Cases on (in, out): (0,0), (0,1), (1,0), (1,1).
        have key : (∑ i' : Fin pb.nN, pb.pE p i' u) =
                   (∑ i' : Fin pb.nN, pb.pE p u i') := by
          rcases hin_int with hin0 | hin1'
          · rcases hout_int with hout0 | hout1'
            · rw [hin0, hout0]
            · exfalso
              have : u = pb.S s' := hsuniq u ⟨hout1', hin0⟩
              exact hu_neq_S s' this
          · rcases hout_int with hout0 | hout1'
            · exfalso
              have : u = pb.B b' := hbuniq u ⟨hin1', hout0⟩
              exact hu_neq_B b' this
            · rw [hin1', hout1']
        exact_mod_cast key
      -- Combine: new inflow = new outflow.
      rw [hin_eq, hout_eq, hpath_deg]
      have hold' :
          ∑ i : Fin pa.nN, (pa.E i (pa.T t) : ℝ) * v.F i.val (pa.T t).val k.val =
          ∑ i : Fin pa.nN, (pa.E (pa.T t) i : ℝ) * v.F (pa.T t).val i.val k.val := by
        rw [← hkk]; exact hold
      rw [hold']
    · -- k' ≠ k: F unchanged.
      have hin_unchanged :
          ∑ i : Fin pa.nN, (pa.E i (pa.T t) : ℝ) * v'.F i.val (pa.T t).val k'.val =
          ∑ i : Fin pa.nN, (pa.E i (pa.T t) : ℝ) * v.F i.val (pa.T t).val k'.val := by
        apply Finset.sum_congr rfl
        intro i _
        rw [hF'_eq, if_neg]
        intro ⟨hk, _⟩; exact hkk hk
      have hout_unchanged :
          ∑ i : Fin pa.nN, (pa.E (pa.T t) i : ℝ) * v'.F (pa.T t).val i.val k'.val =
          ∑ i : Fin pa.nN, (pa.E (pa.T t) i : ℝ) * v.F (pa.T t).val i.val k'.val := by
        apply Finset.sum_congr rfl
        intro i _
        rw [hF'_eq, if_neg]
        intro ⟨hk, _⟩; exact hkk hk
      rw [hin_unchanged, hout_unchanged]; exact hold
  · -- hB_nooutflow.
    intro b k'
    have hold := h.hB_nooutflow b k'
    have hpt : ∀ j : Fin pa.nN,
        (pa.E (pa.B b) j : ℝ) * v'.F (pa.B b).val j.val k'.val =
        (pa.E (pa.B b) j : ℝ) * v.F (pa.B b).val j.val k'.val := by
      intro j
      rw [hF'_eq]
      by_cases hcond : k' = k ∧ pb.pE p (Fin.cast M.hN (pa.B b)) (Fin.cast M.hN j) = 1
      · exfalso
        obtain ⟨hkk, hpE⟩ := hcond
        subst hkk
        have hmem : (pa.B b, j) ∈ pathArcs pa pb M p :=
          (mem_pathArcs pa pb).mpr hpE
        have hE := pathArcs_subset_E pa pb M p hmem
        have hzero := zero_outflow_at_beneficiary h b k' j hE
        have hpos' := hpos (pa.B b) j hmem
        linarith
      · rw [if_neg hcond]
    calc ∑ j : Fin pa.nN, (pa.E (pa.B b) j : ℝ) * v'.F (pa.B b).val j.val k'.val
        = ∑ j : Fin pa.nN, (pa.E (pa.B b) j : ℝ) * v.F (pa.B b).val j.val k'.val := by
              apply Finset.sum_congr rfl; intro j _; exact hpt j
      _ = 0 := hold
  · -- hF_acyclic: same rank witness still strictly increases on positive
    -- entries of v', since v' ≤ v means v' positive ⇒ v positive.
    intro k'
    obtain ⟨rank, hRank⟩ := h.hF_acyclic k'
    refine ⟨rank, ?_⟩
    intro i j hE hF'
    have hF : 0 < v.F i j k' := by
      have heq := hF'_eq i j k'
      by_cases hcond : k' = k ∧ pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1
      · rw [if_pos hcond] at heq
        -- v'.F i j k' = v.F i j k' - δ; v'.F > 0 ⇒ v.F > δ ≥ 0.
        have : v.F i.val j.val k'.val - δ > 0 := heq ▸ hF'
        linarith
      · rw [if_neg hcond] at heq
        rw [heq] at hF'
        exact hF'
    exact hRank i j hE hF
  · -- hF_offedge: subtraction only changes entries where pE = 1, and pE ≤ E,
    -- so off-edge entries are unchanged.
    intro i j k' hE0
    have hpE0 : pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 0 := by
      have hVP := pb.hpE_valid p
      obtain ⟨hbin, hle, _⟩ := hVP
      have h1 : pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) ≤
                pb.E (Fin.cast M.hN i) (Fin.cast M.hN j) := hle _ _
      rw [← M.hEeq, hE0] at h1
      rcases hbin (Fin.cast M.hN i) (Fin.cast M.hN j) with h0 | h1'
      · exact h0
      · rw [h1'] at h1; exact absurd h1 (by norm_num)
    rw [hF'_eq]
    have : ¬ (k' = k ∧ pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1) := by
      intro ⟨_, h2⟩; rw [hpE0] at h2; exact absurd h2 (by norm_num)
    rw [if_neg this]
    exact h.hF_offedge i j k' hE0
  · -- hF_nn.
    exact subtractFlow_F_nn pa pb M v h k p δ hδ_nn hδ_le
  · -- hR_nn.
    intro k'; exact h.hR_nn k'

-- ============================================================================
-- § Single-commodity flow decomposition
-- ============================================================================

/-- **Single-commodity flow decomposition.** By strong induction on the
positive-flow support cardinality. -/
lemma flow_decomp_single_commodity
    (pa : P20.a.Params) (pb : P20.b.Params) (M : ParamsMatch pa pb)
    (v : P20.a.Vars) (h : WeakFeasible pa v) (k : Fin pa.nK) :
    IsFlowDecomposition pa pb M.hN v k := by
  classical
  -- Strong induction on (posSupport pa v k).card.
  -- We do strong induction on n with the invariant n = card.
  suffices H : ∀ n : ℕ, ∀ v : P20.a.Vars, WeakFeasible pa v →
      (posSupport pa v k).card = n → IsFlowDecomposition pa pb M.hN v k by
    exact H _ v h rfl
  intro n
  induction n using Nat.strong_induction_on with
  | _ n ih =>
      intro v h hcard
      by_cases hempty : posSupport pa v k = ∅
      · exact flow_decomposition_empty_support pa pb M.hN v h k hempty
      · have hne : (posSupport pa v k).Nonempty :=
          Finset.nonempty_iff_ne_empty.mpr hempty
        -- Extract path.
        obtain ⟨p, pE', pRank', hVP, hpEp_eq, hpos_arc⟩ :=
          exists_path_index_of_pos_support pa pb M v h k hne
        -- Path arcs all carry positive flow.
        have hpos_arcs : ∀ i j : Fin pa.nN, (i, j) ∈ pathArcs pa pb M p →
            0 < v.F i.val j.val k.val := by
          intro i j hij
          rw [mem_pathArcs] at hij
          rw [hpEp_eq] at hij
          exact hpos_arc i j hij
        -- Bottleneck.
        set δ := bottleneck pa pb M v k p with hδ_def
        have hδ_pos : 0 < δ := bottleneck_pos pa pb M v k p hpos_arcs
        -- New flow.
        set v' := subtractFlow pa pb M v k p δ with hv'_def
        -- WeakFeasible preserved.
        have hWeak' : WeakFeasible pa v' :=
          subtractFlow_weakFeasible pa pb M v h k p hpos_arcs
        -- Path arcs are graph edges.
        have hpEp_le_E : ∀ i j : Fin pa.nN, (i, j) ∈ pathArcs pa pb M p →
            pa.E i j = 1 := fun i j => pathArcs_subset_E pa pb M p
        -- Support strictly decreases.
        have hsupp_lt : (posSupport pa v' k).card < n := by
          rw [← hcard]
          exact subtractFlow_support_lt pa pb M v h k p hpos_arcs hpEp_le_E
        -- Apply IH to v'.
        obtain ⟨x', hx'_nn, hx'_eq⟩ :=
          ih _ hsupp_lt v' hWeak' rfl
        -- Define x := x' + δ * 𝟙_{= p}.
        refine ⟨fun p' => x' p' + (if p' = p then δ else 0), ?_, ?_⟩
        · intro p'
          show 0 ≤ x' p' + (if p' = p then δ else 0)
          by_cases h' : p' = p
          · rw [if_pos h']; linarith [hx'_nn p']
          · rw [if_neg h']; simpa using hx'_nn p'
        · intro i j
          -- Reconstitution.
          have hsplit :
              (∑ p' : Fin pb.nP,
                (pb.pE p' (Fin.cast M.hN i) (Fin.cast M.hN j) : ℝ) *
                  (x' p' + (if p' = p then δ else 0))) =
              (∑ p' : Fin pb.nP,
                (pb.pE p' (Fin.cast M.hN i) (Fin.cast M.hN j) : ℝ) * x' p') +
              (∑ p' : Fin pb.nP,
                (pb.pE p' (Fin.cast M.hN i) (Fin.cast M.hN j) : ℝ) *
                  (if p' = p then δ else 0)) := by
            rw [← Finset.sum_add_distrib]
            apply Finset.sum_congr rfl
            intro p' _; ring
          rw [hsplit]
          rw [hx'_eq i j]
          -- Second sum simplifies to (pb.pE p (cast i) (cast j) : ℝ) * δ.
          have hsnd :
              (∑ p' : Fin pb.nP,
                (pb.pE p' (Fin.cast M.hN i) (Fin.cast M.hN j) : ℝ) *
                  (if p' = p then δ else 0)) =
              (pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) : ℝ) * δ := by
            rw [Finset.sum_eq_single p]
            · rw [if_pos rfl]
            · intro p' _ hp'; rw [if_neg hp']; ring
            · intro hp; exact absurd (Finset.mem_univ p) hp
          rw [hsnd]
          -- Now: v'.F i j k + (pb.pE p (cast i) (cast j) : ℝ) * δ = v.F i j k.
          have hF_eq := subtractFlow_F (pa := pa) (pb := pb) (M := M)
                          (v := v) (k := k) (p := p) (δ := δ) i j k
          -- v'.F i j k = if k=k ∧ pE p (cast i) (cast j) = 1 then v.F-δ else v.F.
          by_cases hcond : pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 1
          · rw [hcond]; push_cast
            have : v'.F i.val j.val k.val = v.F i.val j.val k.val - δ := by
              rw [hv'_def]
              exact subtractFlow_F_on pa pb M v k p δ i j hcond
            rw [this]; ring
          · -- pE p ... = 0.
            have hpE0 : pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) = 0 := by
              rcases pb.hpE_valid p with ⟨hbin, _⟩
              rcases hbin (Fin.cast M.hN i) (Fin.cast M.hN j) with h0 | h1
              · exact h0
              · exact absurd h1 hcond
            rw [hpE0]; push_cast
            have : v'.F i.val j.val k.val = v.F i.val j.val k.val := by
              rw [hv'_def]
              apply subtractFlow_F_off
              intro ⟨_, h2⟩; exact hcond h2
            rw [this]; ring

-- ============================================================================
-- § Multi-commodity lift
-- ============================================================================

/-- **Full flow decomposition predicate.** Existence of `x : Fin pb.nP →
Fin pb.nK → ℝ` reproducing each commodity's flow. -/
def IsFullFlowDecomposition
    (pa : P20.a.Params) (pb : P20.b.Params) (M : ParamsMatch pa pb)
    (v : P20.a.Vars) : Prop :=
  ∃ x : Fin pb.nP → Fin pb.nK → ℝ,
    (∀ p k, 0 ≤ x p k) ∧
    (∀ i j : Fin pa.nN, ∀ k : Fin pa.nK,
      ∑ p : Fin pb.nP,
        (pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) : ℝ) *
          x p (Fin.cast M.hK k)
      = v.F i.val j.val k.val)

/-- **Multi-commodity lift.** Apply single-commodity decomposition for each
`k` independently, then assemble. -/
lemma flow_decomp_full
    (pa : P20.a.Params) (pb : P20.b.Params) (M : ParamsMatch pa pb)
    (v : P20.a.Vars) (h : WeakFeasible pa v) :
    IsFullFlowDecomposition pa pb M v := by
  classical
  -- For each k, get x_k : Fin pb.nP → ℝ via single-commodity decomp.
  have hx : ∀ k : Fin pa.nK, ∃ xk : Fin pb.nP → ℝ,
      (∀ p, 0 ≤ xk p) ∧
      (∀ i j : Fin pa.nN,
        ∑ p : Fin pb.nP,
          (pb.pE p (Fin.cast M.hN i) (Fin.cast M.hN j) : ℝ) * xk p
        = v.F i.val j.val k.val) := by
    intro k
    obtain ⟨xk, hxk_nn, hxk_eq⟩ := flow_decomp_single_commodity pa pb M v h k
    exact ⟨xk, hxk_nn, hxk_eq⟩
  -- Choose witness functions.
  choose xk hxk_nn hxk_eq using hx
  refine ⟨fun p kb => xk (Fin.cast M.hK.symm kb) p, ?_, ?_⟩
  · intro p kb; exact hxk_nn _ p
  · intro i j k
    have hcastk : (Fin.cast M.hK.symm (Fin.cast M.hK k) : Fin pa.nK) = k := by simp
    simp only [hcastk]
    exact hxk_eq k i j

end FlowDecomp

-- ============================================================================
-- § Canonical valid path-lists (foundation for `paramMap`)
-- ============================================================================

/-!
This section sets up `ValidPathList pa`: the type of canonical
node-list representations of valid simple supplier-to-beneficiary paths
on `pa`'s graph. Equipped with a `Fintype` instance, it is the indexing
set `Fin pb.nP` will be defined from when constructing the b-side
parameters from `pa`.

We do not (yet) build the full `paramMap` here — completing the
`hpE_complete` obligation requires a path-reconstruction lemma
(inverting `pathIndicator`) that is still future work.
-/

namespace FlowDecomp

/-- A node-list is a canonical valid simple S-to-B path on `pa` if it is
non-empty, `Nodup`, its head is a supplier (head? is `some (pa.S s)`),
its last is a beneficiary (getLast? is `some (pa.B b)`), and consecutive
nodes are connected by an edge.

We phrase head/last with `head?`/`getLast?` (rather than `head`/`getLast`)
so the predicate does not bake in a non-emptiness hypothesis — this
makes destructuring clean and avoids elimination-into-`Type` issues. -/
def IsValidPathList (pa : P20.a.Params) (L : List (Fin pa.nN)) : Prop :=
  L ≠ [] ∧
  L.Nodup ∧
  (∃ s : Fin pa.nS, L.head? = some (pa.S s)) ∧
  (∃ b : Fin pa.nB, L.getLast? = some (pa.B b)) ∧
  L.IsChain (fun u w => pa.E u w = 1)

/-- Decidability of `IsValidPathList`. -/
instance (pa : P20.a.Params) (L : List (Fin pa.nN)) :
    Decidable (IsValidPathList pa L) := by
  unfold IsValidPathList
  exact inferInstance

/-- Canonical node-list type for valid simple S-to-B paths on `pa`. -/
def ValidPathList (pa : P20.a.Params) : Type :=
  { L : List (Fin pa.nN) // IsValidPathList pa L }

/-- `ValidPathList pa` has decidable equality. -/
instance (pa : P20.a.Params) : DecidableEq (ValidPathList pa) := by
  unfold ValidPathList
  exact inferInstance

namespace ValidPathList

variable {pa : P20.a.Params}

lemma ne_nil (L : ValidPathList pa) : L.val ≠ [] := L.property.1
lemma nodup (L : ValidPathList pa) : L.val.Nodup := L.property.2.1
lemma chain (L : ValidPathList pa) :
    L.val.IsChain (fun u w => pa.E u w = 1) :=
  L.property.2.2.2.2

/-- The head of a `ValidPathList` is some supplier. -/
lemma head_supplier (L : ValidPathList pa) :
    ∃ s : Fin pa.nS, L.val.head L.ne_nil = pa.S s := by
  obtain ⟨s, hs⟩ := L.property.2.2.1
  refine ⟨s, ?_⟩
  have hh : L.val.head? = some (L.val.head L.ne_nil) :=
    List.head?_eq_some_head L.ne_nil
  rw [hh] at hs
  exact Option.some.inj hs

/-- The last node of a `ValidPathList` is some beneficiary. -/
lemma last_beneficiary (L : ValidPathList pa) :
    ∃ b : Fin pa.nB, L.val.getLast L.ne_nil = pa.B b := by
  obtain ⟨b, hb⟩ := L.property.2.2.2.1
  refine ⟨b, ?_⟩
  have hh : L.val.getLast? = some (L.val.getLast L.ne_nil) :=
    List.getLast?_eq_some_getLast L.ne_nil
  rw [hh] at hb
  exact Option.some.inj hb

/-- The `pE`-indicator built from a `ValidPathList`'s underlying list. -/
noncomputable def pE (L : ValidPathList pa) : Fin pa.nN → Fin pa.nN → ℤ :=
  pathIndicator L.val

/-- The `pRank` built from a `ValidPathList`'s underlying list. -/
noncomputable def pRank (L : ValidPathList pa) : Fin pa.nN → ℕ :=
  pathRank L.val

/-- The `pE` / `pRank` from any `ValidPathList` satisfies `IsValidPath`. -/
lemma isValidPath (L : ValidPathList pa) :
    P20.b.IsValidPath pa.S pa.B pa.E L.pE L.pRank := by
  obtain ⟨s, hs⟩ := L.head_supplier
  obtain ⟨b, hb⟩ := L.last_beneficiary
  exact exists_valid_path_of_walk pa.S pa.B pa.E pa.hE_bin pa.hSTB_disj_SB
    L.val L.ne_nil L.nodup L.chain s hs b hb

end ValidPathList

/-- `ValidPathList pa` is a `Fintype`. We factor through Mathlib's
`fintypeNodupList` (= `Fintype { l // l.Nodup }`). -/
noncomputable instance (pa : P20.a.Params) : Fintype (ValidPathList pa) := by
  classical
  -- Re-bracket: `{ L // hne ∧ hnd ∧ hhead ∧ hlast ∧ hchain }` is equivalent to
  -- the nested subtype `{ ⟨L, hnd⟩ // hne ∧ hhead ∧ hlast ∧ hchain }`.
  let P : { L : List (Fin pa.nN) // L.Nodup } → Prop :=
    fun L =>
      L.val ≠ [] ∧
      (∃ s : Fin pa.nS, L.val.head? = some (pa.S s)) ∧
      (∃ b : Fin pa.nB, L.val.getLast? = some (pa.B b)) ∧
      L.val.IsChain (fun u w => pa.E u w = 1)
  have decP : DecidablePred P := by
    intro L
    show Decidable (L.val ≠ [] ∧ _ ∧ _ ∧ _)
    exact inferInstance
  let e : ValidPathList pa ≃ { L : { L : List (Fin pa.nN) // L.Nodup } // P L } := {
    toFun := fun ⟨L, hne, hnd, hhead, hlast, hchain⟩ =>
      ⟨⟨L, hnd⟩, hne, hhead, hlast, hchain⟩,
    invFun := fun ⟨⟨L, hnd⟩, hne, hhead, hlast, hchain⟩ =>
      ⟨L, hne, hnd, hhead, hlast, hchain⟩,
    left_inv := fun ⟨_, _, _, _, _, _⟩ => rfl,
    right_inv := fun ⟨⟨_, _⟩, _, _, _, _⟩ => rfl }
  exact Fintype.ofEquiv _ e.symm

end FlowDecomp

end P20
