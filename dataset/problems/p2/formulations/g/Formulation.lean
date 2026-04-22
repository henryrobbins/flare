import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.g

-- Variable j represents 10× the original experiment count
structure Params where
  m : ℕ  -- number of experiments
  n : ℕ  -- number of resource types
  A : Fin m → ℝ           -- electricity produced by experiment i
  I : Fin n → Fin m → ℝ  -- resource j required for experiment i
  Y : Fin n → ℝ           -- resource j available
  -- Implicit Assumptions
  hm : NeZero m
  hn : NeZero n
  hA_nn : ∀ i, 0 ≤ A i
  hY_nn : ∀ j, 0 ≤ Y j
  hI_nn : ∀ j i, 0 ≤ I j i

structure Vars where
  j : ℕ → ℤ  -- 10× number of times experiment i is conducted

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Resource usage (using scaled variable) does not exceed available
  hres  : ∀ k : Fin p.n, ∑ i : Fin p.m, p.I k i * ((v.j i : ℝ) / 10) ≤ p.Y k
  hj_nn : ∀ i : Fin p.m, 0 ≤ v.j i
  -- Each j value is a multiple of 10 (j = 10 × experiment count)
  hdiv  : ∀ i : Fin p.m, 10 ∣ v.j i

-- Maximize total electricity produced (using scaled variable)
noncomputable def obj (p : Params) (v : Vars) : ℝ :=
  -(∑ i : Fin p.m, p.A i * ((v.j i : ℝ) / 10))

noncomputable def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P2.g
