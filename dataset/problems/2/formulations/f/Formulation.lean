import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.Ff

structure Params (m n : ℕ) where
  A : Fin m → ℝ           -- electricity produced by experiment i
  I : Fin n → Fin m → ℝ  -- resource j required for experiment i
  Y : Fin n → ℝ           -- resource j available
  -- Assumptions
  hA_nn : ∀ i, 0 ≤ A i
  hY_nn : ∀ j, 0 ≤ Y j
  hI_nn : ∀ j i, 0 ≤ I j i

structure Vars (m : ℕ) where
  j1 : Fin m → ℝ  -- part 1 of experiment count
  j2 : Fin m → ℝ  -- part 2 of experiment count

structure Feasible {m n : ℕ} [NeZero m] [NeZero n] (p : Params m n) (v : Vars m) : Prop where
  -- Resource usage does not exceed available
  hres : ∀ i, ∑ k, p.I i k * (v.j1 k + v.j2 k) ≤ p.Y i
  hj1_nn : ∀ i, 0 ≤ v.j1 i
  hj2_nn : ∀ i, 0 ≤ v.j2 i

-- Maximize total electricity produced
def obj {m n : ℕ} (p : Params m n) (v : Vars m) : ℝ :=
  -(∑ i, p.A i * (v.j1 i + v.j2 i))

def formulation (m n : ℕ) [NeZero m] [NeZero n] : MILPFormulation where
  Params   := Params m n
  Vars     := Vars m
  feasible := Feasible
  obj      := obj

end P2.Ff
