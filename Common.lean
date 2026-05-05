import Mathlib.Tactic
import Mathlib.Data.Real.Basic
import Mathlib.Order.Basic

structure MILPFormulation where
  Params   : Type
  Vars     : Type
  feasible : Params → Vars → Prop
  obj      : Params → Vars → ℝ

structure MILPReformulation (F G : MILPFormulation) where
  paramMap    : F.Params → G.Params
  fwd         : F.Params → F.Vars → G.Vars
  bwd         : F.Params → G.Vars → F.Vars
  fwd_feas    : ∀ p x, F.feasible p x → G.feasible (paramMap p) (fwd p x)
  bwd_feas    : ∀ p x', G.feasible (paramMap p) x' → F.feasible p (bwd p x')
  objMap      : ℝ → ℝ
  objMap_mono : StrictMono objMap
  fwd_obj     : ∀ p x, F.feasible p x →
                  G.obj (paramMap p) (fwd p x) = objMap (F.obj p x)
  bwd_obj     : ∀ p x', G.feasible (paramMap p) x' →
                  G.obj (paramMap p) x' = objMap (F.obj p (bwd p x'))
