# World Food Program Food Distribution (WFP)

**Source:** `datasets/Ferchtandiker2025/world_food_program/efficient model.tex`, `datasets/Ferchtandiker2025/world_food_program/inefficient model.tex`, `datasets/Ferchtandiker2025/world_food_program/detailed description.txt`

## Summary

In crisis-affected regions, the World Food Programme (WFP) must deliver food aid
to beneficiary camps through a multi-stage supply network consisting of
suppliers, transshipment points, and camps. The goal is to design a distribution
plan that minimizes the total procurement and transportation cost while ensuring
every camp receives enough of each commodity to meet its ration demand and the
resulting ration collectively satisfies all per-person nutritional requirements.
No storage is assumed at transshipment points, so flow entering a transshipment
point must immediately be redirected.

## Formulations

### Efficient

This formulation models shipments along each edge of the supply network. Flow
conservation is enforced at every node for each commodity, beneficiary camps
receive at least their ration demand on incoming edges, and ration sizes satisfy
all nutritional requirements. The number of flow variables scales with
$|N|^2 |K|$, avoiding the path-enumeration blow-up of the alternative formulation.

#### Model

$$
\begin{aligned}
    \min \quad & \sum_{k \in K} \text{pc}_k \left( \sum_{j \in N_B} \text{dem}_j R_k \right) + \sum_{i \in N} \sum_{j \in N} \sum_{k \in K} \text{tc}_{ijk} F_{ijk} \\
    \text{s.t.} \quad & \sum_{i \in N} E_{ij} F_{ijk} = \sum_{i \in N} E_{ji} F_{jik}, \quad \forall j \in N, \forall k \in K \\
    & \sum_{i \in N} E_{ij} F_{ijk} \geq \text{dem}_j R_k, \quad \forall j \in N_B, \forall k \in K \\
    & \sum_{k \in K} \text{nutval}_{kl} R_k \geq \text{nutreq}_l, \quad \forall l \in L \\
    & R_k, F_{ijk} \geq 0, \quad \forall i,j \in N, \forall k \in K
\end{aligned}.
$$

#### Notation

- $N$: set of nodes.
- $N_S$: set of suppliers ($N_S \subseteq N$).
- $N_T$: set of transshipment points ($N_T \subseteq N$).
- $N_B$: set of beneficiary camps ($N_B \subseteq N$).
- $E$: an $N$ by $N$ matrix with 0-1 indication that an edge exists.
- $L$: set of nutrients.
- $K$: set of commodities.
- $\text{dem}_i$: number of beneficiaries at node $i \in N_B$.
- $\text{pc}_k$: procurement cost of commodity $k \in K$ (\$/kg).
- $\text{tc}_{ijk}$: transportation cost of commodity $k \in K$ from node $i \in N$ to node $j \in N$ (\$/kg).
- $\text{nutreq}_l$: nutritional requirement of one beneficiary for nutrient $l \in L$.
- $\text{nutval}_{kl}$: nutritional value of commodity $k \in K$ for nutrient $l \in L$ (per kg).
- $F_{ijk} \geq 0$: amount of commodity $k \in K$ sent from node $i \in N$ to node $j \in N$ (kg).
- $R_k \geq 0$: ration size of commodity $k \in K$ in one person's portion (kg).

### Inefficient

This formulation enumerates all simple paths from a supplier to a beneficiary
camp and uses one shipment variable per (path, commodity) pair. The flow
conservation constraints at transshipment points are replaced by the implicit
structure of the path set, but the number of variables grows combinatorially
with the size of the network.

#### Model

$$
\begin{aligned}
    \min \quad & \sum_{p \in P} \sum_{k \in K} c_{pk} \; x_{pk} + \sum_{k \in K} q_k \cdot \left( \sum_{p \in P} x_{pk} \right) \\
    \text{s.t.} \quad & \sum_{p \in P} e_{jp} \, x_{pk} \geq \mathrm{dem}_j \cdot R_k, \quad \forall j \in N_B,\; \forall k \in K \\
    & \sum_{k \in K} \mathrm{nutval}_{k\ell} \cdot R_k \geq \mathrm{nutreq}_\ell, \quad \forall \ell \in L \\
    & x_{pk} \geq 0, \quad \forall p \in P, \forall k \in K \\
    & R_k \geq 0, \quad \forall k \in K
\end{aligned}.
$$

#### Notation

- $P$: set of all simple paths from supplier to beneficiary camps.
- $K$: set of commodities.
- $L$: set of nutrients.
- $N_B$: set of beneficiary camps.
- $c_{pk}$: cost of shipping one kg of commodity $k \in K$ along path $p \in P$.
- $q_k$: procurement cost per kg of commodity $k \in K$.
- $\mathrm{nutval}_{k\ell}$: nutrient-$\ell$ content (per kg) of commodity $k \in K$.
- $\mathrm{nutreq}_\ell$: per-person requirement for nutrient $\ell \in L$.
- $\mathrm{dem}_j$: number of beneficiaries at camp $j \in N_B$.
- $e_{jp}$: equals $1$ if path $p$ ends at camp $j$, and $0$ otherwise, for all $j \in N_B$, $p \in P$.
- $x_{pk} \geq 0$: amount (kg) of commodity $k \in K$ shipped along path $p \in P$.
- $R_k \geq 0$: ration size (kg per person) of commodity $k \in K$.
