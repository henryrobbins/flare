import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P3.a

structure Params where
  NumBeakers : ℕ  -- number of beakers
  FlourAvailable : ℝ  -- amount of flour available
  SpecialLiquidAvailable : ℝ  -- amount of special liquid available
  MaxWasteAllowed : ℝ  -- maximum amount of waste allowed
  FlourUsagePerBeaker : Fin NumBeakers → ℝ  -- amount of flour used by each beaker
  SpecialLiquidUsagePerBeaker : Fin NumBeakers → ℝ  -- amount of special liquid used by each beaker
  SlimeProducedPerBeaker : Fin NumBeakers → ℝ  -- amount of slime produced by each beaker
  WasteProducedPerBeaker : Fin NumBeakers → ℝ  -- amount of waste produced by each beaker
  -- Implicit Assumptions
  hNumBeakers : NeZero NumBeakers
  hFlour_nn : ∀ i, 0 ≤ FlourUsagePerBeaker i
  hLiquid_nn : ∀ i, 0 ≤ SpecialLiquidUsagePerBeaker i
  hSlime_nn : ∀ i, 0 ≤ SlimeProducedPerBeaker i
  hWaste_nn : ∀ i, 0 ≤ WasteProducedPerBeaker i

structure Vars where
  NumBeakersUsed : ℕ → ℤ  -- number of beakers of type i used

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Total flour used does not exceed available amount
  hflour  : ∑ i : Fin p.NumBeakers, p.FlourUsagePerBeaker i * (v.NumBeakersUsed i : ℝ) ≤ p.FlourAvailable
  -- Total special liquid used does not exceed available amount
  hliquid : ∑ i : Fin p.NumBeakers, p.SpecialLiquidUsagePerBeaker i * (v.NumBeakersUsed i : ℝ) ≤ p.SpecialLiquidAvailable
  -- Total waste produced does not exceed maximum allowed
  hwaste  : ∑ i : Fin p.NumBeakers, p.WasteProducedPerBeaker i * (v.NumBeakersUsed i : ℝ) ≤ p.MaxWasteAllowed
  -- [Implicit Constraints]
  hNumBeakersUsed_nn : ∀ i : Fin p.NumBeakers, 0 ≤ v.NumBeakersUsed i

-- Maximize total slime produced
def obj (p : Params) (v : Vars) : ℝ :=
  -(∑ i : Fin p.NumBeakers, p.SlimeProducedPerBeaker i * (v.NumBeakersUsed i : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P3.a
