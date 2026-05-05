import Mathlib.Tactic
import Mathlib.Data.Real.Basic
import Mathlib.Order.Basic

structure MILPFormulation where
  Params   : Type
  Vars     : Params → Type
  feasible : (p : Params) → Vars p → Prop
  obj      : (p : Params) → Vars p → ℝ

structure MILPReformulation (F G : MILPFormulation) where
  paramMap    : F.Params → G.Params
  fwd         : (p : F.Params) → F.Vars p → G.Vars (paramMap p)
  bwd         : (p : F.Params) → G.Vars (paramMap p) → F.Vars p
  fwd_feas    : ∀ p x, F.feasible p x → G.feasible (paramMap p) (fwd p x)
  bwd_feas    : ∀ p x', G.feasible (paramMap p) x' → F.feasible p (bwd p x')
  objMap      : ℝ → ℝ
  objMap_mono : StrictMono objMap
  fwd_obj     : ∀ p x, F.feasible p x →
                  G.obj (paramMap p) (fwd p x) = objMap (F.obj p x)
  bwd_obj     : ∀ p x', G.feasible (paramMap p) x' →
                  G.obj (paramMap p) x' = objMap (F.obj p (bwd p x'))
