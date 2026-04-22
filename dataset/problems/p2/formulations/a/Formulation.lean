import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.Fa

-- m = NumExperiments, n = NumResources
structure Params (m n : ℕ) where
  ElectricityProduced : Fin m → ℝ           -- electricity produced by experiment i
  ResourceRequired    : Fin n → Fin m → ℝ  -- resource j required for experiment i
  ResourceAvailable   : Fin n → ℝ           -- resource j available
  -- Assumptions
  hE_nn : ∀ i, 0 ≤ ElectricityProduced i
  hR_nn : ∀ j i, 0 ≤ ResourceRequired j i
  hb_nn : ∀ j, 0 ≤ ResourceAvailable j

structure Vars (m : ℕ) where
  ConductExperiment : Fin m → ℝ  -- number of times experiment i is conducted

structure Feasible {m n : ℕ} [NeZero m] [NeZero n] (p : Params m n) (v : Vars m) : Prop where
  -- Resource j usage does not exceed available amount
  hres  : ∀ j, ∑ i, p.ResourceRequired j i * v.ConductExperiment i ≤ p.ResourceAvailable j
  hx_nn : ∀ i, 0 ≤ v.ConductExperiment i

-- Maximize total electricity produced
def obj {m n : ℕ} (p : Params m n) (v : Vars m) : ℝ :=
  -(∑ i, p.ElectricityProduced i * v.ConductExperiment i)

def formulation (m n : ℕ) [NeZero m] [NeZero n] : MILPFormulation where
  Params   := Params m n
  Vars     := Vars m
  feasible := Feasible
  obj      := obj

end P2.Fa
