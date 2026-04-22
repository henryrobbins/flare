import Common

namespace P5.Ff

structure Params where
  Z : ℝ  -- water per bag of subsoil per day
  B : ℝ  -- water per bag of topsoil per day
  D : ℝ  -- max total bags (subsoil + topsoil)
  P : ℝ  -- min topsoil bags
  K : ℝ  -- max topsoil proportion of all bags

structure Vars where
  d1 : ℝ  -- part 1 of topsoil bag count
  d2 : ℝ  -- part 2 of topsoil bag count
  h1 : ℝ  -- part 1 of subsoil bag count
  h2 : ℝ  -- part 2 of subsoil bag count

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Topsoil proportion ≤ K
  hprop : v.d1 + v.d2 ≤ p.K * ((v.d1 + v.d2) + (v.h1 + v.h2))
  -- Total bags ≤ max
  htotal : (v.h1 + v.h2) + (v.d1 + v.d2) ≤ p.D
  -- At least P topsoil bags
  hmin_top : p.P ≤ v.d1 + v.d2
  hd1_nn : 0 ≤ v.d1
  hd2_nn : 0 ≤ v.d2
  hh1_nn : 0 ≤ v.h1
  hh2_nn : 0 ≤ v.h2

-- Minimize total water required
def obj (p : Params) (v : Vars) : ℝ :=
  p.Z * (v.h1 + v.h2) + p.B * (v.d1 + v.d2)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P5.Ff
