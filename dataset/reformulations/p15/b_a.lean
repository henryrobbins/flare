import Common
import dataset.problems.p15.formulations.a.Formulation
import dataset.problems.p15.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset
open P15.b (apts)

namespace P15

/-!
# P15: Apartment-tower reformulation `B → A`

Formulation `P15.b` indexes floors `k ∈ [0, nK)` and apartments
`a ∈ A_v` explicitly with binary decision variables, while formulation
`P15.a` keeps only aggregate integer counts.
-/

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
    hR_nn    := Rcount_nn p
    harea_nn := p.harea_nn
    hm_nn    := p.hm_nn
    ha_nn    := p.hb_nn
    hs_nn    := p.hs_nn
    ho_nn    := p.ho_nn }

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

end P15
