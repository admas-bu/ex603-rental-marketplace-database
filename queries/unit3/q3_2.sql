
-- 3.2 Part A: The rows that vanished

-- Step 1: How many viewing records exist?
-- We will use this total to check whether any rows are missing.
SELECT COUNT(*) AS table_total
FROM viewings;


-- Step 2: How many viewings did not start within 30 minutes?
-- This query misses viewings where attended_at is NULL.
-- Comparing NULL with a timestamp returns UNKNOWN, which WHERE excludes.
SELECT COUNT(*) AS rows_returned
FROM viewings
WHERE NOT (attended_at <= scheduled_at + INTERVAL '30 minutes');


-- Step 3: How many records are excluded by the two filters?
-- The two conditions should account for all viewings, but they
-- exclude records where attended_at is NULL.
SELECT
    COUNT(*) FILTER (
        WHERE NOT (attended_at <= scheduled_at + INTERVAL '30 minutes')
    ) AS late_viewings,
    COUNT(*) FILTER (
        WHERE attended_at <= scheduled_at + INTERVAL '30 minutes'
    ) AS on_time_viewings,
    COUNT(*) FILTER (
        WHERE attended_at IS NULL
    ) AS missing_start_time,
    COUNT(*) AS table_total
FROM viewings;


-- Step 4: Include viewings that never started.
-- IS NULL explicitly includes records with no start time.
SELECT COUNT(*) AS rows_returned
FROM viewings
WHERE NOT (attended_at <= scheduled_at + INTERVAL '30 minutes')
   OR attended_at IS NULL;


-- Step 4b: Fix the same issue using COALESCE.
-- Treat a missing start time as infinity so it is not
-- considered within 30 minutes of the scheduled time.
SELECT COUNT(*) AS rows_returned
FROM viewings
WHERE NOT (
    COALESCE(attended_at, 'infinity'::timestamp)
    <= scheduled_at + INTERVAL '30 minutes'
);


-- 3.2 Part B: The alias that did not exist yet

-- Step 1: Find viewings that started more than 30 minutes late.
-- This fails because WHERE cannot reference an alias defined in SELECT.
SELECT viewing_id,
       ROUND(EXTRACT(EPOCH FROM (attended_at - scheduled_at)) / 60)
           AS start_delay_min
FROM viewings
WHERE start_delay_min > 30;


-- Step 2: Fix the query by repeating the calculation in WHERE.
SELECT viewing_id,
       ROUND(EXTRACT(EPOCH FROM (attended_at - scheduled_at)) / 60)
           AS start_delay_min
FROM viewings
WHERE ROUND(EXTRACT(EPOCH FROM (attended_at - scheduled_at)) / 60) > 30
ORDER BY start_delay_min DESC, viewing_id;


-- Step 3: Fix the query using a CTE.
-- The alias becomes available to the outer query.
WITH delays AS (
    SELECT viewing_id,
           ROUND(EXTRACT(EPOCH FROM (attended_at - scheduled_at)) / 60)
               AS start_delay_min
    FROM viewings
)
SELECT viewing_id, start_delay_min
FROM delays
WHERE start_delay_min > 30
ORDER BY start_delay_min DESC, viewing_id;
