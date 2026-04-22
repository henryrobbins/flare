import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.Fd

structure Params (m n : ℕ) where
  A : Fin m → ℝ           -- electricity produced by experiment i
  I : Fin n → Fin m → ℝ  -- resource j required for experiment i
  Y : Fin n → ℝ           -- resource j available
  -- Assumptions
  hA_nn : ∀ i, 0 ≤ A i
  hY_nn : ∀ j, 0 ≤ Y j
  hI_nn : ∀ j i, 0 ≤ I j i

structure Vars (m : ℕ) where
  j   : Fin m → ℝ  -- number of times experiment i is conducted
  zed : ℝ          -- auxiliary objective variable (= total electricity)

structure Feasible {m n : ℕ} [NeZero m] [NeZero n] (p : Params m n) (v : Vars m) : Prop where
  -- Auxiliary variable equals total electricity produced
  hzed : v.zed = ∑ i, p.A i * v.j i
  -- Resource usage does not exceed available
  hres : ∀ i, ∑ k, p.I i k * v.j k ≤ p.Y i
  hj_nn : ∀ i, 0 ≤ v.j i

-- Maximize total electricity (minimized negation)
def obj (_ : Params m n) (v : Vars m) : ℝ := -v.zed

def formulation (m n : ℕ) [NeZero m] [NeZero n] : MILPFormulation where
  Params   := Params m n
  Vars     := Vars m
  feasible := Feasible
  obj      := obj

end P2.Fd
