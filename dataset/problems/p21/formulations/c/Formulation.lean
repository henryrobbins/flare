import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P21.c

-- Two distinct vertices are adjacent iff some edge of E connects them
def Adjacent {n m : ℕ} (E : Fin m → Fin n × Fin n) (i j : Fin n) : Prop :=
  (∃ e : Fin m, E e = (i, j)) ∨ (∃ e : Fin m, E e = (j, i))

-- A finite vertex set is a clique iff every pair of distinct vertices is adjacent
def IsClique {n m : ℕ} (E : Fin m → Fin n × Fin n) (S : Finset (Fin n)) : Prop :=
  ∀ i ∈ S, ∀ j ∈ S, i ≠ j → Adjacent E i j

structure Params where
  -- Dimensions
  n : ℕ -- number of vertices in the perfect graph
  m : ℕ -- number of edges in the perfect graph
  P : ℕ -- number of disjoint clusters partitioning the vertex set
  -- Graph and cluster data
  E : Fin m → Fin n × Fin n -- endpoint vertices of each edge, smaller index first
  C : Fin n → Fin P → ℤ -- binary cluster membership matrix: C[i][p] = 1 iff vertex i is in cluster p
  -- Implicit Assumptions
  hn_pos : NeZero n
  hC_bin : ∀ i : Fin n, ∀ p : Fin P, C i p = 0 ∨ C i p = 1
  -- Assumptions
  -- Every vertex belongs to exactly one cluster
  hpartition : ∀ i : Fin n, ∑ p : Fin P, C i p = 1
  -- Each cluster contains at least one vertex
  hcluster_nonempty : ∀ p : Fin P, 1 ≤ ∑ i : Fin n, C i p
  -- Every edge connects two distinct valid vertices with the smaller index first
  hedge_lt : ∀ e : Fin m, (E e).1 < (E e).2
  -- The graph is perfect: every induced subgraph has chromatic number equal to its clique number,
  -- i.e. if every clique within S has at most k vertices, S admits a proper coloring using fewer than k colors
  hperfect : ∀ (S : Finset (Fin n)) (k : ℕ),
    (∀ Q : Finset (Fin n), Q ⊆ S → IsClique E Q → Q.card ≤ k) →
    ∃ c : Fin n → ℕ, (∀ i ∈ S, c i < k) ∧
      ∀ i ∈ S, ∀ j ∈ S, i ≠ j → Adjacent E i j → c i ≠ c j

structure Vars (p : Params) where
  y : Fin p.P → ℤ -- equals 1 if color k is used, 0 otherwise
  w : Fin p.n → Fin p.P → ℤ -- equals 1 if vertex i is selected and assigned color k, 0 otherwise

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- A vertex can only be assigned color k if color k is used
  hlink : ∀ i : Fin p.n, ∀ k : Fin p.P, v.w i k ≤ v.y k
  -- No two vertices sharing an edge may receive the same color
  hedge : ∀ e : Fin p.m, ∀ k : Fin p.P,
    v.w (p.E e).1 k + v.w (p.E e).2 k ≤ 1
  -- Exactly one vertex is selected and colored from each cluster
  hselect : ∀ pIdx : Fin p.P,
    ∑ i : Fin p.n, ∑ k : Fin p.P, p.C i pIdx * v.w i k = 1
  -- Clique cutting plane: for every clique of the graph, the number of colors used must be at
  -- least the number of selected vertices within that clique, since vertices in a clique are
  -- pairwise adjacent and therefore must all receive distinct colors
  hclique : ∀ S : Finset (Fin p.n), IsClique p.E S →
    ∑ i ∈ S, ∑ k : Fin p.P, v.w i k ≤ ∑ k : Fin p.P, v.y k
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

end P21.c
