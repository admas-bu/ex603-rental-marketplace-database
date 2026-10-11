
-- 3.3 Which renters were involved in a disputed viewing?
-- First find disputed viewings, then return the renters involved.

-- 3.3a Find renters involved in disputed viewings using IN.
-- Requirement: Subquery with IN.
SELECT renter_id, renter_name, is_active
FROM renters
WHERE renter_id IN (
    SELECT renter_id
    FROM viewings
    WHERE viewing_status = 'disputed'
)
ORDER BY renter_id;


-- 3.3b Find the same renters using a CTE.
-- Requirement: Common Table Expression using WITH.
WITH disputed_renters AS (
    SELECT DISTINCT renter_id
    FROM viewings
    WHERE viewing_status = 'disputed'
)
SELECT r.renter_id, r.renter_name, r.is_active
FROM renters r
JOIN disputed_renters d ON d.renter_id = r.renter_id
ORDER BY r.renter_id;


-- 3.3c Find the same renters using EXISTS.
-- Requirement: Correlated subquery.
SELECT r.renter_id, r.renter_name, r.is_active
FROM renters r
WHERE EXISTS (
    SELECT 1
    FROM viewings v
    WHERE v.renter_id = r.renter_id
      AND v.viewing_status = 'disputed'
)
ORDER BY r.renter_id;


-- 3.3d Check whether all three queries return identical results.
-- Requirement: Compare actual rows, not just row counts.
-- EXCEPT ALL preserves duplicates, so any differences will be counted.
WITH f1 AS (
    SELECT renter_id, renter_name, is_active
    FROM renters
    WHERE renter_id IN (
        SELECT renter_id
        FROM viewings
        WHERE viewing_status = 'disputed'
    )
),
disputed_renters AS (
    SELECT DISTINCT renter_id
    FROM viewings
    WHERE viewing_status = 'disputed'
),
f2 AS (
    SELECT r.renter_id, r.renter_name, r.is_active
    FROM renters r
    JOIN disputed_renters d ON d.renter_id = r.renter_id
),
f3 AS (
    SELECT r.renter_id, r.renter_name, r.is_active
    FROM renters r
    WHERE EXISTS (
        SELECT 1
        FROM viewings v
        WHERE v.renter_id = r.renter_id
          AND v.viewing_status = 'disputed'
    )
)
SELECT
    (SELECT COUNT(*) FROM f1) AS f1_rows,
    (SELECT COUNT(*) FROM f2) AS f2_rows,
    (SELECT COUNT(*) FROM f3) AS f3_rows,
    (SELECT COUNT(*) FROM (
        SELECT * FROM f1
        EXCEPT ALL
        SELECT * FROM f2
    ) x) AS in_f1_not_f2,
    (SELECT COUNT(*) FROM (
        SELECT * FROM f2
        EXCEPT ALL
        SELECT * FROM f1
    ) x) AS in_f2_not_f1,
    (SELECT COUNT(*) FROM (
        SELECT * FROM f1
        EXCEPT ALL
        SELECT * FROM f3
    ) x) AS in_f1_not_f3,
    (SELECT COUNT(*) FROM (
        SELECT * FROM f3
        EXCEPT ALL
        SELECT * FROM f1
    ) x) AS in_f3_not_f1;


-- 3.3e What happens if a renter has multiple disputed viewings?
-- Requirement: Show a condition where the queries are not equivalent.
-- Removing DISTINCT from the CTE causes duplicate renter records.
WITH disputed_renters AS (
    SELECT renter_id
    FROM viewings
    WHERE viewing_status = 'disputed'
)
SELECT r.renter_id, r.renter_name, r.is_active
FROM renters r
JOIN disputed_renters d ON d.renter_id = r.renter_id
ORDER BY r.renter_id;
