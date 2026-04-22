import Common

namespace P5.j

structure Params where
  Z : ℝ  -- water per bag of subsoil per day
  B : ℝ  -- water per bag of topsoil per day
  D : ℝ  -- max total bags (subsoil + topsoil)
  P : ℝ  -- min topsoil bags
  K : ℝ  -- max topsoil proportion of all bags

structure Vars where
  h : ℤ  -- number of subsoil bags
  d : ℤ  -- number of topsoil bags

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Only topsoil proportion constraint retained
  hprop : v.d ≤ p.K * (v.d + v.h)
  hh_nn : 0 ≤ v.h
  hd_nn : 0 ≤ v.d

-- Minimize total water required
def obj (p : Params) (v : Vars) : ℝ := p.Z * v.h + p.B * v.d

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P5.j
