import Common
import dataset.problems.p8.formulations.a.Formulation
import dataset.problems.p8.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P8

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P8.a.Params) : P8.b.Params :=
  { n          := p.n
    m          := p.m
    p          := p.p
    Om         := p.Om
    hN         := p.hN
    hM         := p.hM
    hp_nn      := p.hp_nn
    hOm_perm   := p.hOm_perm }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

section ForwardHelpers

variable {p : P8.a.Params} {v : P8.a.Vars p} (h : P8.a.Feasible p v)
include h

/-- For any operation (j, k), its completion time S j k + p j k is ≤ Cmax.
    Proof: chain precedence from k to m-1, then apply the makespan bound. -/
private lemma tail_le_Cmax (j : Fin p.n) (k : Fin p.m) :
    v.S j k + p.p j k ≤ v.Cmax := by
  haveI := p.hM
  have hm_pos : 0 < p.m := Nat.pos_of_ne_zero p.hM.out
  have key : ∀ q : ℕ, (hq : q < p.m) → k.val ≤ q →
      v.S j k + p.p j k ≤ v.S j ⟨q, hq⟩ + p.p j ⟨q, hq⟩ := by
    intro q hq hkq
    induction q with
    | zero =>
        have hkz : k.val = 0 := Nat.le_zero.mp hkq
        have : k = ⟨0, hq⟩ := Fin.ext hkz
        rw [this]
    | succ q' ih =>
        rcases Nat.lt_or_ge k.val (q' + 1) with hlt | hge
        · have hkq' : k.val ≤ q' := Nat.lt_succ_iff.mp hlt
          have hq'_lt : q' < p.m := Nat.lt_of_succ_lt hq
          have ih' := ih hq'_lt hkq'
          have hprec := h.hprec j ⟨q', hq'_lt⟩ hq
          have hp_nn := p.hp_nn j ⟨q' + 1, hq⟩
          linarith
        · have hkeq : k.val = q' + 1 := Nat.le_antisymm hkq hge
          have : k = ⟨q' + 1, hq⟩ := Fin.ext hkeq
          rw [this]
  have hmm1_lt : p.m - 1 < p.m := Nat.sub_lt hm_pos Nat.one_pos
  have hk_le : k.val ≤ p.m - 1 := by have := k.isLt; omega
  have := key (p.m - 1) hmm1_lt hk_le
  have hmax := h.hmakespan j
  linarith

/-- For a non-overlapping set T of ops, the total load is ≤ any upper bound
    on individual completion times (provided the bound is non-negative). -/
private lemma nonoverlap_sum_le_span :
    ∀ (T : Finset (Fin p.n × Fin p.m)),
      (∀ a ∈ T, ∀ b ∈ T, a ≠ b →
        v.S a.1 a.2 + p.p a.1 a.2 ≤ v.S b.1 b.2 ∨
        v.S b.1 b.2 + p.p b.1 b.2 ≤ v.S a.1 a.2) →
      ∀ M : ℝ, (∀ e ∈ T, v.S e.1 e.2 + p.p e.1 e.2 ≤ M) →
        0 ≤ M →
        (∑ e ∈ T, p.p e.1 e.2) ≤ M := by
  intro T
  induction T using Finset.strongInduction with
  | H T ih =>
    intro hno M hM_bound hM_nn
    by_cases hT : T.Nonempty
    · obtain ⟨e_star, he_star_mem, he_star_max⟩ :=
        T.exists_max_image (fun e => v.S e.1 e.2 + p.p e.1 e.2) hT
      have hC_star_le_M : v.S e_star.1 e_star.2 + p.p e_star.1 e_star.2 ≤ M :=
        hM_bound e_star he_star_mem
      set T' := T.erase e_star with hT'_def
      have hT'_sub : T' ⊂ T := Finset.erase_ssubset he_star_mem
      set A : Finset (Fin p.n × Fin p.m) :=
        T'.filter (fun e => v.S e.1 e.2 + p.p e.1 e.2 ≤ v.S e_star.1 e_star.2)
        with hA_def
      have hAsub_T' : A ⊆ T' := Finset.filter_subset _ _
      have hAsub_T : A ⊆ T := hAsub_T'.trans (Finset.erase_subset _ _)
      have hno_A : ∀ a ∈ A, ∀ b ∈ A, a ≠ b →
          v.S a.1 a.2 + p.p a.1 a.2 ≤ v.S b.1 b.2 ∨
          v.S b.1 b.2 + p.p b.1 b.2 ≤ v.S a.1 a.2 :=
        fun a ha b hb hab => hno a (hAsub_T ha) b (hAsub_T hb) hab
      have hbound_A : ∀ e ∈ A, v.S e.1 e.2 + p.p e.1 e.2 ≤ v.S e_star.1 e_star.2 :=
        fun e he => (Finset.mem_filter.mp he).2
      have hSstar_nn : 0 ≤ v.S e_star.1 e_star.2 := h.hS_nn e_star.1 e_star.2
      have hA_ssub : A ⊂ T := lt_of_le_of_lt (Finset.le_iff_subset.mpr hAsub_T') hT'_sub
      have hA_sum_bound : (∑ e ∈ A, p.p e.1 e.2) ≤ v.S e_star.1 e_star.2 :=
        ih A hA_ssub hno_A _ hbound_A hSstar_nn
      have hB_zero : ∀ e ∈ T' \ A, p.p e.1 e.2 = 0 := by
        intro e he
        rw [Finset.mem_sdiff, hA_def] at he
        obtain ⟨heT', hnotA⟩ := he
        rw [Finset.mem_filter] at hnotA
        push_neg at hnotA
        have hC_gt : v.S e_star.1 e_star.2 < v.S e.1 e.2 + p.p e.1 e.2 :=
          hnotA heT'
        have heT : e ∈ T := Finset.mem_of_mem_erase heT'
        have hne : e ≠ e_star := (Finset.mem_erase.mp heT').1
        have hover := hno e heT e_star he_star_mem hne
        have hC_e_le_star := he_star_max e heT
        have hp_nn_e := p.hp_nn e.1 e.2
        have hp_nn_star := p.hp_nn e_star.1 e_star.2
        rcases hover with hle | hle
        · exfalso; linarith
        · linarith
      have hB_sum_zero : (∑ e ∈ T' \ A, p.p e.1 e.2) = 0 :=
        Finset.sum_eq_zero (fun e he => hB_zero e he)
      have hT_split :
          (∑ e ∈ T, p.p e.1 e.2) =
            (∑ e ∈ A, p.p e.1 e.2) + (∑ e ∈ T' \ A, p.p e.1 e.2) + p.p e_star.1 e_star.2 := by
        have h1 : (∑ e ∈ T', p.p e.1 e.2) + p.p e_star.1 e_star.2 = (∑ e ∈ T, p.p e.1 e.2) := by
          rw [hT'_def]; exact Finset.sum_erase_add T _ he_star_mem
        have h2 : (∑ e ∈ T', p.p e.1 e.2) = (∑ e ∈ A, p.p e.1 e.2) + (∑ e ∈ T' \ A, p.p e.1 e.2) := by
          rw [← Finset.sum_sdiff hAsub_T', add_comm]
        linarith
      rw [hT_split, hB_sum_zero, add_zero]
      linarith
    · rw [Finset.not_nonempty_iff_eq_empty] at hT
      subst hT
      simp [hM_nn]

/-- The set of all ops assigned to machine i. -/
private def machineOps (p : P8.a.Params) (i : Fin p.m) : Finset (Fin p.n × Fin p.m) :=
  Finset.univ.filter (fun jk : Fin p.n × Fin p.m => p.Om jk.1 jk.2 = i)

/-- Machine load bound: for each machine i, the total processing load ≤ Cmax. -/
private lemma machine_load (i : Fin p.m) :
    (∑ e ∈ machineOps p i, p.p e.1 e.2) ≤ v.Cmax := by
  apply nonoverlap_sum_le_span h (machineOps p i)
  · -- Non-overlap: two distinct ops in machineOps i are non-overlapping
    intro a ha b hb hab
    simp only [machineOps, Finset.mem_filter, Finset.mem_univ, true_and] at ha hb
    -- ha : p.Om a.1 a.2 = i, hb : p.Om b.1 b.2 = i
    have hom : p.Om a.1 a.2 = p.Om b.1 b.2 := ha.trans hb.symm
    exact h.hoverlap a.1 a.2 b.1 b.2 hom (by
      intro heq
      apply hab
      ext <;> simp_all [Prod.ext_iff])
  · intro e _; exact tail_le_Cmax h e.1 e.2
  · exact h.hCmax_nn

end ForwardHelpers

/--
**P8.a → P8.b**: identity on variables. The new EC1 constraint `hec1` is
derived by summing machine load bounds over all machines and dividing by m.
-/
private def fwd (p : P8.a.Params) (v : P8.a.Vars p) : P8.b.Vars (paramMap p) :=
  { S    := v.S
    Cmax := v.Cmax }

private lemma fwd_feas (p : P8.a.Params) (v : P8.a.Vars p)
    (h : P8.a.Feasible p v) :
    P8.b.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hM
  have hm_pos : 0 < p.m := Nat.pos_of_ne_zero p.hM.out
  have hm_pos_r : (0 : ℝ) < (p.m : ℝ) := by exact_mod_cast hm_pos
  refine
    { hprec     := h.hprec
      hoverlap  := h.hoverlap
      hmakespan := h.hmakespan
      hS_nn     := h.hS_nn
      hCmax_nn  := h.hCmax_nn
      hec1      := ?_ }
  -- Goal: v.Cmax ≥ (∑ j, ∑ k, p.p j k) / (p.m : ℝ)
  -- Strategy:
  --   1. For each i, ∑ e ∈ machineOps i, p(e) ≤ Cmax (machine_load).
  --   2. Sum over i : Fin p.m to get ∑_i ∑_{machineOps i} p ≤ p.m * Cmax.
  --   3. ∑_i ∑_{machineOps i} p = ∑ j, ∑ k, p j k (partition via hOm_perm).
  --   4. Divide.
  -- Step 1+2:
  have hstep2 :
      (∑ i : Fin p.m, ∑ e ∈ machineOps p i, p.p e.1 e.2) ≤ (p.m : ℝ) * v.Cmax := by
    calc (∑ i : Fin p.m, ∑ e ∈ machineOps p i, p.p e.1 e.2)
        ≤ (∑ _i : Fin p.m, v.Cmax) := Finset.sum_le_sum (fun i _ => machine_load h i)
      _ = (p.m : ℝ) * v.Cmax := by
          rw [Finset.sum_const, Finset.card_univ, Fintype.card_fin]; ring
  -- Step 3: show ∑_i ∑_{machineOps i} p = ∑ j, ∑ k, p j k.
  -- Rewrite: ∑_i ∑_{(j,k) | Om j k = i} p j k = ∑_{j,k} p j k
  -- by "fiber decomposition": the fibers (Om j k = i) partition univ.
  have hpartition :
      (∑ i : Fin p.m, ∑ e ∈ machineOps p i, p.p e.1 e.2) =
        (∑ j : Fin p.n, ∑ k : Fin p.m, p.p j k) := by
    -- machineOps i = {e ∈ univ | Om e.1 e.2 = i}
    -- By Finset.sum_fiberwise: ∑ i, ∑_{e ∈ univ | g e = i} f e = ∑_{e ∈ univ} f e
    have hfib := Finset.sum_fiberwise (s := (univ : Finset (Fin p.n × Fin p.m)))
      (g := fun e => p.Om e.1 e.2) (f := fun e => p.p e.1 e.2)
    -- hfib : ∑ j, ∑_{e ∈ univ | Om e.1 e.2 = j} p e.1 e.2 = ∑ e ∈ univ, p e.1 e.2
    -- First convert machineOps to the filter form matching hfib
    simp only [machineOps]
    -- Goal: ∑ x, ∑ e with Om e.1 e.2 = x, p e.1 e.2 = ∑ j, ∑ k, p j k
    rw [hfib]
    -- Goal: ∑ e : Fin n × Fin m, p e.1 e.2 = ∑ j, ∑ k, p j k
    rw [Fintype.sum_prod_type]
  -- Step 4:
  rw [hpartition] at hstep2
  show v.Cmax ≥ (∑ j : Fin p.n, ∑ k : Fin p.m, p.p j k) / (p.m : ℝ)
  rw [ge_iff_le, div_le_iff₀ hm_pos_r]
  linarith

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**P8.b → P8.a**: identity on variables. Drop the `hec1` constraint.
-/
private def bwd (p : P8.a.Params) (v : P8.b.Vars (paramMap p)) : P8.a.Vars p :=
  { S    := v.S
    Cmax := v.Cmax }

private lemma bwd_feas (p : P8.a.Params) (v : P8.b.Vars (paramMap p))
    (h : P8.b.Feasible (paramMap p) v) :
    P8.a.Feasible p (bwd p v) :=
  { hprec     := h.hprec
    hoverlap  := h.hoverlap
    hmakespan := h.hmakespan
    hS_nn     := h.hS_nn
    hCmax_nn  := h.hCmax_nn }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

noncomputable def aBReformulation : MILPReformulation P8.a.formulation P8.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P8
