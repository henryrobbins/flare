import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P21.a

structure Params where
  -- Dimensions
  n : ℕ -- number of vertices in the perfect graph
  m : ℕ -- number of edges in the perfect graph
  P : ℕ -- number of disjoint clusters partitioning the vertex set
  clusterSize : Fin P → ℕ -- number of vertices in each cluster
  -- Graph and cluster data
  E : Fin m → Fin n × Fin n -- endpoint vertices of each edge, smaller index first
  clusters : ∀ p : Fin P, Fin (clusterSize p) → Fin n -- vertex indices belonging to each cluster
  -- Implicit Assumptions
  hn_pos : NeZero n
  hP_pos : NeZero P
  hclusterSize_pos : ∀ p : Fin P, NeZero (clusterSize p)
  -- Assumptions
  hpartition_card : ∑ p : Fin P, clusterSize p = n
  hpartition_cover : ∀ i : Fin n, ∃ p : Fin P, ∃ s : Fin (clusterSize p), clusters p s = i
  hpartition_unique : ∀ p1 p2 : Fin P, ∀ s1 : Fin (clusterSize p1), ∀ s2 : Fin (clusterSize p2),
    clusters p1 s1 = clusters p2 s2 → p1 = p2
  hedge_lt : ∀ e : Fin m, (E e).1 < (E e).2

structure Vars (p : Params) where
  y : Fin p.P → ℤ -- equals 1 if color k is used
  w : Fin p.n → Fin p.P → ℤ -- equals 1 if vertex i is selected and assigned color k

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- A vertex can only be assigned color k if color k is used
  hlink : ∀ i : Fin p.n, ∀ k : Fin p.P, v.w i k ≤ v.y k
  -- No two vertices sharing an edge may receive the same color
  hedge : ∀ e : Fin p.m, ∀ k : Fin p.P,
    v.w (p.E e).1 k + v.w (p.E e).2 k ≤ 1
  -- Exactly one vertex is selected and colored from each cluster
  hselect : ∀ pIdx : Fin p.P,
    ∑ s : Fin (p.clusterSize pIdx), ∑ k : Fin p.P, v.w (p.clusters pIdx s) k = 1
  -- Binary variables
  hy_bin : ∀ k : Fin p.P, v.y k = 0 ∨ v.y k = 1
  hw_bin : ∀ i : Fin p.n, ∀ k : Fin p.P, v.w i k = 0 ∨ v.w i k = 1

-- Minimize the total number of distinct colors used across all selected vertices
def obj (p : Params) (v : Vars p) : ℝ :=
  ∑ k : Fin p.P, (v.y k : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P21.a
