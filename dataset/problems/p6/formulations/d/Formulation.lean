import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P6.Fd

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

-- Large warehouses: capacity ≥ max customer demand
noncomputable def largeWarehouses {m n : ℕ} (p : Params m n) : Finset (Fin n) :=
  let dMax := ⨆ i : Fin m, p.d i
  letI : DecidablePred (fun j : Fin n => dMax ≤ p.u j) := Classical.decPred _
  univ.filter (fun j => dMax ≤ p.u j)

-- Customers that cannot be served by any small warehouse
noncomputable def hardCustomers {m n : ℕ} (p : Params m n) : Finset (Fin m) :=
  let T := largeWarehouses p
  let uMaxSmall := if h : (univ \ T : Finset (Fin n)).Nonempty
                   then (univ \ T).sup' h p.u else 0
  letI : DecidablePred (fun i : Fin m => uMaxSmall < p.d i) := Classical.decPred _
  univ.filter (fun i => uMaxSmall < p.d i)

structure Feasible {m n : ℕ} [NeZero m] [NeZero n] (p : Params m n) (v : Vars m n) : Prop where
  hassign : ∀ i, ∑ j, v.x i j = 1
  hcap : ∀ j, ∑ i, p.d i * v.x i j ≤ p.u j * v.y j
  hx_bin : ∀ i j, v.x i j = 0 ∨ v.x i j = 1
  hy_bin : ∀ j, v.y j = 0 ∨ v.y j = 1
  -- EC3 (V1): T-Cover Bound
  -- Hard customers can only go to large warehouses T;
  -- for any permutation σ sorting T-capacities non-increasingly:
  -- if the first k T-capacities are insufficient to cover hard-customer demand,
  -- then at least k large warehouses must be open
  hec3 : ∀ (σ : Fin (largeWarehouses p).card ≃ {j // j ∈ largeWarehouses p}),
    (∀ a b : Fin (largeWarehouses p).card, a ≤ b → p.u (↑(σ b)) ≤ p.u (↑(σ a))) →
    ∀ k : ℕ,
    (∑ a ∈ univ.filter (fun i : Fin (largeWarehouses p).card => i.val < k),
        p.u (↑(σ a)) < ∑ i ∈ hardCustomers p, p.d i) →
    (k : ℤ) ≤ ∑ j, v.y j

def obj {m n : ℕ} (p : Params m n) (v : Vars m n) : ℝ :=
  (∑ j, p.f j * (v.y j : ℝ)) + ∑ i, ∑ j, p.c i j * (v.x i j : ℝ)

def formulation (m n : ℕ) [NeZero m] [NeZero n] : MILPFormulation where
  Params   := Params m n
  Vars     := Vars m n
  feasible := Feasible
  obj      := obj

end P6.Fd
