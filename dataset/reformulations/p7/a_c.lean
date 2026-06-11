import Common
import problems.p7.formulations.a.Formulation
import problems.p7.formulations.c.Formulation

/-!
# p7/a → p7/c is **not** a reformulation

Formulation `c` extends formulation `a` with cutting plane EC2
(Horizontal-Right Break):

  h_{i,j} ≤ ∑_{(a,b): a = j+1} s_i^{ab}    ∀ i, ∀ j ≤ N-2.

EC2 is **not** valid for the IMO 2025 P6 rectangular tiling problem: there
exist tilings (`P7.a.Feasible` solutions) that violate it. A concrete
counter-example at N = 3 is given by `imo6_ce_right_break` in
`refs/evocut-formalized-proofs/EvocutFormalized/V1/IMO6.lean` (holes on the
diagonal (0,0), (1,1), (2,2); strip (2,2) active across rows 0 and 1 so
`s_1^{(2,2)} = 0` but `h_{1,1} = 1`).

## Proof strategy (TODO)

Given `R : MILPReformulation P7.a.formulation P7.c.formulation`:

1. The new `bwd_fwd` axiom forces `R.fwd p` to be injective on
   a-feasible points.
2. At N = 3 (with appropriate `paramMap`), the set of a-feasible tilings
   is finite and strictly contains the set of c-feasible tilings — the
   counter-example above is a-feasible but not c-feasible.
3. An injection from a finite set into a strictly smaller finite set is
   impossible, yielding a contradiction.

See `a_b.lean` for the parallel disproof of EC1; the structure of the
EC2 argument is identical. -/

namespace P7

/--
There is no `MILPReformulation` from `P7.a.formulation` to `P7.c.formulation`.

EC2 (used by `P7.c`) is an invalid cutting plane for the IMO 2025 P6 tiling
problem; see the file docstring for the proof strategy. -/
theorem aCNotReformulation :
    IsEmpty (MILPReformulation P7.a.formulation P7.c.formulation) := by
  sorry

end P7
