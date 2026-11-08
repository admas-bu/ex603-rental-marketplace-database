-- 5.3a-i How big are the two source tables, and what should a CROSS JOIN produce?
-- Requirement: count each source table, run the CROSS JOIN, count its rows,
-- and show the result equals the product of the two counts.
SELECT (SELECT COUNT(*) FROM properties)                       AS properties_rows,
       (SELECT COUNT(*) FROM amenities)                        AS amenities_rows,
       (SELECT COUNT(*) FROM properties)
     * (SELECT COUNT(*) FROM amenities)                        AS expected_product,
       (SELECT COUNT(*) FROM properties CROSS JOIN amenities)  AS cross_join_rows;

-- 5.3a-ii Every property paired with every amenity, and whether it has it.
-- Requirement: CROSS JOIN between two small tables.
-- The Cartesian product is the full grid of possible property/amenity pairs;
-- the LEFT JOIN to the junction marks which pairs actually exist.
SELECT p.property_id,
       a.amenity_name,
       (la.property_id IS NOT NULL) AS has_amenity
FROM properties p
CROSS JOIN amenities a
LEFT JOIN listing_amenities la
       ON la.property_id = p.property_id
      AND la.amenity_id  = a.amenity_id
ORDER BY p.property_id, a.amenity_id;

-- 5.3b How does PostgreSQL plan to execute the three-table join from 5.1a?
-- Requirement: EXPLAIN on the 5.1a query.
-- ANALYZE (on its own) refreshes the planner's table statistics first, so the
-- row estimates reflect the real table sizes. It changes no data.
ANALYZE;

EXPLAIN
SELECT v.viewing_id,
       v.scheduled_at,
       r.renter_id,
       r.renter_name,
       p.property_id,
       p.property_label,
       p.city,
       v.viewing_status
FROM viewings v
JOIN renters    r ON r.renter_id   = v.renter_id
JOIN properties p ON p.property_id = v.property_id
ORDER BY v.scheduled_at;

-- 5.3b (follow-up) Actual execution: real row counts and timings.
-- EXPLAIN ANALYZE runs the query. Safe here because it is a read-only SELECT.
EXPLAIN ANALYZE
SELECT v.viewing_id,
       v.scheduled_at,
       r.renter_id,
       r.renter_name,
       p.property_id,
       p.property_label,
       p.city,
       v.viewing_status
FROM viewings v
JOIN renters    r ON r.renter_id   = v.renter_id
JOIN properties p ON p.property_id = v.property_id
ORDER BY v.scheduled_at;