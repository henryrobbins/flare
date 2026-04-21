Optimizing Park and Bike hub locations for sustainable urban mobility 

Terminology 
A Park & Bike (P&B) hub (or hub) is a facility combining car parking and bike parking. However, not all parking facilities can be transformed into hubs. The suitability of a parking facility for conversion into a hub depends on several elements. These include the size, the location, the accessibility and the potential demand for bike parking in the surrounding area.  

A Point of Interest (POI) is defined as a working location node or a place where people gather.  

The highways around the cities have junctions from which cars can enter the city.   

Data  
The set of potential locations for the hubs is given. Moreover, the number of people on an average day that enter the city at a certain junction and must go to a certain POI is given. Also (car, bike) distances and times from one certain location to another location are given.  

When do people not use a hub? 
There are several reasons why people will not use a hub: 

Commuters do not use a hub when the extra time needed is too much. More precisely, people will not use a hub if the travel time from the junction to the hub plus the biking time from the hub to the POI minus the driving time from the junction to the POI is more than an acceptable extra time Δ.  

Commuters do not want to bike too long. More precisely, people will not use a hub if the biking time from the hub to the POI exceeds a certain threshold (T).  

Commuters will not use the bike (and therefore will not use the hub) if the distance from the hub to the POI is less than a minimum distance (D).  

Commuters will not use a hub if the number of car kilometers saved is too small. More precisely, people will not use a hub if the distance from a junction to the POI minus the distance from that junction to the hub h is less than τ. 

All these conditions make no value for commuters to use a P&B. It is estimated that r% of the commuters for which at least one hub exists for which the above 4 reasons do not hold, will use a hub. 

Goal 
The goal is as follows: Develop a model that determines, given that in total N hubs may be opened, at which locations we should open a hub, such that the total number of commuters that will make use of a hub is maximized. 