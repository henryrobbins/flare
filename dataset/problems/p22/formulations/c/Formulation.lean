import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Fintype.Prod
import Mathlib.Data.Fin.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P22.c

structure Params where
  W : ℕ  -- bin capacity
  m : ℕ  -- number of distinct item types
  w : Fin m → ℕ  -- size of each item type
  b : Fin m → ℤ  -- demand (number of items required) for each item type
  -- Assumptions
  hw_lo : ∀ d : Fin m, 1 ≤ w d
  hw_hi : ∀ d : Fin m, w d ≤ W
  -- Implicit Assumptions
  hW : NeZero W
  hm : NeZero m
  hb_pos : ∀ d : Fin m, 1 ≤ b d

/-
The graph G = (V, A) has vertex set V = {0,...,W}, encoded as Fin (p.W + 1).
The arc set A is a plain set of vertex pairs (i, j), formed exactly as in the
source: the union of item arcs (i, i + w d) for every item type d and start
vertex i with i + w d ≤ W, and loss arcs (k, k + 1) for every k = 0,...,W-1.
Because A is a union of pairs rather than a disjoint tagged union, if some
item type has width exactly 1, its item arc (k, k+1) coincides with the loss
arc (k, k+1): both are the very same element (k, k+1) of A, and hence share
the same flow variable `x k (k+1)`. This is deliberate, matching the source
paper's Equations 7-11 exactly.
-/
def isArc (p : Params) (i j : Fin (p.W + 1)) : Prop :=
  (∃ d : Fin p.m, (j : ℕ) = (i : ℕ) + p.w d) ∨ (j : ℕ) = (i : ℕ) + 1

instance (p : Params) (i j : Fin (p.W + 1)) : Decidable (isArc p i j) := by
  unfold isArc
  infer_instance

-- Outgoing arcs of vertex i (all j with (i,j) ∈ A)
def outArcs (p : Params) (i : Fin (p.W + 1)) : Finset (Fin (p.W + 1)) :=
  univ.filter (fun j => isArc p i j)

-- Incoming arcs of vertex j (all i with (i,j) ∈ A)
def inArcs (p : Params) (j : Fin (p.W + 1)) : Finset (Fin (p.W + 1)) :=
  univ.filter (fun i => isArc p i j)

-- Item arcs of type d, viewed as their start vertices k (the arc is (k, k + w d))
def D (p : Params) (d : Fin p.m) : Finset (Fin (p.W + 1)) :=
  univ.filter (fun k => (k : ℕ) + p.w d ≤ p.W)

-- The endpoint k + w d of the type-d item arc starting at k, capped at W (the
-- cap is never active for k ∈ D p d, where k + w d ≤ W already holds).
def endOf (p : Params) (d : Fin p.m) (k : Fin (p.W + 1)) : Fin (p.W + 1) :=
  ⟨min (k.val + p.w d) p.W, Nat.lt_succ_of_le (min_le_right _ _)⟩

structure Vars (p : Params) where
  x : Fin (p.W + 1) → Fin (p.W + 1) → ℤ  -- flow on arc (i,j) ∈ A
  z : ℤ  -- number of bins used

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Flow conservation at vertex 0: inflow minus outflow equals the negative of the number of bins used
  hflow0 :
    (∑ i ∈ inArcs p 0, v.x i 0) - (∑ j ∈ outArcs p 0, v.x 0 j) = -v.z
  -- Flow conservation at every intermediate vertex: inflow equals outflow
  hflowMid : ∀ vtx : Fin (p.W + 1), 0 < vtx.val → vtx.val < p.W →
    (∑ i ∈ inArcs p vtx, v.x i vtx) - (∑ j ∈ outArcs p vtx, v.x vtx j) = 0
  -- Flow conservation at vertex W: inflow minus outflow equals the number of bins used
  hflowW :
    (∑ i ∈ inArcs p (Fin.last p.W), v.x i (Fin.last p.W))
    - (∑ j ∈ outArcs p (Fin.last p.W), v.x (Fin.last p.W) j) = v.z
  -- The full demand of every item type must be packed
  hdemand : ∀ d : Fin p.m, ∑ k ∈ D p d, v.x k (endOf p d k) ≥ p.b d
  -- Arc flows are non-negative
  hx_nn : ∀ i j : Fin (p.W + 1), isArc p i j → 0 ≤ v.x i j
  -- The number of bins used doesn't exceed the total number of items
  htotal : v.z ≤ ∑ d : Fin p.m, p.b d

-- Minimize the total number of bins used
def obj (p : Params) (v : Vars p) : ℝ :=
  (v.z : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P22.c
