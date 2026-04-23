import Common

namespace P4.c

structure Params where
  K : ℝ  -- car capacity (employees per car)
  M : ℝ  -- car pollution
  D : ℝ  -- bus capacity (employees per bus)
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

structure Vars where
  m_0 : ℤ  -- digit 0 of car count
  m_1 : ℤ  -- digit 1 of car count
  h_0 : ℤ  -- digit 0 of bus count
  h_1 : ℤ  -- digit 1 of bus count

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Use at most S buses
  hmaxbus : ((v.h_0 + 10 * v.h_1 : ℤ) : ℝ) ≤ p.S
  -- Transport at least J employees
  htransport : p.J ≤ ((v.m_0 + 10 * v.m_1 : ℤ) : ℝ) * p.K + ((v.h_0 + 10 * v.h_1 : ℤ) : ℝ) * p.D
  -- Digit bounds
  hm0_nn : 0 ≤ v.m_0
  hm1_nn : 0 ≤ v.m_1
  hh0_nn : 0 ≤ v.h_0
  hh1_nn : 0 ≤ v.h_1
  hm0_hi : v.m_0 ≤ 9
  hm1_hi : v.m_1 ≤ 9
  hh0_hi : v.h_0 ≤ 9
  hh1_hi : v.h_1 ≤ 9

-- Minimize total pollution
def obj (p : Params) (v : Vars) : ℝ :=
  ((v.m_0 + 10 * v.m_1 : ℤ) : ℝ) * p.M + ((v.h_0 + 10 * v.h_1 : ℤ) : ℝ) * p.O

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.c
