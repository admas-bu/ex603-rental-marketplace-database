-- 5.2a-i Every property and how many viewings it has, including properties with none.
-- Requirement: LEFT JOIN from producer to event.
-- COUNT(v.viewing_id) counts only matched rows, so a property with no
-- viewings shows 0 instead of the 1 that COUNT(*) would give it.
SELECT p.property_id,
       p.property_label,
       COUNT(v.viewing_id) AS viewings
FROM properties p
LEFT JOIN viewings v ON v.property_id = p.property_id
GROUP BY p.property_id, p.property_label
ORDER BY p.property_id;

-- 5.2a-ii The same report written with INNER JOIN.
-- Requirement: equivalent query using INNER JOIN.
SELECT p.property_id,
       p.property_label,
       COUNT(v.viewing_id) AS viewings
FROM properties p
JOIN viewings v ON v.property_id = p.property_id
GROUP BY p.property_id, p.property_label
ORDER BY p.property_id;

-- 5.2a-iii How many properties does the inner join leave out?
-- Requirement: count of producers excluded by the inner join.
-- COUNT(DISTINCT property_id) so a property with many viewings counts once.
SELECT (SELECT COUNT(DISTINCT p.property_id)
        FROM properties p
        LEFT JOIN viewings v ON v.property_id = p.property_id)  AS left_join_properties,
       (SELECT COUNT(DISTINCT p.property_id)
        FROM properties p
        JOIN viewings v ON v.property_id = p.property_id)       AS inner_join_properties,
       (SELECT COUNT(DISTINCT p.property_id)
        FROM properties p
        LEFT JOIN viewings v ON v.property_id = p.property_id)
     - (SELECT COUNT(DISTINCT p.property_id)
        FROM properties p
        JOIN viewings v ON v.property_id = p.property_id)       AS excluded_by_inner_join;

-- 5.2b-i The same rows as the LEFT JOIN, written as a RIGHT JOIN.
-- Requirement: RIGHT JOIN equivalent to 5.2a-i. The tables swap sides;
-- properties is now on the right, so it is the side that keeps every row.
SELECT p.property_id,
       p.property_label,
       COUNT(v.viewing_id) AS viewings
FROM viewings v
RIGHT JOIN properties p ON p.property_id = v.property_id
GROUP BY p.property_id, p.property_label
ORDER BY p.property_id;

-- 5.2b-ii Do the LEFT and RIGHT JOIN really return the same rows?
-- Requirement: verify, don't assume. Compare at row level (before grouping),
-- in both directions, with EXCEPT ALL so duplicates would also be caught.
-- Zero in both columns means the two results are identical.
WITH lj AS (
    SELECT p.property_id, v.viewing_id
    FROM properties p
    LEFT JOIN viewings v ON v.property_id = p.property_id
), rj AS (
    SELECT p.property_id, v.viewing_id
    FROM viewings v
    RIGHT JOIN properties p ON p.property_id = v.property_id
)
SELECT (SELECT COUNT(*) FROM lj)                                     AS left_rows,
       (SELECT COUNT(*) FROM rj)                                     AS right_rows,
       (SELECT COUNT(*) FROM (SELECT * FROM lj EXCEPT ALL SELECT * FROM rj) x) AS in_left_not_right,
       (SELECT COUNT(*) FROM (SELECT * FROM rj EXCEPT ALL SELECT * FROM lj) x) AS in_right_not_left;

-- 5.2b-iii Matched and unmatched rows from both sides at once.
-- Requirement: FULL OUTER JOIN between producer and event.
-- Every row of the full join is classified: a viewing with its property,
-- a property with no viewings, or a viewing that points at no property.
-- FILTER keeps a category visible even when its count is 0.
SELECT COUNT(*)                                                          AS full_join_rows,
       COUNT(*) FILTER (WHERE p.property_id IS NOT NULL
                          AND v.viewing_id  IS NOT NULL)                 AS matched,
       COUNT(*) FILTER (WHERE v.viewing_id  IS NULL)                     AS property_no_viewings,
       COUNT(*) FILTER (WHERE p.property_id IS NULL)                     AS viewing_no_property,
       string_agg(p.property_id::text, ', ' ORDER BY p.property_id)
           FILTER (WHERE v.viewing_id IS NULL)                           AS unmatched_property_ids
FROM properties p
FULL OUTER JOIN viewings v ON v.property_id = p.property_id;

-- 5.2c-i Which properties have never had a viewing? (NOT EXISTS)
-- Requirement: anti-join with NOT EXISTS.
SELECT p.property_id,
       p.property_label,
       p.city,
       p.monthly_rent,
       p.listed_on,
       p.is_available
FROM properties p
WHERE NOT EXISTS (
    SELECT 1
    FROM viewings v
    WHERE v.property_id = p.property_id
)
ORDER BY p.property_id;

-- 5.2c-ii Which properties have never had a viewing? (EXCEPT)
-- Requirement: set difference with EXCEPT. Only the key can be compared,
-- so the result is IDs alone.
SELECT property_id FROM properties
EXCEPT
SELECT property_id FROM viewings
ORDER BY property_id;

-- 5.2c-iii Do the two approaches find the same properties?
-- Requirement: compare the two results. Zero rows both ways = identical.
WITH ne AS (
    SELECT p.property_id FROM properties p
    WHERE NOT EXISTS (SELECT 1 FROM viewings v WHERE v.property_id = p.property_id)
), ex AS (
    SELECT property_id FROM properties
    EXCEPT
    SELECT property_id FROM viewings
)
SELECT (SELECT COUNT(*) FROM ne)                                        AS not_exists_count,
       (SELECT COUNT(*) FROM ex)                                        AS except_count,
       (SELECT COUNT(*) FROM (SELECT * FROM ne EXCEPT SELECT * FROM ex) d) AS only_in_not_exists,
       (SELECT COUNT(*) FROM (SELECT * FROM ex EXCEPT SELECT * FROM ne) d) AS only_in_except;