import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P21.b

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
  Q : ℕ -- number of maximal cliques of the graph
  L : Fin Q → ℕ -- number of vertices in each maximal clique
  -- Data
  E : Fin m → Fin n × Fin n -- endpoint vertices of each edge, smaller index first
  C : Fin n → Fin P → ℤ -- binary cluster membership matrix: C i p = 1 if vertex i belongs to cluster p
  K : ∀ q : Fin Q, Fin (L q) → Fin n -- vertex indices belonging to each maximal clique
  -- Implicit Assumptions
  hn_pos : NeZero n
  hQ_pos : NeZero Q
  hL_pos : ∀ q : Fin Q, 1 ≤ L q
  -- C is binary
  hC_bin : ∀ i : Fin n, ∀ p : Fin P, C i p = 0 ∨ C i p = 1
  -- Every vertex belongs to exactly one cluster
  hC_partition : ∀ i : Fin n, ∑ p : Fin P, C i p = 1
  -- Each cluster contains at least one vertex
  hC_nonempty : ∀ p : Fin P, 1 ≤ ∑ i : Fin n, C i p
  -- Every edge connects two distinct, valid vertex indices (smaller index first)
  hedge_lt : ∀ e : Fin m, (E e).1 < (E e).2
  -- Each K q lists distinct vertices
  hK_inj : ∀ q : Fin Q, Function.Injective (K q)
  -- Each K q forms a clique of the graph
  hK_clique : ∀ q : Fin Q, IsClique E (Finset.image (K q) Finset.univ)
  -- K covers every clique of the graph: every clique is a subset of some K q
  hK_complete : ∀ S : Finset (Fin n), IsClique E S →
    ∃ q : Fin Q, S ⊆ Finset.image (K q) Finset.univ
  -- The graph is perfect: every induced subgraph has chromatic number equal to its clique number
  hperfect : ∀ (S : Finset (Fin n)) (k : ℕ),
    (∀ Cl : Finset (Fin n), Cl ⊆ S → IsClique E Cl → Cl.card ≤ k) →
    ∃ c : Fin n → ℕ, (∀ i ∈ S, c i < k) ∧
      ∀ i ∈ S, ∀ j ∈ S, i ≠ j → Adjacent E i j → c i ≠ c j

structure Vars (p : Params) where
  x : Fin p.n → ℤ -- equals 1 if vertex i is selected, 0 otherwise
  t : ℝ -- estimate of the number of colors needed to color the selected vertices

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Exactly one vertex is selected from each cluster
  hcluster : ∀ pp : Fin p.P,
    ∑ i : Fin p.n, p.C i pp * v.x i = 1
  -- t is at least the number of selected vertices within any maximal clique
  hclique : ∀ q : Fin p.Q,
    ∑ i : Fin (p.L q), (v.x (p.K q i) : ℝ) ≤ v.t
  -- Non-negativity of t
  ht_nn : 0 ≤ v.t
  -- Binary variables
  hx_bin : ∀ i : Fin p.n, v.x i = 0 ∨ v.x i = 1

-- Minimize the number of colors needed to color the selected vertices
def obj (p : Params) (v : Vars p) : ℝ :=
  v.t

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P21.b
