import Common
import problems.p6.formulations.a.Formulation
import problems.p6.formulations.g.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P6

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P6.a.Params) : P6.g.Params :=
  { n := p.n
    m := p.m
    d := p.d
    u := p.u
    f := p.f
    c := p.c
    hd_pos := p.hd_pos
    hu_nn := p.hu_nn
    hc_nn := p.hc_nn
    hf_nn := p.hf_nn
    hn := p.hn
    hm := p.hm }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (p : P6.a.Params) (v : P6.a.Vars p) : P6.g.Vars (paramMap p) :=
  { x := v.x
    y := v.y }

private lemma fwd_feas (p : P6.a.Params) (v : P6.a.Vars p)
    (h : P6.a.Feasible p v) :
    P6.g.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hn
  refine ⟨h.hassign, h.hcap, h.hx_bin, h.hy_bin, ?_⟩
  -- Prove hec3: v.x i j ≤ v.y j
  intro i j
  show v.x i j ≤ v.y j
  -- Case on y_j
  rcases h.hy_bin j with hy0 | hy1
  · -- y_j = 0, so capacity constraint forces all x_{ij} = 0
    -- From hcap j: ∑ i, p.d i * (v.x i j : ℝ) ≤ p.u j * 0 = 0
    have hcap_j := h.hcap j
    rw [show ((v.y j : ℝ)) = 0 by exact_mod_cast hy0] at hcap_j
    rw [mul_zero] at hcap_j
    -- Each term is ≥ 0 (d_i > 0, x_{ij} ≥ 0) so each x_{ij} = 0
    have hterm_nn : ∀ k ∈ (Finset.univ : Finset (Fin p.n)),
        0 ≤ p.d k * (v.x k j : ℝ) := by
      intro k _
      rcases h.hx_bin k j with hxk | hxk
      · rw [show ((v.x k j : ℝ)) = 0 by exact_mod_cast hxk]; simp
      · rw [show ((v.x k j : ℝ)) = 1 by exact_mod_cast hxk]
        rw [mul_one]; linarith [p.hd_pos k]
    have hsum_zero : ∑ k : Fin p.n, p.d k * (v.x k j : ℝ) = 0 := by
      apply le_antisymm
      · exact hcap_j
      · exact Finset.sum_nonneg hterm_nn
    -- Each term = 0
    have hi_zero : p.d i * (v.x i j : ℝ) = 0 := by
      have := Finset.sum_eq_zero_iff_of_nonneg hterm_nn |>.mp hsum_zero i (Finset.mem_univ _)
      exact this
    have hd_ne : p.d i ≠ 0 := ne_of_gt (p.hd_pos i)
    have hx_zero_r : (v.x i j : ℝ) = 0 := by
      rcases mul_eq_zero.mp hi_zero with h1 | h2
      · exact absurd h1 hd_ne
      · exact h2
    have hx_zero : v.x i j = 0 := by exact_mod_cast hx_zero_r
    rw [hx_zero, hy0]
  · -- y_j = 1, so x_{ij} ≤ 1 = y_j from binary
    rw [hy1]
    rcases h.hx_bin i j with hx0 | hx1
    · rw [hx0]; decide
    · rw [hx1]

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P6.a.Params) (v : P6.g.Vars (paramMap p)) : P6.a.Vars p :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P6.a.Params) (v : P6.g.Vars (paramMap p))
    (h : P6.g.Feasible (paramMap p) v) :
    P6.a.Feasible p (bwd p v) := by
  exact ⟨h.hassign, h.hcap, h.hx_bin, h.hy_bin⟩

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aGReformulation : MILPReformulation P6.a.formulation P6.g.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P6
