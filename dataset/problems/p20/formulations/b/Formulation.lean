import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P20.b

/-
Inefficient (path-enumeration) formulation of the WFP food distribution problem.
Enumerates all simple paths from suppliers to beneficiary camps.

Dimensions:
- `nP` : number of simple paths from a supplier to a beneficiary camp
- `nK` : number of food commodities
- `nL` : number of nutritional requirements
- `nB` : number of beneficiary camps
-/

structure Params where
  nP : ℕ  -- number of simple supplier-to-camp paths
  nK : ℕ  -- number of commodities
  nL : ℕ  -- number of nutrients
  nB : ℕ  -- number of beneficiary camps
  c : ℕ → ℕ → ℝ  -- shipping cost per kg of commodity k along path p
  q : ℕ → ℝ  -- procurement cost per kg of each commodity
  nutval : ℕ → ℕ → ℝ  -- nutritional value per kg of each commodity for each nutrient
  nutreq : ℕ → ℝ  -- per-person nutritional requirement for each nutrient
  dem : ℕ → ℝ  -- number of beneficiaries at each camp
  e : ℕ → ℕ → ℤ  -- indicator: 1 if path p ends at camp j, 0 otherwise
  -- Assumptions
  hnP : NeZero nP
  hnK : NeZero nK
  hnL : NeZero nL
  hnB : NeZero nB
  -- Implicit Assumptions
  hc_nn : ∀ p : Fin nP, ∀ k : Fin nK, 0 ≤ c p k
  hq_nn : ∀ k : Fin nK, 0 ≤ q k
  hnutval_nn : ∀ k : Fin nK, ∀ l : Fin nL, 0 ≤ nutval k l
  hnutreq_nn : ∀ l : Fin nL, 0 ≤ nutreq l
  hdem_nn : ∀ j : Fin nB, 0 ≤ dem j
  he_bin : ∀ j : Fin nB, ∀ p : Fin nP, e j p = 0 ∨ e j p = 1

structure Vars where
  x : ℕ → ℕ → ℝ  -- amount of commodity k shipped along path p (kg)
  R : ℕ → ℝ  -- ration size per person of each commodity (kg)

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Each camp receives at least its ration demand from paths ending there
  hdemand : ∀ j : Fin p.nB, ∀ k : Fin p.nK,
    p.dem j * v.R k ≤ ∑ π : Fin p.nP, (p.e j π : ℝ) * v.x π k
  -- Rations satisfy all nutritional requirements
  hnutrition : ∀ l : Fin p.nL,
    p.nutreq l ≤ ∑ k : Fin p.nK, p.nutval k l * v.R k
  -- [Implicit Constraints]
  hx_nn : ∀ π : Fin p.nP, ∀ k : Fin p.nK, 0 ≤ v.x π k
  hR_nn : ∀ k : Fin p.nK, 0 ≤ v.R k

-- Minimize total shipping and procurement cost
def obj (p : Params) (v : Vars) : ℝ :=
  (∑ π : Fin p.nP, ∑ k : Fin p.nK, p.c π k * v.x π k)
    + ∑ k : Fin p.nK, p.q k * (∑ π : Fin p.nP, v.x π k)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P20.b
