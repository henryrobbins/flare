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
  clusterSize : Fin P → ℕ -- number of vertices in each cluster
  q : ℕ -- number of maximal cliques of the graph
  cliqueSize : Fin q → ℕ -- number of vertices in each maximal clique
  -- Data
  E : Fin m → Fin n × Fin n -- endpoint vertices of each edge, smaller index first
  clusters : ∀ p : Fin P, Fin (clusterSize p) → Fin n -- vertex indices belonging to each cluster
  K : ∀ l : Fin q, Fin (cliqueSize l) → Fin n -- vertex indices belonging to each maximal clique
  -- Implicit Assumptions
  hn_pos : NeZero n
  hP_pos : NeZero P
  hclusterSize_pos : ∀ p : Fin P, 1 ≤ clusterSize p
  hpartition : ∑ p : Fin P, clusterSize p = n
  hq_pos : NeZero q
  hcliqueSize_pos : ∀ l : Fin q, 1 ≤ cliqueSize l
  hedge_lt : ∀ e : Fin m, (E e).1 < (E e).2
  -- Each K l is injective (lists distinct vertices) and forms a clique of the graph
  hK_inj : ∀ l : Fin q, Function.Injective (K l)
  hK_clique : ∀ l : Fin q, IsClique E (Finset.image (K l) Finset.univ)
  -- K covers every clique of the graph: each clique's vertices lie within the image of
  -- some K l. Since K is computed as the set of all maximal cliques of the graph, every
  -- clique (maximal or not) is a subset of some maximal clique
  hK_complete : ∀ S : Finset (Fin n), IsClique E S →
    ∃ l : Fin q, S ⊆ Finset.image (K l) Finset.univ

structure Vars (p : Params) where
  x : Fin p.n → ℤ -- equals 1 if vertex i is selected, 0 otherwise
  t : ℝ -- estimate of the number of colors needed to color the selected vertices

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Exactly one vertex is selected from each cluster
  hcluster : ∀ pp : Fin p.P,
    ∑ i : Fin (p.clusterSize pp), (v.x (p.clusters pp i) : ℝ) = 1
  -- t is at least the number of selected vertices within any maximal clique
  hclique : ∀ l : Fin p.q,
    ∑ i : Fin (p.cliqueSize l), (v.x (p.K l i) : ℝ) ≤ v.t
  -- Non-negativity
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
