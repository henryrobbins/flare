import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P6.d

structure Params where
  n : ℕ  -- number of customers
  m : ℕ  -- number of candidate warehouses
  d : Fin n → ℝ          -- customer demands
  u : Fin m → ℝ          -- warehouse capacities
  f : Fin m → ℝ          -- fixed opening costs
  c : Fin n → Fin m → ℝ -- transportation costs
  -- Implicit Assumptions
  hd_pos : ∀ i, 0 < d i
  hu_nn : ∀ j, 0 ≤ u j
  hc_nn : ∀ i j, 0 ≤ c i j
  hf_nn : ∀ j, 0 ≤ f j
  hn : NeZero n
  hm : NeZero m

structure Vars where
  x : ℕ → ℕ → ℤ  -- assignment: 1 if customer i assigned to warehouse j
  y : ℕ → ℤ       -- 1 if warehouse j is opened

noncomputable def largeWarehouses (p : Params) : Finset (Fin p.m) :=
  let dMax := ⨆ i : Fin p.n, p.d i
  letI : DecidablePred (fun j : Fin p.m => dMax ≤ p.u j) := Classical.decPred _
  univ.filter (fun j => dMax ≤ p.u j)

noncomputable def hardCustomers (p : Params) : Finset (Fin p.n) :=
  let T := largeWarehouses p
  let uMaxSmall := if h : (univ \ T : Finset (Fin p.m)).Nonempty
                   then (univ \ T).sup' h p.u else 0
  letI : DecidablePred (fun i : Fin p.n => uMaxSmall < p.d i) := Classical.decPred _
  univ.filter (fun i => uMaxSmall < p.d i)

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Each customer is assigned to exactly one warehouse
  hassign : ∀ i : Fin p.n, ∑ j : Fin p.m, v.x i j = 1
  -- Capacity: total demand assigned to each warehouse cannot exceed its capacity times whether it is open
  hcap : ∀ j : Fin p.m, ∑ i : Fin p.n, p.d i * (v.x i j : ℝ) ≤ p.u j * (v.y j : ℝ)
  hx_bin : ∀ i : Fin p.n, ∀ j : Fin p.m, v.x i j = 0 ∨ v.x i j = 1
  hy_bin : ∀ j : Fin p.m, v.y j = 0 ∨ v.y j = 1
  -- T-Cover Bound (EC3 cut family): for any non-increasing ordering σ of large-warehouse
  -- capacities and any k, if the top-k prefix of σ is insufficient to cover hard-customer
  -- demand, at least k warehouses must be open. This is a valid cut family implied by
  -- feasibility; the JSON computes the scalar k_T (minimum prefix length) which is tightest.
  hec3 : ∀ (σ : Fin (largeWarehouses p).card ≃ {j // j ∈ largeWarehouses p}),
    (∀ a b : Fin (largeWarehouses p).card, a ≤ b → p.u (↑(σ b)) ≤ p.u (↑(σ a))) →
    ∀ k : ℕ,
    (∑ a ∈ univ.filter (fun i : Fin (largeWarehouses p).card => i.val < k),
        p.u (↑(σ a)) < ∑ i ∈ hardCustomers p, p.d i) →
    (k : ℤ) ≤ ∑ j : Fin p.m, v.y j

-- Minimize total fixed opening cost plus transportation cost
def obj (p : Params) (v : Vars) : ℝ :=
  (∑ j : Fin p.m, p.f j * (v.y j : ℝ)) + ∑ i : Fin p.n, ∑ j : Fin p.m, p.c i j * (v.x i j : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P6.d
