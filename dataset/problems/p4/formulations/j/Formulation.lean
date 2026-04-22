import Common

namespace P4.j

-- Missing all constraints (invalid/incomplete formulation)
structure Params where
  K : ℝ  -- car capacity (employees per car)
  M : ℝ  -- car pollution
  D : ℝ  -- bus capacity (employees per bus)
  O : ℝ  -- bus pollution
  J : ℝ  -- min employees to transport
  S : ℝ  -- max buses allowed

structure Vars where
  m : ℤ  -- number of cars used
  h : ℤ  -- number of buses used

structure Feasible (_ : Params) (v : Vars) : Prop where
  -- No constraints (incomplete formulation)
  hm_nn : 0 ≤ v.m
  hh_nn : 0 ≤ v.h

-- Minimize total pollution
def obj (p : Params) (v : Vars) : ℝ := v.m * p.M + v.h * p.O

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.j
