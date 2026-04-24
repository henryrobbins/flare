import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P17.b

structure Params where
  n : ℕ  -- number of blocks
  p : ℕ  -- number of scheduling periods
  c : ℕ → ℕ → ℝ  -- NPV of block i in period t
  g : ℕ → ℝ  -- ore grade of block i
  O : ℕ → ℝ  -- ore tonnage of block i
  W : ℕ → ℝ  -- waste tonnage of block i
  G_min : ℝ  -- minimum allowed average ore grade
  G_max : ℝ  -- maximum allowed average ore grade
  PC_min : ℝ  -- minimum per-period ore processing capacity
  PC_max : ℝ  -- maximum per-period ore processing capacity
  MC_min : ℝ  -- minimum per-period total mining capacity
  MC_max : ℝ  -- maximum per-period total mining capacity
  P : ℕ → ℕ → ℤ  -- precedence matrix: P[i][j] = 1 if block i must be mined before block j
  -- Assumptions
  hn : NeZero n
  hp : NeZero p
  -- Implicit Assumptions
  hO_nn : ∀ i : Fin n, 0 ≤ O i
  hW_nn : ∀ i : Fin n, 0 ≤ W i
  hP_bin : ∀ i j : Fin n, P i j = 0 ∨ P i j = 1

-- Variables: x[i][t] is a binary indicator (1 if block i is mined in period t, 0 otherwise)
structure Vars where
  x : ℕ → ℕ → ℤ  -- block-period extraction indicator

structure Feasible (par : Params) (v : Vars) : Prop where
  -- Upper grade blending constraint
  hgrade_hi : ∀ t : Fin par.p,
    ∑ i : Fin par.n, (par.g i - par.G_max) * par.O i * (v.x i t : ℝ) ≤ 0
  -- Lower grade blending constraint
  hgrade_lo : ∀ t : Fin par.p,
    0 ≤ ∑ i : Fin par.n, (par.g i - par.G_min) * par.O i * (v.x i t : ℝ)
  -- Each block mined at most once over the horizon
  honce : ∀ i : Fin par.n,
    ∑ t : Fin par.p, v.x i t ≤ 1
  -- Processing capacity upper bound
  hproc_hi : ∀ t : Fin par.p,
    ∑ i : Fin par.n, par.O i * (v.x i t : ℝ) ≤ par.PC_max
  -- Processing capacity lower bound
  hproc_lo : ∀ t : Fin par.p,
    par.PC_min ≤ ∑ i : Fin par.n, par.O i * (v.x i t : ℝ)
  -- Mining capacity upper bound
  hmine_hi : ∀ t : Fin par.p,
    ∑ i : Fin par.n, (par.O i + par.W i) * (v.x i t : ℝ) ≤ par.MC_max
  -- Mining capacity lower bound
  hmine_lo : ∀ t : Fin par.p,
    par.MC_min ≤ ∑ i : Fin par.n, (par.O i + par.W i) * (v.x i t : ℝ)
  -- Precedence: block j can only be mined in period t if block i (with P[i][j]=1) has been mined by period t
  hprec : ∀ t : Fin par.p, ∀ i j : Fin par.n, par.P i j = 1 →
    v.x j t ≤ ∑ τ ∈ (univ.filter (fun τ : Fin par.p => τ.val ≤ t.val)), v.x i τ
  -- Binary domain for all blocks
  hx_bin : ∀ i : Fin par.n, ∀ t : Fin par.p, v.x i t = 0 ∨ v.x i t = 1

-- Maximize total NPV (negated for minimization convention)
def obj (par : Params) (v : Vars) : ℝ :=
  -(∑ t : Fin par.p, ∑ i : Fin par.n, par.c i t * (v.x i t : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P17.b
