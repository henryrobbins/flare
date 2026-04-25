import Common
import dataset.problems.p8.formulations.a.Formulation
import dataset.problems.p8.formulations.d.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P8

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P8.a.Params) : P8.d.Params :=
  { n          := p.n
    m          := p.m
    p          := p.p
    Om         := p.Om
    hN         := p.hN
    hM         := p.hM
    hp_nn      := p.hp_nn
    hOm_perm   := p.hOm_perm }

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

/-- Extension of the processing-time row for job `j` from `Fin m` to `ℕ`:
    zero outside the valid range. -/
private noncomputable def pext (p : P8.a.Params) (j : Fin p.n) (i : ℕ) : ℝ :=
  if hi : i < p.m then p.p j ⟨i, hi⟩ else 0

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

section ForwardHelpers

variable {p : P8.a.Params} {v : P8.a.Vars} (h : P8.a.Feasible p v)
include h

/-- Telescoping: for every `n < p.m`, the start time of op `n` of job `j` is
    at least the sum of the processing times of the previous operations. -/
private lemma job_telescoping (j : Fin p.n) :
    ∀ n : ℕ, n < p.m →
      (∑ i ∈ range n, pext p j i) ≤ v.S j.val n := by
  intro n hn
  induction n with
  | zero =>
      -- ∑ over empty range = 0, and S j 0 ≥ 0 by hS_nn.
      simp
      have hm_pos : 0 < p.m := hn
      simpa using h.hS_nn j ⟨0, hm_pos⟩
  | succ k ih =>
      have hk_lt : k < p.m := Nat.lt_of_succ_lt hn
      have ih' := ih hk_lt
      -- precedence for k : Fin p.m with k.val+1 < p.m
      have hprec := h.hprec j ⟨k, hk_lt⟩ hn
      -- ∑ i ∈ range (k+1), pext = ∑ i ∈ range k, pext + pext k
      have hsplit :
          (∑ i ∈ range (k + 1), pext p j i)
            = (∑ i ∈ range k, pext p j i) + pext p j k := by
        rw [Finset.sum_range_succ]
      have hpext_k : pext p j k = p.p j ⟨k, hk_lt⟩ := by
        unfold pext; simp [hk_lt]
      rw [hsplit, hpext_k]
      -- From ih': (∑ range k, pext) ≤ S j k
      -- From hprec: S j k + p j ⟨k,_⟩ ≤ S j (k+1)
      linarith

/-- The EC3 "Longest Job Bound": the makespan is at least the total processing
    time of any single job's operation chain. -/
private lemma hec3_proof (j : Fin p.n) :
    v.Cmax ≥ ∑ k : Fin p.m, p.p j k := by
  haveI := p.hM
  have hm_pos : 0 < p.m := Nat.pos_of_ne_zero p.hM.out
  -- Use telescoping at n = p.m - 1.
  have hmm1_lt : p.m - 1 < p.m := Nat.sub_lt hm_pos Nat.one_pos
  have htele := job_telescoping h j (p.m - 1) hmm1_lt
  -- Makespan bound
  have hmax := h.hmakespan j
  -- p.p j ⟨p.m-1, _⟩ = pext j (p.m-1)
  have hpext_last : pext p j (p.m - 1) = p.p j ⟨p.m - 1, hmm1_lt⟩ := by
    unfold pext; simp [hmm1_lt]
  -- Sum identity: ∑ k : Fin p.m, p.p j k = ∑ i ∈ range p.m, pext p j i
  have hsum_eq :
      (∑ k : Fin p.m, p.p j k) = ∑ i ∈ range p.m, pext p j i := by
    rw [← Fin.sum_univ_eq_sum_range (fun i => pext p j i) p.m]
    apply Finset.sum_congr rfl
    intro k _
    unfold pext; simp [k.isLt]
  -- Rewrite ∑ range p.m as ∑ range (p.m-1) + pext (p.m-1)
  have hrange_succ : p.m = (p.m - 1) + 1 := by omega
  have hsum_split :
      (∑ i ∈ range p.m, pext p j i)
        = (∑ i ∈ range (p.m - 1), pext p j i) + pext p j (p.m - 1) := by
    conv_lhs => rw [hrange_succ]
    rw [Finset.sum_range_succ]
  rw [hsum_eq, hsum_split, hpext_last]
  -- Now: ∑ range (p.m - 1) + p.p j ⟨p.m-1,_⟩ ≤ v.Cmax
  -- htele: ∑ range (p.m - 1) ≤ v.S j.val (p.m - 1)
  -- hmax: v.Cmax ≥ v.S j.val (p.m - 1) + p.p j ⟨p.m - 1, _⟩
  linarith

end ForwardHelpers

/--
**P8.a → P8.d**: identity on variables. The new EC3 constraint `hec3` is
derived from the telescoping of precedence plus the makespan bound.
-/
private def fwd (_ : P8.a.Params) (v : P8.a.Vars) : P8.d.Vars :=
  { S    := v.S
    Cmax := v.Cmax }

private lemma fwd_feas (p : P8.a.Params) (v : P8.a.Vars)
    (h : P8.a.Feasible p v) :
    P8.d.Feasible (paramMap p) (fwd p v) := by
  exact
    { hprec     := h.hprec
      hoverlap  := h.hoverlap
      hmakespan := h.hmakespan
      hS_nn     := h.hS_nn
      hCmax_nn  := h.hCmax_nn
      hec3      := hec3_proof h }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**P8.d → P8.a**: identity on variables. Drop the `hec3` constraint.
-/
private def bwd (_ : P8.a.Params) (v : P8.d.Vars) : P8.a.Vars :=
  { S    := v.S
    Cmax := v.Cmax }

private lemma bwd_feas (p : P8.a.Params) (v : P8.d.Vars)
    (h : P8.d.Feasible (paramMap p) v) :
    P8.a.Feasible p (bwd p v) := by
  exact
    { hprec     := h.hprec
      hoverlap  := h.hoverlap
      hmakespan := h.hmakespan
      hS_nn     := h.hS_nn
      hCmax_nn  := h.hCmax_nn }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

noncomputable def aDEquiv : MILPEquiv P8.a.formulation P8.d.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := Or.inl strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P8
