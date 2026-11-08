# Unit 5 — Connecting the Tables

The producer is a property, the actor is a renter, the event is a viewing, and the catalog is `amenities`, linked to properties through the `listing_amenities` junction. A failure is a renter no-show, measured against eligible viewings (everything except "Property withdrawn"), the same definition as Units 3 and 4. The properties flagged in Unit 4 were 2 (18.8%) and 3 (15.4%) to act on now, and 4 (20%, but only 5 eligible viewings) to watch.

## Task 5.1 — Connecting producers to their data

### Question 1: The people behind the events (query 5.1a)

The three-table join returns all 200 viewings with the renter's name, the property, the city, the scheduled time, and the status. Nothing is dropped, because every viewing has a valid renter and property; both foreign keys guarantee it.

### Question 2: Shared catalog tags (queries 5.1b-i and 5.1b-ii)

Properties 2 and 3 share exactly one amenity: Gym. Property 2 also shares Pool with property 4. To test whether Gym explains the no-shows, I returned every property with the Gym tag:

| Property | City     | Eligible | No-shows |
| -------- | -------- | -------- | -------- |
| 2        | Danang   | 16       | 3        |
| 3        | Haiphong | 13       | 2        |
| 11       | Haiphong | 15       | 1        |
| 5        | Saigon   | 17       | 0        |
| 10       | Hanoi    | 19       | 0        |

Properties 5 and 10 have the same tag and no no-shows across 36 eligible viewings, so having a gym is not what the flagged properties have in common. The same is true of Pool, which nine properties have, including three with no no-shows.

### Question 3: Comparing producers with each other (queries 5.1c and 5.1d)

The self join pairs each flagged property with every other property priced within $200 of it or located in the same city.

The price comparison is the more interesting one. All four properties above 10% sit in the top price tier, around $3,200 a month. Across the six properties priced above $3,000, the pooled no-show rate is 9.7% (7 of 72), compared with 4.1% (5 of 121) for everyone else (query 5.1d). But property 5 is priced within a few cents of 2 and 3 and had zero no-shows in 17 eligible viewings, and property 13 ($3,096) also had none. Price may raise the risk, but it does not explain the problem on its own.

The city comparison points the same way for property 3. The other two Haiphong properties (6 and 11) are at 5.0% and 6.7%, close to the platform norm, so location does not explain property 3's rate either. Property 2 is the only Danang listing, so it has no same-city peers.

What remains is how each property is operated, which this database does not record: who the agent is, and how viewings are confirmed. Comparing property 5's process with properties 2 and 3 is the most useful next step.

### Write-up

**1. What feature could use the three-table join?** A viewing schedule for agents and operations staff. Each row would show the time, the renter's name, the property, and the status. Agents would use it as a daily calendar, and the operations manager could filter it to one property to see who booked, who attended, and who did not. That is the view needed to follow up on properties 2 and 3.

**2. Why is the junction table important for Question 2?** A property can have many amenities, and an amenity belongs to many properties. `listing_amenities` stores each pairing as one row, so "which properties have a gym" is a plain equality join. Without it, the amenities would have to live on `properties` either as a column per amenity, which needs a schema change every time a new amenity is added, or as a comma-separated list, which can only be searched with fragile `LIKE` matching and can't be checked by a foreign key. The junction also holds `verified_on`, a fact that belongs to the pairing itself and has nowhere else to go.