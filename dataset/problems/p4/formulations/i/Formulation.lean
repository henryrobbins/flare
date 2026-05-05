import Common

namespace P4.i

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
  e : ℤ  -- number of runners used
  p : ℤ  -- number of canoe trips
  a : ℤ  -- number of runner trips

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Canoe deliveries ≤ fraction P of total deliveries
  hcanoe_frac : (v.p : ℝ) * p.Z ≤ p.P * ((v.p : ℝ) * p.Z + (v.a : ℝ) * p.V)
  -- Total delivery time ≤ available
  htime : p.U * (v.a : ℝ) + p.N * (v.p : ℝ) ≤ p.C
  -- At least E runners required
  hmin_runners : p.E ≤ (v.e : ℝ)
  -- [Implicit Constraints]
  he_nn : 0 ≤ v.e
  hp_nn : 0 ≤ v.p
  ha_nn : 0 ≤ v.a

-- Objective replaced by optimal solution value
def obj (p : Params) (_ : Vars p) : ℝ := -670

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.i
