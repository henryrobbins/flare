import Common

namespace P4.d

structure Params where
  K : ℝ  -- car capacity (employees per car)
  M : ℝ  -- car pollution
  D : ℝ  -- bus capacity (employees per bus)
  O : ℝ  -- bus pollution
  J : ℝ  -- min employees to transport
  S : ℝ  -- max buses allowed

structure Vars where
  m   : ℤ  -- number of cars used
  h   : ℤ  -- number of buses used
  zed : ℝ  -- auxiliary objective variable (= total pollution)

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Auxiliary variable equals total pollution
  hzed : v.zed = v.m * p.M + v.h * p.O
  -- Use at most S buses
  hmaxbus : v.h ≤ p.S
  -- Transport at least J employees
  htransport : p.J ≤ v.m * p.K + v.h * p.D
  hm_nn : 0 ≤ v.m
  hh_nn : 0 ≤ v.h

-- Minimize auxiliary objective variable
def obj (_ : Params) (v : Vars) : ℝ := v.zed

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.d
