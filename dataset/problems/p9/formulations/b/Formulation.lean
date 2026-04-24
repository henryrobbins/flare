import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P9.b

structure Params where
  n : ℕ  -- number of network nodes
  m : ℕ  -- number of candidate directed arcs
  K : ℕ  -- number of commodities
  tail : Fin m → Fin n  -- arc source node
  head : Fin m → Fin n  -- arc destination node
  c : Fin m → ℝ  -- unit transportation cost on each arc
  f : Fin m → ℝ  -- fixed cost to activate each arc
  u : Fin m → ℝ  -- capacity of each arc
  O : Fin K → Fin n  -- origin node of each commodity
  D : Fin K → Fin n  -- destination node of each commodity
  d : Fin K → ℝ  -- demand of each commodity
  -- Implicit Assumptions
  hn : NeZero n
  hm : NeZero m
  hK : NeZero K
  hc_nn : ∀ e : Fin m, 0 ≤ c e
  hf_nn : ∀ e : Fin m, 0 ≤ f e
  hd_pos : ∀ k : Fin K, 0 < d k
  hu_nn : ∀ e : Fin m, 0 ≤ u e

-- Incoming arcs to a destination node for commodity k
private abbrev incArcs (p : Params) (k : Fin p.K) : Finset (Fin p.m) :=
  univ.filter (fun e => p.head e = p.D k)

-- Maximum capacity among incoming arcs to D_k
private noncomputable def uMax (p : Params) (k : Fin p.K) : ℝ :=
  if h : (incArcs p k).Nonempty then (incArcs p k).sup' h p.u else 0

structure Vars where
  x : ℕ → ℕ → ℝ  -- flow of commodity k on arc e
  y : ℕ → ℤ       -- 1 if arc e is activated, 0 otherwise

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Commodity source outflow equals demand
  hout : ∀ k : Fin p.K,
    (univ.filter (fun e : Fin p.m => p.tail e = p.O k)).sum (fun e => v.x e k) = p.d k
  -- Commodity sink inflow equals demand
  hin : ∀ k : Fin p.K,
    (univ.filter (fun e : Fin p.m => p.head e = p.D k)).sum (fun e => v.x e k) = p.d k
  -- Flow conservation at intermediate nodes
  hbal : ∀ k : Fin p.K, ∀ i : Fin p.n, i ≠ p.O k → i ≠ p.D k →
    (univ.filter (fun e : Fin p.m => p.tail e = i)).sum (fun e => v.x e k) =
    (univ.filter (fun e : Fin p.m => p.head e = i)).sum (fun e => v.x e k)
  -- Arc capacity tied to activation
  hcap : ∀ e : Fin p.m,
    ∑ k : Fin p.K, v.x e k ≤ p.u e * (v.y e : ℝ)
  hx_nn : ∀ e : Fin p.m, ∀ k : Fin p.K, 0 ≤ v.x e k
  hy_bin : ∀ e : Fin p.m, v.y e = 0 ∨ v.y e = 1
  -- [Implicit Constraints]
  -- No outflow from any commodity's destination
  hsink : ∀ k : Fin p.K,
    (univ.filter (fun e : Fin p.m => p.tail e = p.D k)).sum (fun e => v.x e k) = 0
  -- EC1 (V1): Destination In-Cut Bound
  hec1 : ∀ k : Fin p.K,
    (incArcs p k).sum
      (fun e => (p.u e + uMax p k) * (v.y e : ℝ)) ≥
    p.d k + uMax p k

-- Minimize total flow cost plus fixed arc activation cost
def obj (p : Params) (v : Vars) : ℝ :=
  (∑ e : Fin p.m, ∑ k : Fin p.K, p.c e * v.x e k) +
  ∑ e : Fin p.m, p.f e * (v.y e : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P9.b
