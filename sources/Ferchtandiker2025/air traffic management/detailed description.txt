Optimizing Air Traffic Flow Management

In the context of increasingly congested airspaces and strained airport capacities, the Air Traffic Flow Management Problem (TFMP) seeks to optimize the allocation of aircraft across a network of airports and airspace sectors over time. This problem is critical for airlines who must efficiently utilize their fleet while respecting operational and capacity constraints.

Core Challenge
Airlines must decide, for each time period, where each plane in their fleet should be located—either at an airport or within an airspace sector. The challenge is to make these assignments in a way that maximizes operational rewards, given the limited capacities of airports and sectors.

Key challenges include:

- Airport congestion: Limited runway and gate availability during peak hours or adverse weather.
- Sector bottlenecks: Airspace regions with strict capacity limits.
- Interconnected delays: Congestion at one location can propagate through the network.
- Reward asymmetry: The reward for a plane being in the air (in a sector) is a constant, while the reward for being at an airport is location-dependent and may reflect operational priorities or incentives.

In this specific case, an airline seeks to determine the optimal position of each plane in its fleet at every time period, balancing the rewards for being at different locations and the constraints imposed by the system.

Operational Components
- Each plane must be assigned to exactly one location (airport or sector) at each time period.
- Each location (airport or sector) has a capacity limit for each time period.
- The reward for a plane being in a sector (in air) is a constant value, while the reward for being at an airport depends on the specific airport.
- Flow preservation: Planes can only move between adjacent locations from one time period to the next, as defined by the adjacency structure of the network. This ensures that the presence of a plane at a location and time is consistent with feasible transitions from previous locations.

Key Constraints:
- Location capacities: No more planes than the allowed capacity at any location and time.
- Unique assignment: Each plane is in exactly one location at each time.
- Flow preservation: For each plane, the number of times it enters a location at time t must equal the number of times it leaves at time t+1, except at the initial and final time periods. This is enforced by only allowing transitions between adjacent locations.

Objective Function:
Maximize the total reward, defined as the sum of rewards for all planes, locations, and times, where the reward is location- and time-dependent (constant for sectors, location-dependent for airports).
