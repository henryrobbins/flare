import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.b

structure Params where
  M : ℕ  -- number of trials
  N : ℕ  -- number of resource types
  A : Fin M → ℝ  -- electrical energy generated from trial i
  I : Fin N → Fin M → ℝ  -- resource j quantity needed for experiment i
  Y : Fin N → ℝ  -- quantity of resource j that is accessible
  -- Implicit Assumptions
  hM : NeZero M
  hN : NeZero N
  hA_nn : ∀ i, 0 ≤ A i
  hI_nn : ∀ j i, 0 ≤ I j i
  hY_nn : ∀ j, 0 ≤ Y j

structure Vars (p : Params) where
  j : Fin p.M → ℤ  -- frequency at which each experiment is performed

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- For each resource, total required across all experiments does not exceed available amount
  hres : ∀ k : Fin p.N, ∑ i : Fin p.M, p.I k i * (v.j i : ℝ) ≤ p.Y k
  -- [Implicit Constraints]
  hj_nn : ∀ i : Fin p.M, 0 ≤ v.j i

-- Maximize total electrical output
def obj (p : Params) (v : Vars p) : ℝ :=
  -(∑ i : Fin p.M, p.A i * (v.j i : ℝ))

def formulation : MILPFormulation where
  Params := Params
  Vars := Vars
  feasible := Feasible
  obj := obj

end P2.b
