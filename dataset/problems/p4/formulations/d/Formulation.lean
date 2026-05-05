import Common

namespace P4.d

structure Params where
  K : ℤ  -- car capacity (employees per car)
  M : ℝ  -- car pollution
  D : ℤ  -- bus capacity (employees per bus)
  O : ℝ  -- bus pollution
  J : ℝ  -- min employees to transport
  S : ℝ  -- max buses allowed
  -- Implicit Assumptions
  hK_nn : 0 ≤ K
  hM_nn : 0 ≤ M
  hD_nn : 0 ≤ D
  hO_nn : 0 ≤ O
  hJ_nn : 0 ≤ J
  hS_nn : 0 ≤ S

structure Vars (p : Params) where
  m : ℤ  -- number of cars used
  h : ℤ  -- number of buses used
  zed : ℝ  -- auxiliary objective variable (= total pollution)

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Auxiliary variable equals total pollution
  hzed : v.zed = (v.m : ℝ) * p.M + (v.h : ℝ) * p.O
  -- Use at most S buses
  hmaxbus : (v.h : ℝ) ≤ p.S
  -- Transport at least J employees
  htransport : p.J ≤ (v.m : ℝ) * (p.K : ℝ) + (v.h : ℝ) * (p.D : ℝ)
  -- [Implicit Constraints]
  hm_nn : 0 ≤ v.m
  hh_nn : 0 ≤ v.h

-- Minimize auxiliary objective variable
def obj (p : Params) (v : Vars p) : ℝ := v.zed

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.d
