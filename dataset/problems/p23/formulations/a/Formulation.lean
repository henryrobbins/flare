import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P23.a

structure Params where
  n : ℕ  -- number of nodes (customers) in the network
  p : ℕ  -- number of nodes to be selected as medians
  c : Fin n → Fin n → ℝ  -- service cost; c i j is the cost of serving node i from median j
  -- Assumptions
  hp_pos : 1 ≤ p  -- at least one median is opened
  hp_lt : p < n  -- fewer medians than nodes (p ≤ n - 1)
  hc_diag : ∀ i : Fin n, c i i = 0  -- self-service cost is zero
  hc_pos : ∀ i j : Fin n, i ≠ j → 0 < c i j  -- distinct-node cost is strictly positive
  -- Implicit Assumptions
  hn : NeZero n

structure Vars (p : Params) where
  x : Fin p.n → Fin p.n → ℤ  -- x i j = 1 iff node i is served by median j; x j j = 1 iff j is a median

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Every node is served by exactly one median
  hassign : ∀ i : Fin p.n, ∑ j : Fin p.n, v.x i j = 1
  -- A node may be served by another node only if that node is selected as a median
  hlink : ∀ i j : Fin p.n, i ≠ j → v.x i j ≤ v.x j j
  -- Exactly p nodes are selected as medians
  hmed : ∑ j : Fin p.n, v.x j j = (p.p : ℤ)
  -- [Implicit Constraints]
  hx_bin : ∀ i j : Fin p.n, v.x i j = 0 ∨ v.x i j = 1

-- Minimize the total service cost summed over all nodes
def obj (p : Params) (v : Vars p) : ℝ :=
  ∑ i : Fin p.n, ∑ j : Fin p.n, p.c i j * (v.x i j : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P23.a
