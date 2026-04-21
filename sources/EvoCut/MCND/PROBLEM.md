# Multi-Commodity Network Design (MCND)

**Source:** `yazdani2025_v1` Section 13.2 and `yazdani2025_v2` Section 14.2

## Summary

The MCND problem involves selecting a set of network links and assigning
multiple flow demands (commodities) at minimal cost. Each commodity must
be routed from its source to destination without exceeding link
capacities, and activating a link incurs a fixed cost. The MCND problem
is an NP-hard combinatorial problem that can be formulated as a MILP.

## Formulation

### Model

$$
\begin{aligned}
\min\;&
      \sum_{(i,j)\in A}\sum_{k\in K} c_{ij}\,x_{ijk}
      +\sum_{(i,j)\in A} f_{ij}\,y_{ij} \\[6pt]
\text{s.t.}\;
&\sum_{j:(i,j)\in A} x_{ijk}=d_k
   &&\forall k\in K,\; i=O_k \\[4pt]
&\sum_{j:(j,i)\in A} x_{jik}=d_k
   &&\forall k\in K,\; i=D_k \\[4pt]
&\sum_{j:(i,j)\in A} x_{ijk}-\sum_{j:(j,i)\in A} x_{jik}=0
   &&\forall k\in K,\; i\in N\setminus\{O_k,D_k\} \\[6pt]
&\sum_{k\in K} x_{ijk}\le u_{ij}\,y_{ij}
   &&\forall(i,j)\in A \\[4pt]
&x_{ijk}\ge 0
   &&\forall(i,j)\in A,\;k\in K \\[2pt]
&y_{ij}\in\{0,1\}
   &&\forall(i,j)\in A
\end{aligned}.
$$

### Notation

- $N$: set of all network nodes (index $i$).
- $A\subseteq N\times N$: set of candidate directed arcs $(i,j)$.
- $K$: set of commodities to be routed (index $k$).
- $O_k$, $D_k$: origin and destination nodes of commodity $k$.
- $d_k$: demand of commodity $k$ to be shipped from $O_k$ to $D_k$.
- $c_{ij}$: unit transportation cost on arc $(i,j)$.
- $f_{ij}$: fixed cost to activate arc $(i,j)$.
- $u_{ij}$: capacity of arc $(i,j)$.
- $x_{ijk}\ge 0$: flow of commodity $k$ on arc $(i,j)$.
- $y_{ij}\in\{0,1\}$: equals 1 iff arc $(i,j)$ is activated.

## Cuts

### Version 1

#### EC1: Destination In-Cut Bound

Let $\delta^{-}(D_k)$ be the set of arcs entering the destination $D_k$ of commodity $k$, and let $u^{\max}_k := \max_{(i,j)\in\delta^{-}(D_k)} u_{ij}$. High-capacity incoming arcs must be selected when demand is large:
$$\sum_{(i,j)\in \delta^{-}(D_k)} \bigl(u_{ij} + u^{\max}_k\bigr)\,y_{ij} \;\ge\; d_k + u^{\max}_k \qquad \forall k\in K.$$

### Version 2

For any node subset $S\subseteq N$, let $\delta^{+}(S):=\{(i,j)\in A : i\in S,\; j\notin S\}$ be the arcs leaving $S$, and $K(S):=\{k\in K : O_k\in S,\; D_k\notin S\}$ be the commodities that must cross this cut. For any bundle $B\subseteq K(S)$, let $D_B:=\sum_{k\in B} d_k$.

#### EC1: Knapsack-Cover Capacity Cut

The truncation $\min\{u_{ij},D_B\}$ prevents the LP relaxation from satisfying the cut using tiny fractional $y_{ij}$ on very high-capacity arcs:
$$\sum_{(i,j)\in \delta^{+}(S)} \min\{u_{ij},\,D_B\}\,y_{ij} \;\ge\; D_B \qquad \forall S\subseteq N,\;\forall B\subseteq K(S).$$

#### EC2: Cardinality Cut

Let $q_{S,B}$ be the smallest integer such that the sum of the $q_{S,B}$ largest capacities in $\delta^{+}(S)$ reaches $D_B$. At least $q_{S,B}$ arcs crossing the cut must be opened:
$$\sum_{(i,j)\in \delta^{+}(S)} y_{ij} \;\ge\; q_{S,B} \qquad \forall S\subseteq N,\;\forall B\subseteq K(S).$$
