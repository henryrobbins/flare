import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.Fg

-- Variable j represents 10× the original experiment count
structure Params (m n : ℕ) where
  A : Fin m → ℝ           -- electricity produced by experiment i
  I : Fin n → Fin m → ℝ  -- resource j required for experiment i
  Y : Fin n → ℝ           -- resource j available
  -- Assumptions
  hA_nn : ∀ i, 0 ≤ A i
  hY_nn : ∀ j, 0 ≤ Y j
  hI_nn : ∀ j i, 0 ≤ I j i

structure Vars (m : ℕ) where
  j : Fin m → ℝ  -- 10× number of times experiment i is conducted

structure Feasible {m n : ℕ} [NeZero m] [NeZero n] (p : Params m n) (v : Vars m) : Prop where
  -- Resource usage (using scaled variable) does not exceed available
  hres : ∀ i, ∑ k, p.I i k * (v.j k / 10) ≤ p.Y i
  hj_nn : ∀ i, 0 ≤ v.j i

-- Maximize total electricity produced (using scaled variable)
def obj {m n : ℕ} (p : Params m n) (v : Vars m) : ℝ :=
  -(∑ i, p.A i * (v.j i / 10))

def formulation (m n : ℕ) [NeZero m] [NeZero n] : MILPFormulation where
  Params   := Params m n
  Vars     := Vars m
  feasible := Feasible
  obj      := obj

end P2.Fg
