# Unit 4 — Aggregating the Marketplace

For this unit, the producer is a property, the actor is a renter, the event is a viewing, and the metric is `duration_min`. Region is `booking_city`, which is stored on `viewings` itself, so none of these queries need a join.

A failure is a renter no-show. I kept the same definition I used to correct the dashboard in Unit 3: the rate is no-shows divided by eligible viewings, and a viewing is eligible unless it was cancelled because the property was withdrawn. A withdrawn listing is not something the renter could have shown up for.

## Task 4.1 — Measuring the platform

### The baseline

| Viewings | Total minutes | Average | Min  | Max   | Distinct renters |
| -------- | ------------- | ------- | ---- | ----- | ---------------- |
| 200      | 3,628.19      | 18.14   | 0.00 | 70.86 | 30               |

The minimum of zero is the first thing that stood out. A viewing that actually took place should never last zero minutes. When I grouped by status, all 34 zero-minute rows were cancelled viewings. The dataset stores `0.00` for viewings that never happened instead of leaving the value `NULL`.

That changes the average. Across all 200 rows the average is 18.14 minutes, but across the 166 viewings that actually happened it is 21.9 minutes. The 18.14 figure mixes "how long viewings last" with "how many viewings were cancelled," and it answers neither question well. My own schema prevents this with `chk_viewings_duration_only_if_completed`, but the reference dataset does not, so from 4.1b onward I use `AVG(NULLIF(duration_min, 0))` to keep the placeholders out of the average.

### Per property

Property 6 has the most viewings (21) and property 4 the fewest (6). Most properties sit between 11 and 20. Average held duration ranges from about 17 minutes (properties 3 and 11) to about 28–29 minutes (properties 5 and 4).

### The threshold

I used `HAVING COUNT(*) >= 10`. With 10 viewings, one no-show moves a property's rate by 10 percentage points. Below that, a single event dominates the result. Property 4 shows why: it has the highest no-show rate on the platform (20%), but that is one no-show out of five eligible viewings. One fewer missed appointment and it would be at 0%.

Twelve of the thirteen properties with viewings meet the threshold. Only property 4 is excluded.

### Two dimensions

Grouping by `booking_city` and `viewing_status` gives one row per region and outcome (14 rows, because Hue has no disputed viewings). Hue has the most cancellations (11 of 40), Saigon the fewest (4 of 40). Hanoi's two disputed viewings averaged only about 9 minutes, much shorter than its attended viewings. That may be worth a look on its own.

### Write-up

The person who would act on the per-property breakdown is the **marketplace operations manager** responsible for listings and the agents who show them. They are the one who can call a landlord or agent, review a listing, or retrain whoever schedules the viewings. Leadership can see that a problem exists, but this person is the one who can fix it.

The aggregates hide a lot:

- **An average hides its distribution.** Property 4's average held viewing is 29.2 minutes, the highest on the platform, but it only had four held viewings and one of them lasted 70.86 minutes. Its median is about 18.6 minutes, which is ordinary. One unusual viewing makes it look like the most engaging listing.
- **A count hides who is counted.** `GROUP BY property_id` on `viewings` only returns properties that have at least one viewing. Properties 14 and 15 have none, so they do not appear at all. A property with zero interest might be a bigger problem than one with a few no-shows, but this query cannot show it. Likewise, "30 distinct renters" does not say whether activity is spread evenly or a few renters account for most of it.
- **A rate hides its denominator.** 18.8% and 20% look similar, but one is 3 of 16 and the other is 1 of 5.

What I would want to see next:

1. Properties with zero viewings, which needs a `LEFT JOIN` from `properties` to `viewings`.
2. No-shows by renter, to tell a property problem apart from a few unreliable renters. For property 2, the three no-shows came from three different renters, which points at the property rather than the renters.
3. The median and spread of `duration_min` per property, not only the average.
4. No-shows by scheduled hour and day of the week. Several no-shows were booked late at night or very early in the morning.

## Task 4.2 — The breakdown leadership asked for

### Part A — Two numbers in one pass

For each property, the query computes total viewings, eligible viewings, and no-shows in a single pass using `SUM(CASE WHEN ... THEN 1 ELSE 0 END)`. There is no `WHERE` clause, so every viewing is read once and counted in each column it belongs to.

It answers two questions side by side:

1. **How many viewings did each property have that could have resulted in a no-show?**
2. **How many of those actually did?**

| Property | Viewings | Eligible | No-shows | Rate  |
| -------- | -------- | -------- | -------- | ----- |
| 4        | 6        | 5        | 1        | 20.0% |
| 2        | 16       | 16       | 3        | 18.8% |
| 3        | 13       | 13       | 2        | 15.4% |
| 1        | 11       | 10       | 1        | 10.0% |

The other nine properties are between 0% and 7.1%. Four of them (5, 8, 10, and 13) had no no-shows at all.

### Part B — Subtotals and a grand total

I used `GROUP BY ROLLUP (booking_city, property_id)` with `HAVING GROUPING(property_id) = 1`. ROLLUP produces three levels: region-and-property detail rows, one subtotal per region, and a grand total. The `HAVING` clause removes the detail rows and keeps the other two levels.

**Which rows are which:** the five rows labelled `region subtotal` (Danang, Haiphong, Hanoi, Hue, Saigon) are the regional subtotals. The single row labelled `grand total` with region `ALL REGIONS` is the platform total. In the raw output, the grand total is the row where `booking_city` would be `NULL`. I replace that with a label using `GROUPING(booking_city) = 1` so it cannot be confused with a missing city.

| Region      | Row type        | Viewings | Eligible | No-shows | Rate  |
| ----------- | --------------- | -------- | -------- | -------- | ----- |
| Danang      | region subtotal | 43       | 41       | 1        | 2.4%  |
| Haiphong    | region subtotal | 39       | 38       | 3        | 7.9%  |
| Hanoi       | region subtotal | 38       | 37       | 3        | 8.1%  |
| Hue         | region subtotal | 40       | 38       | 4        | 10.5% |
| Saigon      | region subtotal | 40       | 39       | 1        | 2.6%  |
| ALL REGIONS | grand total     | 200      | 193      | 12       | 6.2%  |

The reader who needs subtotals rather than detail rows is the **regional director**. They manage a city, not individual listings. They need to know how their region compares to the others, and the property-level rows would just bury that.

The grand total supports a decision none of the region rows can: **what the platform's true no-show rate is, and therefore what number the dashboard should show and what threshold a region or property should be measured against.** It is calculated from the underlying counts (12 of 193), not by averaging the five regional rates. Averaging them would give about 6.3%, because it treats Danang's 41 eligible viewings and Hanoi's 37 as equal weight.

### Part C — A two-step pipeline

The `WITH` clause builds a per-property summary (viewings, eligible viewings, no-shows). The outer query keeps only properties with at least 10 viewings and aggregates them again.

**The question it answers:** *What is a normal no-show rate for a property with enough volume to judge, and how far above that is the worst one?*

| High-volume properties | Viewings | No-shows | Baseline rate | Average of property rates | Worst property |
| ---------------------- | -------- | -------- | ------------- | ------------------------- | -------------- |
| 12                     | 194      | 11       | 5.9%          | 6.2%                      | 18.8%          |

The baseline is 5.9%. The worst high-volume property (property 2) is at 18.8%, a bit more than three times the baseline. I show both the pooled rate and the average of property rates because they answer slightly different questions. The pooled rate weights every viewing equally. The average weights every property equally, so a few small properties with high rates pull it up.

## Reflection

In Part A, one `GROUP BY` gave me total viewings, eligible viewings, and no-shows for every property. The alternative is two queries: a plain `COUNT(*)` per property and a second one with `WHERE no_show_reason = 'Renter no show'`, then lining the two results up.

At 200 rows the difference is invisible. At a million rows, each filtered query reads the event table again, so two metrics cost two full passes and every extra metric adds another one. Conditional aggregation reads each row once and updates several counters as it goes. Adding a metric costs a little CPU instead of another scan.

There are also two correctness problems with separate queries. First, they run at different moments. If viewings are being written continuously, the numerator and denominator can come from slightly different data, and the rate built from them is off. A single query works from one consistent snapshot. Second, the filtered query silently drops groups. A property with zero no-shows has no row in it, so combining the results needs an outer join and `COALESCE`. That is exactly the kind of missing-value handling that produced the 44% error in Unit 3. In one pass, that property simply shows 0.