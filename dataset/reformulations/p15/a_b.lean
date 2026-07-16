import Common
import problems.p15.formulations.a.Formulation
import problems.p15.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset
open P15.b (apts)

namespace P15

/-!
# P15: Apartment-tower reformulation `A → B`

Formulation `P15.a` keeps only aggregate integer counts, while formulation
`P15.b` indexes floors `k ∈ [0, nK)` and apartments `a ∈ A_v` explicitly
with binary decision variables.

This file constructs the constructive `A → B` reformulation. It synthesizes
a `P15.b`-instance from a `P15.a`-instance (`paramMap'`) by choosing, for
each configuration, an explicit apartment-to-area labelling realizing the
aggregate counts `R`. The variable maps and feasibility/objective transports
reuse the aggregate/disaggregate machinery (`fwd`, `bwd`, `fwd_feas`,
`bwd_feas`, `fwd_obj_eq`, `bwd_obj_eq`) developed for the `B → A` direction.
-/

-- ============================================================================
-- § Block-assignment corollary (degree-1 Gale–Ryser)
-- ============================================================================

/-- **Degree-1 Gale–Ryser corollary.** Given target counts `c : ι → ℕ` summing
to `N`, there is an assignment `f : Fin N → ι` whose fiber over each `i` has
cardinality exactly `c i`.

This is the counting core of the `A → B` disaggregation: because each "left
vertex" (a floor, or an individual apartment) has degree exactly `1`, the
existence of the required simple bipartite graph reduces to distributing `N`
labelled items into bins of prescribed sizes `c i` — no matching theorem is
needed. Applied once to assign floors to `(configuration, owner)` pairs, and
once (per area/owner group) to assign apartments to sectors. -/
private lemma exists_block_assign {ι : Type*} [Fintype ι] [DecidableEq ι] {N : ℕ}
    (c : ι → ℕ) (hN : ∑ i, c i = N) :
    ∃ f : Fin N → ι,
      ∀ i : ι, (Finset.univ.filter (fun n => f n = i)).card = c i := by
  classical
  have hcard : Fintype.card (Σ i : ι, Fin (c i)) = N := by
    rw [Fintype.card_sigma]; simp [hN]
  let e : (Σ i : ι, Fin (c i)) ≃ Fin N := Fintype.equivFinOfCardEq hcard
  refine ⟨fun n => (e.symm n).1, ?_⟩
  intro i
  have hequiv :
      {n : Fin N // (e.symm n).1 = i} ≃ {s : (Σ j : ι, Fin (c j)) // s.1 = i} :=
    Equiv.subtypeEquiv e.symm (fun _ => Iff.rfl)
  rw [← Fintype.card_subtype (fun n : Fin N => (e.symm n).1 = i),
      Fintype.card_congr hequiv, Fintype.card_congr (Equiv.sigmaSubtype i),
      Fintype.card_fin]

/-- Fintype-domain form of `exists_block_assign`: assign each element of a finite
domain `D` a label `i`, hitting each label exactly `c i` times. Used to assign
floors to `(configuration, owner)` pairs and apartment slots to sectors without
threading an explicit `Fin N` indexing through the caller. -/
private lemma exists_block_assign' {D ι : Type*} [Fintype D] [Fintype ι] [DecidableEq ι]
    (c : ι → ℕ) (hcard : ∑ i, c i = Fintype.card D) :
    ∃ f : D → ι,
      ∀ i : ι, (Finset.univ.filter (fun d => f d = i)).card = c i := by
  classical
  obtain ⟨g, hg⟩ := exists_block_assign c hcard
  let eD : D ≃ Fin (Fintype.card D) := Fintype.equivFin D
  refine ⟨fun d => g (eD d), ?_⟩
  intro i
  rw [← hg i, ← Fintype.card_subtype (fun d => g (eD d) = i),
      ← Fintype.card_subtype (fun n => g n = i)]
  exact Fintype.card_congr (Equiv.subtypeEquiv eD (fun _ => Iff.rfl))

-- ============================================================================
-- § Parameter Mapping (B → A)
-- ============================================================================

/-- For a fixed `(cap, jApt)` pair (from `P15.b.Params`), the number of
apartments of area index `j` in configuration `v`: this is the count of
indices `a ∈ apts cap v nA` with `jApt v a = j`. This serves as the
`R` array of `P15.a.Params`. -/
private def Rcount (p : P15.b.Params) (j : Fin p.nJ) (v : Fin p.nV) : ℤ :=
  (((apts p.cap v p.nA).filter (fun a => p.jApt v a = j)).card : ℤ)

private lemma Rcount_nn (p : P15.b.Params) (j : Fin p.nJ) (v : Fin p.nV) :
    0 ≤ Rcount p j v := by
  unfold Rcount; positivity

/-- The parameter map: copy across structural data and define `R` from
`(cap, jApt)`. -/
private def paramMap (p : P15.b.Params) : P15.a.Params :=
  { nI       := p.nI
    nJ       := p.nJ
    nH       := p.nH
    nV       := p.nV
    K        := p.nK
    R        := Rcount p
    O        := p.pProfit
    area     := p.area
    m        := p.m
    a        := p.b
    s        := p.s
    o        := p.o
    iFree    := p.iFree
    hCorp    := p.hCorp
    hiFree   := p.hiFree
    hhCorp   := p.hhCorp
    hnI      := p.hnI
    hnJ      := p.hnJ
    hnH      := p.hnH
    hnV      := p.hnV
    hnK      := p.hnK
    hR_nn    := Rcount_nn p
    harea_nn := p.harea_nn
    hm_nn    := p.hm_nn
    ha_nn    := p.hb_nn
    hs_nn    := p.hs_nn
    ho_nn    := p.ho_nn }

-- ============================================================================
-- § Synthesized Parameter Mapping (A → B)
-- ============================================================================

/-- The per-area apartment counts of a configuration sum (as ℕ) to the total
apartment count of that configuration. Holds because every `R j v` is
nonnegative. -/
private lemma sum_toNat (p : P15.a.Params) (v : Fin p.nV) :
    ∑ j : Fin p.nJ, (p.R j v).toNat = (∑ j : Fin p.nJ, p.R j v).toNat := by
  have key : ∀ j : Fin p.nJ, ((p.R j v).toNat : ℤ) = p.R j v :=
    fun j => Int.toNat_of_nonneg (p.hR_nn j v)
  have h1 : ((∑ j : Fin p.nJ, (p.R j v).toNat : ℕ) : ℤ)
      = ((∑ j : Fin p.nJ, p.R j v).toNat : ℤ) := by
    rw [Nat.cast_sum]
    simp_rw [key]
    rw [Int.toNat_of_nonneg (Finset.sum_nonneg (fun j _ => p.hR_nn j v))]
  exact_mod_cast h1

/-- An explicit assignment of each of the `(∑ j, R j v).toNat` apartments of
configuration `v` to an area index `j`, hitting each area exactly `(R j v).toNat`
times. This is the counting core of synthesizing a `P15.b`-instance from a
`P15.a`-instance. -/
private noncomputable def gAssign (p : P15.a.Params) (v : Fin p.nV) :
    Fin ((∑ j : Fin p.nJ, p.R j v).toNat) → Fin p.nJ :=
  (exists_block_assign' (D := Fin ((∑ j : Fin p.nJ, p.R j v).toNat))
    (fun j : Fin p.nJ => (p.R j v).toNat)
    (by rw [Fintype.card_fin]; exact sum_toNat p v)).choose

/-- The assignment `gAssign` realizes the prescribed fiber cardinalities. -/
private lemma gAssign_spec (p : P15.a.Params) (v : Fin p.nV) (j : Fin p.nJ) :
    (univ.filter (fun d => gAssign p v d = j)).card = (p.R j v).toNat :=
  (exists_block_assign' (D := Fin ((∑ j : Fin p.nJ, p.R j v).toNat))
    (fun j : Fin p.nJ => (p.R j v).toNat)
    (by rw [Fintype.card_fin]; exact sum_toNat p v)).choose_spec j

/-- Synthesize a `P15.b`-instance from a `P15.a`-instance. Dimensions are
copied; each configuration `v` gets `cap v = (∑ j, R j v).toNat` apartments,
labelled by the explicit assignment `gAssign`. -/
private noncomputable def paramMap' (p : P15.a.Params) : P15.b.Params :=
  { nK       := p.K
    nV       := p.nV
    nH       := p.nH
    nI       := p.nI
    nJ       := p.nJ
    nA       := (∑ v : Fin p.nV, (∑ j : Fin p.nJ, p.R j v).toNat) + 1
    cap      := fun v => (∑ j : Fin p.nJ, p.R j v).toNat
    jApt     := fun v a =>
      haveI := p.hnJ
      if h : a.val < (∑ j : Fin p.nJ, p.R j v).toNat
      then gAssign p v ⟨a.val, h⟩
      else default
    pProfit  := p.O
    area     := p.area
    m        := p.m
    b        := p.a
    s        := p.s
    o        := p.o
    iFree    := p.iFree
    hCorp    := p.hCorp
    hiFree   := p.hiFree
    hhCorp   := p.hhCorp
    hnK      := p.hnK
    hnV      := p.hnV
    hnH      := p.hnH
    hnI      := p.hnI
    hnJ      := p.hnJ
    hnA      := ⟨by omega⟩
    hcap_le  := fun v => by
      have hle : (∑ j : Fin p.nJ, p.R j v).toNat
          ≤ ∑ v' : Fin p.nV, (∑ j : Fin p.nJ, p.R j v').toNat :=
        Finset.single_le_sum
          (f := fun v' => (∑ j : Fin p.nJ, p.R j v').toNat)
          (fun _ _ => Nat.zero_le _) (Finset.mem_univ v)
      omega
    harea_nn := p.harea_nn
    hm_nn    := p.hm_nn
    hb_nn    := p.ha_nn
    hs_nn    := p.hs_nn
    ho_nn    := p.ho_nn }

/-- The `R` array recovered from the synthesized `paramMap'` equals the original
aggregate counts `p.R`. This is the round-trip identity `Rcount ∘ paramMap' = id`
on the `R` field. -/
private lemma hReq (p : P15.a.Params) : Rcount (paramMap' p) = p.R := by
  classical
  haveI := p.hnJ
  funext j v
  -- Abbreviations for the synthesized configuration `v`.
  set N := (∑ j : Fin p.nJ, p.R j v).toNat with hN
  -- The image embedding `Fin N ↪ Fin nA`.
  have hNlt : N < (∑ v' : Fin p.nV, (∑ j : Fin p.nJ, p.R j v').toNat) + 1 := by
    have hle : N ≤ ∑ v' : Fin p.nV, (∑ j : Fin p.nJ, p.R j v').toNat :=
      Finset.single_le_sum
        (f := fun v' => (∑ j : Fin p.nJ, p.R j v').toNat)
        (fun _ _ => Nat.zero_le _) (Finset.mem_univ v)
    omega
  set nA := (∑ v' : Fin p.nV, (∑ j : Fin p.nJ, p.R j v').toNat) + 1 with hnA
  let e : Fin N → Fin nA := fun d => ⟨d.val, lt_trans d.isLt hNlt⟩
  have he_inj : Function.Injective e := by
    intro d1 d2 hd; apply Fin.ext; simpa [e] using hd
  -- The `apts`-filter set equals the image of the `gAssign`-fiber under `e`.
  have hset :
      (apts (paramMap' p).cap v (paramMap' p).nA).filter
          (fun a => (paramMap' p).jApt v a = j)
      = (univ.filter (fun d => gAssign p v d = j)).image e := by
    ext a
    simp only [Finset.mem_filter, Finset.mem_image, Finset.mem_univ, true_and,
      apts, Finset.mem_filter]
    constructor
    · rintro ⟨ha1, hj⟩
      -- `(paramMap' p).cap v = N`, so `a.val < N`.
      have haN : a.val < N := ha1
      refine ⟨⟨a.val, haN⟩, ?_, ?_⟩
      · -- `gAssign p v ⟨a.val, _⟩ = j` from the dite in `jApt`.
        have : (paramMap' p).jApt v a = gAssign p v ⟨a.val, haN⟩ := by
          show (if h : a.val < N then gAssign p v ⟨a.val, h⟩ else default)
              = gAssign p v ⟨a.val, haN⟩
          rw [dif_pos haN]
        rw [this] at hj; exact hj
      · apply Fin.ext; rfl
    · rintro ⟨d, hgd, rfl⟩
      -- `e d` has value `d.val < N`.
      have haN : (e d).val < N := d.isLt
      refine ⟨haN, ?_⟩
      show (if h : (e d).val < N then gAssign p v ⟨(e d).val, h⟩ else default) = j
      rw [dif_pos haN]
      have : (⟨(e d).val, haN⟩ : Fin N) = d := by apply Fin.ext; rfl
      rw [this]; exact hgd
  -- Conclude by counting.
  show (((apts (paramMap' p).cap v (paramMap' p).nA).filter
          (fun a => (paramMap' p).jApt v a = j)).card : ℤ) = p.R j v
  rw [hset, Finset.card_image_of_injective _ he_inj, gAssign_spec p v j]
  exact Int.toNat_of_nonneg (p.hR_nn j v)

-- ============================================================================
-- § Feasibility Transport across `paramMap ∘ paramMap'`
-- ============================================================================

/-- `P15.a.Vars p` and `P15.a.Vars (paramMap (paramMap' p))` have identical
field structure (they only differ in the `R` parameter, which `Vars` ignores),
but are not the *same* type, since the type application requires the whole
`Params` to be definitionally equal. Re-pack the fields to move between them. -/
private def varCast (p : P15.a.Params) (x : P15.a.Vars p) :
    P15.a.Vars (paramMap (paramMap' p)) := ⟨x.x, x.y⟩

/-- The reverse re-packing of `varCast`. -/
private def varCast' (p : P15.a.Params) (x : P15.a.Vars (paramMap (paramMap' p))) :
    P15.a.Vars p := ⟨x.x, x.y⟩

/-- Every `P15.a.Feasible` field except consistency is definitionally shared
between `p` and `paramMap (paramMap' p)`; consistency transports via `hReq`. -/
private lemma feas_to (p : P15.a.Params) (x : P15.a.Vars p)
    (h : P15.a.Feasible p x) :
    P15.a.Feasible (paramMap (paramMap' p)) (varCast p x) := by
  refine
    { hfloors := ?_
      hconsistency := ?_
      hsector_pct := ?_
      havg_area := ?_
      hmin_area := ?_
      hno_free_corp := ?_
      howner_pct := ?_
      hx_nn := ?_
      hy_nn := ?_ }
  · exact h.hfloors
  · intro j hh
    show ∑ cfg : Fin p.nV, Rcount (paramMap' p) j cfg * x.x cfg hh
        = ∑ i : Fin p.nI, x.y i j hh
    rw [hReq]; exact h.hconsistency j hh
  · exact h.hsector_pct
  · exact h.havg_area
  · exact h.hmin_area
  · exact h.hno_free_corp
  · exact h.howner_pct
  · exact h.hx_nn
  · exact h.hy_nn

/-- The reverse transport of `feas_to`. -/
private lemma feas_from (p : P15.a.Params) (x : P15.a.Vars (paramMap (paramMap' p)))
    (h : P15.a.Feasible (paramMap (paramMap' p)) x) :
    P15.a.Feasible p (varCast' p x) := by
  refine
    { hfloors := ?_
      hconsistency := ?_
      hsector_pct := ?_
      havg_area := ?_
      hmin_area := ?_
      hno_free_corp := ?_
      howner_pct := ?_
      hx_nn := ?_
      hy_nn := ?_ }
  · exact h.hfloors
  · intro j hh
    have hc : ∑ cfg : Fin p.nV, Rcount (paramMap' p) j cfg * x.x cfg hh
        = ∑ i : Fin p.nI, x.y i j hh := h.hconsistency j hh
    rw [hReq] at hc
    show ∑ cfg : Fin p.nV, p.R j cfg * x.x cfg hh = ∑ i : Fin p.nI, x.y i j hh
    exact hc
  · exact h.hsector_pct
  · exact h.havg_area
  · exact h.hmin_area
  · exact h.hno_free_corp
  · exact h.howner_pct
  · exact h.hx_nn
  · exact h.hy_nn

-- ============================================================================
-- § Forward Mapping (B-vars → A-vars)
-- ============================================================================

/-- Aggregate B-variables into A-variables.

* `x_a v h := ∑_k b.x k v h` — number of floors with configuration `v`
  and owner `h`.
* `y_a i j h := ∑_{k, cfg, a ∈ A_cfg, jApt cfg a = j} b.y k cfg h i a` —
  number of apartments of area index `j`, owner `h`, in sector `i`. -/
private def fwd (p : P15.b.Params) (v : P15.b.Vars p) :
    P15.a.Vars (paramMap p) :=
  { x := fun cfg h' => ∑ k : Fin p.nK, v.x k cfg h'
    y := fun i j h' =>
      ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
        ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
          v.y k cfg h' i a }

-- ============================================================================
-- § Helper: fiberwise decomposition of sums over `apts`
-- ============================================================================

/-- The sum over `apts` decomposes as a fiberwise sum over area indices. -/
private lemma sum_apts_split_by_jApt (p : P15.b.Params)
    (cfg : Fin p.nV) (f : Fin p.nA → ℝ) :
    ∑ a ∈ apts p.cap cfg p.nA, f a =
    ∑ j : Fin p.nJ,
      ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j), f a := by
  classical
  haveI := p.hnJ
  rw [← Finset.sum_fiberwise (apts p.cap cfg p.nA) (fun a => p.jApt cfg a) f]

-- ============================================================================
-- § Forward Objective Equality
-- ============================================================================

/-- The forward map preserves the objective value pointwise. -/
private lemma fwd_obj_eq (p : P15.b.Params) (v : P15.b.Vars p) :
    P15.a.formulation.obj (paramMap p) (fwd p v) =
      P15.b.formulation.obj p v := by
  classical
  haveI := p.hnK
  haveI := p.hnV
  haveI := p.hnH
  haveI := p.hnI
  haveI := p.hnJ
  show -(∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH,
            p.pProfit i j h' * ((fwd p v).y i j h' : ℝ)) =
        -(∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ i : Fin p.nI,
            ∑ a ∈ apts p.cap cfg p.nA,
              p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ))
  congr 1
  -- Step 1: unfold (fwd p v).y and push the cast and pProfit inside.
  have step1 :
      ∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH,
        p.pProfit i j h' * ((fwd p v).y i j h' : ℝ)
      = ∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH,
          ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
            ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
              p.pProfit i j h' * (v.y k cfg h' i a : ℝ) := by
    apply Finset.sum_congr rfl; intro i _
    apply Finset.sum_congr rfl; intro j _
    apply Finset.sum_congr rfl; intro h' _
    show p.pProfit i j h' *
        ((∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
            ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
              v.y k cfg h' i a : ℤ) : ℝ) = _
    push_cast
    rw [Finset.mul_sum]
    apply Finset.sum_congr rfl; intro k _
    rw [Finset.mul_sum]
    apply Finset.sum_congr rfl; intro cfg _
    rw [Finset.mul_sum]
  rw [step1]
  -- Step 2: replace `pProfit i j h'` by `pProfit i (jApt cfg a) h'`
  -- inside the filter, where they agree.
  have step2 :
      ∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH,
          ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
            ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
              p.pProfit i j h' * (v.y k cfg h' i a : ℝ)
      = ∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH,
          ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
            ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
              p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ) := by
    apply Finset.sum_congr rfl; intro i _
    apply Finset.sum_congr rfl; intro j _
    apply Finset.sum_congr rfl; intro h' _
    apply Finset.sum_congr rfl; intro k _
    apply Finset.sum_congr rfl; intro cfg _
    apply Finset.sum_congr rfl; intro a ha
    have : p.jApt cfg a = j := (Finset.mem_filter.mp ha).2
    rw [this]
  rw [step2]
  -- Step 3: First merge ∑_j ∑_{a ∈ filter j} into ∑_{a ∈ apts}.
  have stepMerge :
      ∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH,
          ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
            ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
              p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ)
      = ∑ i : Fin p.nI, ∑ h' : Fin p.nH, ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
          ∑ a ∈ apts p.cap cfg p.nA,
            p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ) := by
    apply Finset.sum_congr rfl; intro i _
    -- ∑ j ∑ h' ∑ k ∑ cfg ∑_{a∈filter j} = ∑ h' ∑ k ∑ cfg ∑ j ∑_{a∈filter j}
    -- = ∑ h' ∑ k ∑ cfg ∑_{a∈apts}
    rw [Finset.sum_comm (s := (univ : Finset (Fin p.nJ)))
      (t := (univ : Finset (Fin p.nH)))]
    apply Finset.sum_congr rfl; intro h' _
    rw [Finset.sum_comm (s := (univ : Finset (Fin p.nJ)))
      (t := (univ : Finset (Fin p.nK)))]
    apply Finset.sum_congr rfl; intro k _
    rw [Finset.sum_comm (s := (univ : Finset (Fin p.nJ)))
      (t := (univ : Finset (Fin p.nV)))]
    apply Finset.sum_congr rfl; intro cfg _
    symm
    exact sum_apts_split_by_jApt p cfg
      (fun a => p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ))
  rw [stepMerge]
  -- Step 4: reorder ∑ i ∑ h' ∑ k ∑ cfg → ∑ k ∑ cfg ∑ h' ∑ i via calc.
  -- Pull k out front: ∑ i ∑ h' ∑ k = ∑ k ∑ i ∑ h'.
  calc ∑ i : Fin p.nI, ∑ h' : Fin p.nH, ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
          ∑ a ∈ apts p.cap cfg p.nA,
            p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ)
        = ∑ k : Fin p.nK, ∑ i : Fin p.nI, ∑ h' : Fin p.nH, ∑ cfg : Fin p.nV,
            ∑ a ∈ apts p.cap cfg p.nA,
              p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ) := by
          -- ∑ i ∑ h' ∑ k = ∑ k ∑ i ∑ h':
          -- First: enter i, swap (h', k): ∑ i ∑ k ∑ h'
          have inner : ∀ i : Fin p.nI,
              ∑ h' : Fin p.nH, ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
                  ∑ a ∈ apts p.cap cfg p.nA,
                    p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ)
              = ∑ k : Fin p.nK, ∑ h' : Fin p.nH, ∑ cfg : Fin p.nV,
                  ∑ a ∈ apts p.cap cfg p.nA,
                    p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ) := by
            intro i; rw [Finset.sum_comm]
          simp_rw [inner]
          rw [Finset.sum_comm]
      _ = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ i : Fin p.nI,
            ∑ a ∈ apts p.cap cfg p.nA,
              p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ) := by
          apply Finset.sum_congr rfl; intro k _
          -- ∑ i ∑ h' ∑ cfg = ∑ cfg ∑ h' ∑ i
          have inner : ∀ i : Fin p.nI,
              ∑ h' : Fin p.nH, ∑ cfg : Fin p.nV,
                  ∑ a ∈ apts p.cap cfg p.nA,
                    p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ)
              = ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
                  ∑ a ∈ apts p.cap cfg p.nA,
                    p.pProfit i (p.jApt cfg a) h' * (v.y k cfg h' i a : ℝ) := by
            intro i; rw [Finset.sum_comm]
          simp_rw [inner]
          rw [Finset.sum_comm]
          apply Finset.sum_congr rfl; intro cfg _
          rw [Finset.sum_comm]

-- ============================================================================
-- § Forward Feasibility Helpers
-- ============================================================================

/-- The cardinality of `apts cap cfg nA` equals `cap cfg`. -/
private lemma card_apts (p : P15.b.Params) (cfg : Fin p.nV) :
    (apts p.cap cfg p.nA).card = p.cap cfg := by
  have hb : apts p.cap cfg p.nA =
      (Finset.range (p.cap cfg)).attachFin
        (fun x hx => lt_of_lt_of_le (Finset.mem_range.mp hx) (p.hcap_le cfg)) := by
    ext a
    simp [apts, Finset.mem_attachFin, Finset.mem_range]
  rw [hb, Finset.card_attachFin, Finset.card_range]

-- ============================================================================
-- § Forward Feasibility
-- ============================================================================

/-- The forward map sends B-feasible solutions to A-feasible solutions. -/
private lemma fwd_feas (p : P15.b.Params) (v : P15.b.Vars p)
    (h : P15.b.formulation.feasible p v) :
    P15.a.formulation.feasible (paramMap p) (fwd p v) := by
  classical
  haveI := p.hnK
  haveI := p.hnV
  haveI := p.hnH
  haveI := p.hnI
  haveI := p.hnJ
  haveI := p.hnA
  -- Unpack the B-feasibility hypothesis
  obtain ⟨hfloor, hlink, _hy_outside, hsector_pct, havg_area,
          hmin_area, hno_free_corp, howner_pct, hx_bin, hy_bin⟩ := h
  -- A nonneg fact about each component of `v.x`
  have hxnn : ∀ (k : Fin p.nK) (cfg : Fin p.nV) (h' : Fin p.nH),
      0 ≤ v.x k cfg h' := by
    intro k cfg h'; rcases hx_bin k cfg h' with h0 | h1 <;> omega
  -- A nonneg fact about each component of `v.y`
  have hynn : ∀ (k : Fin p.nK) (cfg : Fin p.nV) (h' : Fin p.nH)
      (i : Fin p.nI) (a : Fin p.nA), 0 ≤ v.y k cfg h' i a := by
    intro k cfg h' i a; rcases hy_bin k cfg h' i a with h0 | h1 <;> omega
  -- Unfold the y-component of the forward image once and for all
  have hfwd_y : ∀ (i : Fin p.nI) (j : Fin p.nJ) (h' : Fin p.nH),
      (fwd p v).y i j h' =
        ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            v.y k cfg h' i a := by
    intros; rfl
  have hfwd_x : ∀ (cfg : Fin p.nV) (h' : Fin p.nH),
      (fwd p v).x cfg h' = ∑ k : Fin p.nK, v.x k cfg h' := by
    intros; rfl
  -- Generic ℤ-version of the fiberwise split lemma over apts.
  have hsplitZ : ∀ (cfg : Fin p.nV) (f : Fin p.nA → ℤ),
      ∑ a ∈ apts p.cap cfg p.nA, f a =
      ∑ j : Fin p.nJ,
        ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j), f a := by
    intro cfg f
    rw [← Finset.sum_fiberwise (apts p.cap cfg p.nA) (fun a => p.jApt cfg a) f]
  -- Aggregate identity: ∑_{a∈apts} ∑_i v.y k cfg h' i a = cap cfg * v.x k cfg h'
  have hcap_link : ∀ (k : Fin p.nK) (cfg : Fin p.nV) (h' : Fin p.nH),
      ∑ a ∈ apts p.cap cfg p.nA, ∑ i : Fin p.nI, v.y k cfg h' i a
        = (p.cap cfg : ℤ) * v.x k cfg h' := by
    intro k cfg h'
    have hsum : ∑ a ∈ apts p.cap cfg p.nA, ∑ i : Fin p.nI, v.y k cfg h' i a
        = ∑ a ∈ apts p.cap cfg p.nA, v.x k cfg h' := by
      apply Finset.sum_congr rfl
      intro a ha
      exact hlink k cfg h' a ha
    rw [hsum, Finset.sum_const, card_apts]
    simp [mul_comm]
  -- Sector aggregation: ∑ j ∑ h' (fwd y) i j h' = ∑ k ∑ cfg ∑ h' ∑ a∈apts v.y.
  have hsec_agg : ∀ (i : Fin p.nI) (h' : Fin p.nH),
      (∑ j : Fin p.nJ, (fwd p v).y i j h')
      = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
          ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h' i a := by
    intro i h'
    simp_rw [hfwd_y]
    -- ∑ j ∑ k ∑ cfg ∑ a∈filter j v.y = ∑ k ∑ cfg ∑ j ∑ a∈filter j v.y
    --                                = ∑ k ∑ cfg ∑ a∈apts v.y
    rw [Finset.sum_comm]
    apply Finset.sum_congr rfl; intro k _
    rw [Finset.sum_comm]
    apply Finset.sum_congr rfl; intro cfg _
    exact (hsplitZ cfg (fun a => v.y k cfg h' i a)).symm
  refine
    { hfloors := ?_
      hconsistency := ?_
      hsector_pct := ?_
      havg_area := ?_
      hmin_area := ?_
      hno_free_corp := ?_
      howner_pct := ?_
      hx_nn := ?_
      hy_nn := ?_ }
  · -- hfloors: ∑ cfg, ∑ h', ∑ k, v.x k cfg h' = (paramMap p).K = nK
    show ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, (fwd p v).x cfg h' = ((paramMap p).K : ℤ)
    simp_rw [hfwd_x]
    -- Goal: ∑ cfg, ∑ h', ∑ k, v.x k cfg h' = ((paramMap p).K : ℤ)
    have hinner : ∀ cfg : Fin p.nV,
        (∑ h' : Fin p.nH, ∑ k : Fin p.nK, v.x k cfg h')
        = ∑ k : Fin p.nK, ∑ h' : Fin p.nH, v.x k cfg h' := by
      intro cfg; rw [Finset.sum_comm]
    have hreorder :
        (∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ k : Fin p.nK, v.x k cfg h')
        = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, v.x k cfg h' := by
      simp_rw [hinner]
      rw [Finset.sum_comm]
    rw [hreorder]
    simp_rw [hfloor]
    rw [Finset.sum_const]
    show (Finset.univ : Finset (Fin p.nK)).card • (1 : ℤ) = ((paramMap p).K : ℤ)
    simp [paramMap]
  · -- hconsistency
    intro j h'
    show ∑ cfg : Fin p.nV, (paramMap p).R j cfg * (fwd p v).x cfg h'
        = ∑ i : Fin p.nI, (fwd p v).y i j h'
    -- LHS = ∑ cfg, |filter j| * ∑ k, v.x k cfg h'
    -- RHS = ∑ i, ∑ k, ∑ cfg, ∑ a∈filter j, v.y k cfg h' i a
    show ∑ cfg : Fin p.nV, Rcount p j cfg * (fwd p v).x cfg h'
        = ∑ i : Fin p.nI, (fwd p v).y i j h'
    simp_rw [hfwd_x, hfwd_y]
    -- transform LHS: card * ∑ k v.x = ∑ k card * v.x = ∑ k ∑ a∈filter j, v.x k cfg h'
    --              = ∑ k ∑ a∈filter j, ∑ i v.y k cfg h' i a (by hlink)
    have hLHS :
        ∀ cfg : Fin p.nV,
          Rcount p j cfg * ∑ k : Fin p.nK, v.x k cfg h'
          = ∑ k : Fin p.nK,
              ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
                ∑ i : Fin p.nI, v.y k cfg h' i a := by
      intro cfg
      rw [Finset.mul_sum]
      apply Finset.sum_congr rfl
      intro k _
      unfold Rcount
      rw [show
            (((((apts p.cap cfg p.nA).filter
                  (fun a => p.jApt cfg a = j)).card : ℤ)) * v.x k cfg h')
            = ∑ _a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
                v.x k cfg h' from by
              rw [Finset.sum_const]; simp [mul_comm]]
      apply Finset.sum_congr rfl
      intro a ha
      have ha' : a ∈ apts p.cap cfg p.nA := (Finset.mem_filter.mp ha).1
      exact (hlink k cfg h' a ha').symm
    simp_rw [hLHS]
    -- LHS: ∑ cfg, ∑ k, ∑ a∈filter j, ∑ i, v.y k cfg h' i a
    -- RHS: ∑ i, ∑ k, ∑ cfg, ∑ a∈filter j, v.y k cfg h' i a
    -- Pull ∑ i out, then reorder ∑ cfg, ∑ k.
    simp_rw [Finset.sum_comm (γ := Fin p.nI)]
    rw [Finset.sum_comm]
  · -- hsector_pct
    intro i
    show ((∑ j : Fin p.nJ, ∑ h' : Fin p.nH, (fwd p v).y i j h' : ℤ) : ℝ) ≥
        (paramMap p).a i *
        ((∑ l : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH, (fwd p v).y l j h' : ℤ) : ℝ)
    have hLHS :
        (∑ j : Fin p.nJ, ∑ h' : Fin p.nH, (fwd p v).y i j h')
        = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
            ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h' i a := by
      rw [Finset.sum_comm]
      have heach : ∀ h' : Fin p.nH,
          (∑ j : Fin p.nJ, (fwd p v).y i j h')
          = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ a ∈ apts p.cap cfg p.nA,
              v.y k cfg h' i a := fun h' => hsec_agg i h'
      simp_rw [heach]
      -- ∑ h' ∑ k ∑ cfg ∑ a = ∑ k ∑ cfg ∑ h' ∑ a
      simp_rw [Finset.sum_comm (γ := Fin p.nK)]
      simp_rw [Finset.sum_comm (γ := Fin p.nV)]
    have hRHS :
        (∑ l : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH, (fwd p v).y l j h')
        = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
            ∑ i' : Fin p.nI, ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h' i' a := by
      have heach : ∀ l : Fin p.nI,
          (∑ j : Fin p.nJ, ∑ h' : Fin p.nH, (fwd p v).y l j h')
          = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
              ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h' l a := by
        intro l
        rw [Finset.sum_comm]
        have heach' : ∀ h' : Fin p.nH,
            (∑ j : Fin p.nJ, (fwd p v).y l j h')
            = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ a ∈ apts p.cap cfg p.nA,
                v.y k cfg h' l a := fun h' => hsec_agg l h'
        simp_rw [heach']
        simp_rw [Finset.sum_comm (γ := Fin p.nK)]
        simp_rw [Finset.sum_comm (γ := Fin p.nV)]
      simp_rw [heach]
      -- ∑ l ∑ k ∑ cfg ∑ h' ∑ a = ∑ k ∑ cfg ∑ h' ∑ l ∑ a
      simp_rw [Finset.sum_comm (γ := Fin p.nI)]
    rw [hLHS, hRHS]
    show (((paramMap p).a i : ℝ)) * _ ≤ _
    exact hsector_pct i
  · -- havg_area
    intro i
    show (∑ j : Fin p.nJ, ∑ h' : Fin p.nH, (paramMap p).area j * ((fwd p v).y i j h' : ℝ))
        ≥ (paramMap p).s i *
            ((∑ j : Fin p.nJ, ∑ h' : Fin p.nH, (fwd p v).y i j h' : ℤ) : ℝ)
    -- RHS rewrite using sector aggregation.
    have hcount :
        (∑ j : Fin p.nJ, ∑ h' : Fin p.nH, (fwd p v).y i j h')
        = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
            ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h' i a := by
      rw [Finset.sum_comm]
      have heach : ∀ h' : Fin p.nH,
          (∑ j : Fin p.nJ, (fwd p v).y i j h')
          = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ a ∈ apts p.cap cfg p.nA,
              v.y k cfg h' i a := fun h' => hsec_agg i h'
      simp_rw [heach]
      simp_rw [Finset.sum_comm (γ := Fin p.nK)]
      simp_rw [Finset.sum_comm (γ := Fin p.nV)]
    rw [hcount]
    -- LHS rewrite: ∑ j ∑ h' area j * (fwd y) i j h'
    --            = ∑ k ∑ cfg ∑ h' ∑ a∈apts, area (jApt cfg a) * v.y k cfg h' i a
    have hLHS :
        (∑ j : Fin p.nJ, ∑ h' : Fin p.nH, (paramMap p).area j * ((fwd p v).y i j h' : ℝ))
        = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
            ∑ a ∈ apts p.cap cfg p.nA,
              p.area (p.jApt cfg a) * (v.y k cfg h' i a : ℝ) := by
      -- Step A: push cast and area inside the inner sum, using filter membership
      -- to substitute `area j` with `area (jApt cfg a)`.
      have hA :
          (∑ j : Fin p.nJ, ∑ h' : Fin p.nH, (paramMap p).area j * ((fwd p v).y i j h' : ℝ))
          = ∑ j : Fin p.nJ, ∑ h' : Fin p.nH, ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
              ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
                p.area (p.jApt cfg a) * (v.y k cfg h' i a : ℝ) := by
        apply Finset.sum_congr rfl; intro j _
        apply Finset.sum_congr rfl; intro h' _
        show p.area j *
            ((∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
                ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
                  v.y k cfg h' i a : ℤ) : ℝ) = _
        push_cast
        rw [Finset.mul_sum]
        apply Finset.sum_congr rfl; intro k _
        rw [Finset.mul_sum]
        apply Finset.sum_congr rfl; intro cfg _
        rw [Finset.mul_sum]
        apply Finset.sum_congr rfl; intro a ha
        have hj : p.jApt cfg a = j := (Finset.mem_filter.mp ha).2
        rw [hj]
      rw [hA]
      -- Step B: real-valued split, then reorder.
      have hsplitR : ∀ (cfg : Fin p.nV) (g : Fin p.nA → ℝ),
          ∑ a ∈ apts p.cap cfg p.nA, g a =
          ∑ j : Fin p.nJ,
            ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j), g a := by
        intro cfg g
        rw [← Finset.sum_fiberwise (apts p.cap cfg p.nA) (fun a => p.jApt cfg a) g]
      -- Step B1: collapse ∑ j ∑ a∈filter j into ∑ a∈apts (after reorder).
      have hcollapse :
          (∑ j : Fin p.nJ, ∑ h' : Fin p.nH, ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
              ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
                p.area (p.jApt cfg a) * (v.y k cfg h' i a : ℝ))
          = ∑ h' : Fin p.nH, ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
              ∑ a ∈ apts p.cap cfg p.nA,
                p.area (p.jApt cfg a) * (v.y k cfg h' i a : ℝ) := by
        rw [Finset.sum_comm (s := (Finset.univ : Finset (Fin p.nJ)))
              (t := (Finset.univ : Finset (Fin p.nH)))]
        apply Finset.sum_congr rfl; intro h' _
        rw [Finset.sum_comm (s := (Finset.univ : Finset (Fin p.nJ)))
              (t := (Finset.univ : Finset (Fin p.nK)))]
        apply Finset.sum_congr rfl; intro k _
        rw [Finset.sum_comm (s := (Finset.univ : Finset (Fin p.nJ)))
              (t := (Finset.univ : Finset (Fin p.nV)))]
        apply Finset.sum_congr rfl; intro cfg _
        exact (hsplitR cfg
          (fun a => p.area (p.jApt cfg a) * (v.y k cfg h' i a : ℝ))).symm
      rw [hcollapse]
      -- Step B2: reorder ∑ h' ∑ k ∑ cfg → ∑ k ∑ cfg ∑ h'.
      rw [Finset.sum_comm (s := (Finset.univ : Finset (Fin p.nH)))
            (t := (Finset.univ : Finset (Fin p.nK)))]
      apply Finset.sum_congr rfl; intro k _
      rw [Finset.sum_comm]
    rw [hLHS]
    -- The transformed inequality is exactly B's `havg_area`.
    show (paramMap p).s i * _ ≤ _
    -- Cast the integer sum on the RHS to a real sum elementwise.
    have hcastsum :
        (((∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
              ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h' i a : ℤ) : ℝ))
        = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
            ∑ a ∈ apts p.cap cfg p.nA, (v.y k cfg h' i a : ℝ) := by
      push_cast; rfl
    rw [hcastsum]
    have := havg_area i
    -- B-side: ∑ k ∑ cfg ∑ h ∑ a∈apts, area (jApt cfg a) * (v.y k cfg h i a : ℝ)
    --         ≥ s i * ∑ k ∑ cfg ∑ h ∑ a∈apts, v.y k cfg h i a (cast)
    -- Massage RHS cast in `this` to match.
    have hRHS :
        ((∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
            ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h' i a : ℤ) : ℝ)
        = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
            ∑ a ∈ apts p.cap cfg p.nA, (v.y k cfg h' i a : ℝ) := by
      push_cast; rfl
    rw [hRHS] at this
    exact this
  · -- hmin_area
    intro i j h' hlt
    show (fwd p v).y i j h' = 0
    rw [hfwd_y]
    apply Finset.sum_eq_zero
    intro k _
    apply Finset.sum_eq_zero
    intro cfg _
    apply Finset.sum_eq_zero
    intro a ha
    have hain : a ∈ apts p.cap cfg p.nA := (Finset.mem_filter.mp ha).1
    have hjeq : p.jApt cfg a = j := (Finset.mem_filter.mp ha).2
    apply hmin_area k cfg h' i a hain
    rw [hjeq]; exact hlt
  · -- hno_free_corp
    intro j
    show (fwd p v).y ⟨(paramMap p).iFree, (paramMap p).hiFree⟩ j
            ⟨(paramMap p).hCorp, (paramMap p).hhCorp⟩ = 0
    rw [hfwd_y]
    apply Finset.sum_eq_zero
    intro k _
    apply Finset.sum_eq_zero
    intro cfg _
    apply Finset.sum_eq_zero
    intro a ha
    have hain : a ∈ apts p.cap cfg p.nA := (Finset.mem_filter.mp ha).1
    exact hno_free_corp k cfg a hain
  · -- howner_pct
    intro h'
    show ((∑ i : Fin p.nI, ∑ j : Fin p.nJ, (fwd p v).y i j h' : ℤ) : ℝ)
        ≥ (paramMap p).o h' *
            ((∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h'' : Fin p.nH,
                (fwd p v).y i j h'' : ℤ) : ℝ)
    -- Translate (for each owner h'') ∑ i ∑ j (fwd y) i j h''
    -- to ∑ k ∑ cfg cap cfg * v.x k cfg h''.
    have htrans : ∀ h'' : Fin p.nH,
        ((∑ i : Fin p.nI, ∑ j : Fin p.nJ, (fwd p v).y i j h'' : ℤ) : ℝ)
        = (∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
            (v.x k cfg h'' : ℝ) * (p.cap cfg : ℝ)) := by
      intro h''
      have hagg :
          (∑ i : Fin p.nI, ∑ j : Fin p.nJ, (fwd p v).y i j h'')
          = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
              (p.cap cfg : ℤ) * v.x k cfg h'' := by
        -- Aggregate over j first using the sector aggregation, then sum over i.
        have hstep :
            (∑ i : Fin p.nI, ∑ j : Fin p.nJ, (fwd p v).y i j h'')
            = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ a ∈ apts p.cap cfg p.nA,
                ∑ i : Fin p.nI, v.y k cfg h'' i a := by
          have heach : ∀ i : Fin p.nI,
              (∑ j : Fin p.nJ, (fwd p v).y i j h'')
              = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
                  ∑ a ∈ apts p.cap cfg p.nA, v.y k cfg h'' i a :=
            fun i => hsec_agg i h''
          simp_rw [heach]
          -- ∑ i ∑ k ∑ cfg ∑ a, v.y = ∑ k ∑ cfg ∑ a ∑ i, v.y
          rw [Finset.sum_comm (s := (Finset.univ : Finset (Fin p.nI)))
                (t := (Finset.univ : Finset (Fin p.nK)))]
          apply Finset.sum_congr rfl; intro k _
          rw [Finset.sum_comm (s := (Finset.univ : Finset (Fin p.nI)))
                (t := (Finset.univ : Finset (Fin p.nV)))]
          apply Finset.sum_congr rfl; intro cfg _
          rw [Finset.sum_comm]
        rw [hstep]
        apply Finset.sum_congr rfl; intro k _
        apply Finset.sum_congr rfl; intro cfg _
        exact hcap_link k cfg h''
      rw [hagg]
      push_cast
      apply Finset.sum_congr rfl; intro k _
      apply Finset.sum_congr rfl; intro cfg _
      ring
    rw [htrans h']
    -- For RHS, push the ℝ-cast through the ∑ h'' and apply htrans pointwise.
    have hRHS :
        ((∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h'' : Fin p.nH,
            (fwd p v).y i j h'' : ℤ) : ℝ)
        = ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h'' : Fin p.nH,
            (v.x k cfg h'' : ℝ) * (p.cap cfg : ℝ) := by
      have hreorderZ :
          (∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h'' : Fin p.nH,
              (fwd p v).y i j h'')
          = ∑ h'' : Fin p.nH, ∑ i : Fin p.nI, ∑ j : Fin p.nJ,
              (fwd p v).y i j h'' := by
        have hinner : ∀ i : Fin p.nI,
            (∑ j : Fin p.nJ, ∑ h'' : Fin p.nH, (fwd p v).y i j h'')
            = ∑ h'' : Fin p.nH, ∑ j : Fin p.nJ, (fwd p v).y i j h'' := by
          intro i; rw [Finset.sum_comm]
        simp_rw [hinner]
        rw [Finset.sum_comm]
      rw [hreorderZ]
      rw [show (((∑ h'' : Fin p.nH, ∑ i : Fin p.nI, ∑ j : Fin p.nJ,
                    (fwd p v).y i j h'' : ℤ) : ℝ))
              = ∑ h'' : Fin p.nH,
                  ((∑ i : Fin p.nI, ∑ j : Fin p.nJ, (fwd p v).y i j h'' : ℤ) : ℝ)
              from by push_cast; rfl]
      simp_rw [htrans]
      -- ∑ h'' ∑ k ∑ cfg → ∑ k ∑ cfg ∑ h''
      rw [Finset.sum_comm (s := (Finset.univ : Finset (Fin p.nH)))
            (t := (Finset.univ : Finset (Fin p.nK)))]
      apply Finset.sum_congr rfl; intro k _
      rw [Finset.sum_comm]
    rw [hRHS]
    show (paramMap p).o h' * _ ≤ _
    exact howner_pct h'
  · -- hx_nn
    intro cfg h'
    show 0 ≤ (fwd p v).x cfg h'
    rw [hfwd_x]
    apply Finset.sum_nonneg
    intro k _
    exact hxnn k cfg h'
  · -- hy_nn
    intro i j h'
    show 0 ≤ (fwd p v).y i j h'
    rw [hfwd_y]
    apply Finset.sum_nonneg
    intro k _
    apply Finset.sum_nonneg
    intro cfg _
    apply Finset.sum_nonneg
    intro a _
    exact hynn k cfg h' i a

-- ============================================================================
-- § Backward Mapping (A-vars → B-vars)
-- ============================================================================

/-- Collapse a `∑` over configurations with a `fowner k = (cfg, h)` guard:
the only surviving term is `cfg = (fowner k).1`, present iff `(fowner k).2 = h`. -/
private lemma sum_ite_fowner_eq {nV nH : ℕ} (fk : Fin nV × Fin nH) (h : Fin nH)
    (Φ : Fin nV → ℤ) :
    ∑ cfg : Fin nV, (if fk = (cfg, h) then Φ cfg else 0)
      = if fk.2 = h then Φ fk.1 else 0 := by
  classical
  by_cases hh : fk.2 = h
  · rw [if_pos hh]
    have hstep : ∀ cfg : Fin nV, (if fk = (cfg, h) then Φ cfg else 0)
        = (if cfg = fk.1 then Φ cfg else 0) := by
      intro cfg
      by_cases hc : cfg = fk.1
      · rw [if_pos hc, if_pos]; rw [Prod.ext_iff]; exact ⟨hc.symm, hh⟩
      · rw [if_neg hc, if_neg]; rw [Prod.ext_iff]; push_neg
        intro he; exact absurd he.symm hc
    simp_rw [hstep]
    rw [Finset.sum_ite_eq' univ fk.1 Φ]; simp
  · rw [if_neg hh]
    apply Finset.sum_eq_zero
    intro cfg _
    rw [if_neg]; rw [Prod.ext_iff]; push_neg; intro _; exact hh

/-- A slot `(k, a)` is *valid* for the `(area j, owner h)` group when floor `k`'s
owner is `h`, apartment `a` exists in `k`'s configuration, and its area is `j`. -/
private def bValid (p : P15.b.Params) (fowner : Fin p.nK → Fin p.nV × Fin p.nH)
    (j : Fin p.nJ) (h : Fin p.nH) (ka : Fin p.nK × Fin p.nA) : Prop :=
  (fowner ka.1).2 = h ∧ (ka.2).val < p.cap (fowner ka.1).1
    ∧ p.jApt (fowner ka.1).1 ka.2 = j

private instance bValid_decidable (p : P15.b.Params)
    (fowner : Fin p.nK → Fin p.nV × Fin p.nH) (j : Fin p.nJ) (h : Fin p.nH) :
    DecidablePred (bValid p fowner j h) := by
  intro ka; unfold bValid; infer_instance

/-- Assign each floor `k` a `(configuration, owner)` pair so that the number of
floors mapped to `(cfg, h)` equals the aggregate count `xa.x cfg h`. Guarded by
the count condition; falls back to a constant map on infeasible input. -/
private noncomputable def bFloorAssign (p : P15.b.Params)
    (xa : P15.a.Vars (paramMap p)) : Fin p.nK → Fin p.nV × Fin p.nH :=
  haveI := p.hnV
  haveI := p.hnH
  if hc : (∑ q : Fin p.nV × Fin p.nH, (xa.x q.1 q.2).toNat) = Fintype.card (Fin p.nK)
  then (exists_block_assign' (fun q : Fin p.nV × Fin p.nH => (xa.x q.1 q.2).toNat) hc).choose
  else fun _ => default

/-- Assign each valid slot of the `(area j, owner h)` group to a sector so that
the number of slots mapped to sector `i` equals the aggregate count `xa.y i j h`.
Guarded by the count condition; falls back to a constant map otherwise. -/
private noncomputable def bSectorAssign (p : P15.b.Params)
    (xa : P15.a.Vars (paramMap p)) (j : Fin p.nJ) (h : Fin p.nH) :
    {ka : Fin p.nK × Fin p.nA // bValid p (bFloorAssign p xa) j h ka} → Fin p.nI :=
  haveI := p.hnI
  if hc : (∑ i : Fin p.nI, (xa.y i j h).toNat)
      = Fintype.card {ka : Fin p.nK × Fin p.nA // bValid p (bFloorAssign p xa) j h ka}
  then (exists_block_assign' (fun i : Fin p.nI => (xa.y i j h).toNat) hc).choose
  else fun _ => default

/-- The sector assignment extended to a total function on all slots. -/
private noncomputable def bSectorTotal (p : P15.b.Params)
    (xa : P15.a.Vars (paramMap p)) (j : Fin p.nJ) (h : Fin p.nH) :
    Fin p.nK × Fin p.nA → Fin p.nI :=
  haveI := p.hnI
  fun ka => if H : bValid p (bFloorAssign p xa) j h ka
            then bSectorAssign p xa j h ⟨ka, H⟩ else default

/-- Disaggregate A-variables into B-variables: place each floor on its assigned
`(configuration, owner)` pair and each apartment on its assigned sector. -/
private noncomputable def bwd (p : P15.b.Params) (xa : P15.a.Vars (paramMap p)) :
    P15.b.Vars p :=
  { x := fun k cfg h => if bFloorAssign p xa k = (cfg, h) then 1 else 0
    y := fun k cfg h i a =>
      if bFloorAssign p xa k = (cfg, h) ∧ a.val < p.cap cfg
          ∧ bSectorTotal p xa (p.jApt cfg a) h (k, a) = i
      then 1 else 0 }

/-- Under A-feasibility, the floor assignment realizes the prescribed fiber
cardinalities: the number of floors mapped to `(cfg, h)` is `(xa.x cfg h).toNat`. -/
private lemma bFloorAssign_spec (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) :
    ∀ q : Fin p.nV × Fin p.nH,
      (univ.filter (fun k => bFloorAssign p xa k = q)).card = (xa.x q.1 q.2).toNat := by
  classical
  haveI := p.hnV
  haveI := p.hnH
  have hxnn : ∀ (cfg : Fin p.nV) (h' : Fin p.nH), 0 ≤ xa.x cfg h' := hf.hx_nn
  have hcond :
      (∑ q : Fin p.nV × Fin p.nH, (xa.x q.1 q.2).toNat) = Fintype.card (Fin p.nK) := by
    rw [Fintype.card_fin]
    have hZ : ((∑ q : Fin p.nV × Fin p.nH, (xa.x q.1 q.2).toNat : ℕ) : ℤ) = (p.nK : ℤ) := by
      rw [Nat.cast_sum]
      have : ∀ q : Fin p.nV × Fin p.nH, ((xa.x q.1 q.2).toNat : ℤ) = xa.x q.1 q.2 := by
        intro q; exact Int.toNat_of_nonneg (hxnn q.1 q.2)
      simp_rw [this]
      rw [Fintype.sum_prod_type]
      exact hf.hfloors
    exact_mod_cast hZ
  have hrw : bFloorAssign p xa
      = (exists_block_assign' (fun q : Fin p.nV × Fin p.nH => (xa.x q.1 q.2).toNat) hcond).choose := by
    unfold bFloorAssign
    rw [dif_pos hcond]
  rw [hrw]
  exact (exists_block_assign' (fun q : Fin p.nV × Fin p.nH => (xa.x q.1 q.2).toNat) hcond).choose_spec

/-- **Crux count.** Under A-feasibility, the number of valid slots of the
`(area j, owner h)` group equals the total sector demand `∑ i, (xa.y i j h).toNat`.
Combines the floor fiber counts with the A-side consistency constraint. -/
private lemma card_bValid (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (j : Fin p.nJ) (h : Fin p.nH) :
    Fintype.card {ka : Fin p.nK × Fin p.nA // bValid p (bFloorAssign p xa) j h ka}
      = ∑ i : Fin p.nI, (xa.y i j h).toNat := by
  classical
  set fowner := bFloorAssign p xa with hfo
  -- Inner-`a` count for a fixed floor `k`.
  have hinner : ∀ k : Fin p.nK,
      (∑ a : Fin p.nA, if bValid p fowner j h (k, a) then 1 else 0)
        = if (fowner k).2 = h
          then ((apts p.cap (fowner k).1 p.nA).filter
                  (fun a => p.jApt (fowner k).1 a = j)).card
          else 0 := by
    intro k
    by_cases hh2 : (fowner k).2 = h
    · rw [if_pos hh2]
      rw [Finset.card_filter]
      rw [show (apts p.cap (fowner k).1 p.nA)
            = (univ : Finset (Fin p.nA)).filter (fun a => a.val < p.cap (fowner k).1)
          from rfl, Finset.sum_filter]
      apply Finset.sum_congr rfl
      intro a _
      unfold bValid
      simp only [hh2, true_and]
      by_cases hlt : a.val < p.cap (fowner k).1
      · by_cases hj : p.jApt (fowner k).1 a = j <;> simp [hlt, hj]
      · simp [hlt]
    · rw [if_neg hh2]
      apply Finset.sum_eq_zero
      intro a _
      rw [if_neg]
      unfold bValid
      rintro ⟨hc, _, _⟩; exact hh2 hc
  -- Reduce the subtype count to a sum over floors.
  rw [Fintype.card_subtype, Finset.card_filter, Fintype.sum_prod_type]
  simp_rw [hinner]
  -- Fiberwise: collect floors by their assigned `(cfg, h')` pair.
  rw [← Finset.sum_fiberwise (univ : Finset (Fin p.nK)) fowner
        (fun k => if (fowner k).2 = h
          then ((apts p.cap (fowner k).1 p.nA).filter
                  (fun a => p.jApt (fowner k).1 a = j)).card else 0)]
  have hfib : ∀ q : Fin p.nV × Fin p.nH,
      (∑ k ∈ univ.filter (fun k => fowner k = q),
          if (fowner k).2 = h
          then ((apts p.cap (fowner k).1 p.nA).filter
                  (fun a => p.jApt (fowner k).1 a = j)).card else 0)
        = (xa.x q.1 q.2).toNat *
            (if q.2 = h
             then ((apts p.cap q.1 p.nA).filter (fun a => p.jApt q.1 a = j)).card else 0) := by
    intro q
    rw [Finset.sum_congr rfl
          (g := fun _ => if q.2 = h
            then ((apts p.cap q.1 p.nA).filter (fun a => p.jApt q.1 a = j)).card else 0)
          (by intro k hk; rw [(Finset.mem_filter.mp hk).2])]
    rw [Finset.sum_const, smul_eq_mul]
    rw [hfo, bFloorAssign_spec p xa hf q]
  rw [Fintype.sum_prod_type]
  simp_rw [hfib]
  -- Collapse the owner sum.
  have hcol : ∀ cfg : Fin p.nV,
      (∑ h' : Fin p.nH, (xa.x cfg h').toNat *
          (if h' = h then ((apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j)).card else 0))
        = (xa.x cfg h).toNat *
            ((apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j)).card := by
    intro cfg
    rw [Finset.sum_congr rfl
          (g := fun h' => if h' = h
            then (xa.x cfg h').toNat *
              ((apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j)).card else 0)
          (by intro h' _; split_ifs with hh' <;> simp [hh'])]
    rw [Finset.sum_ite_eq' univ h
          (fun h' => (xa.x cfg h').toNat *
            ((apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j)).card)]
    simp
  simp_rw [hcol]
  -- Cast to ℤ and use consistency.
  have hxnn : ∀ (cfg : Fin p.nV) (h' : Fin p.nH), 0 ≤ xa.x cfg h' := hf.hx_nn
  have hynn : ∀ (i : Fin p.nI) (j : Fin p.nJ) (h' : Fin p.nH), 0 ≤ xa.y i j h' := hf.hy_nn
  have hZ : ((∑ cfg : Fin p.nV, (xa.x cfg h).toNat *
        ((apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j)).card : ℕ) : ℤ)
      = ((∑ i : Fin p.nI, (xa.y i j h).toNat : ℕ) : ℤ) := by
    push_cast
    have hL : ∀ cfg : Fin p.nV,
        (((xa.x cfg h).toNat : ℤ) *
          (((apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j)).card : ℤ))
        = Rcount p j cfg * xa.x cfg h := by
      intro cfg
      rw [Int.toNat_of_nonneg (hxnn cfg h)]
      unfold Rcount
      ring
    simp_rw [hL]
    have hR : ∀ i : Fin p.nI, ((xa.y i j h).toNat : ℤ) = xa.y i j h := by
      intro i; exact Int.toNat_of_nonneg (hynn i j h)
    simp_rw [hR]
    exact hf.hconsistency j h
  exact Nat.cast_injective hZ

/-- Under A-feasibility, the sector assignment realizes the prescribed fiber
cardinalities: the number of slots mapped to sector `i` is `(xa.y i j h).toNat`. -/
private lemma bSectorAssign_spec (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (j : Fin p.nJ) (h : Fin p.nH) :
    ∀ i : Fin p.nI,
      (univ.filter (fun d => bSectorAssign p xa j h d = i)).card = (xa.y i j h).toNat := by
  classical
  haveI := p.hnI
  have hcond : (∑ i : Fin p.nI, (xa.y i j h).toNat)
      = Fintype.card {ka : Fin p.nK × Fin p.nA // bValid p (bFloorAssign p xa) j h ka} :=
    (card_bValid p xa hf j h).symm
  have hrw : bSectorAssign p xa j h
      = (exists_block_assign' (fun i : Fin p.nI => (xa.y i j h).toNat) hcond).choose := by
    unfold bSectorAssign
    rw [dif_pos hcond]
  rw [hrw]
  exact (exists_block_assign' (fun i : Fin p.nI => (xa.y i j h).toNat) hcond).choose_spec

/-- Aggregating the B-floor variable over floors recovers the A-floor count. -/
private lemma agg_x (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (cfg : Fin p.nV) (h : Fin p.nH) :
    ∑ k : Fin p.nK, (bwd p xa).x k cfg h = xa.x cfg h := by
  classical
  show ∑ k : Fin p.nK, (if bFloorAssign p xa k = (cfg, h) then (1 : ℤ) else 0) = xa.x cfg h
  rw [Finset.sum_boole]
  have hb := bFloorAssign_spec p xa hf (cfg, h)
  simp only at hb
  rw [hb]
  exact Int.toNat_of_nonneg (hf.hx_nn cfg h)

/-- Aggregating the B-apartment variable over floors, configurations and the
apartments of area `j` recovers the A-apartment count `xa.y i j h`. -/
private lemma agg_y (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (i : Fin p.nI) (j : Fin p.nJ) (h : Fin p.nH) :
    ∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
        ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
          (bwd p xa).y k cfg h i a = xa.y i j h := by
  classical
  set fowner := bFloorAssign p xa with hfo
  set F : Fin p.nK × Fin p.nA → ℤ :=
    fun ka => if bSectorTotal p xa j h ka = i then 1 else 0 with hFdef
  -- Step A: the sector-fiber count equals the target.
  have hT : (∑ d : {ka : Fin p.nK × Fin p.nA // bValid p fowner j h ka},
              if bSectorAssign p xa j h d = i then (1 : ℤ) else 0) = xa.y i j h := by
    rw [Finset.sum_boole, bSectorAssign_spec p xa hf j h i]
    exact Int.toNat_of_nonneg (hf.hy_nn i j h)
  -- Step B: rewrite that subtype-sum as a double sum over floors and apartments.
  have hTexp : (∑ d : {ka : Fin p.nK × Fin p.nA // bValid p fowner j h ka},
              if bSectorAssign p xa j h d = i then (1 : ℤ) else 0)
      = ∑ k : Fin p.nK, ∑ a : Fin p.nA,
          (if bValid p fowner j h (k, a) then F (k, a) else 0) := by
    have hsub : (∑ d : {ka : Fin p.nK × Fin p.nA // bValid p fowner j h ka},
              if bSectorAssign p xa j h d = i then (1 : ℤ) else 0)
        = ∑ d : {ka : Fin p.nK × Fin p.nA // bValid p fowner j h ka}, F d.val := by
      apply Finset.sum_congr rfl
      intro d _
      have : bSectorTotal p xa j h d.val = bSectorAssign p xa j h d := by
        unfold bSectorTotal
        rw [dif_pos d.property]
      rw [hFdef]; simp only [this]
    rw [hsub, ← Finset.sum_subtype (univ.filter (bValid p fowner j h))
          (p := bValid p fowner j h) (by intro x; simp) F,
        Finset.sum_filter, Fintype.sum_prod_type]
  -- Step C: the target LHS matches the same double sum, floor by floor.
  have hpk : ∀ k : Fin p.nK,
      (∑ cfg : Fin p.nV, ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
          (bwd p xa).y k cfg h i a)
        = ∑ a : Fin p.nA, (if bValid p fowner j h (k, a) then F (k, a) else 0) := by
    intro k
    -- Common value: `if owner matches then (sum of F over area-j apartments) else 0`.
    have hL :
        (∑ cfg : Fin p.nV, ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            (bwd p xa).y k cfg h i a)
        = if (fowner k).2 = h
          then (∑ a ∈ (apts p.cap (fowner k).1 p.nA).filter
                  (fun a => p.jApt (fowner k).1 a = j), F (k, a))
          else 0 := by
      have hyB : ∀ cfg : Fin p.nV,
          (∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
              (bwd p xa).y k cfg h i a)
          = if fowner k = (cfg, h)
            then (∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j), F (k, a))
            else 0 := by
        intro cfg
        rw [Finset.sum_congr rfl
              (g := fun a => if fowner k = (cfg, h) then F (k, a) else 0) ?_]
        · rw [Finset.sum_ite_irrel, Finset.sum_const_zero]
        · intro a ha
          have ha1 : a.val < p.cap cfg := by
            simpa [apts] using (Finset.mem_filter.mp ha).1
          have ha2 : p.jApt cfg a = j := (Finset.mem_filter.mp ha).2
          show (if fowner k = (cfg, h) ∧ a.val < p.cap cfg
                  ∧ bSectorTotal p xa (p.jApt cfg a) h (k, a) = i then (1 : ℤ) else 0)
              = if fowner k = (cfg, h) then F (k, a) else 0
          rw [ha2, hFdef]
          by_cases hfk : fowner k = (cfg, h) <;> simp [hfk, ha1]
      simp_rw [hyB]
      exact sum_ite_fowner_eq (fowner k) h
        (fun cfg => ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j), F (k, a))
    have hR :
        (∑ a : Fin p.nA, (if bValid p fowner j h (k, a) then F (k, a) else 0))
        = if (fowner k).2 = h
          then (∑ a ∈ (apts p.cap (fowner k).1 p.nA).filter
                  (fun a => p.jApt (fowner k).1 a = j), F (k, a))
          else 0 := by
      have hRpt : ∀ a : Fin p.nA,
          (if bValid p fowner j h (k, a) then F (k, a) else 0)
          = if (fowner k).2 = h
            then (if a.val < p.cap (fowner k).1 ∧ p.jApt (fowner k).1 a = j
                  then F (k, a) else 0)
            else 0 := by
        intro a
        unfold bValid
        by_cases hh2 : (fowner k).2 = h <;> simp [hh2]
      simp_rw [hRpt]
      rw [Finset.sum_ite_irrel, Finset.sum_const_zero]
      by_cases hh2 : (fowner k).2 = h
      · rw [if_pos hh2, if_pos hh2]
        rw [← Finset.sum_filter, Finset.filter_filter]
      · rw [if_neg hh2, if_neg hh2]
    rw [hL, hR]
  rw [← hT, hTexp]
  exact Finset.sum_congr rfl (fun k _ => hpk k)

/-- When the A-side demand `xa.y i j h` is zero, no valid slot is assigned to
sector `i` (its fiber is empty). Used for the forbidden-assignment constraints. -/
private lemma bSector_ne (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (j : Fin p.nJ) (h : Fin p.nH) (i : Fin p.nI)
    (hzero : xa.y i j h = 0)
    (d : {ka : Fin p.nK × Fin p.nA // bValid p (bFloorAssign p xa) j h ka}) :
    bSectorAssign p xa j h d ≠ i := by
  classical
  intro hcon
  have hmem : d ∈ univ.filter (fun d => bSectorAssign p xa j h d = i) := by
    simp [hcon]
  have hcard := bSectorAssign_spec p xa hf j h i
  rw [hzero] at hcard
  simp only [Int.toNat_zero] at hcard
  rw [Finset.card_eq_zero] at hcard
  rw [hcard] at hmem
  exact absurd hmem (Finset.notMem_empty _)

/-- Aggregating the B-apartment variable over floors, configurations and all
apartments (of every area) recovers the A-sector count for owner `h`. -/
private lemma agg_y_apts (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (i : Fin p.nI) (h' : Fin p.nH) :
    ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ a ∈ apts p.cap cfg p.nA,
        (bwd p xa).y k cfg h' i a = ∑ j : Fin p.nJ, xa.y i j h' := by
  classical
  haveI := p.hnJ
  have step : ∀ (k : Fin p.nK) (cfg : Fin p.nV),
      (∑ a ∈ apts p.cap cfg p.nA, (bwd p xa).y k cfg h' i a)
      = ∑ j : Fin p.nJ, ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
          (bwd p xa).y k cfg h' i a := by
    intro k cfg
    rw [← Finset.sum_fiberwise (apts p.cap cfg p.nA) (fun a => p.jApt cfg a)
          (fun a => (bwd p xa).y k cfg h' i a)]
  simp_rw [step]
  have hswap : ∀ k : Fin p.nK,
      (∑ cfg : Fin p.nV, ∑ j : Fin p.nJ,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            (bwd p xa).y k cfg h' i a)
      = ∑ j : Fin p.nJ, ∑ cfg : Fin p.nV,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            (bwd p xa).y k cfg h' i a := fun k => Finset.sum_comm
  simp_rw [hswap]
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl
  intro j _
  exact agg_y p xa hf i j h'

/-- The configuration capacity is the total over areas of the per-area counts. -/
private lemma sum_Rcount_eq_cap (p : P15.b.Params) (cfg : Fin p.nV) :
    (p.cap cfg : ℤ) = ∑ j : Fin p.nJ, Rcount p j cfg := by
  classical
  haveI := p.hnJ
  have hnat : (apts p.cap cfg p.nA).card
      = ∑ j : Fin p.nJ, ((apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j)).card :=
    Finset.card_eq_sum_card_fiberwise (t := (univ : Finset (Fin p.nJ)))
      (fun x _ => Finset.mem_univ (p.jApt cfg x))
  rw [card_apts] at hnat
  unfold Rcount
  rw [← Nat.cast_sum, ← hnat]

/-- Total apartment slots on floors owned by `h'` equal the owner's apartment
count, via the A-side consistency constraint. -/
private lemma sum_cap_x_eq (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (h' : Fin p.nH) :
    ∑ cfg : Fin p.nV, (p.cap cfg : ℤ) * xa.x cfg h'
      = ∑ i : Fin p.nI, ∑ j : Fin p.nJ, xa.y i j h' := by
  classical
  have hterm : ∀ cfg : Fin p.nV,
      (p.cap cfg : ℤ) * xa.x cfg h' = ∑ j : Fin p.nJ, Rcount p j cfg * xa.x cfg h' := by
    intro cfg; rw [sum_Rcount_eq_cap p cfg, Finset.sum_mul]
  simp_rw [hterm]
  rw [Finset.sum_comm]
  rw [show (∑ j : Fin p.nJ, ∑ cfg : Fin p.nV, Rcount p j cfg * xa.x cfg h')
        = ∑ j : Fin p.nJ, ∑ i : Fin p.nI, xa.y i j h' from ?_]
  · rw [Finset.sum_comm]
  · apply Finset.sum_congr rfl; intro j _; exact hf.hconsistency j h'

/-- The B-side sector count (over floors, configurations, owners and all
apartments) reduces to the A-side sector count `∑ j ∑ h, xa.y i j h`. -/
private lemma bwd_sector_count (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (i : Fin p.nI) :
    ∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ a ∈ apts p.cap cfg p.nA,
        (bwd p xa).y k cfg h' i a = ∑ j : Fin p.nJ, ∑ h' : Fin p.nH, xa.y i j h' := by
  classical
  haveI := p.hnH
  have e1 : ∀ k : Fin p.nK,
      (∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ a ∈ apts p.cap cfg p.nA,
          (bwd p xa).y k cfg h' i a)
      = ∑ h' : Fin p.nH, ∑ cfg : Fin p.nV, ∑ a ∈ apts p.cap cfg p.nA,
          (bwd p xa).y k cfg h' i a := fun k => Finset.sum_comm
  simp_rw [e1]
  rw [Finset.sum_comm]
  simp_rw [agg_y_apts p xa hf i]
  rw [Finset.sum_comm]

/-- The B-side area-weighted count reduces to the A-side area-weighted count. -/
private lemma bwd_area_count (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (i : Fin p.nI) :
    (∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ a ∈ apts p.cap cfg p.nA,
        p.area (p.jApt cfg a) * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ j : Fin p.nJ, ∑ h' : Fin p.nH, p.area j * (xa.y i j h' : ℝ) := by
  classical
  haveI := p.hnH
  haveI := p.hnJ
  have agg_yR : ∀ (j : Fin p.nJ) (h' : Fin p.nH),
      (∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            ((bwd p xa).y k cfg h' i a : ℝ)) = (xa.y i j h' : ℝ) := by
    intro j h'; exact_mod_cast agg_y p xa hf i j h'
  have hsplit : ∀ (k : Fin p.nK) (cfg : Fin p.nV) (h' : Fin p.nH),
      (∑ a ∈ apts p.cap cfg p.nA, p.area (p.jApt cfg a) * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ j : Fin p.nJ, ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
          p.area j * ((bwd p xa).y k cfg h' i a : ℝ) := by
    intro k cfg h'
    rw [← Finset.sum_fiberwise (apts p.cap cfg p.nA) (fun a => p.jApt cfg a)
          (fun a => p.area (p.jApt cfg a) * ((bwd p xa).y k cfg h' i a : ℝ))]
    apply Finset.sum_congr rfl; intro j _
    apply Finset.sum_congr rfl; intro a ha
    rw [(Finset.mem_filter.mp ha).2]
  simp_rw [hsplit]
  have r1 : ∀ (k : Fin p.nK) (cfg : Fin p.nV),
      (∑ h' : Fin p.nH, ∑ j : Fin p.nJ,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            p.area j * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ j : Fin p.nJ, ∑ h' : Fin p.nH,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            p.area j * ((bwd p xa).y k cfg h' i a : ℝ) := fun _ _ => Finset.sum_comm
  simp_rw [r1]
  have r2 : ∀ k : Fin p.nK,
      (∑ cfg : Fin p.nV, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            p.area j * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ j : Fin p.nJ, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            p.area j * ((bwd p xa).y k cfg h' i a : ℝ) := fun _ => Finset.sum_comm
  simp_rw [r2]
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl; intro j _
  have r3 : ∀ k : Fin p.nK,
      (∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            p.area j * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ h' : Fin p.nH, ∑ cfg : Fin p.nV,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            p.area j * ((bwd p xa).y k cfg h' i a : ℝ) := fun _ => Finset.sum_comm
  simp_rw [r3]
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl; intro h' _
  rw [show (∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
            ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
              p.area j * ((bwd p xa).y k cfg h' i a : ℝ))
        = p.area j * (∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
            ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
              ((bwd p xa).y k cfg h' i a : ℝ)) from ?_]
  · rw [agg_yR j h']
  · simp_rw [Finset.mul_sum]

/-- The B-side owner "slot" count `∑ x * cap` reduces to the A-side owner
apartment count `∑ i ∑ j, xa.y i j h`. -/
private lemma bwd_owner_count (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (h' : Fin p.nH) :
    (∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ((bwd p xa).x k cfg h' : ℝ) * (p.cap cfg : ℝ))
      = ((∑ i : Fin p.nI, ∑ j : Fin p.nJ, xa.y i j h' : ℤ) : ℝ) := by
  classical
  rw [← sum_cap_x_eq p xa hf h']
  push_cast
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl; intro cfg _
  rw [← Finset.sum_mul, mul_comm]
  congr 1
  exact_mod_cast agg_x p xa hf cfg h'

/-- The backward map sends A-feasible solutions to B-feasible solutions. -/
private lemma bwd_feas (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) :
    P15.b.formulation.feasible p (bwd p xa) := by
  classical
  haveI := p.hnK
  haveI := p.hnV
  haveI := p.hnH
  haveI := p.hnI
  haveI := p.hnJ
  haveI := p.hnA
  refine
    { hfloor := ?_
      hlink := ?_
      hy_outside := ?_
      hsector_pct := ?_
      havg_area := ?_
      hmin_area := ?_
      hno_free_corp := ?_
      howner_pct := ?_
      hx_bin := ?_
      hy_bin := ?_ }
  · -- hfloor
    intro k
    show ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH,
        (if bFloorAssign p xa k = (cfg, h') then (1 : ℤ) else 0) = 1
    rw [← Fintype.sum_prod_type
          (f := fun q : Fin p.nV × Fin p.nH => if bFloorAssign p xa k = q then (1 : ℤ) else 0)]
    rw [Finset.sum_ite_eq univ (bFloorAssign p xa k) (fun _ => (1 : ℤ))]
    simp
  · -- hlink
    intro k cfg h' a ha
    have ha1 : a.val < p.cap cfg := by simpa [apts] using ha
    show (∑ i : Fin p.nI, if bFloorAssign p xa k = (cfg, h') ∧ a.val < p.cap cfg
            ∧ bSectorTotal p xa (p.jApt cfg a) h' (k, a) = i then (1 : ℤ) else 0)
        = if bFloorAssign p xa k = (cfg, h') then (1 : ℤ) else 0
    by_cases hfk : bFloorAssign p xa k = (cfg, h')
    · rw [if_pos hfk]
      rw [Finset.sum_congr rfl
            (g := fun i => if bSectorTotal p xa (p.jApt cfg a) h' (k, a) = i then (1 : ℤ) else 0)
            (by intro i _; simp [hfk, ha1])]
      rw [Finset.sum_ite_eq univ (bSectorTotal p xa (p.jApt cfg a) h' (k, a)) (fun _ => (1 : ℤ))]
      simp
    · rw [if_neg hfk]
      apply Finset.sum_eq_zero
      intro i _
      rw [if_neg]; rintro ⟨hc, _, _⟩; exact hfk hc
  · -- hy_outside
    intro k cfg h' i a hout
    show (if bFloorAssign p xa k = (cfg, h') ∧ a.val < p.cap cfg
            ∧ bSectorTotal p xa (p.jApt cfg a) h' (k, a) = i then (1 : ℤ) else 0) = 0
    have hlt : ¬ a.val < p.cap cfg := by simpa [apts] using hout
    rw [if_neg]
    rintro ⟨_, h2, _⟩; exact hlt h2
  · -- hsector_pct
    intro i
    rw [bwd_sector_count p xa hf i]
    rw [show (∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ i' : Fin p.nI,
              ∑ a ∈ apts p.cap cfg p.nA, (bwd p xa).y k cfg h' i' a)
          = ∑ l : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH, xa.y l j h' from ?_]
    · exact hf.hsector_pct i
    · have s1 : ∀ (k : Fin p.nK) (cfg : Fin p.nV),
          (∑ h' : Fin p.nH, ∑ i' : Fin p.nI, ∑ a ∈ apts p.cap cfg p.nA,
              (bwd p xa).y k cfg h' i' a)
          = ∑ i' : Fin p.nI, ∑ h' : Fin p.nH, ∑ a ∈ apts p.cap cfg p.nA,
              (bwd p xa).y k cfg h' i' a := fun _ _ => Finset.sum_comm
      simp_rw [s1]
      have s2 : ∀ k : Fin p.nK,
          (∑ cfg : Fin p.nV, ∑ i' : Fin p.nI, ∑ h' : Fin p.nH, ∑ a ∈ apts p.cap cfg p.nA,
              (bwd p xa).y k cfg h' i' a)
          = ∑ i' : Fin p.nI, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ a ∈ apts p.cap cfg p.nA,
              (bwd p xa).y k cfg h' i' a := fun _ => Finset.sum_comm
      simp_rw [s2]
      rw [Finset.sum_comm]
      simp_rw [bwd_sector_count p xa hf]
  · -- havg_area
    intro i
    rw [bwd_area_count p xa hf i, bwd_sector_count p xa hf i]
    exact hf.havg_area i
  · -- hmin_area
    intro k cfg h' i a _ hlt
    show (if bFloorAssign p xa k = (cfg, h') ∧ a.val < p.cap cfg
            ∧ bSectorTotal p xa (p.jApt cfg a) h' (k, a) = i then (1 : ℤ) else 0) = 0
    have hzero : xa.y i (p.jApt cfg a) h' = 0 := hf.hmin_area i (p.jApt cfg a) h' hlt
    have hnc : ¬ (bFloorAssign p xa k = (cfg, h') ∧ a.val < p.cap cfg
        ∧ bSectorTotal p xa (p.jApt cfg a) h' (k, a) = i) := by
      rintro ⟨hfk, ha1, hsec⟩
      have hvalid : bValid p (bFloorAssign p xa) (p.jApt cfg a) h' (k, a) := by
        refine ⟨?_, ?_, ?_⟩
        · rw [hfk]
        · rw [hfk]; exact ha1
        · rw [hfk]
      have htot : bSectorTotal p xa (p.jApt cfg a) h' (k, a)
          = bSectorAssign p xa (p.jApt cfg a) h' ⟨(k, a), hvalid⟩ := by
        unfold bSectorTotal; rw [dif_pos hvalid]
      rw [htot] at hsec
      exact bSector_ne p xa hf (p.jApt cfg a) h' i hzero ⟨(k, a), hvalid⟩ hsec
    rw [if_neg hnc]
  · -- hno_free_corp
    intro k cfg a _
    show (if bFloorAssign p xa k = (cfg, ⟨p.hCorp, p.hhCorp⟩) ∧ a.val < p.cap cfg
            ∧ bSectorTotal p xa (p.jApt cfg a) ⟨p.hCorp, p.hhCorp⟩ (k, a)
                = ⟨p.iFree, p.hiFree⟩ then (1 : ℤ) else 0) = 0
    have hzero : xa.y ⟨p.iFree, p.hiFree⟩ (p.jApt cfg a) ⟨p.hCorp, p.hhCorp⟩ = 0 :=
      hf.hno_free_corp (p.jApt cfg a)
    have hnc : ¬ (bFloorAssign p xa k = (cfg, ⟨p.hCorp, p.hhCorp⟩) ∧ a.val < p.cap cfg
        ∧ bSectorTotal p xa (p.jApt cfg a) ⟨p.hCorp, p.hhCorp⟩ (k, a)
            = ⟨p.iFree, p.hiFree⟩) := by
      rintro ⟨hfk, ha1, hsec⟩
      have hvalid : bValid p (bFloorAssign p xa) (p.jApt cfg a) ⟨p.hCorp, p.hhCorp⟩ (k, a) := by
        refine ⟨?_, ?_, ?_⟩
        · rw [hfk]
        · rw [hfk]; exact ha1
        · rw [hfk]
      have htot : bSectorTotal p xa (p.jApt cfg a) ⟨p.hCorp, p.hhCorp⟩ (k, a)
          = bSectorAssign p xa (p.jApt cfg a) ⟨p.hCorp, p.hhCorp⟩ ⟨(k, a), hvalid⟩ := by
        unfold bSectorTotal; rw [dif_pos hvalid]
      rw [htot] at hsec
      exact bSector_ne p xa hf (p.jApt cfg a) ⟨p.hCorp, p.hhCorp⟩ ⟨p.iFree, p.hiFree⟩
        hzero ⟨(k, a), hvalid⟩ hsec
    rw [if_neg hnc]
  · -- howner_pct
    intro h'
    rw [bwd_owner_count p xa hf h']
    rw [show (∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h'' : Fin p.nH,
              ((bwd p xa).x k cfg h'' : ℝ) * (p.cap cfg : ℝ))
          = ((∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h'' : Fin p.nH, xa.y i j h'' : ℤ) : ℝ) from ?_]
    · exact hf.howner_pct h'
    · have e : ∀ k : Fin p.nK,
          (∑ cfg : Fin p.nV, ∑ h'' : Fin p.nH, ((bwd p xa).x k cfg h'' : ℝ) * (p.cap cfg : ℝ))
          = ∑ h'' : Fin p.nH, ∑ cfg : Fin p.nV,
              ((bwd p xa).x k cfg h'' : ℝ) * (p.cap cfg : ℝ) := fun _ => Finset.sum_comm
      simp_rw [e]
      rw [Finset.sum_comm]
      simp_rw [bwd_owner_count p xa hf]
      push_cast
      rw [Finset.sum_comm]
      apply Finset.sum_congr rfl; intro i _
      rw [Finset.sum_comm]
  · -- hx_bin
    intro k cfg h'
    show (if bFloorAssign p xa k = (cfg, h') then (1 : ℤ) else 0) = 0
        ∨ (if bFloorAssign p xa k = (cfg, h') then (1 : ℤ) else 0) = 1
    split_ifs <;> simp
  · -- hy_bin
    intro k cfg h' i a
    show (if bFloorAssign p xa k = (cfg, h') ∧ a.val < p.cap cfg
            ∧ bSectorTotal p xa (p.jApt cfg a) h' (k, a) = i then (1 : ℤ) else 0) = 0
        ∨ (if bFloorAssign p xa k = (cfg, h') ∧ a.val < p.cap cfg
            ∧ bSectorTotal p xa (p.jApt cfg a) h' (k, a) = i then (1 : ℤ) else 0) = 1
    split_ifs <;> simp

-- ============================================================================
-- § Backward Objective Equality
-- ============================================================================

/-- The B-side profit contribution for a fixed sector/owner reduces to the
A-side profit contribution. -/
private lemma bwd_profit_count (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) (i : Fin p.nI) (h' : Fin p.nH) :
    (∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ a ∈ apts p.cap cfg p.nA,
        p.pProfit i (p.jApt cfg a) h' * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ j : Fin p.nJ, p.pProfit i j h' * (xa.y i j h' : ℝ) := by
  classical
  haveI := p.hnJ
  have agg_yR : ∀ j : Fin p.nJ,
      (∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            ((bwd p xa).y k cfg h' i a : ℝ)) = (xa.y i j h' : ℝ) := by
    intro j; exact_mod_cast agg_y p xa hf i j h'
  have hsplit : ∀ (k : Fin p.nK) (cfg : Fin p.nV),
      (∑ a ∈ apts p.cap cfg p.nA,
          p.pProfit i (p.jApt cfg a) h' * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ j : Fin p.nJ, ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
          p.pProfit i j h' * ((bwd p xa).y k cfg h' i a : ℝ) := by
    intro k cfg
    rw [← Finset.sum_fiberwise (apts p.cap cfg p.nA) (fun a => p.jApt cfg a)
          (fun a => p.pProfit i (p.jApt cfg a) h' * ((bwd p xa).y k cfg h' i a : ℝ))]
    apply Finset.sum_congr rfl; intro j _
    apply Finset.sum_congr rfl; intro a ha
    rw [(Finset.mem_filter.mp ha).2]
  simp_rw [hsplit]
  have r : ∀ k : Fin p.nK,
      (∑ cfg : Fin p.nV, ∑ j : Fin p.nJ,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            p.pProfit i j h' * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ j : Fin p.nJ, ∑ cfg : Fin p.nV,
          ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
            p.pProfit i j h' * ((bwd p xa).y k cfg h' i a : ℝ) := fun _ => Finset.sum_comm
  simp_rw [r]
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl; intro j _
  rw [show (∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
            ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
              p.pProfit i j h' * ((bwd p xa).y k cfg h' i a : ℝ))
        = p.pProfit i j h' * (∑ k : Fin p.nK, ∑ cfg : Fin p.nV,
            ∑ a ∈ (apts p.cap cfg p.nA).filter (fun a => p.jApt cfg a = j),
              ((bwd p xa).y k cfg h' i a : ℝ)) from ?_]
  · rw [agg_yR j]
  · simp_rw [Finset.mul_sum]

/-- The backward map preserves the objective value pointwise. -/
private lemma bwd_obj_eq (p : P15.b.Params) (xa : P15.a.Vars (paramMap p))
    (hf : P15.a.Feasible (paramMap p) xa) :
    P15.a.formulation.obj (paramMap p) xa = P15.b.formulation.obj p (bwd p xa) := by
  classical
  haveI := p.hnK
  haveI := p.hnV
  haveI := p.hnH
  haveI := p.hnI
  haveI := p.hnJ
  haveI := p.hnA
  show -(∑ i : Fin p.nI, ∑ j : Fin p.nJ, ∑ h' : Fin p.nH,
          p.pProfit i j h' * ((xa.y i j h' : ℝ)))
      = -(∑ k : Fin p.nK, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ i : Fin p.nI,
          ∑ a ∈ apts p.cap cfg p.nA,
            p.pProfit i (p.jApt cfg a) h' * ((bwd p xa).y k cfg h' i a : ℝ))
  congr 1
  symm
  -- reorder the B-side sum: bring `i` to the front, then `h'`.
  have e1 : ∀ (k : Fin p.nK) (cfg : Fin p.nV),
      (∑ h' : Fin p.nH, ∑ i : Fin p.nI, ∑ a ∈ apts p.cap cfg p.nA,
          p.pProfit i (p.jApt cfg a) h' * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ i : Fin p.nI, ∑ h' : Fin p.nH, ∑ a ∈ apts p.cap cfg p.nA,
          p.pProfit i (p.jApt cfg a) h' * ((bwd p xa).y k cfg h' i a : ℝ) :=
    fun _ _ => Finset.sum_comm
  simp_rw [e1]
  have e2 : ∀ k : Fin p.nK,
      (∑ cfg : Fin p.nV, ∑ i : Fin p.nI, ∑ h' : Fin p.nH, ∑ a ∈ apts p.cap cfg p.nA,
          p.pProfit i (p.jApt cfg a) h' * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ i : Fin p.nI, ∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ a ∈ apts p.cap cfg p.nA,
          p.pProfit i (p.jApt cfg a) h' * ((bwd p xa).y k cfg h' i a : ℝ) :=
    fun _ => Finset.sum_comm
  simp_rw [e2]
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl; intro i _
  -- now bring `h'` to the front within fixed `i`.
  have e3 : ∀ k : Fin p.nK,
      (∑ cfg : Fin p.nV, ∑ h' : Fin p.nH, ∑ a ∈ apts p.cap cfg p.nA,
          p.pProfit i (p.jApt cfg a) h' * ((bwd p xa).y k cfg h' i a : ℝ))
      = ∑ h' : Fin p.nH, ∑ cfg : Fin p.nV, ∑ a ∈ apts p.cap cfg p.nA,
          p.pProfit i (p.jApt cfg a) h' * ((bwd p xa).y k cfg h' i a : ℝ) :=
    fun _ => Finset.sum_comm
  simp_rw [e3]
  rw [Finset.sum_comm]
  simp_rw [bwd_profit_count p xa hf i]
  rw [Finset.sum_comm]

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

/-- Formulation `P15.b` (per-floor/per-apartment binary model) is a
reformulation of formulation `P15.a` (aggregate integer count model), in the
constructive `A → B` orientation: a `P15.b`-instance is synthesized from each
`P15.a`-instance via `paramMap'`, and the aggregate/disaggregate machinery
transports feasibility and objective in both directions. -/
noncomputable def aBReformulation :
    MILPReformulation P15.a.formulation P15.b.formulation where
  paramMap    := paramMap'
  fwd         := fun p x => bwd (paramMap' p) (varCast p x)
  bwd         := fun p y => varCast' p (fwd (paramMap' p) y)
  fwd_feas    := fun p x hx => bwd_feas (paramMap' p) (varCast p x) (feas_to p x hx)
  bwd_feas    := fun p y hy => feas_from p (fwd (paramMap' p) y)
                    (fwd_feas (paramMap' p) y hy)
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj     := fun p x hx =>
                    (bwd_obj_eq (paramMap' p) (varCast p x) (feas_to p x hx)).symm
  bwd_obj     := fun p y _ => (fwd_obj_eq (paramMap' p) y).symm

end P15
