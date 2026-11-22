-- ---------------------------------------------------------------------
-- 6.3A: Top N per category
-- Question: What were the three longest viewings at each property, and
-- how far is each one from that property's longest viewing?
-- Only viewings that took place (duration_min > 0) are ranked.
--
-- Ties at third place: RANK() is used, so if two viewings tie for third,
-- both are returned (that property shows four rows). ROW_NUMBER would
-- drop one of them based on an arbitrary order, which is unfair to a
-- viewing that was exactly as long. In this dataset no property has two
-- viewings with the same duration, so every property returns at most 3.
-- ---------------------------------------------------------------------
WITH ranked AS (
    SELECT v.property_id,
           v.viewing_id,
           v.scheduled_at::date AS viewing_date,
           v.duration_min,
           RANK() OVER (PARTITION BY v.property_id
                        ORDER BY v.duration_min DESC)          AS duration_rank,
           FIRST_VALUE(v.duration_min) OVER (PARTITION BY v.property_id
                        ORDER BY v.duration_min DESC)          AS property_longest_min
    FROM viewings AS v
    WHERE v.duration_min > 0
)
SELECT property_id,
       duration_rank,
       viewing_id,
       viewing_date,
       duration_min,
       property_longest_min,
       duration_min - property_longest_min AS diff_from_longest_min
FROM ranked
WHERE duration_rank <= 3
ORDER BY property_id, duration_rank;


-- ---------------------------------------------------------------------
-- 6.3B: Period over period
-- Question: Is the platform getting better or worse each month? For each
-- month, how many viewings were booked, what was the renter no-show rate,
-- and how did both change from the month before?
-- No-show rate follows the Unit 4 definition: 'Renter no show' divided by
-- viewings that were not cancelled because the property was withdrawn.
-- NULLIF(..., 0) turns a zero denominator into NULL so the percent change
-- returns NULL instead of a division-by-zero error (April had 0 no-shows).
-- prev_month comes from LAG too, so each row shows which month it was
-- compared to; months_apart must be 1 for the comparison to be valid.
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT DATE_TRUNC('month', scheduled_at)::date                         AS month,
           COUNT(*)                                                         AS viewings,
           COUNT(*) FILTER (WHERE no_show_reason = 'Renter no show')        AS no_shows,
           COUNT(*) FILTER (WHERE no_show_reason IS DISTINCT FROM 'Property withdrawn') AS eligible
    FROM viewings
    GROUP BY 1
),
compared AS (
    SELECT month,
           LAG(month)    OVER (ORDER BY month) AS prev_month,
           viewings,
           LAG(viewings) OVER (ORDER BY month) AS prev_viewings,
           no_shows,
           ROUND(100.0 * no_shows / NULLIF(eligible, 0), 1) AS no_show_rate_pct,
           LAG(ROUND(100.0 * no_shows / NULLIF(eligible, 0), 1))
                         OVER (ORDER BY month) AS prev_no_show_rate_pct
    FROM monthly
)
SELECT month,
       (EXTRACT(YEAR FROM AGE(month, prev_month)) * 12
        + EXTRACT(MONTH FROM AGE(month, prev_month)))::int                AS months_apart,
       viewings,
       ROUND(100.0 * (viewings - prev_viewings)
             / NULLIF(prev_viewings, 0), 1)                               AS viewings_pct_change,
       no_shows,
       no_show_rate_pct,
       ROUND(100.0 * (no_show_rate_pct - prev_no_show_rate_pct)
             / NULLIF(prev_no_show_rate_pct, 0), 1)                       AS no_show_rate_pct_change
FROM compared
ORDER BY month;


-- ---------------------------------------------------------------------
-- 6.3B: Missing-month check
-- Question: Is any calendar month between the first and last viewing
-- missing from the data? LAG counts rows, so a missing month would make
-- the query above compare, say, March with January without saying so.
-- Zero rows returned = every month is present and LAG compared neighbors.
-- ---------------------------------------------------------------------
WITH calendar AS (
    SELECT GENERATE_SERIES(DATE_TRUNC('month', MIN(scheduled_at)),
                           DATE_TRUNC('month', MAX(scheduled_at)),
                           INTERVAL '1 month')::date AS month
    FROM viewings
)
SELECT c.month AS missing_month
FROM calendar AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM viewings AS v
    WHERE DATE_TRUNC('month', v.scheduled_at)::date = c.month
);