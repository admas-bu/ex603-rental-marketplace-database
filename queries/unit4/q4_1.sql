-- 4.1a Baseline: what does the whole viewings table look like?
-- Requirement: COUNT, SUM, AVG, MIN, MAX on the metric, plus COUNT(DISTINCT actor).
SELECT COUNT(*)                     AS viewings,
       SUM(duration_min)            AS total_minutes,
       ROUND(AVG(duration_min), 2)  AS avg_minutes,
       MIN(duration_min)            AS min_minutes,
       MAX(duration_min)            AS max_minutes,
       COUNT(DISTINCT renter_id)    AS distinct_renters
FROM viewings;

-- 4.1a (follow-up) Why is the minimum zero?
-- Requirement: data-quality check on the baseline.
-- Cancelled viewings store 0.00 instead of NULL, so they drag the average down.
SELECT viewing_status,
       COUNT(*)                                 AS viewings,
       COUNT(*) FILTER (WHERE duration_min = 0) AS zero_minute_rows,
       ROUND(AVG(NULLIF(duration_min, 0)), 2)   AS avg_minutes_excl_zero
FROM viewings
GROUP BY viewing_status
ORDER BY viewing_status;

-- 4.1b How busy is each property, and how long do its viewings last?
-- Requirement: GROUP BY producer, sorted from most to fewest events.
-- NULLIF keeps the 0.00 placeholders on cancelled rows out of the average.
SELECT property_id,
       COUNT(*)                               AS viewings,
       ROUND(AVG(NULLIF(duration_min, 0)), 2) AS avg_minutes_held
FROM viewings
GROUP BY property_id
ORDER BY viewings DESC, property_id;

-- 4.1c Which properties have enough viewings for a rate to mean anything?
-- Requirement: HAVING with a minimum event-count threshold (10 viewings).
SELECT property_id,
       COUNT(*)                               AS viewings,
       ROUND(AVG(NULLIF(duration_min, 0)), 2) AS avg_minutes_held
FROM viewings
GROUP BY property_id
HAVING COUNT(*) >= 10
ORDER BY viewings DESC, property_id;

-- 4.1d How does activity look by region and outcome at the same time?
-- Requirement: GROUP BY two dimensions, one row per combination.
SELECT booking_city,
       viewing_status,
       COUNT(*)                               AS viewings,
       ROUND(AVG(NULLIF(duration_min, 0)), 2) AS avg_minutes_held
FROM viewings
GROUP BY booking_city, viewing_status
ORDER BY booking_city, viewing_status;