import Common
import dataset.problems.p16.formulations.a.Formulation
import dataset.problems.p16.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P16

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P16.a.Params) : P16.b.Params :=
  { N       := p.N
    M       := p.M
    nP      := p.nP
    nS      := p.nS
    v       := p.v
    F       := p.F
    U       := p.U
    hN_le_M := p.hN_le_M
    hF_bin  := p.hF_bin
    hNP     := p.hNP
    hNS     := p.hNS
    hM      := p.hM
    hv_nn   := p.hv_nn
    hU_nn   := p.hU_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

/-- Set of `(s,q,h)` such that `h` is the smallest index (by `Fin.val`) with
`F[s,h,q] = 1` and `y[h] = 1`. -/
private noncomputable def chosenHub (p : P16.a.Params) (v : P16.a.Vars)
    (s : Fin p.nS) (q : Fin p.nP) : Option (Fin p.M) :=
  haveI := p.hM
  let S : Finset (Fin p.M) :=
    (univ : Finset (Fin p.M)).filter (fun h => p.F s h q = 1 ∧ v.y h.val = 1)
  if hS : S.Nonempty then some (S.min' hS) else none

open Classical in
/--
**A → B**: `x[s,h,q] = 1` iff `v.z s q = 1` and `h` is the chosen
(smallest-index) feasible open hub for `(s,q)`; else `0`. `y` is copied.
-/
private noncomputable def fwd (p : P16.a.Params) (v : P16.a.Vars) : P16.b.Vars :=
  { y := v.y
    x := fun s hh q =>
      if hs : s < p.nS ∧ q < p.nP then
        if v.z s q = 1 then
          match chosenHub p v ⟨s, hs.1⟩ ⟨q, hs.2⟩ with
          | some h => if h.val = hh then 1 else 0
          | none => 0
        else 0
      else 0 }

/-- Key lemma: when `v.z s q = 1`, the chosen hub exists. -/
private lemma chosenHub_isSome_of_z {p : P16.a.Params} {v : P16.a.Vars}
    (h : P16.a.Feasible p v) {s : Fin p.nS} {q : Fin p.nP}
    (hz : v.z s.val q.val = 1) :
    (chosenHub p v s q).isSome := by
  haveI := p.hM
  unfold chosenHub
  -- Need to show the filter set is nonempty
  have hy_nn : ∀ hh : Fin p.M, 0 ≤ v.y hh.val := fun hh => by
    rcases h.hy_bin hh with h0 | h1 <;> omega
  have hF_nn : ∀ hh : Fin p.M, 0 ≤ p.F s hh q := fun hh => by
    rcases p.hF_bin s hh q with h0 | h1 <;> omega
  have hne : ((univ : Finset (Fin p.M)).filter
      (fun h => p.F s h q = 1 ∧ v.y h.val = 1)).Nonempty := by
    -- by hcover: 1 = v.z ≤ ∑ F*y; so some term = 1
    have hcov := h.hcover s q
    rw [hz] at hcov
    by_contra hnemp
    rw [Finset.not_nonempty_iff_eq_empty] at hnemp
    have hzero : ∀ hh : Fin p.M, p.F s hh q * v.y hh.val = 0 := by
      intro hh
      have hh_not_mem : hh ∉ (univ : Finset (Fin p.M)).filter
          (fun h => p.F s h q = 1 ∧ v.y h.val = 1) := by
        rw [hnemp]; exact notMem_empty _
      simp only [mem_filter, mem_univ, true_and, not_and_or] at hh_not_mem
      rcases p.hF_bin s hh q with hF0 | hF1
      · rw [hF0]; ring
      · rcases h.hy_bin hh with hy0 | hy1
        · rw [hy0]; ring
        · exfalso
          rcases hh_not_mem with hF | hy
          · exact hF hF1
          · exact hy hy1
    have hsum_zero : ∑ hh : Fin p.M, p.F s hh q * v.y hh.val = 0 := by
      apply Finset.sum_eq_zero
      intro hh _
      exact hzero hh
    rw [hsum_zero] at hcov
    exact absurd hcov (by norm_num)
  simp [hne]

/-- The chosen hub, when it exists, has `F = 1` and `y = 1`. -/
private lemma chosenHub_spec (p : P16.a.Params) (v : P16.a.Vars)
    (s : Fin p.nS) (q : Fin p.nP) (hh : Fin p.M)
    (hch : chosenHub p v s q = some hh) :
    p.F s hh q = 1 ∧ v.y hh.val = 1 := by
  haveI := p.hM
  unfold chosenHub at hch
  simp only at hch
  by_cases hS : ((univ : Finset (Fin p.M)).filter
      (fun h => p.F s h q = 1 ∧ v.y h.val = 1)).Nonempty
  · rw [dif_pos hS] at hch
    have hminEq : (((univ : Finset (Fin p.M)).filter
        (fun h => p.F s h q = 1 ∧ v.y h.val = 1)).min' hS) = hh :=
      Option.some_injective _ hch
    have hmem := Finset.min'_mem _ hS
    rw [hminEq] at hmem
    simp only [mem_filter, mem_univ, true_and] at hmem
    exact hmem
  · rw [dif_neg hS] at hch
    exact absurd hch (by simp)

/-- Simplified form of `fwd.x` on valid indices. -/
private lemma fwd_x_apply (p : P16.a.Params) (v : P16.a.Vars)
    (s : Fin p.nS) (q : Fin p.nP) (hh : Fin p.M) :
    (fwd p v).x s.val hh.val q.val =
      if v.z s.val q.val = 1 then
        match chosenHub p v s q with
        | some h => if h.val = hh.val then 1 else 0
        | none => 0
      else 0 := by
  unfold fwd
  simp only
  rw [dif_pos ⟨s.isLt, q.isLt⟩]

/-- Sum of `fwd` x-values over `h` equals `z[s,q]`. -/
private lemma fwd_sum_x_eq_z (p : P16.a.Params) (v : P16.a.Vars)
    (h : P16.a.Feasible p v) (s : Fin p.nS) (q : Fin p.nP) :
    ∑ hh : Fin p.M, (fwd p v).x s.val hh.val q.val = v.z s.val q.val := by
  haveI := p.hM
  simp_rw [fwd_x_apply p v s q]
  rcases h.hz_bin s q with hz0 | hz1
  · rw [hz0]
    simp
  · rw [hz1]
    simp only [if_true]
    have hisSome := chosenHub_isSome_of_z h hz1
    rcases hch : chosenHub p v s q with _ | hh0
    · rw [hch] at hisSome; simp at hisSome
    · -- sum of an indicator = 1
      simp only
      rw [Finset.sum_eq_single hh0]
      · simp
      · intro b _ hbne
        rw [if_neg]
        intro heq
        apply hbne
        exact Fin.ext heq.symm
      · intro hnmem; exact absurd (mem_univ hh0) hnmem

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**B → A**: set `z[s,q] = Σ_h x[s,h,q]` and keep `y`.
-/
private def bwd (p : P16.a.Params) (v : P16.b.Vars) : P16.a.Vars :=
  { y := v.y
    z := fun s q => ∑ hh : Fin p.M, v.x s hh.val q }

private lemma fwd_feas (p : P16.a.Params) (v : P16.a.Vars)
    (h : P16.a.Feasible p v) :
    P16.b.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hM
  have hy_nn : ∀ hh : Fin p.M, 0 ≤ v.y hh.val := fun hh => by
    rcases h.hy_bin hh with h0 | h1 <;> omega
  have hF_nn : ∀ (s : Fin p.nS) (hh : Fin p.M) (q : Fin p.nP),
      0 ≤ p.F s hh q := fun s hh q => by
    rcases p.hF_bin s hh q with h0 | h1 <;> omega
  -- x is binary
  have hx_bin : ∀ (s : Fin p.nS) (hh : Fin p.M) (q : Fin p.nP),
      (fwd p v).x s.val hh.val q.val = 0 ∨
      (fwd p v).x s.val hh.val q.val = 1 := by
    intro s hh q
    rw [fwd_x_apply]
    by_cases hz : v.z s.val q.val = 1
    · rw [if_pos hz]
      rcases hch : chosenHub p v s q with _ | h0
      · simp
      · simp only
        by_cases hheq : h0.val = hh.val
        · right; rw [if_pos hheq]
        · left; rw [if_neg hheq]
    · rw [if_neg hz]; left; rfl
  -- x = 1 implies chosen hub matches, implying F=1 and y=1
  have hx_one_spec : ∀ (s : Fin p.nS) (hh : Fin p.M) (q : Fin p.nP),
      (fwd p v).x s.val hh.val q.val = 1 →
        p.F s hh q = 1 ∧ v.y hh.val = 1 := by
    intro s hh q hxone
    rw [fwd_x_apply] at hxone
    by_cases hz : v.z s.val q.val = 1
    · rw [if_pos hz] at hxone
      rcases hch : chosenHub p v s q with _ | h0
      · rw [hch] at hxone; simp at hxone
      · rw [hch] at hxone
        simp only at hxone
        by_cases hheq : h0.val = hh.val
        · have := chosenHub_spec p v s q h0 hch
          rw [hheq] at this
          -- h0.val = hh.val, so Fin.val equality => Fin equality iff they are same type
          -- but p.F s h0 q = p.F s hh q requires h0 = hh as Fin p.M
          have hh0_eq : h0 = hh := Fin.ext hheq
          rw [hh0_eq] at this
          exact this
        · rw [if_neg hheq] at hxone; exact absurd hxone (by norm_num)
    · rw [if_neg hz] at hxone; exact absurd hxone (by norm_num)
  refine ?_
  constructor
  · -- hnew_cap
    show ∑ hh ∈ (univ : Finset (Fin p.M)).filter (fun hh => (paramMap p).N ≤ hh.val),
        ((fwd p v).y hh.val : ℤ) ≤ (paramMap p).U
    simp only [paramMap]
    exact h.hnew_cap
  · -- hexisting
    show ∑ hh ∈ (univ : Finset (Fin p.M)).filter (fun hh => hh.val < (paramMap p).N),
        ((fwd p v).y hh.val : ℤ) = ((paramMap p).N : ℤ)
    simp only [paramMap]
    exact h.hexisting
  · -- hopen: x ≤ y
    intro s hh q
    show (fwd p v).x s.val hh.val q.val ≤ (fwd p v).y hh.val
    rcases hx_bin s hh q with hx0 | hx1
    · rw [hx0]; exact hy_nn hh
    · rw [hx1]
      have := hx_one_spec s hh q hx1
      show 1 ≤ v.y hh.val
      rw [this.2]
  · -- hfeas: x ≤ F
    intro s hh q
    show ((fwd p v).x s.val hh.val q.val : ℤ) ≤ (paramMap p).F s hh q
    simp only [paramMap]
    rcases hx_bin s hh q with hx0 | hx1
    · rw [hx0]; exact hF_nn s hh q
    · rw [hx1]
      have := hx_one_spec s hh q hx1
      show (1 : ℤ) ≤ p.F s hh q
      rw [this.1]
  · -- hassign: Σ_h x ≤ 1
    intro s q
    show (∑ hh : Fin (paramMap p).M, (fwd p v).x s.val hh.val q.val) ≤ 1
    simp only [paramMap]
    rw [fwd_sum_x_eq_z p v h s q]
    rcases h.hz_bin s q with hz0 | hz1
    · rw [hz0]; norm_num
    · rw [hz1]
  · -- hy_bin
    exact h.hy_bin
  · -- hx_bin
    exact hx_bin

private lemma bwd_feas (p : P16.a.Params) (v : P16.b.Vars)
    (h : P16.b.Feasible (paramMap p) v) :
    P16.a.Feasible p (bwd p v) := by
  haveI := p.hM
  have hx_nn : ∀ s : Fin p.nS, ∀ hh : Fin p.M, ∀ q : Fin p.nP,
      0 ≤ v.x s.val hh.val q.val := fun s hh q => by
    rcases h.hx_bin s hh q with h0 | h1 <;> omega
  have hy_nn : ∀ hh : Fin p.M, 0 ≤ v.y hh.val := fun hh => by
    rcases h.hy_bin hh with h0 | h1 <;> omega
  refine ?_
  constructor
  · -- hnew_cap
    exact h.hnew_cap
  · -- hexisting
    exact h.hexisting
  · -- hcover: z_sq ≤ Σ F*y, with z_sq := Σ_h x_shq
    intro s q
    show (∑ hh : Fin p.M, v.x s.val hh.val q.val) ≤ ∑ hh : Fin p.M, p.F s hh q * v.y hh.val
    apply Finset.sum_le_sum
    intro hh _
    -- x ≤ F*y: using x ≤ F and x ≤ y; x,F,y ∈ {0,1}
    rcases h.hx_bin s hh q with hx0 | hx1
    · rw [hx0]
      exact mul_nonneg (by rcases p.hF_bin s hh q with h0 | h1 <;> omega) (hy_nn hh)
    · rw [hx1]
      have hFx := h.hfeas s hh q
      have hyx := h.hopen s hh q
      rw [hx1] at hFx hyx
      simp only [paramMap] at hFx
      -- show 1 ≤ F*y where F ≥ 1 and y ≥ 1 (binary)
      have hF1 : p.F s hh q = 1 := by
        rcases p.hF_bin s hh q with h0 | h1
        · rw [h0] at hFx; linarith
        · exact h1
      have hy1 : v.y hh.val = 1 := by
        rcases h.hy_bin hh with h0 | h1
        · rw [h0] at hyx; linarith
        · exact h1
      rw [hF1, hy1]; norm_num
  · -- hy_bin
    exact h.hy_bin
  · -- hz_bin
    intro s q
    show (∑ hh : Fin p.M, v.x s.val hh.val q.val) = 0 ∨
         (∑ hh : Fin p.M, v.x s.val hh.val q.val) = 1
    -- sum of binary values bounded by 1 → 0 or 1
    have hsum_nn : 0 ≤ ∑ hh : Fin p.M, v.x s.val hh.val q.val := by
      apply Finset.sum_nonneg
      intro hh _
      exact hx_nn s hh q
    have hsum_le : ∑ hh : Fin p.M, v.x s.val hh.val q.val ≤ 1 := h.hassign s q
    -- Since it's an integer sum with 0 ≤ sum ≤ 1
    omega

-- ============================================================================
-- § Objective Mapping
-- ============================================================================

private lemma fwd_obj (p : P16.a.Params) (v : P16.a.Vars)
    (h : P16.a.Feasible p v) :
    (P16.b.formulation).obj (paramMap p) (fwd p v) = P16.a.formulation.obj p v := by
  show P16.b.obj (paramMap p) (fwd p v) = P16.a.obj p v
  unfold P16.b.obj P16.a.obj
  congr 1
  apply Finset.sum_congr rfl
  intro s _
  -- swap Σ_h Σ_q → Σ_q Σ_h
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl
  intro q _
  -- Σ_h v_sq * x_shq = v_sq * Σ_h x_shq = v_sq * z_sq
  rw [← Finset.mul_sum]
  congr 1
  have hsum := fwd_sum_x_eq_z p v h s q
  exact_mod_cast hsum

private lemma bwd_obj (p : P16.a.Params) (v : P16.b.Vars)
    (_h : P16.b.Feasible (paramMap p) v) :
    (P16.b.formulation).obj (paramMap p) v = P16.a.formulation.obj p (bwd p v) := by
  show P16.b.obj (paramMap p) v = P16.a.obj p (bwd p v)
  unfold P16.b.obj P16.a.obj
  congr 1
  apply Finset.sum_congr rfl
  intro s _
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl
  intro q _
  rw [← Finset.mul_sum]
  -- (bwd p v).z s.val q.val = ∑ h, v.x s.val h.val q.val
  show (paramMap p).v s q * _ = p.v s q * ((∑ hh : Fin p.M, v.x s.val hh.val q.val : ℤ) : ℝ)
  congr 1
  push_cast
  rfl

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

noncomputable def aBEquiv : MILPEquiv P16.a.formulation P16.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := Or.inl strictMono_id
  fwd_obj p v h := fwd_obj p v h
  bwd_obj p v h := bwd_obj p v h

end P16
