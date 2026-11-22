-- ---------------------------------------------------------------------
-- 6.2A
-- Question: For property 2 (flagged for no-shows in Units 4 and 5), are
-- viewings getting longer or shorter over time, one viewing to the next?
-- LAG/LEAD run over every property; the outer query keeps property 2.
-- Only viewings that took place (duration_min > 0) are compared.
-- ---------------------------------------------------------------------
WITH neighbors AS (
    SELECT v.viewing_id,
           v.property_id,
           v.scheduled_at,
           LAG(v.duration_min)  OVER (PARTITION BY v.property_id ORDER BY v.scheduled_at) AS prev_duration_min,
           v.duration_min,
           LEAD(v.duration_min) OVER (PARTITION BY v.property_id ORDER BY v.scheduled_at) AS next_duration_min,
           v.duration_min
             - LAG(v.duration_min) OVER (PARTITION BY v.property_id ORDER BY v.scheduled_at) AS delta_min
    FROM viewings AS v
    WHERE v.duration_min > 0
)
SELECT viewing_id,
       scheduled_at::date AS viewing_date,
       prev_duration_min,
       duration_min,
       next_duration_min,
       delta_min
FROM neighbors
WHERE property_id = 2
ORDER BY scheduled_at;


-- ---------------------------------------------------------------------
-- 6.2B (running total against a target)
-- Question: Is the platform hitting its target of 50 booked viewings per
-- quarter, and where does Q4 (the latest quarter) stand day by day?
-- Viewings are first counted per day; the running total restarts each
-- quarter. The outer query shows Q4 only so the climb is easy to read.
-- ---------------------------------------------------------------------
WITH daily AS (
    SELECT scheduled_at::date                          AS viewing_date,
           DATE_TRUNC('quarter', scheduled_at)::date   AS quarter_start,
           COUNT(*)                                    AS viewings
    FROM viewings
    GROUP BY 1, 2
),
running AS (
    SELECT viewing_date,
           quarter_start,
           viewings,
           SUM(viewings) OVER (PARTITION BY quarter_start
                               ORDER BY viewing_date
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
    FROM daily
)
SELECT viewing_date,
       viewings,
       running_total,
       50                                   AS quarter_target,
       ROUND(100.0 * running_total / 50, 1) AS pct_of_target
FROM running
WHERE quarter_start = DATE '2023-10-01'
ORDER BY viewing_date;


-- ---------------------------------------------------------------------
-- 6.2B (cumulative vs. moving no-show rate)
-- Question: Is the renter no-show rate drifting up or down, both for the
-- year so far and over the most recent 30 viewings?
-- Viewings cancelled because the property was withdrawn are left out,
-- matching the Unit 4 definition (12 no-shows / 193 viewings = 6.2%).
-- Window = 30 rows, about two months at ~16 viewings a month. ROWS counts
-- viewings, not days, so 30 rows covers more calendar time in slow months
-- like March and April.
-- The outer query keeps the last viewing of each month (one row per month).
-- ---------------------------------------------------------------------
WITH flagged AS (
    SELECT viewing_id,
           scheduled_at,
           CASE WHEN no_show_reason = 'Renter no show' THEN 1 ELSE 0 END AS is_no_show
    FROM viewings
    WHERE no_show_reason IS DISTINCT FROM 'Property withdrawn'
),
rates AS (
    SELECT scheduled_at,
           SUM(is_no_show) OVER w_all AS cum_no_shows,
           COUNT(*)        OVER w_all AS cum_viewings,
           ROUND(100 * AVG(is_no_show) OVER (ORDER BY scheduled_at
                       ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 1) AS moving_rate_last_30_pct,
           ROW_NUMBER() OVER (PARTITION BY DATE_TRUNC('month', scheduled_at)
                              ORDER BY scheduled_at DESC)           AS rn_from_month_end
    FROM flagged
    WINDOW w_all AS (ORDER BY scheduled_at ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
)
SELECT DATE_TRUNC('month', scheduled_at)::date               AS month,
       cum_viewings,
       cum_no_shows,
       ROUND(100.0 * cum_no_shows / cum_viewings, 1)         AS cumulative_rate_pct,
       moving_rate_last_30_pct
FROM rates
WHERE rn_from_month_end = 1
ORDER BY month;


-- ---------------------------------------------------------------------
-- 6.2B (ROWS vs RANGE)
-- Question: What changes when two viewings fall on the same day?
-- With ORDER BY viewing_date, ROWS adds one row at a time, so two viewings
-- on Jan 8 get different running totals. RANGE treats rows with the same
-- ORDER BY value as peers and gives all of them the total through the end
-- of that day. Shown for the first 10 viewings of January.
-- ---------------------------------------------------------------------
SELECT viewing_id,
       scheduled_at::date AS viewing_date,
       COUNT(*) OVER (ORDER BY scheduled_at::date
                      ROWS  BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_rows,
       COUNT(*) OVER (ORDER BY scheduled_at::date
                      RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_range
FROM viewings
ORDER BY scheduled_at
LIMIT 10;


-- ---------------------------------------------------------------------
-- 6.2C
-- Question: Which properties went more than 90 days without a single
-- viewing, and was the rest of the platform still active during that gap?
-- The gap is computed in a CTE (window functions run after WHERE, so the
-- gap cannot be filtered in the same query). platform_viewings_in_gap
-- counts other properties' viewings inside the gap: if the platform was
-- busy, the silence belongs to this property, not to a platform-wide
-- data outage.
-- ---------------------------------------------------------------------
WITH gaps AS (
    SELECT property_id,
           LAG(scheduled_at) OVER (PARTITION BY property_id ORDER BY scheduled_at) AS prev_viewing,
           scheduled_at                                                           AS next_viewing
    FROM viewings
)
SELECT g.property_id,
       g.prev_viewing::date                          AS last_viewing_before_gap,
       g.next_viewing::date                          AS first_viewing_after_gap,
       g.next_viewing::date - g.prev_viewing::date   AS gap_days,
       (SELECT COUNT(*)
        FROM viewings AS o
        WHERE o.property_id <> g.property_id
          AND o.scheduled_at > g.prev_viewing
          AND o.scheduled_at < g.next_viewing)       AS platform_viewings_in_gap
FROM gaps AS g
WHERE g.next_viewing::date - g.prev_viewing::date > 90
ORDER BY gap_days DESC;