import Common

namespace P5.a

structure Params where
  WaterSubsoil         : ℝ  -- water per bag of subsoil per day
  WaterTopsoil         : ℝ  -- water per bag of topsoil per day
  MaxTotalBags         : ℝ  -- max total bags (subsoil + topsoil)
  MinTopsoilBags       : ℝ  -- min topsoil bags
  MaxTopsoilProportion : ℝ  -- max topsoil proportion of all bags
  -- Implicit Assumptions
  hWaterSubsoil_nn         : 0 ≤ WaterSubsoil
  hWaterTopsoil_nn         : 0 ≤ WaterTopsoil
  hMaxTotalBags_nn         : 0 ≤ MaxTotalBags
  hMinTopsoilBags_nn       : 0 ≤ MinTopsoilBags
  hMaxTopsoilProportion_nn : 0 ≤ MaxTopsoilProportion

structure Vars where
  SubsoilBags : ℤ  -- number of subsoil bags
  TopsoilBags : ℤ  -- number of topsoil bags

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Total bags ≤ max
  htotal   : (v.SubsoilBags : ℝ) + v.TopsoilBags ≤ p.MaxTotalBags
  -- At least MinTopsoilBags topsoil bags
  hmin_top : p.MinTopsoilBags ≤ (v.TopsoilBags : ℝ)
  -- Topsoil proportion ≤ MaxTopsoilProportion
  hprop    : (v.TopsoilBags : ℝ) ≤ p.MaxTopsoilProportion * ((v.TopsoilBags : ℝ) + v.SubsoilBags)
  hss_nn   : 0 ≤ v.SubsoilBags
  hts_nn   : 0 ≤ v.TopsoilBags

-- Minimize total water required
def obj (p : Params) (v : Vars) : ℝ :=
  p.WaterSubsoil * (v.SubsoilBags : ℝ) + p.WaterTopsoil * v.TopsoilBags

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P5.a
