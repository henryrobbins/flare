import Common

namespace P5.i

-- Different problem: wine bottle production (objective replaced by solution value)
structure Params where
  Q : ℝ  -- min vintage bottles to produce
  D : ℝ  -- volume of one vintage bottle (ml)
  O : ℝ  -- min ratio of regular to vintage bottles
  J : ℝ  -- volume of one regular bottle (ml)
  A : ℝ  -- total wine available (ml)

structure Vars where
  z : ℝ  -- number of regular bottles produced
  g : ℝ  -- number of vintage bottles produced

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Regular bottles ≥ O times vintage bottles
  hratio : p.O * v.g ≤ v.z
  -- At least Q vintage bottles
  hmin_vintage : p.Q ≤ v.g
  -- Total wine usage ≤ available
  hwine : p.D * v.g + p.J * v.z ≤ p.A
  hz_nn : 0 ≤ v.z
  hg_nn : 0 ≤ v.g

-- Objective replaced by constant solution value 300.0
def obj (_ : Params) (_ : Vars) : ℝ := -300

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P5.i
