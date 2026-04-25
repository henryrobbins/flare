import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P17.a

structure Params where
  n : ℕ  -- number of blocks
  T : ℕ  -- number of scheduling periods
  c : Fin n → Fin T → ℝ  -- NPV of block i in period t
  g : Fin n → ℝ  -- ore grade of block i
  O : Fin n → ℝ  -- ore tonnage of block i
  W : Fin n → ℝ  -- waste tonnage of block i
  G_min : ℝ  -- minimum allowed average ore grade
  G_max : ℝ  -- maximum allowed average ore grade
  PC_min : ℝ  -- minimum per-period ore processing capacity
  PC_max : ℝ  -- maximum per-period ore processing capacity
  MC_min : ℝ  -- minimum per-period total mining capacity
  MC_max : ℝ  -- maximum per-period total mining capacity
  P : Fin n → Fin n → ℤ  -- precedence matrix: P[i][j] = 1 if block i must be mined before block j
  -- Assumptions
  hP_bin : ∀ i j : Fin n, P i j = 0 ∨ P i j = 1
  -- Implicit Assumptions
  hn : NeZero n
  hT : NeZero T
  hc_nn : ∀ i : Fin n, ∀ t : Fin T, 0 ≤ c i t
  hg_nn: ∀ i :  Fin n, 0 ≤ g i
  hO_nn : ∀ i : Fin n, 0 ≤ O i
  hW_nn : ∀ i : Fin n, 0 ≤ W i


-- Variables: x[i][t] is a continuous fraction in [0,1] for pure-ore blocks (g=1),
-- and a binary indicator for mixed/low-grade blocks (g<1)
structure Vars where
  x : ℕ → ℕ → ℝ  -- block-period extraction fraction (binary for g<1, continuous for g=1)

structure Feasible (par : Params) (v : Vars) : Prop where
  -- Upper grade blending constraint
  hgrade_hi : ∀ t : Fin par.T,
    ∑ i : Fin par.n, (par.g i - par.G_max) * par.O i * v.x i t ≤ 0
  -- Lower grade blending constraint
  hgrade_lo : ∀ t : Fin par.T,
    0 ≤ ∑ i : Fin par.n, (par.g i - par.G_min) * par.O i * v.x i t
  -- Each block mined at most once over the horizon
  honce : ∀ i : Fin par.n,
    ∑ t : Fin par.T, v.x i t ≤ 1
  -- Processing capacity upper bound
  hproc_hi : ∀ t : Fin par.T,
    ∑ i : Fin par.n, par.O i * v.x i t ≤ par.PC_max
  -- Processing capacity lower bound
  hproc_lo : ∀ t : Fin par.T,
    par.PC_min ≤ ∑ i : Fin par.n, par.O i * v.x i t
  -- Mining capacity upper bound
  hmine_hi : ∀ t : Fin par.T,
    ∑ i : Fin par.n, (par.O i + par.W i) * v.x i t ≤ par.MC_max
  -- Mining capacity lower bound
  hmine_lo : ∀ t : Fin par.T,
    par.MC_min ≤ ∑ i : Fin par.n, (par.O i + par.W i) * v.x i t
  -- Precedence: block j can only be mined in period t if block i (with P[i][j]=1) has been mined by period t
  hprec : ∀ t : Fin par.T, ∀ i j : Fin par.n, par.P i j = 1 →
    v.x j t ≤ ∑ τ ∈ (univ.filter (fun τ : Fin par.T => τ.val ≤ t.val)), v.x i τ
  -- Binary domain for blocks in I0 (grade strictly less than 1)
  hx_bin_I0 : ∀ i : Fin par.n, ∀ t : Fin par.T, par.g i < 1 → v.x i t = 0 ∨ v.x i t = 1
  -- Continuous domain [0,1] for blocks in I1 (grade equal to 1)
  hx_lo_I1 : ∀ i : Fin par.n, ∀ t : Fin par.T, par.g i = 1 → 0 ≤ v.x i t
  hx_hi_I1 : ∀ i : Fin par.n, ∀ t : Fin par.T, par.g i = 1 → v.x i t ≤ 1

-- Maximize total NPV (negated for minimization convention)
def obj (par : Params) (v : Vars) : ℝ :=
  -(∑ t : Fin par.T, ∑ i : Fin par.n, par.c i t * v.x i t)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P17.a
