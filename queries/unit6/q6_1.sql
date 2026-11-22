-- ---------------------------------------------------------------------
-- 6.1a (window version)
-- Question: Is each viewing unusually long or short for its own property?
-- Every viewing keeps its row and gets its property's average beside it.
-- Only viewings that took place (duration_min > 0, 166 rows) are used;
-- cancelled viewings are stored as 0 minutes and would drag averages down.
-- ---------------------------------------------------------------------
SELECT v.viewing_id,
       v.property_id,
       v.scheduled_at::date                                          AS viewing_date,
       v.duration_min,
       ROUND(AVG(v.duration_min) OVER (PARTITION BY v.property_id), 2) AS property_avg_min,
       ROUND(v.duration_min
             - AVG(v.duration_min) OVER (PARTITION BY v.property_id), 2) AS diff_from_avg_min
FROM viewings AS v
WHERE v.duration_min > 0
ORDER BY v.property_id, v.scheduled_at;


-- ---------------------------------------------------------------------
-- 6.1a (GROUP BY version)
-- Question: What is the average viewing length per property?
-- Same average, but the rows collapse to one per property, so the
-- individual viewings (and how far each one is from the average) are gone.
-- ---------------------------------------------------------------------
SELECT v.property_id,
       COUNT(*)                        AS viewings_held,
       ROUND(AVG(v.duration_min), 2)   AS property_avg_min
FROM viewings AS v
WHERE v.duration_min > 0
GROUP BY v.property_id
ORDER BY v.property_id;


-- ---------------------------------------------------------------------
-- 6.1a (row counts side by side)
-- Question: How many rows does each version return?
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(*)
     FROM (SELECT AVG(duration_min) OVER (PARTITION BY property_id)
           FROM viewings WHERE duration_min > 0) AS w)          AS window_version_rows,
    (SELECT COUNT(*)
     FROM (SELECT property_id
           FROM viewings WHERE duration_min > 0
           GROUP BY property_id) AS g)                           AS group_by_version_rows;


-- ---------------------------------------------------------------------
-- 6.1b
-- Question: How do the three ranking functions order properties by number
-- of viewings, and what happens when two properties have the same count?
-- LEFT JOIN keeps properties 14 and 15 (zero viewings) on the leaderboard,
-- as recommended in the Unit 5 memo.
-- ROW_NUMBER needs a tiebreaker (property_id) to be repeatable; without it
-- Postgres may return tied rows in any order from one run to the next.
-- ---------------------------------------------------------------------
WITH counts AS (
    SELECT p.property_id,
           COUNT(v.viewing_id) AS viewings
    FROM properties AS p
    LEFT JOIN viewings AS v ON v.property_id = p.property_id
    GROUP BY p.property_id
)
SELECT property_id,
       viewings,
       ROW_NUMBER() OVER (ORDER BY viewings DESC, property_id) AS row_number,
       RANK()       OVER (ORDER BY viewings DESC)              AS rank,
       DENSE_RANK() OVER (ORDER BY viewings DESC)              AS dense_rank
FROM counts
ORDER BY viewings DESC, property_id;


-- ---------------------------------------------------------------------
-- 6.1c
-- Question: If we split properties into four demand bands by number of
-- viewings, do properties with the same count always land in the same band?
-- NTILE only counts rows (15 properties -> bands of 4, 4, 4, 3). It does not
-- look at the values, so a tie can be cut in half at a band boundary.
-- tie_split_across_bands is TRUE when properties with the same count were
-- put in different bands.
-- ---------------------------------------------------------------------
WITH counts AS (
    SELECT p.property_id,
           COUNT(v.viewing_id) AS viewings
    FROM properties AS p
    LEFT JOIN viewings AS v ON v.property_id = p.property_id
    GROUP BY p.property_id
),
banded AS (
    SELECT property_id,
           viewings,
           NTILE(4) OVER (ORDER BY viewings DESC, property_id) AS demand_band
    FROM counts
)
SELECT property_id,
       viewings,
       demand_band,
       MIN(demand_band) OVER (PARTITION BY viewings)
         <> MAX(demand_band) OVER (PARTITION BY viewings)      AS tie_split_across_bands
FROM banded
ORDER BY demand_band, viewings DESC, property_id;