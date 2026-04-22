import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P3.Ff

structure Params (n : ℕ) where
  D : ℝ           -- flour available
  Z : ℝ           -- special liquid available
  E : ℝ           -- max waste allowed
  T : Fin n → ℝ  -- flour usage per beaker (not used in constraints)
  V : Fin n → ℝ  -- special liquid usage rate per beaker
  X : Fin n → ℝ  -- slime produced per beaker
  C : Fin n → ℝ  -- waste produced per beaker
  -- Assumptions
  hV_nn : ∀ i, 0 ≤ V i
  hX_nn : ∀ i, 0 ≤ X i
  hC_nn : ∀ i, 0 ≤ C i

structure Vars (n : ℕ) where
  n1 : Fin n → ℝ  -- part 1 of flour used by beaker type i
  n2 : Fin n → ℝ  -- part 2 of flour used by beaker type i

structure Feasible {n : ℕ} [NeZero n] (p : Params n) (v : Vars n) : Prop where
  -- Total liquid used ≤ available
  hliquid : ∑ i, p.V i * (v.n1 i + v.n2 i) ≤ p.Z
  -- Total flour used ≤ available
  hflour : ∑ i, (v.n1 i + v.n2 i) ≤ p.D
  -- Total waste ≤ allowed
  hwaste : ∑ i, p.C i * (v.n1 i + v.n2 i) ≤ p.E
  hn1_nn : ∀ i, 0 ≤ v.n1 i
  hn2_nn : ∀ i, 0 ≤ v.n2 i

-- Maximize total slime produced
def obj {n : ℕ} (p : Params n) (v : Vars n) : ℝ :=
  -(∑ i, p.X i * (v.n1 i + v.n2 i))

def formulation (n : ℕ) [NeZero n] : MILPFormulation where
  Params   := Params n
  Vars     := Vars n
  feasible := Feasible
  obj      := obj

end P3.Ff
