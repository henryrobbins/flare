import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Order.Monotone.Basic

open BigOperators Finset

namespace P23.b

structure Params where
  n : ℕ  -- number of nodes (customers) in the network
  p : ℕ  -- number of nodes to be selected as medians
  c : Fin n → Fin n → ℝ  -- service cost; c i j is the cost of serving node i from median j
  G : Fin n → ℕ  -- G i = number of distinct cost values c i j in row i of the cost matrix
  D : (i : Fin n) → Fin (G i) → ℝ
    -- sorted distinct cost values of row i of c; G i values, D i 0 = 0 up to D i (G i - 1) = max_j c i j
  -- Assumptions
  hp_pos : 1 ≤ p  -- at least one median is opened
  hp_lt : p < n  -- fewer medians than nodes (p ≤ n - 1)
  hc_diag : ∀ i : Fin n, c i i = 0  -- self-service cost is zero
  hc_pos : ∀ i j : Fin n, i ≠ j → 0 < c i j  -- distinct-node cost is strictly positive
  hG_pos : ∀ i : Fin n, 1 ≤ G i  -- each row has at least one distinct cost value (the zero self cost)
  -- D i is the sorted list of distinct cost values in row i: the smallest is the
  -- zero self cost, the values are strictly increasing, and they range over
  -- exactly the cost values {c i j : j}.
  hD_zero : ∀ i : Fin n, D i ⟨0, hG_pos i⟩ = 0
  hD_mono : ∀ i : Fin n, StrictMono (D i)
  hD_image : ∀ (i : Fin n) (val : ℝ),
    (∃ k : Fin (G i), D i k = val) ↔ (∃ j : Fin n, c i j = val)
  -- Implicit Assumptions
  hn : NeZero n

structure Vars (p : Params) where
  y : Fin p.n → ℤ  -- y j = 1 iff node j is selected as a median
  z : (i : Fin p.n) → Fin (p.G i) → ℤ
    -- radius variable: z i k = 1 iff the cost of serving node i is at least D i k
    -- (the k = 0 entry mirrors the paper's omitted z_{i1} and is left unused)

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Exactly p nodes are selected as medians
  hmed : ∑ j : Fin p.n, v.y j = (p.p : ℤ)
  -- Covering: for each node i and threshold D i k with k ≥ 1, either some median lies
  -- at a cost strictly below the threshold, or the radius variable z i k is charged
  hcov : ∀ (i : Fin p.n) (k : Fin (p.G i)), k.val ≠ 0 →
    (1 : ℝ) ≤ (v.z i k : ℝ)
      + ∑ j : Fin p.n, (if p.c i j < p.D i k then (v.y j : ℝ) else 0)
  -- [Implicit Constraints]
  -- Radius variables are binary
  hz_bin : ∀ (i : Fin p.n) (k : Fin (p.G i)), v.z i k = 0 ∨ v.z i k = 1
  -- Location variables are binary
  hy_bin : ∀ j : Fin p.n, v.y j = 0 ∨ v.y j = 1

-- Minimize the total service cost, expressed as a telescoping sum of radius
-- increments: node i pays D i k - D i (k-1) for every threshold k ≥ 1 up to the
-- cost at which it is first covered by an open median. The k = 0 summand vanishes
-- since its predecessor index clamps to 0, so z i 0 does not appear.
def obj (p : Params) (v : Vars p) : ℝ :=
  ∑ i : Fin p.n, ∑ k : Fin (p.G i),
    (p.D i k - p.D i ⟨k.val - 1, lt_of_le_of_lt (Nat.sub_le _ _) k.isLt⟩) * (v.z i k : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P23.b
