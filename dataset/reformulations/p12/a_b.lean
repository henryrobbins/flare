import Common
import dataset.problems.p12.formulations.a.Formulation
import dataset.problems.p12.formulations.b.Formulation
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

-- If ∑ k ∈ s, f k = 1, each f k ≥ 0, f a = 1, a ≠ b, then f b = 0.
private lemma sum_one_of_ne_zero {α : Type*} [DecidableEq α] {s : Finset α}
    {f : α → ℤ} {a b : α} (ha : a ∈ s) (hb : b ∈ s) (hab : a ≠ b)
    (hnn : ∀ k ∈ s, 0 ≤ f k) (hsum : ∑ k ∈ s, f k = 1) (hfa : f a = 1) :
    f b = 0 := by
  have hge : 0 ≤ f b := hnn b hb
  have key : f a + ∑ k ∈ s.erase a, f k = 1 :=
    calc f a + ∑ k ∈ s.erase a, f k = ∑ k ∈ s, f k := Finset.add_sum_erase s f ha
      _ = 1 := hsum
  have hrest : ∑ k ∈ s.erase a, f k = 0 := by linarith [hfa ▸ key]
  have hb_erase : b ∈ s.erase a := Finset.mem_erase.mpr ⟨hab.symm, hb⟩
  have hnn2 : ∀ k ∈ s.erase a, 0 ≤ f k := fun k hk =>
    hnn k (Finset.mem_of_mem_erase hk)
  exact (Finset.sum_eq_zero_iff_of_nonneg hnn2).mp hrest b hb_erase

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

-- fwd modifies u: if x 0 j = 1, set u j = 2; otherwise keep u j.
-- This ensures hec1 holds: when x 0 j = 1, u j = 2 ≤ 2 + 0.
private def fwd (p : P12.a.Params) (v : P12.a.Vars p) : P12.b.Vars (paramMap p) :=
  haveI : NeZero p.n := p.hn
  { x := v.x
    u := fun i => if v.x 0 i = 1 then 2 else v.u i }

private lemma fwd_feas (p : P12.a.Params) (v : P12.a.Vars p)
    (h : P12.a.Feasible p v) :
    P12.b.Feasible (paramMap p) (fwd p v) := by
  haveI : NeZero p.n := p.hn
  have hn_pos : 0 < p.n := Nat.pos_of_ne_zero (NeZero.ne p.n)
  -- Depot index (same n since (paramMap p).n = p.n definitionally)
  let depot : Fin p.n := ⟨0, hn_pos⟩
  -- x 0 0 = 0 (no self-loop)
  have hself0 : v.x 0 0 = 0 := h.hx_no_self depot
  -- x a b ∈ {0, 1}
  have xnn : ∀ (a b : Fin p.n), 0 ≤ v.x a b := fun a b => by
    rcases h.hx_bin a b with h0 | h1 <;> omega
  -- x 0 k = 0 when x 0 k ≠ 1
  have xzero : ∀ k : Fin p.n, ¬v.x 0 k = 1 → v.x 0 k = 0 := fun k hk =>
    (h.hx_bin depot k).resolve_right hk
  constructor
  · -- hout: x unchanged
    exact h.hout
  · -- hin: x unchanged
    exact h.hin
  · -- hmtz: u' i - u' j + n * x i j ≤ n - 1
    intro i j hi hj hij
    simp only [fwd, paramMap]
    by_cases hxi : v.x 0 i = 1
    · by_cases hxj : v.x 0 j = 1
      · -- Both x_{0i} = 1 and x_{0j} = 1: contradicts hout (sum = 1 but ≥ 2)
        exfalso
        have hout0 := h.hout depot
        -- depot ≠ i and depot ≠ j (since i.val ≠ 0 and j.val ≠ 0)
        have hdi : depot ≠ i := Fin.val_ne_iff.mp (Ne.symm hi)
        have hdj : depot ≠ j := Fin.val_ne_iff.mp (Ne.symm hj)
        -- split sum: x depot i + ∑ (erase i) = 1
        rw [← Finset.add_sum_erase univ (fun k : Fin p.n => v.x depot k)
              (mem_univ i)] at hout0
        -- further split: x depot j + ∑ (erase i, erase j) ≤ sum over erase i
        have hj_in : j ∈ (univ (α := Fin p.n)).erase i :=
          Finset.mem_erase.mpr ⟨hij.symm, mem_univ _⟩
        rw [← Finset.add_sum_erase _ (fun k : Fin p.n => v.x depot k) hj_in] at hout0
        have hge3 : 0 ≤ ∑ k ∈ ((univ (α := Fin p.n)).erase i).erase j, v.x depot k :=
          Finset.sum_nonneg (fun k _ => xnn depot k)
        have hxi' : v.x depot i = 1 := hxi
        have hxj' : v.x depot j = 1 := hxj
        linarith [hxi', hxj']
      · -- x_{0i} = 1, x_{0j} ≠ 1 (so = 0): u'_i = 2, u'_j = v.u j
        rw [if_pos hxi, if_neg hxj]
        linarith [h.hmtz i j hi hj hij, h.hu_lo i hi]
    · by_cases hxj : v.x 0 j = 1
      · -- x_{0i} ≠ 1 (so = 0), x_{0j} = 1: u'_i = v.u i, u'_j = 2
        rw [if_neg hxi, if_pos hxj]
        -- x i j = 0: from hin j and x depot j = 1
        have hdi : depot ≠ i := Fin.val_ne_iff.mp (Ne.symm hi)
        have hxij : v.x i j = 0 :=
          sum_one_of_ne_zero (s := univ)
            (a := (⟨0, hn_pos⟩ : Fin (paramMap p).n)) (b := i)
            (mem_univ _) (mem_univ i) (Fin.val_ne_iff.mp (Ne.symm hi))
            (fun k _ => xnn k j) (h.hin j) hxj
        rw [hxij]; push_cast
        linarith [h.hu_hi i]
      · -- x_{0i} ≠ 1, x_{0j} ≠ 1: u'_i = v.u i, u'_j = v.u j
        rw [if_neg hxi, if_neg hxj]
        exact h.hmtz i j hi hj hij
  · -- hu_depot: u' 0 = 1
    simp only [fwd, hself0]
    exact h.hu_depot
  · -- hx_bin: x unchanged
    exact h.hx_bin
  · -- hu_lo: u' i ≥ 2 for i ≠ 0
    intro i hi
    simp only [fwd]
    split_ifs with hxi
    · norm_num
    · exact h.hu_lo i hi
  · -- hu_hi: u' i ≤ n
    intro i
    simp only [fwd, paramMap]
    split_ifs with hxi
    · -- u'_i = 2; need (2 : ℝ) ≤ (p.n : ℝ)
      -- x 0 i = 1, x 0 0 = 0, so i ≠ 0, so hu_lo gives 2 ≤ u i ≤ n
      have hi_ne_0 : i.val ≠ 0 := fun heq => by
        have hi0 : i = (0 : Fin p.n) := Fin.ext (by simpa using heq)
        rw [hi0, hself0] at hxi
        omega
      linarith [h.hu_lo i hi_ne_0, h.hu_hi i]
    · exact h.hu_hi i
  · -- hec1: ∀ j ≠ 0, u' j ≤ 2 + (n - 2) * (1 - x 0 j)
    intro j hj
    simp only [fwd, paramMap]
    split_ifs with hxj
    · -- u'_j = 2, x 0 j = 1: RHS = 2 + (n-2) * 0 = 2
      push_cast [hxj]; ring_nf; norm_num
    · -- u'_j = v.u j, x 0 j = 0: RHS = 2 + (n-2) * 1 = n
      push_cast [xzero j hxj]; ring_nf; linarith [h.hu_hi j]
  · -- hx_no_self: x i i = 0
    exact h.hx_no_self

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- bwd simply drops hec1
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
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj p v _ := by
    simp only [P12.a.formulation, P12.b.formulation, P12.a.obj, P12.b.obj, fwd, paramMap, id]
  bwd_obj p v _ := by
    simp only [P12.a.formulation, P12.b.formulation, P12.a.obj, P12.b.obj, bwd, paramMap, id]

end P12
