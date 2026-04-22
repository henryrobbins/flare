import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P6.Fc

structure Params (m n : ℕ) where
  d : Fin m → ℝ           -- customer demands
  u : Fin n → ℝ           -- warehouse capacities
  f : Fin n → ℝ           -- fixed opening costs
  c : Fin m → Fin n → ℝ  -- transportation costs
  hd_pos : ∀ i, 0 < d i
  hu_nn  : ∀ j, 0 ≤ u j

structure Vars (m n : ℕ) where
  x : Fin m → Fin n → ℤ  -- assignment
  y : Fin n → ℤ           -- warehouse activation

structure Feasible {m n : ℕ} [NeZero m] [NeZero n] (p : Params m n) (v : Vars m n) : Prop where
  hassign : ∀ i, ∑ j, v.x i j = 1
  hcap : ∀ j, ∑ i, p.d i * v.x i j ≤ p.u j * v.y j
  hx_bin : ∀ i j, v.x i j = 0 ∨ v.x i j = 1
  hy_bin : ∀ j, v.y j = 0 ∨ v.y j = 1
  -- EC2 (V1): Demand-Cover Bound
  -- For any permutation σ sorting capacities in non-increasing order:
  -- if the first k sorted capacities are insufficient to cover total demand,
  -- then at least k warehouses must be open
  hec2 : ∀ (σ : Fin n ≃ Fin n),
    (∀ a b : Fin n, a ≤ b → p.u (σ b) ≤ p.u (σ a)) →
    ∀ k : ℕ,
    (∑ a ∈ univ.filter (fun i : Fin n => i.val < k), p.u (σ a) < ∑ i, p.d i) →
    (k : ℤ) ≤ ∑ j, v.y j

def obj {m n : ℕ} (p : Params m n) (v : Vars m n) : ℝ :=
  (∑ j, p.f j * (v.y j : ℝ)) + ∑ i, ∑ j, p.c i j * (v.x i j : ℝ)

def formulation (m n : ℕ) [NeZero m] [NeZero n] : MILPFormulation where
  Params   := Params m n
  Vars     := Vars m n
  feasible := Feasible
  obj      := obj

end P6.Fc
