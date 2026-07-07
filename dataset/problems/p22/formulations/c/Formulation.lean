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
The graph has vertex set {0,...,W} (encoded as Fin (p.W + 1)). An item arc of
type d starts at vertex i and ends at vertex i + w d; it exists exactly when
i + w d ≤ W. A loss arc starts at vertex k and ends at vertex k + 1; since
these arcs exist for exactly k = 0,...,W-1, they are indexed directly by
`Fin p.W` rather than filtered out of a larger domain.
-/

-- Item-type arcs leaving vertex i (all d with an existing arc (i, i + w d, d))
def itemArcsOut (p : Params) (i : Fin (p.W + 1)) : Finset (Fin p.m) :=
  univ.filter (fun d => i.val + p.w d ≤ p.W)

-- Item-type arcs entering vertex v (all (i,d) pairs with i + w d = v)
def itemArcsIn (p : Params) (v : Fin (p.W + 1)) : Finset (Fin (p.W + 1) × Fin p.m) :=
  univ.filter (fun id => id.1.val + p.w id.2 = v.val)

-- All item arcs of a given type d (all start vertices i with an existing arc)
def D (p : Params) (d : Fin p.m) : Finset (Fin (p.W + 1)) :=
  univ.filter (fun i => i.val + p.w d ≤ p.W)

-- Loss arcs leaving vertex v (the arc (v, v+1), if it exists)
def lossArcsOut (p : Params) (v : Fin (p.W + 1)) : Finset (Fin p.W) :=
  univ.filter (fun k => k.val = v.val)

-- Loss arcs entering vertex v (the arc (v-1, v), if it exists)
def lossArcsIn (p : Params) (v : Fin (p.W + 1)) : Finset (Fin p.W) :=
  univ.filter (fun k => k.val + 1 = v.val)

structure Vars (p : Params) where
  xItem : Fin (p.W + 1) → Fin p.m → ℤ  -- flow on the item arc starting at i with type d
  xLoss : Fin p.W → ℤ  -- flow on the loss arc starting at k
  z : ℤ  -- number of bins used

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Flow conservation at vertex 0: inflow minus outflow equals the negative of the number of bins used
  hflow0 :
    (∑ id ∈ itemArcsIn p 0, v.xItem id.1 id.2) + (∑ k ∈ lossArcsIn p 0, v.xLoss k)
    - ((∑ d ∈ itemArcsOut p 0, v.xItem 0 d) + (∑ k ∈ lossArcsOut p 0, v.xLoss k))
    = -v.z
  -- Flow conservation at every intermediate vertex: inflow equals outflow
  hflowMid : ∀ vtx : Fin (p.W + 1), 0 < vtx.val → vtx.val < p.W →
    (∑ id ∈ itemArcsIn p vtx, v.xItem id.1 id.2) + (∑ k ∈ lossArcsIn p vtx, v.xLoss k)
    - ((∑ d ∈ itemArcsOut p vtx, v.xItem vtx d) + (∑ k ∈ lossArcsOut p vtx, v.xLoss k))
    = 0
  -- Flow conservation at vertex W: inflow minus outflow equals the number of bins used
  hflowW :
    (∑ id ∈ itemArcsIn p (Fin.last p.W), v.xItem id.1 id.2)
      + (∑ k ∈ lossArcsIn p (Fin.last p.W), v.xLoss k)
    - ((∑ d ∈ itemArcsOut p (Fin.last p.W), v.xItem (Fin.last p.W) d)
      + (∑ k ∈ lossArcsOut p (Fin.last p.W), v.xLoss k))
    = v.z
  -- The full demand of every item type must be packed
  hdemand : ∀ d : Fin p.m, ∑ i ∈ D p d, v.xItem i d ≥ p.b d
  hxItem_nn : ∀ i : Fin (p.W + 1), ∀ d : Fin p.m, 0 ≤ v.xItem i d
  hxLoss_nn : ∀ k : Fin p.W, 0 ≤ v.xLoss k
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
