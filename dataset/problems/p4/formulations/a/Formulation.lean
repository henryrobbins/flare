import Common

namespace P4.a

structure Params where
  CarCapacity : ℤ  -- car capacity (employees per car)
  CarPollution : ℝ  -- car pollution
  BusCapacity : ℤ  -- bus capacity (employees per bus)
  BusPollution : ℝ  -- bus pollution
  MinEmployeesToTransport : ℝ  -- min employees to transport
  MaxBuses : ℝ  -- max buses allowed
  -- Implicit Assumptions
  hCarCapacity_nn : 0 ≤ CarCapacity
  hCarPollution_nn : 0 ≤ CarPollution
  hBusCapacity_nn : 0 ≤ BusCapacity
  hBusPollution_nn : 0 ≤ BusPollution
  hMinEmployeesToTransport_nn : 0 ≤ MinEmployeesToTransport
  hMaxBuses_nn : 0 ≤ MaxBuses

structure Vars where
  xCars : ℤ  -- number of cars used
  xBuses : ℤ  -- number of buses used

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Transport at least MinEmployeesToTransport employees
  htransport : p.MinEmployeesToTransport ≤ (v.xCars : ℝ) * (p.CarCapacity : ℝ) + (v.xBuses : ℝ) * (p.BusCapacity : ℝ)
  -- Use at most MaxBuses buses
  hmaxbus : (v.xBuses : ℝ) ≤ p.MaxBuses
  -- [Implicit Constraints]
  hcars_nn : 0 ≤ v.xCars
  hbus_nn : 0 ≤ v.xBuses

-- Minimize total pollution
def obj (p : Params) (v : Vars) : ℝ := (v.xCars : ℝ) * p.CarPollution + (v.xBuses : ℝ) * p.BusPollution

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.a
