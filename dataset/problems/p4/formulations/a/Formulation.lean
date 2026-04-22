import Common

namespace P4.Fa

structure Params where
  CarCapacity             : ℝ  -- car capacity (employees per car)
  CarPollution            : ℝ  -- car pollution
  BusCapacity             : ℝ  -- bus capacity (employees per bus)
  BusPollution            : ℝ  -- bus pollution
  MinEmployeesToTransport : ℝ  -- min employees to transport
  MaxBuses                : ℝ  -- max buses allowed

structure Vars where
  xCars  : ℤ  -- number of cars used
  xBuses : ℤ  -- number of buses used

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Transport at least MinEmployeesToTransport employees
  htransport : p.MinEmployeesToTransport ≤ v.xCars * p.CarCapacity + v.xBuses * p.BusCapacity
  -- Use at most MaxBuses buses
  hmaxbus    : v.xBuses ≤ p.MaxBuses
  hcars_nn   : 0 ≤ v.xCars
  hbus_nn    : 0 ≤ v.xBuses

-- Minimize total pollution
def obj (p : Params) (v : Vars) : ℝ := v.xCars * p.CarPollution + v.xBuses * p.BusPollution

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.Fa
