import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P6.Fi

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

-- Base conflict set for warehouse j: customers with demand > u_j / 2
noncomputable def clique {m n : ℕ} (p : Params m n) (j : Fin n) : Finset (Fin m) :=
  letI : DecidablePred (fun i : Fin m => p.u j / 2 < p.d i) := Classical.decPred _
  univ.filter (fun i => p.u j / 2 < p.d i)

-- One step of the greedy lift: add i to acc if it conflicts with every member already in acc
private noncomputable def greedyStep {m n : ℕ} (p : Params m n) (j : Fin n)
    (acc : Finset (Fin m)) (i : Fin m) : Finset (Fin m) :=
  if ∀ i' ∈ acc, p.u j < p.d i + p.d i' then insert i acc else acc

-- Lifted conflict set: greedily extend the base clique with smaller customers that still conflict
noncomputable def liftedClique {m n : ℕ} (p : Params m n) (j : Fin n) : Finset (Fin m) :=
  ((univ \ clique p j).sort (· ≤ ·)).foldl (greedyStep p j) (clique p j)

structure Feasible {m n : ℕ} [NeZero m] [NeZero n] (p : Params m n) (v : Vars m n) : Prop where
  hassign : ∀ i, ∑ j, v.x i j = 1
  hcap : ∀ j, ∑ i, p.d i * v.x i j ≤ p.u j * v.y j
  hx_bin : ∀ i j, v.x i j = 0 ∨ v.x i j = 1
  hy_bin : ∀ j, v.y j = 0 ∨ v.y j = 1
  -- EC5 (V2): Warehouse Clique Bound
  -- At most one customer from the lifted conflict set can be assigned to each warehouse
  hec5 : ∀ j, ∑ i ∈ liftedClique p j, v.x i j ≤ v.y j

def obj {m n : ℕ} (p : Params m n) (v : Vars m n) : ℝ :=
  (∑ j, p.f j * (v.y j : ℝ)) + ∑ i, ∑ j, p.c i j * (v.x i j : ℝ)

def formulation (m n : ℕ) [NeZero m] [NeZero n] : MILPFormulation where
  Params   := Params m n
  Vars     := Vars m n
  feasible := Feasible
  obj      := obj

end P6.Fi
