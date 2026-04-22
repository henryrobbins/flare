import Common

namespace P5.Fd

structure Params where
  Z : ℝ  -- water per bag of subsoil per day
  B : ℝ  -- water per bag of topsoil per day
  D : ℝ  -- max total bags (subsoil + topsoil)
  P : ℝ  -- min topsoil bags
  K : ℝ  -- max topsoil proportion of all bags

structure Vars where
  h   : ℝ  -- number of subsoil bags
  d   : ℝ  -- number of topsoil bags
  zed : ℝ  -- auxiliary objective variable (= total water)

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Auxiliary variable equals total water required
  hzed : v.zed = p.Z * v.h + p.B * v.d
  -- Topsoil proportion ≤ K
  hprop : v.d ≤ p.K * (v.d + v.h)
  -- Total bags ≤ max
  htotal : v.d + v.h ≤ p.D
  -- At least P topsoil bags
  hmin_top : p.P ≤ v.d
  hh_nn : 0 ≤ v.h
  hd_nn : 0 ≤ v.d

-- Minimize auxiliary objective variable
def obj (_ : Params) (v : Vars) : ℝ := v.zed

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P5.Fd
