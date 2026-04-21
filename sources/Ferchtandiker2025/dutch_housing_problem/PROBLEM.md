# Dutch Housing Problem (DHP)

**Source:** `datasets/Ferchtandiker2025/dutch_housing_problem/`

## Summary

A real estate developer designs a residential tower with a fixed number of floors. Each floor is built according to one of several floor configurations, where a configuration determines the number of apartments on the floor and the area of each apartment. Every apartment is assigned to an owner class (corporation, investor, or private) and to a sector (social, middle, or free), and the profit per apartment depends on the area, sector, and owner. The developer chooses which configuration and owner to use for each floor, together with the sector assignment of each apartment, to maximize total profit subject to sector-mix, average-area, per-sector ownership, and per-owner percentage constraints. Two equivalent MILP formulations are provided: an aggregate formulation that counts floors and apartments by type, and a disaggregate formulation that models each floor and apartment individually.

## Formulations

### Aggregate (Efficient)

The aggregate formulation indexes decisions by configuration and by (sector, area, owner) counts. Variables $x_{vh}$ record how many floors use configuration $v$ with owner $h$, and $y_{ijh}$ records how many apartments of area $j$ are assigned to sector $i$ with owner $h$. Consistency between floor choices and apartment counts is enforced through the parameter $R_{jv}$ giving the number of apartments of area $j$ in configuration $v$.

#### Model

$$
\begin{aligned}
\max \quad & \sum_{i \in I} \sum_{j \in J} \sum_{h \in H} O_{ijh}\, y_{ijh}\\[3pt]
\text{s.t.} \quad & \sum_{v \in V} \sum_{h \in H} x_{vh} = K\\
& \sum_{v \in V} R_{jv}\, x_{vh} = \sum_{i \in I} y_{ijh} && \forall j \in J,\; h \in H\\
& \sum_{j \in J} \sum_{h \in H} y_{ijh} \geq a_i \sum_{l \in I} \sum_{j \in J} \sum_{h \in H} y_{ljh} && \forall i \in I\\
& \sum_{j \in J} \sum_{h \in H} j \cdot y_{ijh} \geq s_i \sum_{j \in J} \sum_{h \in H} y_{ijh} && \forall i \in I\\
& y_{ijh} = 0 && \forall i \in I,\; j \in J,\; h \in H \text{ with } j < m_{ih}\\
& y_{\text{free},j,\text{corporation}} = 0 && \forall j \in J\\
& \sum_{i \in I} \sum_{j \in J} y_{ijh} \geq o_h \sum_{i \in I} \sum_{j \in J} \sum_{h' \in H} y_{ijh'} && \forall h \in H\\
& y_{ijh},\; x_{vh} \in \mathbb{N} && \forall i \in I,\; j \in J,\; h \in H,\; v \in V
\end{aligned}.
$$

#### Notation

- $I$: set of sectors $\{\text{social}, \text{middle}, \text{free}\}$.
- $J$: set of apartment floor areas.
- $H$: set of owners $\{\text{corporation}, \text{investor}, \text{private}\}$.
- $V$: set of floor configurations.
- $K$: total number of floors.
- $R_{jv}$: number of apartments with floor area $j$ in configuration $v$.
- $O_{ijh}$: profit per apartment for sector $i$, floor area $j$, and owner $h$.
- $m_{ih}$: minimal floor area for sector $i$ and owner $h$.
- $a_i$: minimum percentage of apartments of sector $i$ in the total program.
- $s_i$: minimum average floor area for sector $i$.
- $o_h$: minimum percentage of apartments of owner $h$ in the total program.
- $x_{vh} \in \mathbb{N}$: number of floors of configuration $v$ with owner $h$.
- $y_{ijh} \in \mathbb{N}$: number of apartments in sector $i$ with floor area $j$ and owner $h$.

### Disaggregate (Inefficient)

The disaggregate formulation indexes decisions individually by floor, configuration, owner, sector, and apartment. The binary variable $x_{kvh}$ picks the configuration and owner of each floor $k$, and $y_{kvhia}$ assigns each apartment $a$ in configuration $v$ on floor $k$ (with owner $h$) to sector $i$. Apartment areas are accessed via the parameter $j_{v,a}$ giving the area of apartment $a$ in configuration $v$.

#### Model

$$
\begin{aligned}
\max \quad & \sum_{k \in K} \sum_{v \in V} \sum_{h \in H} \sum_{i \in I} \sum_{a \in A_v} p_{i\, j_{v,a}\, h} \cdot y_{kvhia}\\[3pt]
\text{s.t.} \quad & \sum_{v \in V} \sum_{h \in H} x_{kvh} = 1 && \forall k \in K\\
& \sum_{i \in I} y_{kvhia} \leq x_{kvh} && \forall k \in K,\; v \in V,\; h \in H,\; a \in A_v\\
& \sum_{k \in K} \sum_{v \in V} \sum_{h \in H} \sum_{a \in A_v} y_{kvhia} \geq b_i \sum_{k \in K} \sum_{v \in V} \sum_{h \in H} \sum_{i' \in I} \sum_{a \in A_v} y_{kvhi'a} && \forall i \in I\\
& \sum_{k \in K} \sum_{v \in V} \sum_{h \in H} \sum_{a \in A_v} j_{v,a} \cdot y_{kvhia} \geq s_i \cdot \sum_{k \in K} \sum_{v \in V} \sum_{h \in H} \sum_{a \in A_v} y_{kvhia} && \forall i \in I\\
& y_{kvhia} = 0 && \forall k,v,h,i,a \in A_v \text{ with } j_{v,a} < m_{ih}\\
& y_{k v h_{\text{corp}} i_{\text{free}} a} = 0 && \forall k,v,a \in A_v\\
& \sum_{k \in K} \sum_{v \in V} x_{kvh} \cdot |A_v| \geq o_h \cdot \sum_{k \in K} \sum_{v \in V} \sum_{h' \in H} x_{kvh'} \cdot |A_v| && \forall h \in H\\
& x_{kvh} \in \{0,1\},\; y_{kvhia} \in \{0,1\} && \forall k,v,h,i,a \in A_v
\end{aligned}.
$$

#### Notation

- $I$: set of sectors $\{\text{social}, \text{middle}, \text{free}\}$.
- $J$: set of apartment floor areas.
- $H$: set of owners $\{\text{corporation}, \text{investor}, \text{private}\}$.
- $V$: set of floor configurations.
- $A_v$: set of apartments in configuration $v \in V$.
- $K$: set of floors.
- $p_{ijh}$: profit for sector $i \in I$, area $j \in J$, and owner $h \in H$.
- $m_{ih}$: minimum area for sector $i \in I$ and owner $h \in H$.
- $b_i$: minimum percentage of apartments in sector $i \in I$.
- $s_i$: minimum average area for sector $i \in I$.
- $o_h$: minimum ownership percentage for owner $h \in H$.
- $j_{v,a}$: area of apartment $a \in A_v$ in configuration $v \in V$.
- $|A_v|$: number of apartments in configuration $v \in V$.
- $x_{kvh} \in \{0,1\}$: equals 1 iff floor $k$ uses configuration $v$ and owner $h$.
- $y_{kvhia} \in \{0,1\}$: equals 1 iff apartment $a \in A_v$ on floor $k$ (configuration $v$, owner $h$) is assigned to sector $i$.
