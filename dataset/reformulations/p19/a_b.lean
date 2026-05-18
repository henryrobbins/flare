import Common
import problems.p19.formulations.a.Formulation
import problems.p19.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P19

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P19.a.Params) : P19.b.Params :=
  { nH      := p.nH
    nC      := p.nC
    a       := p.a
    C       := p.C
    t       := p.t
    T       := p.T
    n       := p.n
    Hf      := p.Hf
    hHf_bin := p.hHf_bin
    hnH     := p.hnH
    hnC     := p.hnC
    ha_nn   := p.ha_nn
    hC_nn   := p.hC_nn
    ht_nn   := p.ht_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

/--
**A → B**: copy `q := x` and `y := y`; set `z[h,c] := y[h]` for all `c`.
Then the capacity sum `∑_c z[h,c] = nC * y[h]` is tight, and the disjunction
holds because either `y[h] = 1` (right) or `y[h] = 0`, in which case
`∑_c x[h,c] ≤ 0` together with `x ≥ 0` force `x[h,c] = 0` (left).
-/
private def fwd (p : P19.a.Params) (v : P19.a.Vars p) : P19.b.Vars (paramMap p) :=
  { q := v.x
    z := fun h _ => v.y h
    y := v.y }

private lemma fwd_feas (p : P19.a.Params) (v : P19.a.Vars p)
    (h : P19.a.Feasible p v) :
    P19.b.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hnH
  haveI := p.hnC
  refine ?_
  constructor
  · -- hlink: q[h,c] = 0 ∨ z[h,c] = 1
    intro hh c
    show v.x hh c = 0 ∨ v.y hh = 1
    rcases h.hy_bin hh with hy0 | hy1
    · left
      -- y[h] = 0 ⇒ sum_c x[h,c] ≤ 0, with x ≥ 0 ⇒ x[h,c] = 0
      have hcap := h.hcap hh
      rw [hy0] at hcap
      simp at hcap
      have hsum_nn : 0 ≤ ∑ c' : Fin p.nC, v.x hh c' := by
        apply Finset.sum_nonneg
        intro c' _; exact h.hx_nn hh c'
      have hsum_zero : ∑ c' : Fin p.nC, v.x hh c' = 0 :=
        le_antisymm hcap hsum_nn
      have hxc_nn : 0 ≤ v.x hh c := h.hx_nn hh c
      have hxc_le : v.x hh c ≤ 0 := by
        have := Finset.single_le_sum
          (f := fun c' : Fin p.nC => v.x hh c')
          (s := univ) (fun c' _ => h.hx_nn hh c') (mem_univ c)
        linarith
      linarith
    · right; exact hy1
  · -- hdemand
    exact h.hdemand
  · -- hcap: sum_c z[h,c] ≤ nC * y[h]; here z[h,c] = y[h], so equality
    intro hh
    show ∑ _c : Fin (paramMap p).nC, v.y hh ≤ ((paramMap p).nC : ℤ) * v.y hh
    simp [paramMap]
  · -- hopen
    exact h.hopen
  · -- hfixed
    exact h.hfixed
  · -- htime
    exact h.htime
  · -- hq_nn
    intro hh c; exact h.hx_nn hh c
  · -- hz_bin
    intro hh _c
    show v.y hh = 0 ∨ v.y hh = 1
    exact h.hy_bin hh
  · -- hy_bin
    exact h.hy_bin

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**B → A**: copy `x := q` and `y := y`; drop `z`.
-/
private def bwd (p : P19.a.Params) (v : P19.b.Vars (paramMap p)) : P19.a.Vars p :=
  { x := v.q
    y := v.y }

private lemma bwd_feas (p : P19.a.Params) (v : P19.b.Vars (paramMap p))
    (h : P19.b.Feasible (paramMap p) v) :
    P19.a.Feasible p (bwd p v) := by
  haveI := p.hnH
  haveI := p.hnC
  -- bound q[h,c] ≤ 1 from demand and non-negativity
  have hq_le_one : ∀ (hh : Fin p.nH) (c : Fin p.nC), v.q hh c ≤ 1 := by
    intro hh c
    have hd := h.hdemand c
    simp only [paramMap] at hd
    have hsum_nn : ∀ hh' : Fin p.nH, 0 ≤ v.q hh' c := by
      intro hh'; exact h.hq_nn hh' c
    have hsingle : v.q hh c ≤ ∑ hh' : Fin p.nH, v.q hh' c :=
      Finset.single_le_sum
        (f := fun hh' : Fin p.nH => v.q hh' c)
        (s := univ) (fun hh' _ => hsum_nn hh') (mem_univ hh)
    linarith
  refine ?_
  constructor
  · -- hcap: sum_c x[h,c] ≤ nC * y[h]
    intro hh
    show ∑ c : Fin p.nC, v.q hh c ≤ (p.nC : ℝ) * (v.y hh : ℝ)
    rcases h.hy_bin hh with hy0 | hy1
    · -- y[h] = 0: from hcap, sum_c z[h,c] ≤ 0; with z ∈ {0,1} ⇒ all z = 0
      -- then from hlink, q[h,c] = 0
      rw [hy0]
      simp
      have hcap := h.hcap hh
      simp only [paramMap] at hcap
      rw [hy0, mul_zero] at hcap
      -- All z[h,c] = 0
      have hz_zero : ∀ c : Fin p.nC, v.z hh c = 0 := by
        intro c
        have hz_nn : ∀ c' : Fin p.nC, 0 ≤ v.z hh c' := by
          intro c'; rcases h.hz_bin hh c' with h0 | h1 <;> omega
        have hsingle := Finset.single_le_sum
          (f := fun c' : Fin p.nC => v.z hh c')
          (s := univ) (fun c' _ => hz_nn c') (mem_univ c)
        have : v.z hh c ≤ 0 := hsingle.trans hcap
        rcases h.hz_bin hh c with h0 | h1
        · exact h0
        · omega
      have hq_zero : ∀ c : Fin p.nC, v.q hh c = 0 := by
        intro c
        rcases h.hlink hh c with hq | hz
        · exact hq
        · exfalso; rw [hz_zero c] at hz; exact absurd hz (by norm_num)
      have hsum_zero : ∑ c : Fin p.nC, v.q hh c = 0 := by
        apply Finset.sum_eq_zero
        intro c _; exact hq_zero c
      linarith
    · -- y[h] = 1: bound sum_c q ≤ nC = nC * 1
      rw [hy1]
      push_cast
      rw [mul_one]
      calc ∑ c : Fin p.nC, v.q hh c
          ≤ ∑ _c : Fin p.nC, (1 : ℝ) := by
            apply Finset.sum_le_sum
            intro c _; exact hq_le_one hh c
        _ = (p.nC : ℝ) := by simp
  · -- hdemand
    exact h.hdemand
  · -- hopen
    exact h.hopen
  · -- hfixed
    exact h.hfixed
  · -- htime
    exact h.htime
  · -- hx_nn
    intro hh c; exact h.hq_nn hh c
  · -- hy_bin
    exact h.hy_bin

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aBReformulation : MILPReformulation P19.a.formulation P19.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P19
