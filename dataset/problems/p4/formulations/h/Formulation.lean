import Common

namespace P4.h

structure Params where
  U : ℝ  -- time per runner trip (hours)
  C : ℝ  -- max total delivery hours
  V : ℝ  -- bags per runner trip
  N : ℝ  -- time per canoe trip (hours)
  Z : ℝ  -- bags per canoe trip
  E : ℝ  -- min runners required
  P : ℝ  -- max fraction of deliveries by canoe
  -- Implicit Assumptions
  hU_nn : 0 ≤ U
  hC_nn : 0 ≤ C
  hV_nn : 0 ≤ V
  hN_nn : 0 ≤ N
  hZ_nn : 0 ≤ Z
  hE_nn : 0 ≤ E
  hP_nn : 0 ≤ P

structure Vars (p : Params) where
  e : ℝ  -- number of runners used
  p : ℝ  -- number of canoe trips
  a : ℝ  -- number of runner trips

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Canoe deliveries ≤ fraction P of total deliveries
  hcanoe_frac : v.p * p.Z ≤ p.P * (v.p * p.Z + v.a * p.V)
  -- Total delivery time ≤ available
  htime : p.U * v.a + p.N * v.p ≤ p.C
  -- At least E runners required
  hmin_runners : p.E ≤ v.e
  -- [Implicit Constraints]
  he_nn : 0 ≤ v.e
  hp_nn : 0 ≤ v.p
  ha_nn : 0 ≤ v.a

-- Maximize total mail delivered
def obj (p : Params) (v : Vars p) : ℝ := -(v.a * p.V + v.p * p.Z)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.h
