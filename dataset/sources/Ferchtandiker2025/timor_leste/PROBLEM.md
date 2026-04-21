# Timor-Leste Hospital Location (TLHL)

**Source:** `datasets/Ferchtandiker2025/timor_leste/`

## Summary

Timor-Leste, a country with significant rural populations and challenging terrain, faces difficulties in ensuring equitable access to healthcare. Given a set of households (with known populations), a set of existing hospitals that must remain open, and a set of candidate sites for new hospitals, the goal is to choose at most $p$ new hospital locations so as to maximize the number of people living within a maximum allowed travel distance $S$ of an open hospital. A household is considered covered only if at least one open hospital lies within distance $S$.

## Formulations

### Efficient

The efficient formulation introduces a single binary coverage variable $y_i$ per household, set to 1 if household $i$ is served by any open hospital within distance $S$. Coverage is linked to the hospital-opening decisions through indicator parameters $a_{ij}$ that pre-encode which hospitals are within range of each household.

#### Model

$$
\begin{aligned}
\max\;
&\sum_{i \in I} v_i y_i\\[3pt]
\text{s.t.}\;
&x_j = 1 && \forall j \in J_0\\
&\sum_{j \in J_1} x_j \leq p\\
&y_i \leq \sum_{j \in J} a_{ij} x_j && \forall i \in I\\
&x_j \in \{0,1\} && \forall j \in J\\
&y_i \in \{0,1\} && \forall i \in I
\end{aligned}.
$$

#### Notation

- $I$: index set of households, $i = 1, \ldots, n$.
- $J_0$: index set of existing hospitals, $j = 1, \ldots, m$.
- $J_1$: index set of candidate (potential) hospital locations, $j = m+1, \ldots, M$.
- $J = J_0 \cup J_1$: index set of all hospital sites.
- $v_i$: number of people in household or cluster $i \in I$.
- $d_{ij}$: travel distance from household $i \in I$ to hospital $j \in J$.
- $a_{ij}$: indicator parameter, $a_{ij} = 1$ if $d_{ij} \leq S$, $0$ otherwise.
- $S$: maximum allowed travel distance from household to hospital.
- $p$: maximum number of additional hospitals to be opened.
- $x_j \in \{0,1\}$: equals 1 iff hospital $j$ is opened.
- $y_i \in \{0,1\}$: equals 1 iff household $i$ is served by any hospital within $S$.

### Inefficient

The inefficient formulation uses explicit assignment variables $y_{ij}$ that indicate whether household $i$ is assigned to hospital $j$. It enforces that assignment is only permitted when the hospital is open, within distance $S$, and that each household is assigned to at most one hospital.

#### Model

$$
\begin{aligned}
\max\;
&\sum_{i \in I} \sum_{j \in J} v_i y_{ij}\\[3pt]
\text{s.t.}\;
&x_j = 1 && \forall j \in J_0\\
&\sum_{j \in J_1} x_j \leq p\\
&\sum_{i \in I} y_{ij} \leq |I| x_j && \forall j \in J\\
&\sum_{j \in J} y_{ij} \leq 1 && \forall i \in I\\
&y_{ij} \leq a_{ij} && \forall i \in I,\; \forall j \in J\\
&x_j \in \{0,1\} && \forall j \in J\\
&y_{ij} \in \{0,1\} && \forall i \in I,\; \forall j \in J
\end{aligned}.
$$

#### Notation

- $I$: index set of households, $i = 1, \ldots, n$.
- $J_0$: index set of existing hospitals, $j = 1, \ldots, m$.
- $J_1$: index set of candidate (potential) hospital locations, $j = m+1, \ldots, M$.
- $J = J_0 \cup J_1$: index set of all hospital sites.
- $v_i$: number of people in household or cluster of households $i \in I$.
- $d_{ij}$: travel distance from household $i \in I$ to hospital facility $j \in J$.
- $a_{ij}$: indicator parameter, $a_{ij} = 1$ if $d_{ij} \leq S$, $0$ otherwise.
- $S$: maximum travel distance from a household to a hospital.
- $p$: number of additional hospitals to be located.
- $x_j \in \{0,1\}$: equals 1 iff hospital $j$ is opened.
- $y_{ij} \in \{0,1\}$: equals 1 iff demand at household $i$ is served by hospital $j$.
