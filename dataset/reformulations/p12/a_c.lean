import Common
import problems.p12.formulations.a.Formulation
import problems.p12.formulations.c.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P12

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P12.a.Params) : P12.c.Params :=
  { n  := p.n
    c  := p.c
    hn := p.hn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- fwd overrides u: if x i 0 = 1, set u i = n. This ensures hec2 holds without
-- breaking hmtz (the unique outgoing arc from such an i is 0, so x_{i j} = 0
-- for all j in Fin p.n, and the incoming constraint forbids two such i's).
private def fwd (p : P12.a.Params) (v : P12.a.Vars p) : P12.c.Vars (paramMap p) :=
  haveI : NeZero p.n := ⟨by have := p.hn; omega⟩
  { x := v.x
    u := fun i => if v.x i 0 = 1 then (p.n : ℝ) else v.u i }

private lemma fwd_feas (p : P12.a.Params) (v : P12.a.Vars p)
    (h : P12.a.Feasible p v) :
    P12.c.Feasible (paramMap p) (fwd p v) := by
  haveI : NeZero p.n := ⟨by have := p.hn; omega⟩
  have hn_pos : 0 < p.n := Nat.pos_of_ne_zero (NeZero.ne p.n)
  -- x a b ∈ {0, 1} so nonneg
  have xnn : ∀ (a b : Fin p.n), 0 ≤ v.x a b := fun a b => by
    rcases h.hx_bin a b with h0 | h1 <;> omega
  -- x 0 0 = 0 (no self-loop on depot ∈ Fin p.n)
  have hself0 : v.x 0 0 = 0 := h.hx_no_self ⟨0, hn_pos⟩
  -- p.n ≥ 2 from feasibility
  have hn2 : 2 ≤ p.n := by
    rcases Nat.lt_or_ge p.n 2 with hlt | hge
    · exfalso
      have hn1 : p.n = 1 := by omega
      have hout0 := h.hout ⟨0, hn_pos⟩
      have hfin : (univ : Finset (Fin p.n)) = {⟨0, hn_pos⟩} := by
        apply Finset.eq_singleton_iff_unique_mem.mpr
        exact ⟨mem_univ _, fun x _ => Fin.ext (by have := x.isLt; omega)⟩
      rw [hfin, Finset.sum_singleton] at hout0
      simp [hself0] at hout0
    · exact hge
  refine
    { hout       := h.hout
      hin        := h.hin
      hmtz       := ?_
      hu_depot   := ?_
      hx_bin     := h.hx_bin
      hu_lo      := ?_
      hu_hi      := ?_
      hx_no_self := h.hx_no_self
      hec2       := ?_ }
  · -- hmtz
    intro i j hi hj hij
    simp only [fwd, paramMap]
    by_cases hxi : v.x i 0 = 1
    · -- x_{i 0} = 1: u'_i = n; x_{i j} = 0 by hout (unique outgoing)
      have hxij : v.x i j = 0 := by
        have hout_i := h.hout i
        have h0_in : (⟨0, hn_pos⟩ : Fin p.n) ∈ (univ : Finset (Fin p.n)) := mem_univ _
        have hj_ne_0 : j ≠ ⟨0, hn_pos⟩ := fun heq => hj (by rw [heq])
        have hj_in_erase : j ∈ (univ : Finset (Fin p.n)).erase ⟨0, hn_pos⟩ :=
          Finset.mem_erase.mpr ⟨hj_ne_0, mem_univ _⟩
        rw [← Finset.add_sum_erase univ (fun k : Fin p.n => v.x i k) h0_in]
          at hout_i
        rw [← Finset.add_sum_erase _ (fun k : Fin p.n => v.x i k) hj_in_erase]
          at hout_i
        have hrest_nn : 0 ≤ ∑ k ∈ ((univ : Finset (Fin p.n)).erase ⟨0, hn_pos⟩).erase j,
            v.x i k :=
          Finset.sum_nonneg (fun k _ => xnn _ _)
        have hxij_nn : 0 ≤ v.x i j := xnn _ _
        have hxi0' : v.x i ⟨0, hn_pos⟩ = 1 := hxi
        omega
      rw [if_pos hxi]
      by_cases hxj : v.x j 0 = 1
      · -- Two distinct nodes both point to 0: violates hin 0
        exfalso
        have hin0 := h.hin ⟨0, hn_pos⟩
        have hi_in : i ∈ (univ : Finset (Fin p.n)) := mem_univ _
        have hj_in_erase : j ∈ (univ : Finset (Fin p.n)).erase i :=
          Finset.mem_erase.mpr ⟨hij.symm, mem_univ _⟩
        rw [← Finset.add_sum_erase univ (fun k : Fin p.n => v.x k ⟨0, hn_pos⟩) hi_in]
          at hin0
        rw [← Finset.add_sum_erase _ (fun k : Fin p.n => v.x k ⟨0, hn_pos⟩) hj_in_erase]
          at hin0
        have hrest_nn : 0 ≤ ∑ k ∈ ((univ : Finset (Fin p.n)).erase i).erase j,
            v.x k ⟨0, hn_pos⟩ :=
          Finset.sum_nonneg (fun k _ => xnn k ⟨0, hn_pos⟩)
        have hxi0' : v.x i ⟨0, hn_pos⟩ = 1 := hxi
        have hxj0' : v.x j ⟨0, hn_pos⟩ = 1 := hxj
        omega
      · rw [if_neg hxj, hxij]
        push_cast
        have hulo_j := h.hu_lo j hj
        linarith
    · rw [if_neg hxi]
      by_cases hxj : v.x j 0 = 1
      · rw [if_pos hxj]
        have hmtz := h.hmtz i j hi hj hij
        have huhi_j := h.hu_hi j
        linarith
      · rw [if_neg hxj]
        exact h.hmtz i j hi hj hij
  · -- hu_depot: u' 0 = 1
    show (if v.x 0 0 = 1 then (p.n : ℝ) else v.u 0) = 1
    rw [hself0]; simp; exact h.hu_depot
  · -- hu_lo
    intro i hi
    simp only [fwd]
    split_ifs with hxi
    · exact_mod_cast hn2
    · exact h.hu_lo i hi
  · -- hu_hi
    intro i
    simp only [fwd, paramMap]
    split_ifs with hxi
    · exact le_refl _
    · exact h.hu_hi i
  · -- hec2
    intro i hi
    simp only [fwd, paramMap]
    by_cases hxi : v.x i 0 = 1
    · simp [hxi]
    · rw [if_neg hxi]
      have hx0 : v.x i 0 = 0 := (h.hx_bin i ⟨0, hn_pos⟩).resolve_right hxi
      rw [hx0]; push_cast
      have := h.hu_lo i hi
      linarith

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- bwd simply drops hec2
private def bwd (p : P12.a.Params) (v : P12.c.Vars (paramMap p)) : P12.a.Vars p :=
  { x := v.x
    u := v.u }

private lemma bwd_feas (p : P12.a.Params) (v : P12.c.Vars (paramMap p))
    (h : P12.c.Feasible (paramMap p) v) :
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

def aCReformulation : MILPReformulation P12.a.formulation P12.c.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj p v _ := by
    simp only [P12.a.formulation, P12.c.formulation, P12.a.obj, P12.c.obj,
      fwd, paramMap, id]
  bwd_obj p v _ := by
    simp only [P12.a.formulation, P12.c.formulation, P12.a.obj, P12.c.obj,
      bwd, paramMap, id]

end P12
