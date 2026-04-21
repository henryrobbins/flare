# Park and Bike Hub Location (Mobian)

**Source:** `datasets/Ferchtandiker2025/mobian/detailed description.txt`, `datasets/Ferchtandiker2025/mobian/efficient model.tex`, `datasets/Ferchtandiker2025/mobian/inefficient model.tex`

## Summary

The Park and Bike (P&B) hub location problem asks which parking facilities
should be converted into Park and Bike hubs so that the total commuter
demand covered by the hub network is maximized. Commuters arrive at city
junctions and travel to Points of Interest (POIs). For each
junction-hub-POI triple, a binary feasibility parameter encodes whether
the commuter would realistically use the hub: the extra time relative to
driving directly must be at most $\Delta$, the bike leg from the hub to
the POI must take at most $T$ minutes, the hub must be at least $D$
kilometers from the POI, and the driving distance saved
($d_{sp}-d_{sh}$) must be at least $\tau$. A fixed set of existing hubs
must remain open, and at most $U$ new hubs may be opened from the set of
potential new hub locations.

## Formulations

### Efficient

The efficient formulation uses one binary variable $z_{sp}$ per
junction-POI pair that indicates whether the demand from $s$ to $p$ is
covered by at least one open hub that makes the trip feasible. Coverage
is enforced by a single aggregated constraint per $(s,p)$, which sums
the feasibility parameter over all hubs.

#### Model

$$
\begin{aligned}
\max\;
&\sum_{s\in S}\sum_{p\in P} v_{sp}\,z_{sp}\\[3pt]
\text{s.t.}\;
&\sum_{h=N+1}^{M} y_h \le U\\
&\sum_{h=1}^{N} y_h = N\\
&z_{sp} \le \sum_{h\in H} F_{shp}\,y_h && \forall s\in S,\;\forall p\in P\\
&y_h \in \{0,1\} && \forall h\in H\\
&z_{sp} \in \{0,1\} && \forall s\in S,\;\forall p\in P
\end{aligned}.
$$

#### Notation

- $H$: set of all hub indexes; $h=1,\dots,N$ for existing hubs and $h=N+1,\dots,M$ for potential new hubs.
- $P$: set of Points of Interest (POIs).
- $S$: set of junction roads (origins).
- $v_{sp}$: demand originating at junction $s$ for POI $p$.
- $c_{sp}$: travel time by car from junction $s$ to POI $p$ (minutes).
- $c_{sh}$: travel time by car from junction $s$ to hub $h$ (minutes).
- $b_{hp}$: travel time by bike from hub $h$ to POI $p$ (minutes).
- $d_{sp}$: distance from junction $s$ to POI $p$ (kilometers).
- $d_{hp}$: distance from hub $h$ to POI $p$ (kilometers).
- $d_{sh}$: distance from junction $s$ to hub $h$ (kilometers).
- $T$: maximum allowed bike travel time from a hub $h$ to a POI $p$ (minutes).
- $N$: number of existing hubs.
- $U$: maximum number of new hubs that can be opened.
- $D$: minimum required distance between a hub $h$ and POI $p$ (kilometers).
- $\Delta$: maximum additional travel time allowed when using a bike via a hub compared to traveling directly by car (minutes).
- $\tau$: minimum required distance difference $(d_{sp}-d_{sh})$ (kilometers).
- $F_{shp}\in\{0,1\}$: equals 1 iff $(c_{sh}+b_{hp})-c_{sp}\le\Delta$, $b_{hp}\le T$, $d_{hp}\ge D$, and $d_{sp}-d_{sh}\ge\tau$ all hold.
- $y_h\in\{0,1\}$: equals 1 iff hub $h$ is opened.
- $z_{sp}\in\{0,1\}$: equals 1 iff the demand from junction $s$ to POI $p$ is covered by any open hub.

### Inefficient

The inefficient formulation introduces one binary assignment variable
$x_{shp}$ per junction-hub-POI triple, indicating that the demand from
$s$ to $p$ is served via hub $h$. Separate per-hub constraints enforce
that an assignment can only occur when the hub is open and the triple is
feasible, and each $(s,p)$ pair can be assigned to at most one hub. The
model has $|S|\cdot|H|\cdot|P|$ binary variables rather than
$|S|\cdot|P|$, leading to a larger LP relaxation.

#### Model

$$
\begin{aligned}
\max\;
&\sum_{s\in S}\sum_{h\in H}\sum_{p\in P} v_{sp}\,x_{shp}\\[3pt]
\text{s.t.}\;
&\sum_{h=N+1}^{M} y_h \le U\\
&\sum_{h=1}^{N} y_h = N\\
&x_{shp} \le y_h && \forall s\in S,\;\forall h\in H,\;\forall p\in P\\
&x_{shp} \le F_{shp} && \forall s\in S,\;\forall h\in H,\;\forall p\in P\\
&\sum_{h\in H} x_{shp} \le 1 && \forall s\in S,\;\forall p\in P\\
&y_h \in \{0,1\} && \forall h\in H\\
&x_{shp} \in \{0,1\} && \forall s\in S,\;\forall h\in H,\;\forall p\in P
\end{aligned}.
$$

#### Notation

- $H$: set of all hub indexes; $h=1,\dots,N$ for existing hubs and $h=N+1,\dots,M$ for potential new hubs.
- $P$: set of Points of Interest (POIs).
- $S$: set of junction roads (origins).
- $v_{sp}$: demand originating at junction $s$ for POI $p$.
- $c_{sp}$: travel time by car from junction $s$ to POI $p$ (minutes).
- $c_{sh}$: travel time by car from junction $s$ to hub $h$ (minutes).
- $b_{hp}$: travel time by bike from hub $h$ to POI $p$ (minutes).
- $d_{sp}$: distance from junction $s$ to POI $p$ (kilometers).
- $d_{hp}$: distance from hub $h$ to POI $p$ (kilometers).
- $d_{sh}$: distance from junction $s$ to hub $h$ (kilometers).
- $T$: maximum allowed bike travel time from a hub $h$ to a POI $p$ (minutes).
- $N$: number of existing hubs.
- $U$: maximum number of new hubs that can be opened.
- $D$: minimum required distance between a hub $h$ and POI $p$ (kilometers).
- $\Delta$: maximum additional travel time allowed when using a bike via a hub compared to traveling directly by car (minutes).
- $\tau$: minimum required distance difference $(d_{sp}-d_{sh})$ (kilometers).
- $F_{shp}\in\{0,1\}$: equals 1 iff $(c_{sh}+b_{hp})-c_{sp}\le\Delta$, $b_{hp}\le T$, $d_{hp}\ge D$, and $d_{sp}-d_{sh}\ge\tau$ all hold.
- $y_h\in\{0,1\}$: equals 1 iff hub $h$ is opened.
- $x_{shp}\in\{0,1\}$: equals 1 iff the demand from junction $s$ to POI $p$ is assigned via hub $h$.
