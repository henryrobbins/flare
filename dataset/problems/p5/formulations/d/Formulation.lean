import Common

namespace P5.d

structure Params where
  Z : ℝ  -- water per bag of subsoil per day
  B : ℝ  -- water per bag of topsoil per day
  D : ℤ  -- max total bags (subsoil + topsoil)
  P : ℤ  -- min topsoil bags
  K : ℝ  -- max topsoil proportion of all bags
  -- Implicit Assumptions
  hZ_nn : 0 ≤ Z
  hB_nn : 0 ≤ B
  hD_nn : 0 ≤ D
  hP_nn : 0 ≤ P
  hK_nn : 0 ≤ K

structure Vars where
  h   : ℤ  -- number of subsoil bags
  d   : ℤ  -- number of topsoil bags
  zed : ℝ  -- auxiliary objective variable (= total water)

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Auxiliary variable equals total water required
  hzed     : v.zed = p.Z * (v.h : ℝ) + p.B * v.d
  -- Topsoil proportion ≤ K
  hprop    : (v.d : ℝ) ≤ p.K * ((v.d : ℝ) + v.h)
  -- Total bags ≤ max
  htotal   : (v.d : ℝ) + v.h ≤ (p.D : ℝ)
  -- At least P topsoil bags
  hmin_top : (p.P : ℝ) ≤ (v.d : ℝ)
  hh_nn : 0 ≤ v.h
  hd_nn : 0 ≤ v.d

-- Minimize auxiliary objective variable
def obj (_ : Params) (v : Vars) : ℝ := v.zed

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P5.d
