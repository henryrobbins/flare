import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P8.Fd

structure Params (nJ nM : ℕ) where
  p   : Fin nJ → Fin nM → ℝ
  Om  : Fin nM → Finset (Fin nJ × Fin nM)
  M   : ℝ
  hp_nn   : ∀ j k, 0 ≤ p j k
  hM_pos  : 0 < M
  hOm_ne  : ∀ m, (Om m).Nonempty

structure Vars (nJ nM : ℕ) where
  S    : Fin nJ → Fin nM → ℝ
  y    : Fin nJ → Fin nM → Fin nJ → Fin nM → ℤ
  Cmax : ℝ

-- Operations from other jobs assigned to the same machine as operation (j,k)
private def conflicting (Om : Fin nM → Finset (Fin nJ × Fin nM))
    (j : Fin nJ) (k : Fin nM) : Finset (Fin nJ × Fin nM) :=
  (Finset.univ.biUnion Om).filter (fun jk => jk.1 ≠ j ∧ ∃ m, (j, k) ∈ Om m ∧ jk ∈ Om m)

structure Feasible {nJ nM : ℕ} [NeZero nJ] [NeZero nM]
    (P : Params nJ nM) (v : Vars nJ nM) : Prop where
  hprec : ∀ j k, (h : k.val + 1 < nM) →
    v.S j ⟨k.val + 1, h⟩ ≥ v.S j k + P.p j k
  hoverlap_fwd : ∀ m, ∀ a ∈ P.Om m, ∀ b ∈ P.Om m, a ≠ b →
    v.S a.1 a.2 + P.p a.1 a.2 ≤ v.S b.1 b.2 + P.M * (1 - v.y a.1 a.2 b.1 b.2)
  hoverlap_bwd : ∀ m, ∀ a ∈ P.Om m, ∀ b ∈ P.Om m, a ≠ b →
    v.S b.1 b.2 + P.p b.1 b.2 ≤ v.S a.1 a.2 + P.M * v.y a.1 a.2 b.1 b.2
  hmakespan : ∀ j, v.Cmax ≥
    v.S j ⟨nM - 1, by have := NeZero.pos nM; omega⟩ +
    P.p j ⟨nM - 1, by have := NeZero.pos nM; omega⟩
  hS_nn  : ∀ j k, 0 ≤ v.S j k
  hy_bin : ∀ j1 k1 j2 k2, v.y j1 k1 j2 k2 = 0 ∨ v.y j1 k1 j2 k2 = 1
  -- EC3 (V1): Job Interference Bound
  -- For each job j and each choice of one conflicting op per operation of j,
  -- makespan ≥ total processing of j + sum of chosen conflicting ops
  -- (Universally quantifying over choices linearizes the per-operation min)
  hec3 : ∀ j : Fin nJ, ∀ sel : Fin nM → Fin nJ × Fin nM,
    (∀ k, sel k ∈ conflicting P.Om j k) →
    v.Cmax ≥ ∑ k : Fin nM, P.p j k
           + ∑ k : Fin nM, P.p (sel k).1 (sel k).2

def obj {nJ nM : ℕ} (_ : Params nJ nM) (v : Vars nJ nM) : ℝ := v.Cmax

def formulation (nJ nM : ℕ) [NeZero nJ] [NeZero nM] : MILPFormulation where
  Params   := Params nJ nM
  Vars     := Vars nJ nM
  feasible := Feasible
  obj      := obj

end P8.Fd
