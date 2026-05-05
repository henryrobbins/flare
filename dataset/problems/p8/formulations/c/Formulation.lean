import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic

open BigOperators Finset

namespace P8.c

structure Params where
  n : ℕ  -- number of jobs
  m : ℕ  -- number of machines
  p : Fin n → Fin m → ℝ       -- processing time of op k of job j
  Om : Fin n → Fin m → Fin m  -- machine index for op k of job j
  -- Implicit Assumptions
  hN : NeZero n
  hM : NeZero m
  hp_nn : ∀ j k, 0 ≤ p j k
  hOm_perm : ∀ j : Fin n, Function.Bijective (Om j)

structure Vars (p : Params) where
  S : Fin p.n → Fin p.m → ℝ  -- start time of op k of job j
  Cmax : ℝ        -- makespan

-- Operations assigned to machine i
private def machineOps (p : Params) (i : Fin p.m) : Finset (Fin p.n × Fin p.m) :=
  Finset.univ.filter (fun jk => p.Om jk.1 jk.2 = i)

private lemma machineOps_ne (p : Params) (i : Fin p.m) : (machineOps p i).Nonempty := by
  have hn : 0 < p.n := Nat.pos_of_ne_zero p.hN.out
  obtain ⟨k, hk⟩ := (p.hOm_perm ⟨0, hn⟩).2 i
  exact ⟨⟨⟨0, hn⟩, k⟩, Finset.mem_filter.mpr ⟨Finset.mem_univ _, hk⟩⟩

-- Head of operation (j,k): total processing time of earlier ops in job j
private def head {n m : ℕ} (p : Fin n → Fin m → ℝ) (j : Fin n) (k : Fin m) : ℝ :=
  ∑ t : Fin m, if t.val < k.val then p j t else 0

-- Tail of operation (j,k): total processing time of later ops in job j
private def tail {n m : ℕ} (p : Fin n → Fin m → ℝ) (j : Fin n) (k : Fin m) : ℝ :=
  ∑ t : Fin m, if k.val < t.val then p j t else 0

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Technological ordering: op k+1 starts after op k finishes
  hprec : ∀ j : Fin p.n, ∀ k : Fin p.m, (h : k.val + 1 < p.m) →
    v.S j ⟨k.val + 1, h⟩ ≥ v.S j k + p.p j k
  -- Machine non-overlap: two distinct ops on the same machine do not overlap
  -- (encodes Big-M machine non-overlap constraints, y elided)
  hoverlap : ∀ j1 : Fin p.n, ∀ k1 : Fin p.m, ∀ j2 : Fin p.n, ∀ k2 : Fin p.m,
    p.Om j1 k1 = p.Om j2 k2 → (j1, k1) ≠ (j2, k2) →
    v.S j1 k1 + p.p j1 k1 ≤ v.S j2 k2 ∨
    v.S j2 k2 + p.p j2 k2 ≤ v.S j1 k1
  -- Makespan bounds the completion of each job's last operation
  hmakespan : ∀ j : Fin p.n, v.Cmax ≥
    v.S j ⟨p.m - 1, by have := p.hM.out; omega⟩ + p.p j ⟨p.m - 1, by have := p.hM.out; omega⟩
  hS_nn : ∀ j : Fin p.n, ∀ k : Fin p.m, 0 ≤ v.S j k
  hCmax_nn : 0 ≤ v.Cmax
  -- EC2: for each machine, makespan ≥ machine load + min head + min tail over its ops
  hec2 : ∀ i : Fin p.m,
    v.Cmax ≥ (∑ jk ∈ machineOps p i, p.p jk.1 jk.2)
           + (machineOps p i).inf' (machineOps_ne p i) (fun a => head p.p a.1 a.2)
           + (machineOps p i).inf' (machineOps_ne p i) (fun b => tail p.p b.1 b.2)

-- Minimize the makespan
def obj (p : Params) (v : Vars p) : ℝ := v.Cmax

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P8.c
