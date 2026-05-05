import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.j

structure Params where
  M : ℕ  -- number of experiments
  N : ℕ  -- number of resource types
  A : Fin M → ℝ  -- electricity produced by experiment i
  I : Fin N → Fin M → ℝ  -- resource j required for experiment i
  Y : Fin N → ℝ  -- resource j available
  -- Assumptions
  hM : NeZero M
  hN : NeZero N
  -- Implicit Assumptions
  hA_nn : ∀ i, 0 ≤ A i
  hY_nn : ∀ j, 0 ≤ Y j
  hI_nn : ∀ j i, 0 ≤ I j i

structure Vars (p : Params) where
  j : Fin p.M → ℝ  -- number of times experiment i is conducted

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- For each resource, total required across all experiments does not exceed available amount
  hres : ∀ k : Fin p.N, ∑ i : Fin p.M, p.I k i * v.j i ≤ p.Y k
  -- [Implicit Constraints]
  hj_nn : ∀ i : Fin p.M, 0 ≤ v.j i

-- Maximize total electricity produced
def obj (p : Params) (v : Vars p) : ℝ :=
  -(∑ i : Fin p.M, p.A i * v.j i)

def formulation : MILPFormulation where
  Params := Params
  Vars := Vars
  feasible := Feasible
  obj := obj

end P2.j
