import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P17.b

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
  hG : G_min ≤ G_max
  hPC : PC_min ≤ PC_max
  hMC : MC_min ≤ MC_max

structure Vars where
  x : ℕ → ℕ → ℤ  -- 1 if block i is mined in period t, 0 otherwise

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Upper grade blending constraint
  hgrade_hi : ∀ t : Fin p.T,
    ∑ i : Fin p.n, (p.g i - p.G_max) * p.O i * (v.x i t : ℝ) ≤ 0
  -- Lower grade blending constraint
  hgrade_lo : ∀ t : Fin p.T,
    0 ≤ ∑ i : Fin p.n, (p.g i - p.G_min) * p.O i * (v.x i t : ℝ)
  -- Each block mined at most once over the horizon
  honce : ∀ i : Fin p.n,
    ∑ t : Fin p.T, v.x i t ≤ 1
  -- Processing capacity upper bound
  hproc_hi : ∀ t : Fin p.T,
    ∑ i : Fin p.n, p.O i * (v.x i t : ℝ) ≤ p.PC_max
  -- Processing capacity lower bound
  hproc_lo : ∀ t : Fin p.T,
    p.PC_min ≤ ∑ i : Fin p.n, p.O i * (v.x i t : ℝ)
  -- Mining capacity upper bound
  hmine_hi : ∀ t : Fin p.T,
    ∑ i : Fin p.n, (p.O i + p.W i) * (v.x i t : ℝ) ≤ p.MC_max
  -- Mining capacity lower bound
  hmine_lo : ∀ t : Fin p.T,
    p.MC_min ≤ ∑ i : Fin p.n, (p.O i + p.W i) * (v.x i t : ℝ)
  -- Precedence: block j can only be mined in period t if block i (with P[i][j]=1) has been mined by period t
  hprec : ∀ t : Fin p.T, ∀ i j : Fin p.n, p.P i j = 1 →
    v.x j t ≤ ∑ τ ∈ (univ.filter (fun τ : Fin p.T => τ.val ≤ t.val)), v.x i τ
  -- Binary domain for all blocks
  hx_bin : ∀ i : Fin p.n, ∀ t : Fin p.T, v.x i t = 0 ∨ v.x i t = 1

-- Maximize total NPV (negated for minimization convention)
def obj (p : Params) (v : Vars) : ℝ :=
  -(∑ t : Fin p.T, ∑ i : Fin p.n, p.c i t * (v.x i t : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P17.b
