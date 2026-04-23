import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.a

structure Params where
  NumExperiments : ℕ  -- number of experiments
  NumResources : ℕ  -- number of resource types
  ElectricityProduced : Fin NumExperiments → ℝ  -- amount of electricity produced by experiment i
  ResourceRequired : Fin NumResources → Fin NumExperiments → ℝ  -- amount of resource j required for experiment i
  ResourceAvailable : Fin NumResources → ℝ  -- amount of resource j available
  -- Implicit Assumptions
  hNumExperiments : NeZero NumExperiments
  hNumResources : NeZero NumResources
  hElectricityProduced_nn : ∀ i, 0 ≤ ElectricityProduced i
  hResourceRequired_nn : ∀ j i, 0 ≤ ResourceRequired j i
  hResourceAvailable_nn : ∀ j, 0 ≤ ResourceAvailable j

structure Vars where
  ConductExperiment : ℕ → ℤ  -- number of times each experiment is conducted

structure Feasible (p : Params) (v : Vars) : Prop where
  -- For each resource, total required across all experiments does not exceed available amount
  hres : ∀ j : Fin p.NumResources, ∑ i : Fin p.NumExperiments, p.ResourceRequired j i * (v.ConductExperiment i : ℝ) ≤ p.ResourceAvailable j
  -- [Implicit Constraints]
  hConductExperiment_nn : ∀ i : Fin p.NumExperiments, 0 ≤ v.ConductExperiment i

-- Maximize total electricity produced
def obj (p : Params) (v : Vars) : ℝ :=
  -(∑ i : Fin p.NumExperiments, p.ElectricityProduced i * (v.ConductExperiment i : ℝ))

def formulation : MILPFormulation where
  Params := Params
  Vars := Vars
  feasible := Feasible
  obj := obj

end P2.a
