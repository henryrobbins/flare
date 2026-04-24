import Common
import dataset.problems.p9.formulations.a.Formulation
import dataset.problems.p9.formulations.d.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P9

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P9.a.Params) : P9.d.Params :=
  { n      := p.n
    m      := p.m
    K      := p.K
    tail   := p.tail
    head   := p.head
    c      := p.c
    f      := p.f
    u      := p.u
    O      := p.O
    D      := p.D
    d      := p.d
    hn     := p.hn
    hm     := p.hm
    hK     := p.hK
    hc_nn  := p.hc_nn
    hf_nn  := p.hf_nn
    hd_pos := p.hd_pos
    hu_nn  := p.hu_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

section ForwardHelpers

variable {p : P9.a.Params} {v : P9.a.Vars} (h : P9.a.Feasible p v)
include h

/-- Per-commodity capacity: x_{e,k} ≤ u_e * y_e. -/
private lemma per_commodity_cap (e : Fin p.m) (k : Fin p.K) :
    v.x e k ≤ p.u e * (v.y e.val : ℝ) := by
  haveI := p.hK
  have hsum : v.x e k ≤ ∑ k' : Fin p.K, v.x e k' :=
    Finset.single_le_sum
      (f := fun k' : Fin p.K => v.x e k')
      (s := univ)
      (hf := fun k' _ => h.hx_nn e k')
      (mem_univ k)
  exact le_trans hsum (h.hcap e)

/-- No flow of commodity k enters its origin. -/
private lemma no_inflow_origin (k : Fin p.K) :
    (univ.filter (fun e : Fin p.m => p.head e = p.O k)).sum
      (fun e => v.x e k) = 0 := by
  haveI := p.hn
  haveI := p.hm
  have hout_Dk :
      (univ.filter (fun e : Fin p.m => p.tail e = p.D k)).sum
        (fun e => v.x e k) = 0 := h.hsink k
  by_cases hOD : p.O k = p.D k
  · exfalso; linarith [h.hout k, hOD ▸ hout_Dk, p.hd_pos k]
  have hglob_out :
      (univ : Finset (Fin p.n)).sum (fun i =>
        (univ.filter (fun e : Fin p.m => p.tail e = i)).sum (fun e => v.x e k)) =
      (univ : Finset (Fin p.m)).sum (fun e => v.x e k) := by
    rw [← sum_biUnion]
    · congr 1; ext e; simp [mem_biUnion, mem_filter]
    · intro i _ j _ hij
      exact disjoint_filter.mpr (fun e _ h1 h2 => hij (h1 ▸ h2))
  have hglob_in :
      (univ : Finset (Fin p.n)).sum (fun i =>
        (univ.filter (fun e : Fin p.m => p.head e = i)).sum (fun e => v.x e k)) =
      (univ : Finset (Fin p.m)).sum (fun e => v.x e k) := by
    rw [← sum_biUnion]
    · congr 1; ext e; simp [mem_biUnion, mem_filter]
    · intro i _ j _ hij
      exact disjoint_filter.mpr (fun e _ h1 h2 => hij (h1 ▸ h2))
  have hO_mem : p.O k ∈ (univ : Finset (Fin p.n)) := mem_univ _
  have hD_mem : p.D k ∈ (univ.erase (p.O k)) :=
    mem_erase.mpr ⟨Ne.symm hOD, mem_univ _⟩
  rw [← add_sum_erase _ _ hO_mem,
      ← add_sum_erase _ _ hD_mem] at hglob_out
  rw [← add_sum_erase _ _ hO_mem,
      ← add_sum_erase _ _ hD_mem] at hglob_in
  have hrest_eq :
      ((univ.erase (p.O k)).erase (p.D k)).sum (fun i =>
        (univ.filter (fun e : Fin p.m => p.tail e = i)).sum (fun e => v.x e k)) =
      ((univ.erase (p.O k)).erase (p.D k)).sum (fun i =>
        (univ.filter (fun e : Fin p.m => p.head e = i)).sum (fun e => v.x e k)) := by
    apply sum_congr rfl
    intro i hi
    have hi_ne_Dk : i ≠ p.D k := ne_of_mem_erase hi
    have hi_ne_Ok : i ≠ p.O k := by
      have := mem_of_mem_erase hi
      exact ne_of_mem_erase this
    exact h.hbal k i hi_ne_Ok hi_ne_Dk
  rw [h.hout k, hout_Dk] at hglob_out
  rw [h.hin k] at hglob_in
  linarith

/-- Cut-flow bound: for any commodity k with O_k ∈ S and D_k ∉ S,
    the total flow of k crossing the cut δ⁺(S) is at least d_k. -/
private lemma cut_flow_bound (S : Finset (Fin p.n)) (k : Fin p.K)
    (hOk : p.O k ∈ S) (hDk : p.D k ∉ S) :
    p.d k ≤ (univ.filter (fun e : Fin p.m => p.tail e ∈ S ∧ p.head e ∉ S)).sum
              (fun e => v.x e k) := by
  haveI := p.hn
  haveI := p.hm
  set cutOut : Finset (Fin p.m) :=
    univ.filter (fun e => p.tail e ∈ S ∧ p.head e ∉ S) with hcutOut
  set cutIn : Finset (Fin p.m) :=
    univ.filter (fun e => p.head e ∈ S ∧ p.tail e ∉ S) with hcutIn
  suffices hh : p.d k + cutIn.sum (fun e => v.x e k) = cutOut.sum (fun e => v.x e k) by
    linarith [sum_nonneg (fun e (_ : e ∈ cutIn) => h.hx_nn e k)]
  have htail_reindex : S.sum (fun i =>
      (univ.filter (fun e : Fin p.m => p.tail e = i)).sum (fun e => v.x e k)) =
      (univ.filter (fun e : Fin p.m => p.tail e ∈ S)).sum (fun e => v.x e k) := by
    rw [← sum_biUnion]
    · congr 1; ext e; simp [mem_biUnion, mem_filter]
    · intro i _ j _ hij
      exact disjoint_filter.mpr (fun e _ h1 h2 => hij (h1 ▸ h2))
  have hhead_reindex : S.sum (fun i =>
      (univ.filter (fun e : Fin p.m => p.head e = i)).sum (fun e => v.x e k)) =
      (univ.filter (fun e : Fin p.m => p.head e ∈ S)).sum (fun e => v.x e k) := by
    rw [← sum_biUnion]
    · congr 1; ext e; simp [mem_biUnion, mem_filter]
    · intro i _ j _ hij
      exact disjoint_filter.mpr (fun e _ h1 h2 => hij (h1 ▸ h2))
  have hnode_sum : S.sum (fun i =>
      (univ.filter (fun e : Fin p.m => p.tail e = i)).sum (fun e => v.x e k) -
      (univ.filter (fun e : Fin p.m => p.head e = i)).sum (fun e => v.x e k)) = p.d k := by
    rw [← add_sum_erase S _ hOk]
    have hin_Ok := no_inflow_origin h k
    have horigin :
        (univ.filter (fun e : Fin p.m => p.tail e = p.O k)).sum (fun e => v.x e k) -
        (univ.filter (fun e : Fin p.m => p.head e = p.O k)).sum (fun e => v.x e k) =
        p.d k := by
      rw [h.hout k, hin_Ok]; ring
    have hrest : (S.erase (p.O k)).sum (fun i =>
        (univ.filter (fun e : Fin p.m => p.tail e = i)).sum (fun e => v.x e k) -
        (univ.filter (fun e : Fin p.m => p.head e = i)).sum (fun e => v.x e k)) = 0 := by
      apply sum_eq_zero
      intro i hi
      have hi_in_S : i ∈ S := mem_of_mem_erase hi
      have hi_ne_Ok : i ≠ p.O k := ne_of_mem_erase hi
      have hi_ne_Dk : i ≠ p.D k := fun hh => hDk (hh ▸ hi_in_S)
      have := h.hbal k i hi_ne_Ok hi_ne_Dk
      linarith
    linarith
  have htail_split :
      (univ.filter (fun e : Fin p.m => p.tail e ∈ S)).sum (fun e => v.x e k) =
      cutOut.sum (fun e => v.x e k) +
      (univ.filter (fun e : Fin p.m => p.tail e ∈ S ∧ p.head e ∈ S)).sum
        (fun e => v.x e k) := by
    have hh := sum_filter_add_sum_filter_not
      (univ.filter (fun e : Fin p.m => p.tail e ∈ S))
      (fun e : Fin p.m => p.head e ∉ S) (fun e => v.x e k)
    rw [filter_filter, filter_filter] at hh
    simp only [not_not] at hh
    linarith
  have hhead_split :
      (univ.filter (fun e : Fin p.m => p.head e ∈ S)).sum (fun e => v.x e k) =
      cutIn.sum (fun e => v.x e k) +
      (univ.filter (fun e : Fin p.m => p.tail e ∈ S ∧ p.head e ∈ S)).sum
        (fun e => v.x e k) := by
    have hh := sum_filter_add_sum_filter_not
      (univ.filter (fun e : Fin p.m => p.head e ∈ S))
      (fun e : Fin p.m => p.tail e ∉ S) (fun e => v.x e k)
    rw [filter_filter, filter_filter] at hh
    simp only [not_not] at hh
    have hcomm :
        (univ.filter (fun e : Fin p.m => p.head e ∈ S ∧ p.tail e ∈ S)).sum
          (fun e => v.x e k) =
        (univ.filter (fun e : Fin p.m => p.tail e ∈ S ∧ p.head e ∈ S)).sum
          (fun e => v.x e k) :=
      sum_congr (filter_congr (fun _ _ => and_comm)) (fun _ _ => rfl)
    linarith
  have hsub : S.sum (fun i =>
      (univ.filter (fun e : Fin p.m => p.tail e = i)).sum (fun e => v.x e k) -
      (univ.filter (fun e : Fin p.m => p.head e = i)).sum (fun e => v.x e k)) =
    S.sum (fun i => (univ.filter (fun e : Fin p.m => p.tail e = i)).sum (fun e => v.x e k)) -
    S.sum (fun i => (univ.filter (fun e : Fin p.m => p.head e = i)).sum (fun e => v.x e k)) :=
    sum_sub_distrib
      (fun i => (univ.filter (fun e : Fin p.m => p.tail e = i)).sum (fun e => v.x e k))
      (fun i => (univ.filter (fun e : Fin p.m => p.head e = i)).sum (fun e => v.x e k))
  linarith

end ForwardHelpers

/--
**P9.a → P9.d**: identity on variables. We must additionally verify the
cardinality cut EC2.
-/
private def fwd (_ : P9.a.Params) (v : P9.a.Vars) : P9.d.Vars :=
  { x := v.x
    y := v.y }

private lemma fwd_feas (p : P9.a.Params) (v : P9.a.Vars)
    (h : P9.a.Feasible p v) :
    P9.d.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hm
  haveI := p.hK
  refine
    { hout   := h.hout
      hin    := h.hin
      hbal   := h.hbal
      hcap   := h.hcap
      hx_nn  := h.hx_nn
      hy_bin := h.hy_bin
      hsink  := h.hsink
      hec2   := ?_ }
  intro S _hSne _hSu
  -- Unfold the let-bound cutS, B, and D_B from EC2's definition.
  simp only []
  intro q hq
  -- Set up local names for the cut, commodity set, and demand.
  set cutS : Finset (Fin p.m) :=
    univ.filter (fun e : Fin p.m => p.tail e ∈ S ∧ p.head e ∉ S) with hcutS
  set B : Finset (Fin p.K) :=
    univ.filter (fun k : Fin p.K => p.O k ∈ S ∧ p.D k ∉ S) with hBdef
  set DB : ℝ := B.sum p.d with hDB_def
  -- T = activated cut arcs.
  set T := cutS.filter (fun e : Fin p.m => v.y e.val = 1) with hTdef
  -- Step 1: DB ≤ cutS.sum (fun e => B.sum (v.x e ·))
  have hDB_le :
      DB ≤ cutS.sum (fun e => B.sum (fun k => v.x e k)) := by
    have hstep1 :
        DB ≤ B.sum (fun k => cutS.sum (fun e => v.x e k)) := by
      refine sum_le_sum (fun k hkB => ?_)
      have hk_mem := mem_filter.mp hkB
      have hOk : p.O k ∈ S := hk_mem.2.1
      have hDk : p.D k ∉ S := hk_mem.2.2
      exact cut_flow_bound h S k hOk hDk
    calc DB ≤ B.sum (fun k => cutS.sum (fun e => v.x e k)) := hstep1
      _ = cutS.sum (fun e => B.sum (fun k => v.x e k)) := sum_comm
  -- Zero-flow on inactive cut arcs.
  have hzero : ∀ e ∈ cutS, e ∉ T → B.sum (fun k => v.x e k) = 0 := by
    intro e hec he
    have hy0 : v.y e.val = 0 := by
      have hne : v.y e.val ≠ 1 := fun hh => he (mem_filter.mpr ⟨hec, hh⟩)
      have := h.hy_bin e; omega
    have hye0 : (v.y e.val : ℝ) = 0 := by exact_mod_cast hy0
    have htotal0 : ∑ k : Fin p.K, v.x e k ≤ 0 := by
      have := h.hcap e; rw [hye0, mul_zero] at this; exact this
    have hBle : B.sum (fun k => v.x e k) ≤ ∑ k : Fin p.K, v.x e k :=
      sum_le_sum_of_subset_of_nonneg (subset_univ B)
        (fun k _ _ => h.hx_nn e k)
    have hBge : 0 ≤ B.sum (fun k => v.x e k) :=
      sum_nonneg (fun k _ => h.hx_nn e k)
    linarith
  have hDB_T : DB ≤ T.sum (fun e => B.sum (fun k => v.x e k)) := by
    have hss := sum_subset (filter_subset _ cutS) hzero
    linarith
  -- Step 2: T.sum (B.sum x) ≤ T.sum p.u.
  have hT_cap : T.sum (fun e => B.sum (fun k => v.x e k)) ≤ T.sum p.u := by
    refine sum_le_sum fun e he => ?_
    have hye1 : (v.y e.val : ℝ) = 1 := by exact_mod_cast (mem_filter.mp he).2
    calc B.sum (fun k => v.x e k)
        ≤ ∑ k : Fin p.K, v.x e k :=
          sum_le_sum_of_subset_of_nonneg (subset_univ B)
            (fun k _ _ => h.hx_nn e k)
      _ ≤ p.u e := by have := h.hcap e; rw [hye1, mul_one] at this; exact this
  have hDB_cap : DB ≤ T.sum p.u := by linarith
  -- Step 3: q ≤ T.card (contrapositive of hq).
  have hT_sub_cutS : T ⊆ cutS := filter_subset _ _
  have hq_le : q ≤ T.card := by
    by_contra hlt; push_neg at hlt
    -- `cut` is an `abbrev` for the same filter expression that defines `cutS`,
    -- and `(paramMap p).u = p.u`, `(paramMap p).d = p.d` are definitionally equal.
    -- The `hT_in_cut` coercion is trivial since `paramMap` copies fields identically.
    have hT_in_cut : T ⊆ cutS := hT_sub_cutS
    have hbad := hq T hT_in_cut hlt
    change T.sum p.u < B.sum p.d at hbad
    linarith
  -- Step 4: T.sum y_e = T.card (since y_e = 1 on T), and T ⊆ cutS.
  have hT_ones : T.sum (fun e => (v.y e.val : ℝ)) = (T.card : ℝ) := by
    have h1 : T.sum (fun e => (v.y e.val : ℝ)) = T.sum (fun _ => (1 : ℝ)) :=
      sum_congr rfl fun e he => by exact_mod_cast (mem_filter.mp he).2
    rw [h1]; simp
  have hge_T :
      T.sum (fun e => (v.y e.val : ℝ)) ≤ cutS.sum (fun e => (v.y e.val : ℝ)) :=
    sum_le_sum_of_subset_of_nonneg hT_sub_cutS
      (fun e _ _ => by have := h.hy_bin e; norm_cast; omega)
  have hq_real : (q : ℝ) ≤ (T.card : ℝ) := by exact_mod_cast hq_le
  -- Goal: (q : ℝ) ≤ cutS.sum (fun e => (v.y e.val : ℝ)).
  -- `P9.d.cut (paramMap p).tail (paramMap p).head S` and `(fwd p v).y` reduce to
  -- `cutS` and `v.y` by definition since paramMap and fwd copy all fields identically.
  change (q : ℝ) ≤ cutS.sum (fun e => (v.y e.val : ℝ))
  linarith

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**P9.d → P9.a**: identity on variables. All constraints except `hec2`
transfer directly; `hec2` is simply dropped.
-/
private def bwd (_ : P9.a.Params) (v : P9.d.Vars) : P9.a.Vars :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P9.a.Params) (v : P9.d.Vars)
    (h : P9.d.Feasible (paramMap p) v) :
    P9.a.Feasible p (bwd p v) := by
  exact
    { hout   := h.hout
      hin    := h.hin
      hbal   := h.hbal
      hcap   := h.hcap
      hx_nn  := h.hx_nn
      hy_bin := h.hy_bin
      hsink  := h.hsink }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aDEquiv : MILPEquiv P9.a.formulation P9.d.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := monotone_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P9
