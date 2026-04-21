# Blood Bank Distribution Center Location (BBDCL)

**Source:** `datasets/Ferchtandiker2025/blood_bank_netherlands/efficient model.tex`, `datasets/Ferchtandiker2025/blood_bank_netherlands/inefficient model.tex`, `datasets/Ferchtandiker2025/blood_bank_netherlands/detailed description.txt`

## Summary

Sanquin, the Dutch blood bank, aims to locate a fixed number of blood distribution
centers (DCs) at a subset of candidate hospital locations in the Netherlands and
assign every hospital to one of the selected DCs so as to minimize the total
(equivalently, average) drive time. A hospital may only be assigned to a DC
whose travel time does not exceed a fixed limit $T$, ensuring that blood products
with limited shelf lives can be delivered in a timely manner.

## Formulations

### Efficient

This formulation uses a precomputed feasibility indicator $\delta_{ij}$ to
eliminate infeasible DC-hospital pairs from the model. It only considers
allocations within the travel time limit, and bounds the number of hospitals a
DC can serve by the number of hospitals feasibly reachable from that DC.

#### Model

$$
\begin{aligned}
\min \quad & \sum_{i \in \mathcal{S}} \sum_{j \in \mathcal{H}} \delta_{ij} \, y_{ij} \, T_{ij} \\
\text{s.t.} \quad & \sum_{i \in \mathcal{S}} x_i = n \\
& \sum_{j \in \mathcal{H}} \delta_{ij} \, y_{ij} \leq x_i \cdot \sum_{j \in \mathcal{H}} \delta_{ij}, \quad \forall i \in \mathcal{S} \\
& \sum_{i \in \mathcal{S}} \delta_{ij} \, y_{ij} = 1, \quad \forall j \in \mathcal{H} \\
& y_{ij} = 0, \quad \forall i \in \mathcal{S},\, j \in \mathcal{H} \text{ with } \delta_{ij} = 0 \\
& x_i \in \{0,1\}, \quad \forall i \in \mathcal{S} \\
& y_{ij} \in \{0,1\}, \quad \forall i \in \mathcal{S},\, j \in \mathcal{H}
\end{aligned}.
$$

#### Notation

- $\mathcal{S}$ (index $i$): set of candidate DC locations.
- $\mathcal{H}$ (index $j$): set of all hospital locations.
- $n$: total number of DCs that should be in use.
- $T_{ij}$: travel time between candidate DC location $i$ and hospital $j$.
- $T$: limit on travel time from candidate DC location $i \in \mathcal{S}$ to hospital $j \in \mathcal{H}$.
- $\delta_{ij}$: indicator parameter, $1$ if $T_{ij} \leq T$, $0$ otherwise.
- $x_i \in \{0,1\}$: decision variable that equals 1 iff DC location $i$ is in use.
- $y_{ij} \in \{0,1\}$: decision variable that equals 1 iff hospital $j$ is allocated to DC $i$.

### Inefficient

This formulation does not precompute feasibility and instead enforces the
travel time limit as a constraint of the model. It also uses the loose bound
$|\mathcal{H}|$ to link allocations of hospitals to active DCs.

#### Model

$$
\begin{aligned}
\min \quad & \sum_{i \in \mathcal{S},\, j \in \mathcal{H}} y_{ij} \cdot T_{ij} \\
\text{s.t.} \quad & \sum_{i \in \mathcal{S}} x_i = n \\
& \sum_{j \in \mathcal{H}} y_{ij} \leq x_i \cdot |\mathcal{H}|, \quad \forall i \in \mathcal{S} \\
& \sum_{i \in \mathcal{S}} y_{ij} = 1, \quad \forall j \in \mathcal{H} \\
& T_{ij} \cdot y_{ij} \leq T, \quad \forall i \in \mathcal{S},\, j \in \mathcal{H} \\
& x_i \in \{0,1\}, \quad \forall i \in \mathcal{S} \\
& y_{ij} \in \{0,1\}, \quad \forall i \in \mathcal{S},\, j \in \mathcal{H}
\end{aligned}.
$$

#### Notation

- $\mathcal{S}$ (index $i$): set of candidate DC locations.
- $\mathcal{H}$ (index $j$): set of all hospital locations.
- $n$: total number of DCs that should be in use.
- $T_{ij}$: travel time between candidate DC location $i$ and hospital $j$.
- $T$: limit on travel time from candidate DC location $i \in \mathcal{S}$ to hospital $j \in \mathcal{H}$.
- $x_i \in \{0,1\}$: decision variable that equals 1 iff DC location $i$ is in use.
- $y_{ij} \in \{0,1\}$: decision variable that equals 1 iff hospital $j$ is allocated to DC $i$.
