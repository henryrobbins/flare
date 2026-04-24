import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P6.i

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

noncomputable def clique (p : Params) (j : Fin p.m) : Finset (Fin p.n) :=
  letI : DecidablePred (fun i : Fin p.n => p.u j / 2 < p.d i) := Classical.decPred _
  univ.filter (fun i => p.u j / 2 < p.d i)

noncomputable def greedyStep (p : Params) (j : Fin p.m)
    (acc : Finset (Fin p.n)) (i : Fin p.n) : Finset (Fin p.n) :=
  if ∀ i' ∈ acc, p.u j < p.d i + p.d i' then insert i acc else acc

-- Note: the JSON sorts remaining customers by demand descending before the greedy extension;
-- here we sort by index ascending (· ≤ ·). The result is a valid lifted clique inequality
-- regardless of order, but may differ from the JSON's specific instance.
noncomputable def liftedClique (p : Params) (j : Fin p.m) : Finset (Fin p.n) :=
  ((univ \ clique p j).sort (· ≤ ·)).foldl (greedyStep p j) (clique p j)

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Each customer is assigned to exactly one warehouse
  hassign : ∀ i : Fin p.n, ∑ j : Fin p.m, v.x i j = 1
  -- Capacity: total demand assigned to each warehouse cannot exceed its capacity times whether it is open
  hcap : ∀ j : Fin p.m, ∑ i : Fin p.n, p.d i * (v.x i j : ℝ) ≤ p.u j * (v.y j : ℝ)
  hx_bin : ∀ i : Fin p.n, ∀ j : Fin p.m, v.x i j = 0 ∨ v.x i j = 1
  hy_bin : ∀ j : Fin p.m, v.y j = 0 ∨ v.y j = 1
  -- Warehouse Clique Bound: at most one customer from the lifted conflict set can be assigned per warehouse
  hec5 : ∀ j : Fin p.m, ∑ i ∈ liftedClique p j, v.x i j ≤ v.y j

-- Minimize total fixed opening cost plus transportation cost
def obj (p : Params) (v : Vars) : ℝ :=
  (∑ j : Fin p.m, p.f j * (v.y j : ℝ)) + ∑ i : Fin p.n, ∑ j : Fin p.m, p.c i j * (v.x i j : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P6.i
