import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P20.a

/-
Efficient formulation of the WFP food distribution problem.
Models flow on each edge of the supply network.

Dimensions:
- `nN` : total number of nodes (suppliers, transshipment points, beneficiary camps)
- `nK` : number of food commodities
- `nL` : number of nutritional requirements

Beneficiary camps are identified by the indicator `isB`.
-/

structure Params where
  nN : ℕ  -- total number of nodes
  nK : ℕ  -- number of commodities
  nL : ℕ  -- number of nutrients
  isB : ℕ → ℤ  -- beneficiary-camp indicator (1 if node is a camp, 0 otherwise)
  E : ℕ → ℕ → ℤ  -- adjacency matrix (1 if edge exists, 0 otherwise)
  dem : ℕ → ℝ  -- number of beneficiaries at each node (0 for non-beneficiary nodes)
  pc : ℕ → ℝ  -- procurement cost per kg of each commodity
  tc : ℕ → ℕ → ℕ → ℝ  -- transportation cost per kg along each arc per commodity
  nutreq : ℕ → ℝ  -- per-person nutritional requirement for each nutrient
  nutval : ℕ → ℕ → ℝ  -- nutritional value per kg of each commodity for each nutrient
  -- Assumptions
  hnN : NeZero nN
  hnK : NeZero nK
  hnL : NeZero nL
  -- Implicit Assumptions
  hisB_bin : ∀ j : Fin nN, isB j = 0 ∨ isB j = 1
  hE_bin : ∀ i j : Fin nN, E i j = 0 ∨ E i j = 1
  hdem_nn : ∀ j : Fin nN, 0 ≤ dem j
  hpc_nn : ∀ k : Fin nK, 0 ≤ pc k
  htc_nn : ∀ i j : Fin nN, ∀ k : Fin nK, 0 ≤ tc i j k
  hnutreq_nn : ∀ l : Fin nL, 0 ≤ nutreq l
  hnutval_nn : ∀ k : Fin nK, ∀ l : Fin nL, 0 ≤ nutval k l

structure Vars where
  F : ℕ → ℕ → ℕ → ℝ  -- amount of commodity k sent from node i to node j (kg)
  R : ℕ → ℝ  -- ration size per person of each commodity (kg)

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Flow conservation at every node for each commodity (no storage)
  hflow : ∀ j : Fin p.nN, ∀ k : Fin p.nK,
    ∑ i : Fin p.nN, (p.E i j : ℝ) * v.F i j k =
    ∑ i : Fin p.nN, (p.E j i : ℝ) * v.F j i k
  -- Beneficiary camps receive at least their ration demand
  hdemand : ∀ j : Fin p.nN, ∀ k : Fin p.nK,
    p.isB j = 1 →
    p.dem j * v.R k ≤ ∑ i : Fin p.nN, (p.E i j : ℝ) * v.F i j k
  -- Rations satisfy all nutritional requirements
  hnutrition : ∀ l : Fin p.nL,
    p.nutreq l ≤ ∑ k : Fin p.nK, p.nutval k l * v.R k
  -- [Implicit Constraints]
  hF_nn : ∀ i j : Fin p.nN, ∀ k : Fin p.nK, 0 ≤ v.F i j k
  hR_nn : ∀ k : Fin p.nK, 0 ≤ v.R k

-- Minimize total procurement and transportation cost
def obj (p : Params) (v : Vars) : ℝ :=
  (∑ k : Fin p.nK, p.pc k * (∑ j : Fin p.nN, (p.isB j : ℝ) * p.dem j * v.R k))
    + ∑ i : Fin p.nN, ∑ j : Fin p.nN, ∑ k : Fin p.nK, p.tc i j k * v.F i j k

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P20.a
