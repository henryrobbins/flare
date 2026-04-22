import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P9.Fc

structure Params (nN nA nK : ℕ) where
  tail : Fin nA → Fin nN  -- arc source
  head : Fin nA → Fin nN  -- arc destination
  u    : Fin nA → ℝ       -- arc capacity
  O    : Fin nK → Fin nN  -- commodity origin
  D    : Fin nK → Fin nN  -- commodity destination
  d    : Fin nK → ℝ       -- commodity demand
  c    : Fin nA → ℝ       -- unit transportation cost
  f    : Fin nA → ℝ       -- fixed activation cost
  hd_pos : ∀ k, 0 < d k
  hu_nn  : ∀ e, 0 ≤ u e

structure Vars (nA nK : ℕ) where
  x : Fin nA → Fin nK → ℝ  -- flow of commodity k on arc e
  y : Fin nA → ℤ            -- arc activation

-- Outgoing cut arcs: δ⁺(S)
private abbrev cut {nN nA : ℕ} (tail head : Fin nA → Fin nN)
    (S : Finset (Fin nN)) : Finset (Fin nA) :=
  univ.filter (fun e => tail e ∈ S ∧ head e ∉ S)

-- Commodities crossing the cut: K(S)
private abbrev KS {nN nK : ℕ} (O D : Fin nK → Fin nN)
    (S : Finset (Fin nN)) : Finset (Fin nK) :=
  univ.filter (fun k => O k ∈ S ∧ D k ∉ S)

structure Feasible {nN nA nK : ℕ} [NeZero nN] [NeZero nA] [NeZero nK]
    (p : Params nN nA nK) (v : Vars nA nK) : Prop where
  -- Commodity source outflow equals demand
  hout : ∀ k, (univ.filter (fun e => p.tail e = p.O k)).sum (v.x · k) = p.d k
  -- Commodity sink inflow equals demand
  hin  : ∀ k, (univ.filter (fun e => p.head e = p.D k)).sum (v.x · k) = p.d k
  -- Flow conservation at intermediate nodes
  hbal : ∀ k i, i ≠ p.O k → i ≠ p.D k →
    (univ.filter (fun e => p.tail e = i)).sum (v.x · k) =
    (univ.filter (fun e => p.head e = i)).sum (v.x · k)
  -- Arc capacity tied to activation
  hcap : ∀ e, ∑ k, v.x e k ≤ p.u e * v.y e
  hx_nn  : ∀ e k, 0 ≤ v.x e k
  hy_bin : ∀ e, v.y e = 0 ∨ v.y e = 1
  -- No outflow from any commodity's destination
  hsink : ∀ k e, p.tail e = p.D k → v.x e k = 0
  -- EC1 (V2): Knapsack-Cover Capacity Cut
  -- For every non-trivial node subset S and commodity bundle B ⊆ K(S), the
  -- cut arcs δ⁺(S) weighted by min(u_e, D_B) must cover the total bundle demand D_B.
  hec1 : ∀ (S : Finset (Fin nN)), S.Nonempty → S ≠ univ →
    ∀ (B : Finset (Fin nK)), B ⊆ KS p.O p.D S →
    let D_B := B.sum p.d
    (cut p.tail p.head S).sum (fun e => min (p.u e) D_B * (v.y e : ℝ)) ≥ D_B

-- Minimize total flow cost plus fixed arc activation cost
def obj {nN nA nK : ℕ} (p : Params nN nA nK) (v : Vars nA nK) : ℝ :=
  (∑ e, ∑ k, p.c e * v.x e k) + ∑ e, p.f e * (v.y e : ℝ)

def formulation (nN nA nK : ℕ) [NeZero nN] [NeZero nA] [NeZero nK] :
    MILPFormulation where
  Params   := Params nN nA nK
  Vars     := Vars nA nK
  feasible := Feasible
  obj      := obj

end P9.Fc
