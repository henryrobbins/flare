import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.c

structure Params where
  M : ℕ  -- number of experiments
  N : ℕ  -- number of resource types
  A : Fin M → ℝ  -- electricity produced by experiment i
  I : Fin N → Fin M → ℝ  -- resource j required for experiment i
  Y : Fin N → ℝ  -- resource j available
  -- Implicit Assumptions
  hM : NeZero M
  hN : NeZero N
  hA_nn : ∀ i, 0 ≤ A i
  hY_nn : ∀ j, 0 ≤ Y j
  hI_nn : ∀ j i, 0 ≤ I j i

structure Vars where
  j_0 : ℕ → ℤ  -- digit 0 of the frequency at which each experiment is performed
  j_1 : ℕ → ℤ  -- digit 1 of the frequency at which each experiment is performed

structure Feasible (p : Params) (v : Vars) : Prop where
  -- For each resource, total required does not exceed available
  hres : ∀ k : Fin p.N, ∑ i : Fin p.M, p.I k i * ((v.j_0 i : ℝ) + 10 * (v.j_1 i : ℝ)) ≤ p.Y k
  -- Digit bounds
  hj0_hi : ∀ i : Fin p.M, v.j_0 i ≤ 9
  hj1_hi : ∀ i : Fin p.M, v.j_1 i ≤ 9
  -- [Implicit Constraints]
  hj0_nn : ∀ i : Fin p.M, 0 ≤ v.j_0 i
  hj1_nn : ∀ i : Fin p.M, 0 ≤ v.j_1 i

-- Maximize total electricity produced
def obj (p : Params) (v : Vars) : ℝ :=
  -(∑ i : Fin p.M, p.A i * ((v.j_0 i : ℝ) + 10 * (v.j_1 i : ℝ)))

def formulation : MILPFormulation where
  Params := Params
  Vars := Vars
  feasible := Feasible
  obj := obj

end P2.c
