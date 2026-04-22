import Common

namespace P3.h

-- Different problem: glass pane production
structure Params where
  C : ℝ  -- heating time per regular pane
  S : ℝ  -- cooling time per regular pane
  P : ℝ  -- heating time per tempered pane
  L : ℝ  -- cooling time per tempered pane
  T : ℝ  -- profit per regular pane
  H : ℝ  -- profit per tempered pane
  D : ℝ  -- max heating machine time per day
  V : ℝ  -- max cooling machine time per day

structure Vars where
  e : ℝ  -- number of regular panes produced
  h : ℝ  -- number of tempered panes produced

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Total heating time does not exceed machine capacity
  hheating : p.C * v.e + p.P * v.h ≤ p.D
  -- Total cooling time does not exceed machine capacity
  hcooling : p.S * v.e + p.L * v.h ≤ p.V
  he_nn : 0 ≤ v.e
  hh_nn : 0 ≤ v.h

-- Maximize total profit
def obj (p : Params) (v : Vars) : ℝ := -(p.T * v.e + p.H * v.h)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P3.h
