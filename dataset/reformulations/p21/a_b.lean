import Common
import problems.p21.formulations.a.Formulation
import problems.p21.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P21

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P21.a.Params) : P21.b.Params :=
  { n                 := p.n
    m                 := p.m
    P                 := p.P
    E                 := p.E
    C                 := p.C
    hn_pos            := p.hn_pos
    hC_bin            := p.hC_bin
    hpartition        := p.hpartition
    hcluster_nonempty := p.hcluster_nonempty
    hedge_lt          := p.hedge_lt
    hperfect          := p.hperfect }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

section ForwardHelpers

variable {p : P21.a.Params} {v : P21.a.Vars p} (h : P21.a.Feasible p v)
include h

/--
For a fixed color `k`, at most one vertex of a clique `S` can be assigned
color `k`: if two distinct vertices `i j ∈ S` both had `w i k = w j k = 1`,
they would be adjacent (since `S` is a clique), and `hedge` on the connecting
edge would force `w i k + w j k ≤ 1`, a contradiction.
-/
private lemma clique_card_le_one (S : Finset (Fin p.n)) (hS : P21.b.IsClique p.E S)
    (k : Fin p.P) :
    (S.filter (fun i => v.w i k = 1)).card ≤ 1 := by
  rw [Finset.card_le_one]
  intro a ha b hb
  simp only [Finset.mem_filter] at ha hb
  by_contra hab
  have hadj := hS a ha.1 b hb.1 hab
  rcases hadj with ⟨e, he⟩ | ⟨e, he⟩ <;> {
    have hedge := h.hedge e k
    rw [he] at hedge
    linarith [ha.2, hb.2] }

/--
For a fixed color `k`, the sum of `w i k` over a clique `S` is at most `y k`.
If `y k = 0`, `hlink` forces every term to be `≤ 0`. If `y k = 1`,
`clique_card_le_one` bounds the number of `1`-terms in the sum (over a
binary-valued function) by `1`.
-/
private lemma clique_sum_le_y (S : Finset (Fin p.n)) (hS : P21.b.IsClique p.E S)
    (k : Fin p.P) :
    ∑ i ∈ S, v.w i k ≤ v.y k := by
  rcases h.hy_bin k with hy0 | hy1
  · rw [hy0]
    apply Finset.sum_nonpos
    intro i _
    have := h.hlink i k
    rw [hy0] at this
    exact this
  · rw [hy1]
    have hcard := clique_card_le_one h S hS k
    rw [← Finset.sum_filter_add_sum_filter_not S (fun i => v.w i k = 1)
        (fun i => v.w i k)]
    have h1 : ∑ i ∈ S.filter (fun i => v.w i k = 1), v.w i k =
        (S.filter (fun i => v.w i k = 1)).card := by
      rw [Finset.sum_congr rfl (fun i hi => (Finset.mem_filter.mp hi).2)]
      simp
    have h0 : ∑ i ∈ S.filter (fun i => ¬v.w i k = 1), v.w i k = 0 := by
      apply Finset.sum_eq_zero
      intro i hi
      exact (h.hw_bin i k).resolve_right (Finset.mem_filter.mp hi).2
    rw [h1, h0]
    simp only [add_zero]
    exact_mod_cast hcard

end ForwardHelpers

/-- **P21.a → P21.b**: the variables are unchanged; only the additional clique
constraint needs to be verified in `fwd_feas`. -/
private def fwd (p : P21.a.Params) (v : P21.a.Vars p) : P21.b.Vars (paramMap p) :=
  { y := v.y
    w := v.w }

private lemma fwd_feas (p : P21.a.Params) (v : P21.a.Vars p)
    (h : P21.a.Feasible p v) :
    P21.b.Feasible (paramMap p) (fwd p v) := by
  refine
    { hlink := h.hlink
      hedge := h.hedge
      hselect := h.hselect
      hclique := ?_
      hy_bin := h.hy_bin
      hw_bin := h.hw_bin }
  intro S hS
  calc ∑ i ∈ S, ∑ k : Fin p.P, v.w i k
      = ∑ k : Fin p.P, ∑ i ∈ S, v.w i k := Finset.sum_comm
    _ ≤ ∑ k : Fin p.P, v.y k := Finset.sum_le_sum (fun k _ => clique_sum_le_y h S hS k)

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-- **P21.b → P21.a**: the variables are unchanged; `b`'s `Feasible` already
contains every field of `a`'s `Feasible` (plus the extra `hclique` field), so
the backward direction simply forgets `hclique`. -/
private def bwd (p : P21.a.Params) (v : P21.b.Vars (paramMap p)) : P21.a.Vars p :=
  { y := v.y
    w := v.w }

private lemma bwd_feas (p : P21.a.Params) (v : P21.b.Vars (paramMap p))
    (h : P21.b.Feasible (paramMap p) v) :
    P21.a.Feasible p (bwd p v) :=
  { hlink   := h.hlink
    hedge   := h.hedge
    hselect := h.hselect
    hy_bin  := h.hy_bin
    hw_bin  := h.hw_bin }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aBReformulation : MILPReformulation P21.a.formulation P21.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P21
