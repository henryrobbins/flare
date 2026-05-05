import Common
import dataset.problems.p14.formulations.a.Formulation
import dataset.problems.p14.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P14

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P14.a.Params) : P14.b.Params :=
  { nS          := p.nS
    nH          := p.nH
    numDC       := p.numDC
    T           := p.T
    T_limit     := p.T_limit
    hnS         := p.hnS
    hnH         := p.hnH
    hT_nn       := p.hT_nn
    hT_limit_nn := p.hT_limit_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (p : P14.a.Params) (v : P14.a.Vars p) : P14.b.Vars (paramMap p) :=
  { x := v.x
    y := v.y }

private lemma fwd_feas (p : P14.a.Params) (v : P14.a.Vars p)
    (h : P14.a.Feasible p v) :
    P14.b.Feasible (paramMap p) (fwd p v) := by
  -- `y` is non-negative everywhere (binary) and vanishes when `delta = 0`
  have hy_nn : ∀ (i : Fin p.nS) (j : Fin p.nH), 0 ≤ v.y i j := fun i j => by
    rcases h.hy_bin i j with h0 | h1 <;> omega
  have hx_nn : ∀ (i : Fin p.nS), 0 ≤ v.x i := fun i => by
    rcases h.hx_bin i with h0 | h1 <;> omega
  -- Key: `delta i j * v.y i j = v.y i j` (when delta=0, y=0 by hinfeas)
  have hdy : ∀ (i : Fin p.nS) (j : Fin p.nH),
      p.delta i j * v.y i j = v.y i j := by
    intro i j
    rcases p.hdelta_bin i j with hd0 | hd1
    · rw [hd0, h.hinfeas i j hd0]; ring
    · rw [hd1]; ring
  refine ?_
  constructor
  · -- hselect
    exact h.hselect
  · -- hactive: ∑ y ≤ x * nH
    intro i
    rcases h.hx_bin i with hx0 | hx1
    · -- x = 0: hactive in A gives ∑ delta*y ≤ 0, so ∑ y ≤ 0, all y = 0
      have hall_zero : ∀ j : Fin p.nH, v.y i j = 0 := by
        have hsum_dy := h.hactive i
        rw [hx0] at hsum_dy
        simp only [zero_mul] at hsum_dy
        -- ∑ delta * y ≤ 0, and each delta * y ≥ 0
        have hterm_nn : ∀ j ∈ (univ : Finset (Fin p.nH)),
            0 ≤ p.delta i j * v.y i j := by
          intro j _
          rcases p.hdelta_bin i j with hd0 | hd1
          · rw [hd0]; simp
          · rw [hd1]; simpa using hy_nn i j
        have hsum_nn : 0 ≤ ∑ j : Fin p.nH, p.delta i j * v.y i j :=
          Finset.sum_nonneg hterm_nn
        have hsum_zero : ∑ j : Fin p.nH, p.delta i j * v.y i j = 0 := by linarith
        -- From hsum_zero, each term is 0
        have hterm_zero := (Finset.sum_eq_zero_iff_of_nonneg hterm_nn).mp hsum_zero
        intro j
        have := hterm_zero j (mem_univ j)
        rcases p.hdelta_bin i j with hd0 | hd1
        · exact h.hinfeas i j hd0
        · rw [hd1, one_mul] at this
          exact this
      show ∑ j : Fin p.nH, v.y i j ≤ v.x i * (p.nH : ℤ)
      rw [hx0]
      simp [hall_zero]
    · -- x = 1: ∑ y ≤ nH since each y ≤ 1
      show ∑ j : Fin p.nH, v.y i j ≤ v.x i * (p.nH : ℤ)
      rw [hx1]
      simp only [one_mul]
      have hyle : ∀ j ∈ (univ : Finset (Fin p.nH)), v.y i j ≤ 1 := by
        intro j _
        rcases h.hy_bin i j with h0 | h1 <;> omega
      calc ∑ j : Fin p.nH, v.y i j
          ≤ ∑ _j : Fin p.nH, (1 : ℤ) := Finset.sum_le_sum hyle
        _ = (p.nH : ℤ) := by simp
  · -- hassign: ∑ y = 1
    intro j
    have hkey := h.hassign j
    -- rewrite delta * y = y
    have : ∑ i : Fin p.nS, v.y i j = ∑ i : Fin p.nS, p.delta i j * v.y i j :=
      Finset.sum_congr rfl (fun i _ => (hdy i j).symm)
    show ∑ i : Fin p.nS, v.y i j = 1
    rw [this]; exact hkey
  · -- htime: T i j * y ≤ T_limit
    intro i j
    show p.T i j * (v.y i j : ℝ) ≤ p.T_limit
    rcases h.hy_bin i j with hy0 | hy1
    · rw [hy0]; push_cast; simp [p.hT_limit_nn]
    · rw [hy1]; push_cast
      -- y = 1, need T ≤ T_limit, i.e., delta = 1
      -- If delta = 0, hinfeas gives y = 0, contradicting y = 1
      rcases p.hdelta_bin i j with hd0 | hd1
      · exfalso
        have := h.hinfeas i j hd0
        omega
      · rw [mul_one]; exact (p.hdelta_def i j).1.mp hd1
  · -- hx_bin
    exact h.hx_bin
  · -- hy_bin
    exact h.hy_bin

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P14.a.Params) (v : P14.b.Vars (paramMap p)) : P14.a.Vars p :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P14.a.Params) (v : P14.b.Vars (paramMap p))
    (h : P14.b.Feasible (paramMap p) v) :
    P14.a.Feasible p (bwd p v) := by
  -- `y` is binary non-negative; when delta = 0 (T > T_limit), y = 0 by htime.
  have hy_nn : ∀ (i : Fin p.nS) (j : Fin p.nH), 0 ≤ v.y i j := fun i j => by
    rcases h.hy_bin i j with h0 | h1 <;> omega
  have hx_nn : ∀ (i : Fin p.nS), 0 ≤ v.x i := fun i => by
    rcases h.hx_bin i with h0 | h1 <;> omega
  -- key lemma: delta = 0 → y = 0
  have hinfeas : ∀ (i : Fin p.nS) (j : Fin p.nH),
      p.delta i j = 0 → v.y i j = 0 := by
    intro i j hd0
    have hT_gt : p.T_limit < p.T i j := (p.hdelta_def i j).2.mp hd0
    rcases h.hy_bin i j with hy0 | hy1
    · exact hy0
    · exfalso
      have htime := h.htime i j
      -- T * 1 ≤ T_limit but T > T_limit
      rw [hy1] at htime
      simp only [paramMap] at htime
      push_cast at htime
      linarith
  have hdelta_bin : ∀ (i : Fin p.nS) (j : Fin p.nH),
      p.delta i j = 0 ∨ p.delta i j = 1 := p.hdelta_bin
  -- delta * y = y (because when delta = 0, y = 0)
  have hdy : ∀ (i : Fin p.nS) (j : Fin p.nH),
      p.delta i j * v.y i j = v.y i j := by
    intro i j
    rcases hdelta_bin i j with hd0 | hd1
    · rw [hd0, hinfeas i j hd0]; ring
    · rw [hd1]; ring
  refine ?_
  constructor
  · -- hselect
    exact h.hselect
  · -- hactive: ∑ delta * y ≤ x * ∑ delta
    intro i
    simp only [bwd]
    -- Rewrite ∑ delta * y = ∑ y (via hdy)
    have hrw : ∑ j : Fin p.nH, p.delta i j * v.y i j
                = ∑ j : Fin p.nH, v.y i j :=
      Finset.sum_congr rfl (fun j _ => hdy i j)
    rw [hrw]
    show ∑ j : Fin p.nH, v.y i j ≤ v.x i * ∑ j : Fin p.nH, p.delta i j
    rcases h.hx_bin i with hx0 | hx1
    · -- x = 0: B's hactive gives ∑ y ≤ 0; need ∑ y ≤ 0 * ∑ delta = 0
      have hact := h.hactive i
      rw [hx0]
      simp only [zero_mul]
      rw [hx0] at hact
      simp only [zero_mul] at hact
      exact hact
    · -- x = 1: need ∑ y ≤ 1 * ∑ delta = ∑ delta; delta ∈ {0,1}, y ≤ delta
      rw [hx1]
      simp only [one_mul]
      -- Show y_{ij} ≤ delta_{ij} for each j
      apply Finset.sum_le_sum
      intro j _
      rcases hdelta_bin i j with hd0 | hd1
      · rw [hd0, hinfeas i j hd0]
      · rw [hd1]
        rcases h.hy_bin i j with hy0 | hy1 <;> omega
  · -- hassign: ∑ delta * y = 1
    intro j
    simp only [bwd]
    have hrw : ∑ i : Fin p.nS, p.delta i j * v.y i j
                = ∑ i : Fin p.nS, v.y i j :=
      Finset.sum_congr rfl (fun i _ => hdy i j)
    rw [hrw]
    exact h.hassign j
  · -- hinfeas
    intro i j hd0
    simp only [bwd]
    exact hinfeas i j hd0
  · intro i
    simp only [bwd]
    exact h.hx_bin i
  · intro i j
    simp only [bwd]
    exact h.hy_bin i j

-- ============================================================================
-- § Objective Mapping
-- ============================================================================

private lemma fwd_obj (p : P14.a.Params) (v : P14.a.Vars p)
    (h : P14.a.Feasible p v) :
    (P14.b.formulation).obj (paramMap p) (fwd p v) = P14.a.formulation.obj p v := by
  show P14.b.obj (paramMap p) (fwd p v) = P14.a.obj p v
  unfold P14.b.obj P14.a.obj
  -- For each (i,j): (v.y i j : ℝ) * T i j = (delta i j : ℝ) * (v.y i j : ℝ) * T i j
  -- Because delta = 0 → y = 0
  apply Finset.sum_congr rfl
  intro i _
  apply Finset.sum_congr rfl
  intro j _
  show (v.y i j : ℝ) * p.T i j
        = (p.delta i j : ℝ) * (v.y i j : ℝ) * p.T i j
  rcases p.hdelta_bin i j with hd0 | hd1
  · have hy0 := h.hinfeas i j hd0
    rw [hd0, hy0]; push_cast; ring
  · rw [hd1]; push_cast; ring

private lemma bwd_obj (p : P14.a.Params) (v : P14.b.Vars (paramMap p))
    (h : P14.b.Feasible (paramMap p) v) :
    (P14.b.formulation).obj (paramMap p) v = P14.a.formulation.obj p (bwd p v) := by
  show P14.b.obj (paramMap p) v = P14.a.obj p (bwd p v)
  unfold P14.b.obj P14.a.obj
  -- Same idea: for delta=0, htime forces y=0; for delta=1, the factor is 1.
  have hinfeas : ∀ (i : Fin p.nS) (j : Fin p.nH),
      p.delta i j = 0 → v.y i j = 0 := by
    intro i j hd0
    have hT_gt : p.T_limit < p.T i j := (p.hdelta_def i j).2.mp hd0
    rcases h.hy_bin i j with hy0 | hy1
    · exact hy0
    · exfalso
      have htime := h.htime i j
      rw [hy1] at htime
      simp only [paramMap] at htime
      push_cast at htime
      linarith
  apply Finset.sum_congr rfl
  intro i _
  apply Finset.sum_congr rfl
  intro j _
  show (v.y i j : ℝ) * p.T i j
        = (p.delta i j : ℝ) * (v.y i j : ℝ) * p.T i j
  rcases p.hdelta_bin i j with hd0 | hd1
  · have hy0 := hinfeas i j hd0
    rw [hd0, hy0]; push_cast; ring
  · rw [hd1]; push_cast; ring

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aBReformulation : MILPReformulation P14.a.formulation P14.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj p v h := fwd_obj p v h
  bwd_obj p v h := bwd_obj p v h

end P14
