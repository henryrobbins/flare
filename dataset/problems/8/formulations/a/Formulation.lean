import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P8.Fa

structure Params (nJ nM : ℕ) where
  p   : Fin nJ → Fin nM → ℝ               -- processing time of op k of job j
  Om  : Fin nM → Finset (Fin nJ × Fin nM) -- ops assigned to each machine
  M   : ℝ                                  -- big-M constant
  hp_nn   : ∀ j k, 0 ≤ p j k
  hM_pos  : 0 < M
  hOm_ne  : ∀ m, (Om m).Nonempty

structure Vars (nJ nM : ℕ) where
  S    : Fin nJ → Fin nM → ℝ              -- start time of op k of job j
  y    : Fin nJ → Fin nM → Fin nJ → Fin nM → ℤ  -- 1 if (j1,k1) precedes (j2,k2)
  Cmax : ℝ                                 -- makespan

structure Feasible {nJ nM : ℕ} [NeZero nJ] [NeZero nM]
    (P : Params nJ nM) (v : Vars nJ nM) : Prop where
  -- Technological ordering: op k+1 starts after op k finishes
  hprec : ∀ j k, (h : k.val + 1 < nM) →
    v.S j ⟨k.val + 1, h⟩ ≥ v.S j k + P.p j k
  -- Machine non-overlap (forward): if y=1, (j1,k1) precedes (j2,k2)
  hoverlap_fwd : ∀ m, ∀ a ∈ P.Om m, ∀ b ∈ P.Om m, a ≠ b →
    v.S a.1 a.2 + P.p a.1 a.2 ≤ v.S b.1 b.2 + P.M * (1 - v.y a.1 a.2 b.1 b.2)
  -- Machine non-overlap (reverse): if y=0, (j2,k2) precedes (j1,k1)
  hoverlap_bwd : ∀ m, ∀ a ∈ P.Om m, ∀ b ∈ P.Om m, a ≠ b →
    v.S b.1 b.2 + P.p b.1 b.2 ≤ v.S a.1 a.2 + P.M * v.y a.1 a.2 b.1 b.2
  -- Makespan bounds the completion of each job's last operation
  hmakespan : ∀ j, v.Cmax ≥
    v.S j ⟨nM - 1, by have := NeZero.pos nM; omega⟩ +
    P.p j ⟨nM - 1, by have := NeZero.pos nM; omega⟩
  hS_nn  : ∀ j k, 0 ≤ v.S j k
  hy_bin : ∀ j1 k1 j2 k2, v.y j1 k1 j2 k2 = 0 ∨ v.y j1 k1 j2 k2 = 1

-- Minimize the makespan
def obj {nJ nM : ℕ} (_ : Params nJ nM) (v : Vars nJ nM) : ℝ := v.Cmax

def formulation (nJ nM : ℕ) [NeZero nJ] [NeZero nM] : MILPFormulation where
  Params   := Params nJ nM
  Vars     := Vars nJ nM
  feasible := Feasible
  obj      := obj

end P8.Fa
