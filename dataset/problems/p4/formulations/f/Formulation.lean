import Common

namespace P4.Ff

structure Params where
  K : ℝ  -- car capacity (employees per car)
  M : ℝ  -- car pollution
  D : ℝ  -- bus capacity (employees per bus)
  O : ℝ  -- bus pollution
  J : ℝ  -- min employees to transport
  S : ℝ  -- max buses allowed

structure Vars where
  m1 : ℤ  -- part 1 of car count
  m2 : ℤ  -- part 2 of car count
  h1 : ℤ  -- part 1 of bus count
  h2 : ℤ  -- part 2 of bus count

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Use at most S buses
  hmaxbus : v.h1 + v.h2 ≤ p.S
  -- Transport at least J employees
  htransport : p.J ≤ (v.m1 + v.m2) * p.K + (v.h1 + v.h2) * p.D
  hm1_nn : 0 ≤ v.m1
  hm2_nn : 0 ≤ v.m2
  hh1_nn : 0 ≤ v.h1
  hh2_nn : 0 ≤ v.h2

-- Minimize total pollution
def obj (p : Params) (v : Vars) : ℝ := (v.m1 + v.m2) * p.M + (v.h1 + v.h2) * p.O

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.Ff
