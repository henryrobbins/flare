import Common

namespace P4.Fe

structure Params where
  K : ℝ  -- car capacity (employees per car)
  M : ℝ  -- car pollution
  D : ℝ  -- bus capacity (employees per bus)
  O : ℝ  -- bus pollution
  J : ℝ  -- min employees to transport
  S : ℝ  -- max buses allowed

structure Vars where
  m       : ℝ  -- number of cars used
  h       : ℝ  -- number of buses used
  slack_0 : ℝ  -- slack for employee transport constraint

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Transport equality with slack (slack_0 ≥ 0 makes original ≥ constraint)
  htransport : v.m * p.K + v.h * p.D - v.slack_0 = p.J
  hm_nn : 0 ≤ v.m
  hh_nn : 0 ≤ v.h
  -- [Implicit Constraints]
  -- Slack non-negativity
  hslack0_nn : 0 ≤ v.slack_0

-- Minimize total pollution
def obj (p : Params) (v : Vars) : ℝ := v.m * p.M + v.h * p.O

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.Fe
