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

Properties 5 and 10 have the same tag and no no-shows across 36 eligible viewings, so having a gym is not what the flagged properties have in common.

### Question 3: Comparing producers with each other (queries 5.1c and 5.1d)

The self join pairs each flagged property with every other property priced within $200 of it or located in the same city.

The price comparison is the more interesting one. All four properties above 10% sit in the top price tier, around $3,200 a month. Across the six properties priced above $3,000, the pooled no-show rate is 9.7% (7 of 72), compared with 4.1% (5 of 121) for everyone else (query 5.1d). But property 5 is priced within a few cents of 2 and 3 and had zero no-shows in 17 eligible viewings, and property 13 ($3,096) also had none. Price may raise the risk, but it does not explain the problem on its own.

The city comparison points the same way for property 3. The other two Haiphong properties (6 and 11) are at 5.0% and 6.7%, close to the platform norm, so location does not explain property 3's rate either. Property 2 is the only Danang listing, so it has no same-city peers.

What remains is how each property is operated, which this database does not record: who the agent is, and how viewings are confirmed. Comparing property 5's process with properties 2 and 3 is the most useful next step.

### Write-up

**1. What feature could use the three-table join?** A viewing schedule for agents and operations staff. Each row would show the time, the renter's name, the property, and the status. Agents would use it as a daily calendar, and the operations manager could filter it to one property to see who booked, who attended, and who did not. That is the view needed to follow up on properties 2 and 3.

**2. Why is the junction table important for Question 2?** A property can have many amenities, and an amenity belongs to many properties. `listing_amenities` stores each pairing as one row, so "which properties have a gym" is a plain equality join. Without it, the amenities would have to live on `properties` either as a column per amenity, which needs a schema change every time a new amenity is added, or as a comma-separated list, which can only be searched with fragile `LIKE` matching and can't be checked by a foreign key. The junction also holds `verified_on`, a fact that belongs to the pairing itself and has nowhere else to go.


## Task 5.2 — Records that joins exclude

### Part A — INNER JOIN vs LEFT JOIN (queries 5.2a-i to 5.2a-iii)

The LEFT JOIN returns 15 properties and the INNER JOIN returns 13. Counting `DISTINCT property_id` on each side, **the inner join excludes 2 properties**. The missing two are the properties with no viewings; an inner join only keeps a property if at least one viewing matches it. In the LEFT JOIN they appear with a count of 0 because I count `v.viewing_id`, which is NULL for the padded row. `COUNT(*)` would have reported 1.

### Part B — RIGHT JOIN and FULL OUTER JOIN (queries 5.2b-i to 5.2b-iii)

The RIGHT JOIN puts `viewings` on the left and `properties` on the right, so properties is still the side that keeps every row. I didn't assume the two were equivalent. I compared their ungrouped rows with `EXCEPT ALL` in both directions: each returns 202 rows (200 viewings plus 2 padded rows), and neither direction has a row the other lacks.

The FULL OUTER JOIN also returns 202 rows: 200 matched, 2 properties with no viewings (14 and 15), and 0 viewings with no property. A left or right join can only show unmatched rows from one side. A full outer join shows both directions in a single result, which makes it the natural reconciliation query between two tables. Here the second direction is empty because `fk_viewings_prod` makes an orphan viewing impossible. In a dataset without that constraint, such as an import from another system, this is the query that would find them.

### Part C — NOT EXISTS vs EXCEPT (queries 5.2c-i to 5.2c-iii)

Both approaches return properties 14 and 15, and a two-way `EXCEPT` between their results is empty. `NOT EXISTS` checks each property for a matching viewing and returns the whole property row. `EXCEPT` subtracts one set of IDs from another, so it can only return the compared column and needs another join to get anything else. It also removes duplicates. Both are NULL-safe, unlike `NOT IN`.

### Write-up

**1. Which producers did the inner join exclude?** Properties **14** and **15**.

| Property | City   | Rent      | Listed     | Available |
| -------- | ------ | --------- | ---------- | --------- |
| 14       | Saigon | $651.07   | 2022-04-11 | Yes       |
| 15       | Hue    | $1,342.76 | 2022-11-18 | Yes       |

**2. What does it mean when a property has no events?** In this data, it means no renter booked a viewing of it at any point in 2023, the full period the viewings cover, even though both listings are marked available and were listed well before the year started.

The data shows a little more. Neither property has any amenity recorded in `listing_amenities`; only one other property (13) is in that position. Price is unlikely to be the reason: property 14 rents for $651, and the two $600 properties (6 and 7) drew 21 and 18 viewings.

The data cannot tell me why. Possible explanations, all of which need checking outside the database:

- the listing is not actually visible in search, even though it is flagged available;
- the listing is incomplete, with no amenities and possibly no photos, so renters pass it over;
- the owner is not accepting viewings, or bookings are handled offline;
- the location or unit is unappealing in a way the data does not capture.

**3. How could an inner-join report mislead leadership?** It shows only properties that have activity. A report of no-show rates by property would list 13 properties and look complete, while two of the fifteen listings silently produced nothing. The worst performers by that measure, the properties with no interest at all, would not appear anywhere. This is the same kind of silent exclusion that inflated the Unit 3 dashboard.

**4. Why identify producers who have never been active?** A listing with no viewings earns nothing, yet it still costs the platform something: it takes up space in search results and represents an owner who is probably unhappy. It may also point to a broken process, such as a listing that never finished publishing. Whatever the cause, it can only be fixed if someone knows the listing exists.

**5. What action could leadership take?** Check the two listings directly: confirm they are visible in search, add the missing amenities and photos, and contact the owners. Separately, change the per-property reports to start from `properties` with a LEFT JOIN, so properties with zero viewings show up as zero instead of disappearing.


## Task 5.3 — Join performance and execution plans

### Part A — CROSS JOIN (queries 5.3a-i and 5.3a-ii)

`properties` has 15 rows and `amenities` has 5. 15 × 5 = 75, and the CROSS JOIN returns 75 rows. Joining that grid to `listing_amenities` shows that 25 property/amenity pairs exist and 50 do not.

### Part B — The execution plan (query 5.3b)

I ran `ANALYZE` first so the planner's statistics matched the real table sizes, then `EXPLAIN` and `EXPLAIN ANALYZE` on the three-table join from 5.1a. The plan has two Hash Joins over three sequential scans, followed by a sort:

1. Seq Scan on `renters` (30 rows) builds a hash table (10 kB, 1 batch).
2. Seq Scan on `viewings` (200 rows) probes it on `renter_id`.
3. Seq Scan on `properties` (15 rows) builds a second hash table (9 kB, 1 batch), probed on `property_id`.
4. Sort on `scheduled_at` with an in-memory quicksort (53 kB).

The estimated row counts matched the actual ones exactly at every step (200, 30, 15). Planning took 0.378 ms and execution 0.626 ms. The timings show where the work went: both joins and all three scans were finished at 0.302 ms, and the sort took the query to 0.526 ms, so sorting accounted for roughly 40% of the run.

### Write-up

**1. When could a Cartesian product be useful?** As an amenity-coverage grid: every property paired with every amenity, then marked present or missing. The 50 missing pairs could drive a "complete your listing" prompt for owners, and the grid shows at a glance that properties 13, 14, and 15 have no amenities at all. The same pattern could generate every property × time-slot combination for a booking calendar. A Cartesian product is a mistake when it comes from a missing join condition. Joining `viewings` to `renters` without an `ON` clause would return 200 × 30 = 6,000 rows, and every count built on it would be wrong.

**2. Which join algorithms did PostgreSQL choose?** Hash Join for both joins: `viewings` to `renters` on `renter_id`, then that result to `properties` on `property_id`.

**3. What in the plan explains those choices?**

- The query has no `WHERE` clause, so every row of every table is needed, and the Seq Scans read each table exactly once.
- The two tables being hashed are tiny (30 and 15 rows). Each hash table fits in memory in a single batch (10 kB and 9 kB), so building them is nearly free.
- PostgreSQL hashed the smaller tables and streamed the larger `viewings` table through them, which is the standard way to set up a hash join.
- The only indexes are the primary keys. There is no index on `viewings.renter_id` or `viewings.property_id`, because PostgreSQL does not create indexes for foreign-key columns automatically. A Nested Loop would have to probe once per viewing, and a Merge Join would have to sort both inputs on the join key first.

**4. Why is it useful to understand the selected algorithms?** The plan shows where the time goes and what would make it go away. Here the joins finished in 0.3 ms and the sort took most of the rest, so if this report grows, the first fix is an index or pagination on `scheduled_at`, not a change to the joins. The plan also shows whether the planner's estimates are accurate. Every estimate here matched the actual row count, but without up-to-date statistics PostgreSQL falls back on default guesses about table size, and badly wrong estimates are the most common cause of a poor plan.

**5. What changes might make another join algorithm more appropriate?**

- A selective filter, such as one property's viewings, makes a Nested Loop cheaper, especially with an index on `viewings.property_id`.
- Two large inputs that are already sorted on the join key, for example through indexes, make a Merge Join more attractive.
- A hash table that no longer fits in `work_mem` spills to disk in batches, which makes hashing less attractive.

## Reflection

On this dataset, PostgreSQL chose two Hash Joins with sequential scans. That is the right plan when every table is small and the query needs every row: it hashes the 30 renters and 15 properties once (10 kB and 9 kB, one batch each) and reads the 200 viewings a single time.

Three kinds of change would push it toward a different algorithm. The first is a selective filter. If the query asked for one property's viewings, only a handful of rows would match, and a Nested Loop that looks each one up becomes cheaper than building hash tables. An index on `viewings.property_id`, which PostgreSQL does not create automatically for a foreign key, would make those lookups fast. The second is size on both sides. A Hash Join stays cheap only while the smaller table fits in `work_mem`. If renters grew into the millions, the hash would spill to disk in batches, and a Merge Join over inputs already sorted by an index on the join key could win. The third is the number of matching rows. When a join matches most rows, scanning everything is cheaper than millions of index lookups, so the planner stays with hashing.

Growth in viewings alone would not change the join algorithm, because renters and properties would still be small. It would make the sequential scan and the sort on `scheduled_at` expensive. An index on `scheduled_at` with a `LIMIT`, so the report is paginated, would address that.