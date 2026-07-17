import Common
import problems.p13.formulations.a.Formulation
import problems.p13.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P13

/-!
# P13: aggregate ↔ per-plane reformulation (b → a direction)

This file proves that the aggregate formulation `P13.b.formulation`
(variables `n`, `f` counting flights per location and per arc) is a
`MILPReformulation` of the per-plane formulation `P13.a.formulation`
(binary `y`, `z` per individual plane).

Because the P13 transition graph is layered in time, no general graph
flow-decomposition theorem is needed: the forward map is built by
induction over the time layers. The key ingredients are:

* `exists_pick_on` — prescribed-size partition of a finite set (Lemma A).
* `layer_base` — placement of the planes at the initial time layer.
* `layer_step` — the single-layer inductive step that routes the planes at
  each location among the outgoing arcs and re-establishes the node counts
  at the next layer via flow conservation.
* `LayerDecomp` / `build_layers` — the full layered induction assembling a
  per-plane routing from a feasible aggregate solution.
* `bwd` / `fwd` — the backward (aggregate-by-summing) and forward
  (expand-via-decomposition) maps, with their feasibility and objective
  preservation proofs.

The final `MILPReformulation` instance is `p13_b_a_reformulation`.
-/

-- ============================================================================
-- § Lemma A: prescribed-size partition of a finite set
-- ============================================================================

/-- **Single-location routing (prescribed-size partition).**
Given a finite index set (via a `Finset s`) and target sizes
`sz : Fin m → ℕ` whose total does not exceed `s.card`, there is a choice
function `pick` assigning each element an optional target, so that exactly
`sz k` elements are assigned to each target `k` and unassigned elements lie
outside `s`. This is the heart of "route the flights at one location into
the outgoing arcs (the leftover takes no arc)." -/
lemma exists_pick_on {ι : Type*} [DecidableEq ι] :
    ∀ (m : ℕ) (sz : Fin m → ℕ) (s : Finset ι),
      (∑ k, sz k) ≤ s.card →
      ∃ pick : ι → Option (Fin m),
        (∀ i, pick i ≠ none → i ∈ s) ∧
        (∀ k, (s.filter (fun i => pick i = some k)).card = sz k) := by
  intro m
  induction m with
  | zero =>
    intro sz s _
    refine ⟨fun _ => none, ?_, ?_⟩
    · intro i h; exact absurd rfl h
    · intro k; exact Fin.elim0 k
  | succ m ih =>
    intro sz s hsum
    rw [Fin.sum_univ_castSucc] at hsum
    have hlast : sz (Fin.last m) ≤ s.card := by omega
    obtain ⟨t, hts, htcard⟩ := Finset.exists_subset_card_eq hlast
    set s' := s \ t with hs'
    have hs'card : (∑ k : Fin m, sz (Fin.castSucc k)) ≤ s'.card := by
      rw [hs', Finset.card_sdiff_of_subset hts, htcard]
      omega
    obtain ⟨pick', hpick'sub, hpick'card⟩ := ih (fun k => sz (Fin.castSucc k)) s' hs'card
    refine ⟨fun i => if i ∈ t then some (Fin.last m) else (pick' i).map Fin.castSucc, ?_, ?_⟩
    · intro i hne
      by_cases hi : i ∈ t
      · exact hts hi
      · simp only [hi, if_false] at hne
        have hp : pick' i ≠ none := by
          intro hc; rw [hc] at hne; simp at hne
        have hmem := hpick'sub i hp
        rw [hs'] at hmem
        exact (Finset.mem_sdiff.mp hmem).1
    · intro k
      refine Fin.lastCases ?_ ?_ k
      · have hfilt : (s.filter (fun i => (if i ∈ t then some (Fin.last m)
            else (pick' i).map Fin.castSucc) = some (Fin.last m))) = t := by
          apply Finset.ext
          intro i
          simp only [Finset.mem_filter]
          constructor
          · rintro ⟨his, hcond⟩
            by_cases hi : i ∈ t
            · exact hi
            · exfalso
              simp only [hi, if_false] at hcond
              rcases hpi : pick' i with _ | v
              · rw [hpi] at hcond; simp at hcond
              · rw [hpi] at hcond
                simp only [Option.map_some] at hcond
                exact absurd (Option.some.inj hcond) (Fin.castSucc_lt_last v).ne
          · intro hi
            exact ⟨hts hi, by simp [hi]⟩
        rw [hfilt, htcard]
      · intro k'
        have hfilt : (s.filter (fun i => (if i ∈ t then some (Fin.last m)
            else (pick' i).map Fin.castSucc) = some (Fin.castSucc k')))
            = s'.filter (fun i => pick' i = some k') := by
          apply Finset.ext
          intro i
          simp only [Finset.mem_filter]
          constructor
          · rintro ⟨his, hcond⟩
            by_cases hi : i ∈ t
            · exfalso
              simp only [hi, if_true] at hcond
              exact absurd (Option.some.inj hcond).symm (Fin.castSucc_lt_last k').ne
            · simp only [hi, if_false] at hcond
              rcases hpi : pick' i with _ | v
              · rw [hpi] at hcond; simp at hcond
              · rw [hpi] at hcond
                simp only [Option.map_some] at hcond
                have hvk : v = k' := Fin.castSucc_injective _ (Option.some.inj hcond)
                have hmem := hpick'sub i (by rw [hpi]; simp)
                refine ⟨hmem, ?_⟩
                rw [hvk]
          · rintro ⟨his', hcond⟩
            have hi : i ∉ t := by
              rw [hs'] at his'; exact (Finset.mem_sdiff.mp his').2
            refine ⟨(Finset.mem_sdiff.mp (hs' ▸ his')).1, ?_⟩
            simp only [hi, if_false, hcond, Option.map_some]
        rw [hfilt, hpick'card k']

-- ============================================================================
-- § Cast helper: sum of `Int.toNat` over nonnegative integers
-- ============================================================================

/-- For nonnegative integers, the `ℕ`-sum of `Int.toNat`s casts back to the
`ℤ`-sum. Used to translate the aggregate flow-conservation identity between
`ℤ` (formulation `b`) and `ℕ` (cardinalities of plane sets). -/
private lemma cast_sum_toNat {n : ℕ} (g : Fin n → ℤ) (hg : ∀ i, 0 ≤ g i) :
    ((∑ i, (g i).toNat : ℕ) : ℤ) = ∑ i, g i := by
  push_cast
  exact Finset.sum_congr rfl (fun i _ => Int.toNat_of_nonneg (hg i))

-- ============================================================================
-- § Base layer: placement of planes at the initial time
-- ============================================================================

/-- **Base layer.** Given nonnegative per-location counts summing to `nP`,
there is a placement `loc : Fin nP → Fin nA` of the `nP` planes realizing
exactly `(n a).toNat` planes at each location `a`. -/
lemma layer_base {nP nA : ℕ} [NeZero nA] (n : Fin nA → ℤ)
    (hn_nn : ∀ a, 0 ≤ n a) (hsum : (∑ a, n a) = (nP : ℤ)) :
    ∃ loc : Fin nP → Fin nA,
      ∀ a, (univ.filter (fun pl => loc pl = a)).card = (n a).toNat := by
  classical
  have hcast : ((∑ a : Fin nA, (n a).toNat : ℕ) : ℤ) = ∑ a, n a := cast_sum_toNat n hn_nn
  have hpre : (∑ a : Fin nA, (n a).toNat) ≤ (univ : Finset (Fin nP)).card := by
    rw [Finset.card_univ, Fintype.card_fin]
    omega
  obtain ⟨pick, hsub, hcard⟩ := exists_pick_on nA (fun a => (n a).toNat) univ hpre
  have hnone : (univ.filter (fun pl => pick pl = none)).card = 0 := by
    have hfib : (univ : Finset (Fin nP)).card
        = ∑ o : Option (Fin nA), (univ.filter (fun pl => pick pl = o)).card :=
      Finset.card_eq_sum_card_fiberwise (fun pl _ => Finset.mem_univ (pick pl))
    rw [Fintype.sum_option] at hfib
    simp only [hcard] at hfib
    rw [Finset.card_univ, Fintype.card_fin] at hfib
    omega
  have hnone' : ∀ pl, pick pl ≠ none := by
    intro pl hpn
    have hmem : pl ∈ univ.filter (fun pl => pick pl = none) := by simp [hpn]
    have := Finset.card_pos.mpr ⟨pl, hmem⟩
    omega
  refine ⟨fun pl => (pick pl).getD ⟨0, Nat.pos_of_ne_zero (NeZero.ne nA)⟩, ?_⟩
  intro a
  have hset : (univ.filter (fun pl => (pick pl).getD ⟨0, Nat.pos_of_ne_zero (NeZero.ne nA)⟩ = a))
      = univ.filter (fun pl => pick pl = some a) := by
    apply Finset.filter_congr
    intro pl _
    rcases hpp : pick pl with _ | x
    · exact absurd hpp (hnone' pl)
    · simp
  rw [hset, hcard a]

-- ============================================================================
-- § Single-layer step: route planes among outgoing arcs
-- ============================================================================

/-- **Single-layer inductive step.** Given a placement `curLoc` of planes
realizing per-location counts `(n a).toNat`, nonnegative arc counts `f`
with `∑_{a'} f a a' ≤ n a` (no more departures than presence), route the
planes at each location among the outgoing arcs. This produces:

* an arc choice `arcCh` with exactly `(f a a').toNat` planes leaving `a`
  toward `a'`,
* a next-layer placement `nextLoc` (a plane taking arc `some a'` moves to
  `a'`; a plane with no arc stays put), and
* next-layer counts equal to `n a' + ∑_a f a a' - ∑_{a''} f a' a''` (in
  `Int.toNat`) — exactly the aggregate flow-conservation right-hand side. -/
lemma layer_step {nP nA : ℕ} [NeZero nA]
    (curLoc : Fin nP → Fin nA)
    (n : Fin nA → ℤ) (f : Fin nA → Fin nA → ℤ)
    (hn_nn : ∀ a, 0 ≤ n a)
    (hf_nn : ∀ a a', 0 ≤ f a a')
    (hstay : ∀ a, (∑ a', f a a') ≤ n a)
    (hcount : ∀ a, (univ.filter (fun pl => curLoc pl = a)).card = (n a).toNat) :
    ∃ (nextLoc : Fin nP → Fin nA) (arcCh : Fin nP → Option (Fin nA)),
      (∀ a a', (univ.filter (fun pl => curLoc pl = a ∧ arcCh pl = some a')).card
        = (f a a').toNat) ∧
      (∀ pl a', arcCh pl = some a' → nextLoc pl = a') ∧
      (∀ pl, arcCh pl = none → nextLoc pl = curLoc pl) ∧
      (∀ a', (univ.filter (fun pl => nextLoc pl = a')).card
        = (n a' + (∑ a, f a a') - (∑ a'', f a' a'')).toNat) := by
  classical
  have hpre : ∀ a, (∑ a' : Fin nA, ((f a a').toNat))
      ≤ (univ.filter (fun pl => curLoc pl = a)).card := by
    intro a
    rw [hcount a]
    have h1 : ((∑ a' : Fin nA, ((f a a').toNat) : ℕ) : ℤ) ≤ (n a) := by
      rw [cast_sum_toNat (fun a' => f a a') (fun a' => hf_nn a a')]
      exact hstay a
    have := hn_nn a
    omega
  choose pick hpsub hpcard using
    fun a => exists_pick_on nA (fun a' => (f a a').toNat)
      (univ.filter (fun pl => curLoc pl = a)) (hpre a)
  set arcCh : Fin nP → Option (Fin nA) := fun pl => pick (curLoc pl) pl with harc
  set nextLoc : Fin nP → Fin nA := fun pl => (arcCh pl).getD (curLoc pl) with hnext
  have harccount : ∀ a a', (univ.filter (fun pl => curLoc pl = a ∧ arcCh pl = some a')).card
      = (f a a').toNat := by
    intro a a'
    have hset : (univ.filter (fun pl => curLoc pl = a ∧ arcCh pl = some a'))
        = (univ.filter (fun pl => curLoc pl = a)).filter (fun pl => pick a pl = some a') := by
      rw [Finset.filter_filter]
      apply Finset.filter_congr
      intro pl _
      constructor
      · rintro ⟨hc, ha⟩
        refine ⟨hc, ?_⟩
        rw [harc] at ha; simp only at ha; rw [hc] at ha; exact ha
      · rintro ⟨hc, ha⟩
        refine ⟨hc, ?_⟩
        rw [harc]; simp only; rw [hc]; exact ha
    rw [hset, hpcard a a']
  refine ⟨nextLoc, arcCh, harccount, ?_, ?_, ?_⟩
  · intro pl a' ha
    rw [hnext]; simp only; rw [ha]; rfl
  · intro pl ha
    rw [hnext]; simp only; rw [ha]; rfl
  · intro a'
    set S1 := univ.filter (fun pl => arcCh pl = some a') with hS1
    set S2 := univ.filter (fun pl => arcCh pl = none ∧ curLoc pl = a') with hS2
    have hsplit : (univ.filter (fun pl => nextLoc pl = a')) = S1 ∪ S2 := by
      ext pl
      simp only [hS1, hS2, Finset.mem_union, Finset.mem_filter, Finset.mem_univ, true_and]
      rw [hnext]
      rcases h : arcCh pl with _ | x
      · simp [h]
      · simp [h]
    have hdisj : Disjoint S1 S2 := by
      rw [Finset.disjoint_left]
      intro pl h1 h2
      simp only [hS1, Finset.mem_filter, Finset.mem_univ, true_and] at h1
      simp only [hS2, Finset.mem_filter, Finset.mem_univ, true_and] at h2
      rw [h1] at h2; exact absurd h2.1 (by simp)
    rw [hsplit, Finset.card_union_of_disjoint hdisj]
    have hcardS1 : S1.card = ∑ a : Fin nA, (f a a').toNat := by
      rw [hS1]
      rw [Finset.card_eq_sum_card_fiberwise (f := curLoc) (t := (univ : Finset (Fin nA)))
        (fun pl _ => Finset.mem_univ (curLoc pl))]
      apply Finset.sum_congr rfl
      intro a _
      rw [Finset.filter_filter]
      have hcongr : (univ.filter (fun pl => arcCh pl = some a' ∧ curLoc pl = a))
          = (univ.filter (fun pl => curLoc pl = a ∧ arcCh pl = some a')) := by
        apply Finset.filter_congr; intro pl _; tauto
      rw [hcongr, harccount a a']
    have hcardS2 : S2.card = (n a').toNat - ∑ a'' : Fin nA, (f a' a'').toNat := by
      set T := univ.filter (fun pl => curLoc pl = a') with hT
      have hTcard : T.card = (n a').toNat := by rw [hT, hcount a']
      have hfib : T.card = ∑ o : Option (Fin nA), (T.filter (fun pl => arcCh pl = o)).card :=
        Finset.card_eq_sum_card_fiberwise (fun pl _ => Finset.mem_univ (arcCh pl))
      rw [Fintype.sum_option] at hfib
      have hnone : (T.filter (fun pl => arcCh pl = none)).card = S2.card := by
        rw [hS2, hT, Finset.filter_filter]
        congr 1
        apply Finset.filter_congr; intro pl _; tauto
      have hsome : ∀ a'', (T.filter (fun pl => arcCh pl = some a'')).card = (f a' a'').toNat := by
        intro a''
        rw [hT, Finset.filter_filter, harccount a' a'']
      rw [hnone] at hfib
      simp only [hsome] at hfib
      omega
    rw [hcardS1, hcardS2]
    have hA : ((∑ a : Fin nA, (f a a').toNat : ℕ) : ℤ) = ∑ a, f a a' :=
      cast_sum_toNat (fun a => f a a') (fun a => hf_nn a a')
    have hB : ((∑ a'' : Fin nA, (f a' a'').toNat : ℕ) : ℤ) = ∑ a'', f a' a'' :=
      cast_sum_toNat (fun a'' => f a' a'') (fun a'' => hf_nn a' a'')
    have hN : ((n a').toNat : ℤ) = n a' := Int.toNat_of_nonneg (hn_nn a')
    have hBN : (∑ a'', f a' a'') ≤ n a' := hstay a'
    have hXnn : (0 : ℤ) ≤ ∑ a, f a a' := Finset.sum_nonneg (fun a _ => hf_nn a a')
    omega

-- ============================================================================
-- § Parameter map and backward variable map
-- ============================================================================

/-- Parameter map `b.Params → a.Params` (identical data, distinct types). -/
def paramMap (p : P13.b.Params) : P13.a.Params where
  nP := p.nP
  nA := p.nA
  nT := p.nT
  adj := p.adj
  r := p.r
  cap := p.cap
  hadj_bin := p.hadj_bin
  hnP := p.hnP
  hnA := p.hnA
  hnT := p.hnT
  hadj_self := p.hadj_self
  hcap_nn := p.hcap_nn

/-- Backward variable map: aggregate the per-plane variables. -/
def bwd (p : P13.b.Params) (v : P13.a.Vars (paramMap p)) : P13.b.Vars p where
  n := fun a t => ∑ pl, v.y pl a t
  f := fun a a' t => ∑ pl, v.z pl a a' t

/-- The backward map sends feasible per-plane solutions to feasible
aggregate solutions. -/
theorem bwd_feas (p : P13.b.Params) (v : P13.a.Vars (paramMap p))
    (hv : P13.a.Feasible (paramMap p) v) : P13.b.Feasible p (bwd p v) where
  hcount := by
    intro t
    show (∑ a, ∑ pl, v.y pl a t) = (p.nP : ℤ)
    rw [Finset.sum_comm]
    calc ∑ pl, ∑ a, v.y pl a t
        = ∑ _pl : Fin p.nP, (1 : ℤ) := Finset.sum_congr rfl (fun pl _ => hv.hassign pl t)
      _ = (p.nP : ℤ) := by simp
  hcap := by
    intro a t
    simp only [bwd]
    push_cast
    exact hv.hcap a t
  hflow := by
    intro a t ht
    simp only [bwd]
    rw [Finset.sum_comm (s := (univ : Finset (Fin p.nA)))
        (f := fun a' pl => v.z pl a' a ⟨t.val - 1, by show t.val - 1 < p.nT; omega⟩)]
    rw [Finset.sum_comm (s := (univ : Finset (Fin p.nA)))
        (f := fun a' pl => v.z pl a a' ⟨t.val - 1, by show t.val - 1 < p.nT; omega⟩)]
    rw [← Finset.sum_add_distrib, ← Finset.sum_sub_distrib]
    exact Finset.sum_congr rfl (fun pl _ => hv.hflow pl a t ht)
  hadj := by
    intro a a' t
    simp only [bwd]
    calc ∑ pl, v.z pl a a' t
        ≤ ∑ _pl : Fin p.nP, p.adj a a' := Finset.sum_le_sum (fun pl _ => hv.hadj pl a a' t)
      _ = (p.nP : ℤ) * p.adj a a' := by
            rw [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]
  hno_depart_last := by
    intro a a' t ht
    simp only [bwd]
    rw [Finset.sum_congr rfl (fun pl _ => hv.hno_depart_last pl a a' t ht)]
    simp
  hstay_nn := by
    intro a t
    simp only [bwd]
    rw [Finset.sum_comm]
    exact Finset.sum_le_sum (fun pl _ => hv.hstay_nn pl a t)
  hn_nn := by
    intro a t
    simp only [bwd]
    exact Finset.sum_nonneg (fun pl _ => by rcases hv.hy_bin pl a t with h | h <;> omega)
  hf_nn := by
    intro a a' t
    simp only [bwd]
    exact Finset.sum_nonneg (fun pl _ => by rcases hv.hz_bin pl a a' t with h | h <;> omega)

/-- The backward map preserves the objective. -/
theorem bwd_obj (p : P13.b.Params) (v : P13.a.Vars (paramMap p)) :
    P13.b.obj p (bwd p v) = P13.a.obj (paramMap p) v := by
  simp only [P13.b.obj, P13.a.obj, bwd]
  push_cast
  simp_rw [Finset.mul_sum]
  conv_lhs => enter [2, x]; rw [Finset.sum_comm]
  rw [Finset.sum_comm]
  rfl

-- ============================================================================
-- § Layered decomposition: constructing the per-plane solution
-- ============================================================================

/-- Single-layer data extracted from `layer_step` at time `k`, with the
next-layer count invariant rewritten via aggregate flow conservation. -/
noncomputable def layerData (p : P13.b.Params) (v : P13.b.Vars p)
    (h : P13.b.Feasible p v) (k : ℕ) (hk1 : k + 1 < p.nT)
    (curLoc : Fin p.nP → Fin p.nA)
    (hinv : ∀ a, (univ.filter (fun pl => curLoc pl = a)).card
        = (v.n a ⟨k, by omega⟩).toNat) :
    {d : (Fin p.nP → Fin p.nA) × (Fin p.nP → Option (Fin p.nA)) //
      (∀ a a', (univ.filter (fun pl => curLoc pl = a ∧ d.2 pl = some a')).card
          = (v.f a a' ⟨k, by omega⟩).toNat) ∧
      (∀ pl a', d.2 pl = some a' → d.1 pl = a') ∧
      (∀ pl, d.2 pl = none → d.1 pl = curLoc pl) ∧
      (∀ a', (univ.filter (fun pl => d.1 pl = a')).card
          = (v.n a' ⟨k + 1, hk1⟩).toNat)} := by
  haveI := p.hnA
  have hstep := layer_step curLoc (fun a => v.n a ⟨k, by omega⟩)
    (fun a a' => v.f a a' ⟨k, by omega⟩)
    (fun a => h.hn_nn a _) (fun a a' => h.hf_nn a a' _)
    (fun a => h.hstay_nn a _) hinv
  choose nextLoc arcCh harccount hmove hstayloc hnextcount using hstep
  refine ⟨(nextLoc, arcCh), harccount, hmove, hstayloc, ?_⟩
  intro a'
  rw [hnextcount a']
  have hf : v.n a' ⟨k + 1, hk1⟩
      = v.n a' ⟨k, by omega⟩ + (∑ a, v.f a a' ⟨k, by omega⟩)
        - (∑ a'', v.f a' a'' ⟨k, by omega⟩) :=
    h.hflow a' ⟨k + 1, hk1⟩ (Nat.succ_pos k)
  rw [hf]

/-- The layer placement at time `k`, built by recursion over the layers,
carrying the per-location count invariant. -/
noncomputable def buildAux (p : P13.b.Params) (v : P13.b.Vars p)
    (h : P13.b.Feasible p v) :
    (k : ℕ) → (hk : k < p.nT) →
    {lc : Fin p.nP → Fin p.nA //
      ∀ a, (univ.filter (fun pl => lc pl = a)).card = (v.n a ⟨k, hk⟩).toNat}
  | 0, hk => by
      haveI := p.hnA
      have hsum : (∑ a, v.n a ⟨0, hk⟩) = (p.nP : ℤ) := h.hcount ⟨0, hk⟩
      have hb := layer_base (nP := p.nP) (fun a => v.n a ⟨0, hk⟩)
        (fun a => h.hn_nn a _) hsum
      exact ⟨hb.choose, hb.choose_spec⟩
  | (k + 1), hk => by
      have prev := buildAux p v h k (by omega)
      exact ⟨(layerData p v h k hk prev.val prev.property).val.1,
             (layerData p v h k hk prev.val prev.property).property.2.2.2⟩

/-- Per-plane placement at each time layer. -/
noncomputable def locF (p : P13.b.Params) (v : P13.b.Vars p)
    (h : P13.b.Feasible p v) (pl : Fin p.nP) (t : Fin p.nT) : Fin p.nA :=
  (buildAux p v h t.val t.isLt).val pl

/-- Per-plane arc choice at each time layer (none on the last layer). -/
noncomputable def arcF (p : P13.b.Params) (v : P13.b.Vars p)
    (h : P13.b.Feasible p v) (pl : Fin p.nP) (t : Fin p.nT) : Option (Fin p.nA) :=
  if ht : t.val + 1 < p.nT then
    (layerData p v h t.val ht (buildAux p v h t.val t.isLt).val
      (buildAux p v h t.val t.isLt).property).val.2 pl
  else none

/-- Bundled layered decomposition of an aggregate solution into a per-plane
routing over the time layers. -/
structure LayerDecomp (p : P13.b.Params) (v : P13.b.Vars p) where
  loc   : Fin p.nP → Fin p.nT → Fin p.nA
  arcCh : Fin p.nP → Fin p.nT → Option (Fin p.nA)
  hcount : ∀ a t, (univ.filter (fun pl => loc pl t = a)).card = (v.n a t).toNat
  harc   : ∀ a a' t,
    (univ.filter (fun pl => loc pl t = a ∧ arcCh pl t = some a')).card = (v.f a a' t).toNat
  hmove  : ∀ pl (t : Fin p.nT) (ht : t.val + 1 < p.nT) a',
    arcCh pl t = some a' → loc pl ⟨t.val + 1, ht⟩ = a'
  hstayloc : ∀ pl (t : Fin p.nT) (ht : t.val + 1 < p.nT),
    arcCh pl t = none → loc pl ⟨t.val + 1, ht⟩ = loc pl t
  hlast  : ∀ pl (t : Fin p.nT), t.val + 1 = p.nT → arcCh pl t = none

/-- Every feasible aggregate solution admits a layered per-plane
decomposition. -/
theorem build_layers (p : P13.b.Params) (v : P13.b.Vars p)
    (h : P13.b.Feasible p v) : Nonempty (LayerDecomp p v) := by
  refine ⟨{
    loc := locF p v h
    arcCh := arcF p v h
    hcount := ?_
    harc := ?_
    hmove := ?_
    hstayloc := ?_
    hlast := ?_ }⟩
  · -- hcount
    intro a t
    simpa only [locF] using (buildAux p v h t.val t.isLt).property a
  · -- harc
    intro a a' t
    by_cases ht : t.val + 1 < p.nT
    · have hL := (layerData p v h t.val ht (buildAux p v h t.val t.isLt).val
        (buildAux p v h t.val t.isLt).property).property.1 a a'
      simpa only [locF, arcF, dif_pos ht] using hL
    · have hlt : t.val + 1 = p.nT := by omega
      have hz : v.f a a' t = 0 := h.hno_depart_last a a' t hlt
      simp [arcF, dif_neg ht, hz]
  · -- hmove
    intro pl t ht a' harcpl
    have key : locF p v h pl ⟨t.val + 1, ht⟩
        = (layerData p v h t.val ht (buildAux p v h t.val t.isLt).val
            (buildAux p v h t.val t.isLt).property).val.1 pl := by
      simp only [locF, buildAux]
    rw [key]
    refine (layerData p v h t.val ht (buildAux p v h t.val t.isLt).val
      (buildAux p v h t.val t.isLt).property).property.2.1 pl a' ?_
    simpa only [arcF, dif_pos ht] using harcpl
  · -- hstayloc
    intro pl t ht harcpl
    have key : locF p v h pl ⟨t.val + 1, ht⟩
        = (layerData p v h t.val ht (buildAux p v h t.val t.isLt).val
            (buildAux p v h t.val t.isLt).property).val.1 pl := by
      simp only [locF, buildAux]
    rw [key]
    have := (layerData p v h t.val ht (buildAux p v h t.val t.isLt).val
      (buildAux p v h t.val t.isLt).property).property.2.2.1 pl
        (by simpa only [arcF, dif_pos ht] using harcpl)
    simpa only [locF] using this
  · -- hlast
    intro pl t hlt
    simp only [arcF, dif_neg (by omega : ¬ t.val + 1 < p.nT)]

-- ============================================================================
-- § Forward map
-- ============================================================================

/-- Forward map: expand an aggregate solution into a per-plane solution using
the layered decomposition (identically zero on infeasible inputs). -/
noncomputable def fwd (p : P13.b.Params) (v : P13.b.Vars p) :
    P13.a.Vars (paramMap p) := by
  classical
  exact
    if h : P13.b.Feasible p v then
      { y := fun pl a t =>
          if (Classical.choice (build_layers p v h)).loc pl t = a then 1 else 0
        z := fun pl a a' t =>
          if (Classical.choice (build_layers p v h)).arcCh pl t = some a'
              ∧ (Classical.choice (build_layers p v h)).loc pl t = a then 1 else 0 }
    else
      { y := fun _ _ _ => 0, z := fun _ _ _ _ => 0 }

/-- The forward map sends feasible aggregate solutions to feasible per-plane
solutions. -/
theorem fwd_feas (p : P13.b.Params) (v : P13.b.Vars p) (h : P13.b.Feasible p v) :
    P13.a.Feasible (paramMap p) (fwd p v) := by
  classical
  set D := Classical.choice (build_layers p v h) with hD
  have hy : ∀ pl a t, (fwd p v).y pl a t = if D.loc pl t = a then (1 : ℤ) else 0 := by
    intro pl a t; simp only [fwd, dif_pos h, ← hD]
  have hz : ∀ pl a a' t, (fwd p v).z pl a a' t
      = if D.arcCh pl t = some a' ∧ D.loc pl t = a then (1 : ℤ) else 0 := by
    intro pl a a' t; simp only [fwd, dif_pos h, ← hD]
  have sum_in : ∀ (pl : Fin (paramMap p).nP) (s : Fin (paramMap p).nT) (b : Fin (paramMap p).nA),
      (∑ a' : Fin (paramMap p).nA, if D.arcCh pl s = some b ∧ D.loc pl s = a' then (1 : ℤ) else 0)
        = if D.arcCh pl s = some b then 1 else 0 := by
    intro pl s b
    by_cases hc : D.arcCh pl s = some b <;> simp [hc, Finset.sum_ite_eq]
  have sum_out : ∀ (pl : Fin (paramMap p).nP) (s : Fin (paramMap p).nT) (b : Fin (paramMap p).nA),
      (∑ a' : Fin (paramMap p).nA, if D.arcCh pl s = some a' ∧ D.loc pl s = b then (1 : ℤ) else 0)
        = if D.loc pl s = b then
            (∑ a' : Fin (paramMap p).nA, if D.arcCh pl s = some a' then (1 : ℤ) else 0) else 0 := by
    intro pl s b
    by_cases hb : D.loc pl s = b
    · simp only [hb, and_true, if_true]
    · simp [hb]
  refine { hassign := ?_, hcap := ?_, hflow := ?_, hadj := ?_,
           hno_depart_last := ?_, hstay_nn := ?_, hy_bin := ?_, hz_bin := ?_ }
  · -- hassign
    intro pl t
    simp [hy, Finset.sum_ite_eq]
  · -- hcap
    intro a t
    simp only [hy]
    have hcnt : (univ.filter (fun pl : Fin (paramMap p).nP => D.loc pl t = a)).card
        = (v.n a t).toNat := D.hcount a t
    push_cast
    rw [Finset.sum_boole, hcnt,
        show (((v.n a t).toNat : ℝ)) = (v.n a t : ℝ) from by
          exact_mod_cast Int.toNat_of_nonneg (h.hn_nn a t)]
    exact h.hcap a t
  · -- hflow
    intro pl a t ht
    simp only [hy, hz]
    set s : Fin (paramMap p).nT := ⟨t.val - 1, by omega⟩ with hs_def
    have hsval : s.val = t.val - 1 := by rw [hs_def]
    have hlt : s.val + 1 < (paramMap p).nT := by rw [hsval]; omega
    have hst : (⟨s.val + 1, hlt⟩ : Fin (paramMap p).nT) = t := by
      apply Fin.ext; show s.val + 1 = t.val; omega
    rw [sum_in pl s a, sum_out pl s a]
    rcases hc : D.arcCh pl s with _ | c
    · -- no departing arc: plane stays
      have hloc : D.loc pl t = D.loc pl s := by
        rw [← hst]; exact D.hstayloc pl s hlt hc
      rw [hloc]; simp
    · -- departs on arc c
      have hloc : D.loc pl t = c := by
        rw [← hst]; exact D.hmove pl s hlt c hc
      rw [hloc]
      simp only [Option.some.injEq]
      rw [show (∑ a' : Fin (paramMap p).nA, if c = a' then (1 : ℤ) else 0) = 1 from by
        simp only [Finset.sum_ite_eq, Finset.mem_univ, if_true]]
      ring
  · -- hadj
    intro pl a a' t
    rw [hz]
    split_ifs with hcond
    · have hmem : pl ∈ univ.filter (fun q => D.loc q t = a ∧ D.arcCh q t = some a') := by
        simp only [Finset.mem_filter, Finset.mem_univ, true_and]
        exact ⟨hcond.2, hcond.1⟩
      have hcardpos : 0 < (univ.filter (fun q => D.loc q t = a ∧ D.arcCh q t = some a')).card :=
        Finset.card_pos.mpr ⟨pl, hmem⟩
      rw [D.harc a a' t] at hcardpos
      have hpos : 0 < v.f a a' t := by omega
      have hb := h.hadj a a' t
      rcases p.hadj_bin a a' with h0 | h1
      · exfalso; rw [h0, mul_zero] at hb; omega
      · show (1 : ℤ) ≤ p.adj a a'; rw [h1]
    · show (0 : ℤ) ≤ p.adj a a'
      rcases p.hadj_bin a a' with h0 | h1 <;> omega
  · -- hno_depart_last
    intro pl a a' t hlt
    simp [hz, D.hlast pl t hlt]
  · -- hstay_nn
    intro pl a t
    simp only [hy, hz]
    rw [sum_out pl t a]
    by_cases hla : D.loc pl t = a
    · rw [if_pos hla, if_pos hla]
      rcases hc : D.arcCh pl t with _ | c <;> simp [Finset.sum_ite_eq]
    · simp [hla]
  · -- hy_bin
    intro pl a t
    rw [hy]; split_ifs <;> simp
  · -- hz_bin
    intro pl a a' t
    rw [hz]; split_ifs <;> simp

/-- The forward map preserves the objective. -/
theorem fwd_obj (p : P13.b.Params) (v : P13.b.Vars p) (h : P13.b.Feasible p v) :
    P13.a.obj (paramMap p) (fwd p v) = P13.b.obj p v := by
  classical
  set D := Classical.choice (build_layers p v h) with hD
  have hy : ∀ pl a t, (fwd p v).y pl a t = if D.loc pl t = a then (1 : ℤ) else 0 := by
    intro pl a t; simp only [fwd, dif_pos h, ← hD]
  simp only [P13.a.obj, P13.b.obj, hy]
  rw [Finset.sum_comm]
  conv_lhs => enter [2, a]; rw [Finset.sum_comm]
  apply Finset.sum_congr rfl; intro a _
  apply Finset.sum_congr rfl; intro t _
  have hcnt : (univ.filter (fun pl : Fin (paramMap p).nP => D.loc pl t = a)).card
      = (v.n a t).toNat := D.hcount a t
  rw [← Finset.mul_sum]
  congr 1
  push_cast
  rw [Finset.sum_boole, hcnt]
  exact_mod_cast Int.toNat_of_nonneg (h.hn_nn a t)

-- ============================================================================
-- § The reformulation
-- ============================================================================

/-- The aggregate formulation `P13.b` is a reformulation of the per-plane
formulation `P13.a`: the forward map expands an aggregate solution into a
per-plane routing via the layered flow decomposition, and the backward map
aggregates a per-plane solution by summing over planes. -/
noncomputable def p13_b_a_reformulation :
    MILPReformulation P13.b.formulation P13.a.formulation where
  paramMap := paramMap
  fwd := fwd
  bwd := bwd
  fwd_feas := fwd_feas
  bwd_feas := bwd_feas
  objMap := id
  objMap_mono := strictMono_id
  fwd_obj := fun p x hx => fwd_obj p x hx
  bwd_obj := fun p x' _ => (bwd_obj p x').symm

end P13
