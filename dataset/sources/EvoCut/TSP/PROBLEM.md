# Traveling Salesman Problem (TSP)

**Source:** `yazdani2025_v1` Section 13.1 and `yazdani2025_v2` Section 14.1

## Summary

TSP aims to find the shortest cycle in a graph that visits every node
exactly once. It is a classic NP-hard combinatorial optimization problem
that admits a pure MILP model. We use the Miller-Tucker-Zemlin (MTZ)
formulation.

## Formulation

### Model

$$
\begin{aligned}
\min\;&\sum_{(i,j)\in A} c_{ij}\,x_{ij}\\[3pt]
\text{s.t.}\;
&\sum_{j\in V\setminus\{i\}} x_{ij}=1 &&\forall i\in V\\
&\sum_{i\in V\setminus\{j\}} x_{ij}=1 &&\forall j\in V\\
&u_i-u_j+n\,x_{ij}\le n-1 &&\forall i,j\in V\setminus\{1\},\;i\neq j\\
&x_{ij}\in\{0,1\} &&\forall(i,j)\in A\\
&1\le u_i\le n &&\forall i\in V,\quad u_1=1
\end{aligned}.
$$

### Notation

- $V$: set of cities to be visited (index $i,j$).
- $A\subseteq V\times V$: set of directed arcs $(i,j)$.
- $c_{ij}$: travel cost from city $i$ to city $j$.
- $n=|V|$: number of cities.
- $x_{ij}\in\{0,1\}$: equals 1 iff the tour goes directly from city $i$ to city $j$.
- $u_i\in[1,n]$: MTZ position of city $i$ in the tour; $u_1$ is fixed to 1 to anchor the numbering.

## Cuts

### Version 1

#### EC1: Depot-Exit Position Bound

If the tour leaves the depot directly to city $j$, then $j$ must be first in the ordering:
$$u_j \;\le\; 2 + (n-2)(1-x_{1j}) \qquad \forall j\in V\setminus\{1\}.$$

#### EC2: Depot-Entry Position Bound

If the tour returns to the depot directly from city $i$, then $i$ must be last in the ordering:
$$u_i \;\ge\; n - (n-2)(1-x_{i1}) \qquad \forall i\in V\setminus\{1\}.$$

#### EC3: Two-City Detour Elimination

For any two non-depot cities $i,j$, eliminates infeasible two-city detours through the depot:
$$x_{j1} + x_{ji} + (u_j-u_i-1) \;\le\; (n-1)(2-x_{1i}-x_{ij}) \qquad \forall i,j\in V\setminus\{1\},\;i\neq j.$$

### Version 2

#### EC1: Arc Symmetry

Eliminates two-city cycles by forbidding both directions of an arc simultaneously:
$$x_{ij} + x_{ji} \;\le\; 1 \qquad \forall i,j\in V,\; i<j.$$

#### EC2: Depot Triangle

Eliminates three-city subtours passing through the depot:
$$x_{1i}+x_{i1}+x_{1j}+x_{j1}+x_{ij}+x_{ji} \;\le\; 2 \qquad \forall i,j\in V\setminus\{1\},\; i<j.$$

#### EC3: Lifted Desrochers–Laporte MTZ Ordering

A lifted strengthening of the MTZ subtour-elimination constraint:
$$u_i - u_j + (n-1)\,x_{ij} + (n-3)\,x_{ji} \;\le\; n-2 \qquad \forall i,j\in V\setminus\{1\},\;i\neq j.$$

#### EC4: Lower MTZ Envelope

Tightens the lower bound on city $i$'s position using its depot-adjacent arcs:
$$u_i \;\ge\; 3 - x_{1i} + (n-3)\,x_{i1} \qquad \forall i\in V\setminus\{1\}.$$

#### EC5: Upper MTZ Envelope

Tightens the upper bound on city $i$'s position using its depot-adjacent arcs:
$$u_i \;\le\; (n-1) + x_{i1} - (n-3)\,x_{1i} \qquad \forall i\in V\setminus\{1\}.$$
