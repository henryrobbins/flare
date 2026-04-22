import Common

namespace P1.a

structure Params where
  CashMachineProcessingRate : ℝ  -- cash machine processing rate (people/hour)
  CardMachineProcessingRate : ℝ  -- card machine processing rate (people/hour)
  CashMachinePaperRolls     : ℝ  -- paper rolls/hour for cash machine
  CardMachinePaperRolls     : ℝ  -- paper rolls/hour for card machine
  MinPeopleProcessed        : ℝ  -- min people processed per hour
  MaxPaperRolls             : ℝ  -- max paper rolls per hour

structure Vars where
  NumCashMachines : ℤ  -- number of cash machines
  NumCardMachines : ℤ  -- number of card machines

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Process at least MinPeopleProcessed people per hour
  hpeople : p.MinPeopleProcessed ≤ p.CashMachineProcessingRate * v.NumCashMachines + p.CardMachineProcessingRate * v.NumCardMachines
  -- Use at most MaxPaperRolls paper rolls per hour
  hpaper  : v.NumCashMachines * p.CashMachinePaperRolls + v.NumCardMachines * p.CardMachinePaperRolls ≤ p.MaxPaperRolls
  -- Card machines ≤ cash machines
  hcard   : v.NumCardMachines ≤ v.NumCashMachines
  hNumCashMachines_nn : 0 ≤ v.NumCashMachines
  hNumCardMachines_nn : 0 ≤ v.NumCardMachines

-- Minimize the total number of machines
def obj (_ : Params) (v : Vars) : ℝ := v.NumCashMachines + v.NumCardMachines

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.a
