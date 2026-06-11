import Common
import problems.p7.formulations.a.Formulation
import problems.p7.formulations.b.Formulation

/-!
# p7/a → p7/b is **not** a reformulation

Formulation `b` extends formulation `a` with cutting plane EC1
(Horizontal-Left Break):

  h_{i,j} ≤ ∑_{(a,b): b = j-1} t_i^{ab}    ∀ i, ∀ j ≥ 1.

EC1 is **not** valid for the IMO 2025 P6 rectangular tiling problem: there
exist tilings (`P7.a.Feasible` solutions) that violate it. A concrete
counter-example at N = 3 is given by `imo6_ce_left_break` in
`refs/evocut-formalized-proofs/EvocutFormalized/V1/IMO6.lean` (holes at
(0,1), (1,2), (2,0); strip (0,0) active across rows 0 and 1 so
`t_0^{(0,0)} = 0` but `h_{0,1} = 1`).

## Proof strategy (TODO)

Given `R : MILPReformulation P7.a.formulation P7.b.formulation`:

1. The new `bwd_fwd` axiom forces `R.fwd p` to be injective on
   a-feasible points.
2. At N = 3 (with appropriate `paramMap`), the set of a-feasible tilings
   is finite and strictly contains the set of b-feasible tilings — the
   counter-example above is a-feasible but not b-feasible.
3. An injection from a finite set into a strictly smaller finite set is
   impossible, yielding a contradiction.

Carrying this out formally requires (i) lifting the IMO6 counter-example
into `P7.a.Vars` with curried index encoding, (ii) discharging the eleven
feasibility constraints by `fin_cases`/`decide`, (iii) finitizing the
`Feasible` sets (binary-valued so each is a subset of a `Fintype`), and
(iv) handling `R.paramMap`'s freedom on `Params := { N }`. -/

namespace P7

/--
There is no `MILPReformulation` from `P7.a.formulation` to `P7.b.formulation`.

EC1 (used by `P7.b`) is an invalid cutting plane for the IMO 2025 P6 tiling
problem; see the file docstring for the proof strategy. -/
theorem aBNotReformulation :
    IsEmpty (MILPReformulation P7.a.formulation P7.b.formulation) := by
  sorry

end P7
