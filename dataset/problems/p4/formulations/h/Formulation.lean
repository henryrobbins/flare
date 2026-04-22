import Common

namespace P4.h

-- Different problem: mail delivery by runners and canoeers
structure Params where
  U : ℝ  -- time per runner trip (hours)
  C : ℝ  -- max total delivery hours
  V : ℝ  -- bags per runner trip
  N : ℝ  -- time per canoe trip (hours)
  Z : ℝ  -- bags per canoe trip
  E : ℝ  -- min runners required
  P : ℝ  -- max fraction of deliveries by canoe

structure Vars where
  e : ℝ  -- number of runners used
  p : ℝ  -- number of canoe trips
  a : ℝ  -- number of runner trips

structure Feasible (p_params : Params) (v : Vars) : Prop where
  -- Canoe deliveries ≤ fraction P of total deliveries
  hcanoe_frac : v.p * p_params.Z ≤ p_params.P * (v.p * p_params.Z + v.a * p_params.V)
  -- Total delivery time ≤ available
  htime : p_params.U * v.a + p_params.N * v.p ≤ p_params.C
  -- At least E runners required
  hmin_runners : p_params.E ≤ v.e
  he_nn : 0 ≤ v.e
  hp_nn : 0 ≤ v.p
  ha_nn : 0 ≤ v.a

-- Maximize total mail delivered
def obj (p : Params) (v : Vars) : ℝ := -(v.a * p.V + v.p * p.Z)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.h
