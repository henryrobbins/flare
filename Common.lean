import Mathlib.Tactic
import Mathlib.Data.Real.Basic
import Mathlib.Order.Basic

structure MILPFormulation where
  Params   : Type
  Vars     : Type
  feasible : Params → Vars → Prop
  obj      : Params → Vars → ℝ

structure MILPEquiv (F G : MILPFormulation) where
  paramMap    : F.Params → G.Params
  fwd         : F.Params → F.Vars → G.Vars
  bwd         : F.Params → G.Vars → F.Vars
  fwd_feas    : ∀ p v, F.feasible p v → G.feasible (paramMap p) (fwd p v)
  bwd_feas    : ∀ p v, G.feasible (paramMap p) v → F.feasible p (bwd p v)
  objMap      : ℝ → ℝ
  objMap_mono : StrictMono objMap ∨ StrictAnti objMap
  fwd_obj     : ∀ p v, F.feasible p v →
                  G.obj (paramMap p) (fwd p v) = objMap (F.obj p v)
  bwd_obj     : ∀ p v, G.feasible (paramMap p) v →
                  G.obj (paramMap p) v = objMap (F.obj p (bwd p v))
