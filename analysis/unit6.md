# Unit 6 — Analytics with Window Functions

The producer is a property, the event is a viewing, and the metric is `duration_min`. A failure is still a renter no-show, measured against eligible viewings (everything except "Property withdrawn"), the same definition as Units 3 to 5: 12 no-shows out of 193 eligible viewings, or 6.2%. The data covers one year, 1 January to 28 December 2023.

Two details about the data shaped every query in this unit:

- **Cancelled viewings are stored as 0 minutes.** All duration questions use only the 166 viewings that took place (`duration_min > 0`). Otherwise every property average would be pulled down by viewings that never happened.
- **`viewing_id` is not in time order.** IDs 1 to 200 were handed out in blocks per property (property 1 is 1–11, property 2 is 12–27, and so on). Every LAG, LEAD, running total and moving average therefore orders by `scheduled_at`. Ordering by the ID would compare viewings months apart as if they were neighbours.

## Task 6.1 — Compute across a window without collapsing

### Each viewing next to its property's average (queries 6.1a)

`AVG(duration_min) OVER (PARTITION BY property_id)` returns **166 rows**: every viewing that took place, each with its property's average and the difference beside it. The GROUP BY version returns **13 rows**, one per property. Both produce the same averages. What GROUP BY loses is every individual viewing, and with it any way to tell which viewings were unusual. Property 1 averages 19.59 minutes, but two of its viewings lasted about 7 minutes (−12.19 and −12.52), and only the window version shows that.

### Ranking producers three ways (query 6.1b)

Ranking all 15 properties by number of viewings (with a LEFT JOIN, so 14 and 15 appear with 0) produces four ties. The first one shows how the three functions differ:

| Property | Viewings | ROW_NUMBER | RANK | DENSE_RANK |
| -------- | -------- | ---------- | ---- | ---------- |
| 5        | 18       | 4          | 4    | 4          |
| 7        | 18       | 5          | 4    | 4          |
| 12       | 17       | 6          | 6    | 5          |

ROW_NUMBER puts property 5 ahead of 7, but only because I added `property_id` as a tiebreaker. Without one, Postgres can return the tied rows in either order. RANK gives both 4th and then skips to 6th. DENSE_RANK gives both 4th and continues at 5th. The other ties are properties 2 and 11 (16), 1 and 13 (11), and 14 and 15 (0).

### Four demand bands (query 6.1c)

`NTILE(4)` splits the 15 properties into bands of 4, 4, 4 and 3 rows. It counts rows and ignores the values, so **properties 5 and 7, with 18 viewings each, land in different bands**: 5 in band 1 and 7 in band 2. The tiebreaker on `property_id` decided which one moved up. A `tie_split_across_bands` column (comparing MIN and MAX band within each viewing count) flags both rows. Anyone using these bands for something with consequences, such as a "top demand" label, would be treating two identical properties differently.

### Write-up

**1. A question that needs each row beside its group average.** "Which viewings ran much shorter than usual *for that property*?" A 7-minute viewing at property 1, where viewings average almost 20 minutes, suggests a renter who left as soon as they arrived, which is worth following up. At a property where every viewing is short, the same 7 minutes would mean nothing. GROUP BY can give me the average, but the average alone can't say which rows sit far from it. To answer the question without a window function, I would have to compute the averages in one query and join them back onto every viewing.

**2. A feature that would use the ranking.** A "Most viewed" leaderboard that owners and renters can see. It should use **RANK**. Two listings with the same number of viewings have earned the same position, and ROW_NUMBER would let `property_id`, a number nobody outside the database sees, decide which owner gets the higher spot. The gap RANK leaves after a tie is also accurate: property 12 has five listings ahead of it, so 6th is correct. DENSE_RANK would call it 5th and understate the competition. ROW_NUMBER is the right choice only where exactly one row must win, such as picking a single featured listing, and even then the tiebreaker should be something defensible, like the most recent viewing.


## Task 6.2 — Compare each row to its neighbors

### Part A — Row to row (query 6.2A)

For property 2, flagged in Units 4 and 5, LAG and LEAD show the previous and next viewing's duration on each row, partitioned by property and ordered by `scheduled_at`. Across its 12 viewings that took place, there is no steady trend up or down. The pattern is volatility: viewings go from 19.83 to **47.81 minutes (+27.98)** on 4 May and then fall to **15.22 (−32.59)** on 3 June. The first row has no previous viewing and the last has no next one, so both show NULL, which is the correct result rather than a gap in the data.

### Part B — Cumulative and smoothed (queries 6.2B)

**Running total against a target.** I set a target of **50 booked viewings per quarter**. Counting viewings per day and running `SUM(...) OVER (PARTITION BY quarter ORDER BY day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`, the platform reached 53 in Q1 and 51 in Q3 but fell short in Q2 (48) and Q4 (48). In Q4 the running total was at 26 (52%) by 13 November and finished at **48 of 50 (96%)** on 28 December.

**Moving average.** The no-show rate over the last 30 eligible viewings (`AVG(is_no_show) OVER (ORDER BY scheduled_at ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)`) sits at 6.7% for most of the year, falls to **0.0% at the end of October and November**, and returns to 6.7% in December. The cumulative rate moves from 10.0% after January to 6.2% at year end and stays between 5% and 8% from February on.

**ROWS vs RANGE (query 6.2B, first 10 viewings).** When rows share the same ORDER BY value, ROWS still counts them one at a time, so the three viewings on 8 January get running counts of 4, 5 and 6 in whatever order Postgres reads them. RANGE treats rows with the same value as peers and gives all three the total through the end of that day, 6.

### Part C — Where the series stops (query 6.2C)

The gap is computed with LAG in a CTE and filtered in the outer query, because a window function's result can't be used in the WHERE of the same query. Three properties went more than 90 days without a viewing:

| Property | Last viewing before | First viewing after | Gap (days) | Viewings elsewhere during the gap |
| -------- | ------------------- | ------------------- | ---------- | --------------------------------- |
| 9        | 2023-01-05          | 2023-04-28          | 113        | 61                                |
| 12       | 2023-03-02          | 2023-06-17          | 107        | 48                                |
| 5        | 2023-02-01          | 2023-05-05          | 93         | 46                                |

### Write-up

**1. What would a large delta tell someone, and what should they do?** A large swing in viewing length from one viewing to the next means the viewing experience at that property is inconsistent. One renter spends 48 minutes and the next leaves after 15. That points to differences in how viewings are run, such as different agents, renters arriving without the details they needed, or a unit that doesn't match its listing. At property 2 it sits alongside an 18.8% no-show rate. The action is to standardize the viewing there: one confirmed agent, a confirmation message with what to expect, and a short note after each viewing on how it went.

**2. Why does a running total answer a question that a plain SUM cannot?** A plain SUM says Q4 ended at 48. The running total also says *when* the quarter fell behind. A quarter of about 92 days needs a pace of roughly one booking every two days. Q4 was at only 52% of target by 13 November, and someone looking at it in early December could have seen the shortfall coming while there was still time to act. SUM only reports the result after the quarter is over.

**3. Why 30 viewings for the moving average?** The platform averages about 16 viewings a month, so 30 rows covers roughly two months. That is long enough for a single no-show not to swing the line, and short enough to show a change within a quarter. With a 20-viewing window, the line jumped between 0% and 10% on one no-show. With 50, the quiet stretch in October and November barely showed (the line only dipped to about 4%). Because ROWS counts viewings rather than days, 30 rows covers more calendar time in slow months like March and April. That is acceptable here, because the question is about the rate per viewing, not per day.

**4. What does the gap mean?** For property 9, the evidence points to a **real stop in activity**, not a data problem:

- `viewing_id` runs from 1 to 200 with no missing numbers, so no recorded viewings were deleted.
- The rest of the platform booked 61 viewings during the gap, so this was not a platform-wide outage or a failed import.
- Property 9 is currently marked unavailable, which fits a listing that has been paused or taken off the market before.

One thing the data can't rule out: a booking that was never recorded at all would also never have received an ID. Ruling that out means checking with the owner whether the listing was paused between January and April. All three gaps also overlap March and April, when platform bookings halved (11 viewings in each month), so part of each gap is probably that drop in demand rather than anything about the property itself.


## Task 6.3 — Build the reporting patterns

### Part A — Top N per category (query 6.3A)

`RANK() OVER (PARTITION BY property_id ORDER BY duration_min DESC)` in a CTE, filtered to `<= 3` in the outer query, returns the three longest viewings at each of the 13 properties with viewings, **39 rows** in all. `FIRST_VALUE(duration_min)` over the same window gives each property's longest viewing, so every row also shows how far it is from the top. Property 4 stands out: its longest viewing was 70.86 minutes and its second only 22.77.

Ties at third place: I used RANK, so if two viewings tie for third, both are returned and that property shows four rows. ROW_NUMBER would drop one of them arbitrarily. No property in this data has two viewings of the same length, so every property returns exactly three.

### Part B — Period over period (queries 6.3B)

| Month | Viewings | Change | No-shows | No-show rate |
| ----- | -------- | ------ | -------- | ------------ |
| Jan   | 21       | —      | 2        | 10.0%        |
| Feb   | 21       | 0.0%   | 0        | 0.0%         |
| Mar   | 11       | −47.6% | 2        | 18.2%        |
| Apr   | 11       | 0.0%   | 0        | 0.0%         |
| May   | 17       | +54.5% | 2        | 11.8%        |
| Jun   | 20       | +17.6% | 1        | 5.3%         |
| Jul   | 17       | −15.0% | 1        | 5.9%         |
| Aug   | 18       | +5.9%  | 1        | 5.6%         |
| Sep   | 16       | −11.1% | 1        | 7.1%         |
| Oct   | 18       | +12.5% | 0        | 0.0%         |
| Nov   | 14       | −22.2% | 0        | 0.0%         |
| Dec   | 16       | +14.3% | 2        | 12.5%        |

`NULLIF(previous, 0)` prevents division by zero. The months after a 0% month (March, May, November and December) return NULL for the rate's percent change instead of an error. The missing-month check builds every calendar month with `GENERATE_SERIES` and returns **0 rows**. The query also shows `months_apart`, which is 1 on every row. LAG counts rows, not months, so without this check a missing month would make it compare the wrong pair without any warning.

### Write-up

**1. The feature top-N would power.** A "Best viewings" panel on each property's owner dashboard, showing the three longest viewings for that listing. A long viewing is the clearest sign in this data that a renter was seriously considering the place. Three is enough to look for a pattern (same agent, same time of day, same kind of renter) without resting on one lucky outlier. One viewing could be exactly that outlier: property 4's top viewing is 48 minutes longer than its second. Ten would cover most of a property's history here, since property 4 had only 4 viewings that took place and property 1 had 9. A top ten would just be the full list.

**2. What a large month-over-month change means.** In this data there are two kinds, and only one is worth acting on.

- **No-show rate changes are noise at this volume.** The rate goes from 0% to 18.2% to 0% because monthly no-shows range from 0 to 2. A "−100%" change is one or two renters. Nobody should act on a single month. The rate should be reported quarterly or on the 30-viewing moving window from Task 6.2, with an alert only when a single property stays above about 12% (twice the platform's 6.2%) for two quarters in a row.
- **Volume changes are a real signal.** Bookings fell **47.6%** in March and stayed at 11 in April, including ten days with no viewings at all on the platform (2 to 12 April). A drop like that should send someone, within a week, to check whether listings went inactive, search stopped returning them, or demand really fell. Q2 then finished at 48, short of the target of 50.


## Reflection

A question leadership asks every quarter is "are we on track?" For this platform that means: on each day of the quarter, how many viewings have been booked so far, and how close is that to the target of 50? A running total answers it in one pass. `SUM(viewings) OVER (PARTITION BY quarter ORDER BY day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` keeps every day as its own row and adds everything before it, so the Q4 result reads like a progress bar: 26 by November 13, 38 by December 14, and 48 at the end, two short.

GROUP BY can't produce that on its own. It collapses rows into one total per group, so grouping by quarter gives the final 48 and loses the path, and grouping by day gives each day's count and loses everything before it. To rebuild the running total without a window function, every day would have to be joined to all earlier days in the same quarter and summed again, which is a self-join that repeats the work for every row and is easy to get wrong at the quarter boundary.

The same applies to comparing a viewing with its property's average, or a month with the month before. The answer depends on a row and its neighbours at the same time, and GROUP BY only gives one or the other. A window function keeps the detail and adds the context next to it.