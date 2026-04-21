Sanquin, the Dutch blood bank, aims to optimize the distribution of blood products to hospitals across the Netherlands. To ensure timely and efficient delivery, Sanquin plans to establish a network of blood distribution centers (DCs) at select hospitals. The goal is to minimize the average drive time between hospitals and their assigned DCs while adhering to logistical constraints.

Key Components of the Problem
Facilities Involved:
Hospitals (Demand Points): All hospitals in the Netherlands require regular blood deliveries.
Candidate Distributoion Center (DC) Locations: A subset of hospitals has been pre-identified as potential sites for DCs. Only these candidate hospitals can host a DC.

Decisions to Make:
Sanquin needs to know which hospitals should serve as DCs such that the average drive time to other hospitals is minimized. 

Critical Constraints:
Travel Time Limit: A hospital can only be assigned to a specific DC if the travel time between them does not exceed T minutes. This ensures blood products reach hospitals within a safe timeframe.

DC Activation Requirement: A hospital can only be assigned to a DC if that DC is operational (i.e., selected as one of the n DCs).

Objective:
Minimize the average drive time between hospitals and their assigned DCs. This is equivalent to minimizing the total drive time across all hospital-DC pairs, as the number of hospitals is fixed.

Operational Details
Drive Time vs. Cost: The drive time between a DC and a hospital directly translates to a transportation cost. Minimizing total cost in the model corresponds to minimizing total drive time.

Travel Time Limit (T): Assignments violating the T-minute threshold are strictly prohibited. For instance, if T = 60, no hospital can be paired with a DC more than 60 minutes away.

Why This Matters
Blood products have limited shelf lives, and emergencies require rapid delivery. By optimizing DC locations and assignments, Sanquin ensures:

Faster emergency response via minimized average drive times.
Compliance with time-sensitive delivery requirements through the T-minute constraint.
Cost-effective operations by avoiding unnecessary infrastructure (only n DCs are activated).