# Air Traffic Flow Management Problem (TFMP)

**Source:** `datasets/Ferchtandiker2025/air traffic management/efficient model.tex`, `datasets/Ferchtandiker2025/air traffic management/inefficient model.tex`, `datasets/Ferchtandiker2025/air traffic management/detailed description.txt`

## Summary

The Air Traffic Flow Management Problem seeks to allocate a fleet of vehicles (planes) across a network of locations (airports) over a discrete time horizon, maximizing the total reward collected from locating planes at rewarding locations while respecting per-location, per-time capacity limits. Planes can only transition between locations in a way that is consistent with the travel time $\tau_{a,a'}$ from one location to another.

## Formulations

### Time-Indexed

The time-indexed formulation introduces a binary variable $y_{p,a,t}$ indicating whether vehicle $p$ is at location $a$ at time $t$, along with a departure variable $z_{p,a,a',t}$ for each potential trip. A flow-conservation constraint links successive time periods via the travel time $\tau_{a',a}$, and each plane is required to be at exactly one location at every time.

#### Model

$$
\begin{aligned}
\max\;
&\sum_{p \in P} \sum_{a \in A} \sum_{t \in T} r_{a,t}\, y_{p,a,t}\\
\text{s.t.}\;
&\sum_{a \in A} y_{p,a,t} = 1 && \forall p \in P,\; t \in T\\
&\sum_{p \in P} y_{p,a,t} \leq \text{cap}_{a,t} && \forall a \in A,\; t \in T\\
&y_{p,a,t} = y_{p,a,t-1} + \sum_{a' \in A} \sum_{t' : t' + \tau_{a',a} = t} z_{p,a',a,t'} - \sum_{a' \in A} z_{p,a,a',t} && \forall p \in P,\; a \in A,\; t \in T,\; t > 0\\
&y_{p,a,t} \in \{0,1\},\; z_{p,a,a',t} \in \{0,1\}
\end{aligned}.
$$

#### Notation

- $P$: set of vehicles (planes).
- $A$: set of locations (airports).
- $T$: set of time periods.
- $\text{cap}_{a,t}$: capacity of location $a \in A$ at time $t \in T$.
- $\tau_{a,a'}$: travel time from location $a$ to $a'$.
- $r_{a,t}$: reward for being at location $a$ at time $t$.
- $y_{p,a,t} \in \{0,1\}$: 1 if vehicle $p$ is at location $a$ at time $t$, 0 otherwise.
- $z_{p,a,a',t} \in \{0,1\}$: 1 if vehicle $p$ departs from $a$ to $a'$ at time $t$, 0 otherwise.

### Event-Based

The event-based formulation retains only the departure variable $x_{p,a,a',t}$ that fires when a vehicle departs location $a$ for $a'$ at time $t$. The presence of a plane at a location at time $t$ is reconstructed implicitly by enumerating the departures whose arrival time $t' + \tau_{a,a'}$ equals $t$. Each vehicle is required to make at least one trip, and capacity at each location and time bounds the total number of simultaneous departures.

#### Model

$$
\begin{aligned}
\max\;
&\sum_{p \in P} \sum_{a \in A} \sum_{t \in T} r_{a,t} \left( \sum_{a' \in A} \sum_{t' \in T: t' + \tau_{a,a'} = t} x_{p,a,a',t'} \right)\\
\text{s.t.}\;
&\sum_{a \in A} \sum_{a' \in A} \sum_{t \in T} x_{p,a,a',t} \geq 1 && \forall p \in P\\
&\sum_{p \in P} \sum_{a \in A} \sum_{a' \in A} x_{p,a,a',t} \leq \text{cap}_{a,t} && \forall a \in A,\; t \in T\\
&x_{p,a,a',t} \in \{0,1\}
\end{aligned}.
$$

#### Notation

- $P$: set of vehicles (planes).
- $A$: set of locations (airports).
- $T$: set of possible event times.
- $\text{cap}_{a,t}$: capacity of location $a \in A$ at time $t \in T$.
- $\tau_{a,a'}$: travel time from location $a$ to $a'$.
- $r_{a,t}$: reward for being at location $a$ at time $t$.
- $x_{p,a,a',t} \in \{0,1\}$: 1 if vehicle $p$ departs from $a$ to $a'$ at time $t$, 0 otherwise.
- $t^{\text{arr}}_{p,a,a',t} = t + \tau_{a,a'}$: arrival time if $x_{p,a,a',t} = 1$.
