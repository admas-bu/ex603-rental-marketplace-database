-- 4.2a For each property: how many viewings, and how many were renter no-shows?
-- Requirement: conditional aggregation (CASE inside an aggregate), one pass, no WHERE.
-- Eligible viewings exclude 'Property withdrawn', matching the Unit 3 correction.
SELECT property_id,
       COUNT(*)                                                       AS viewings,
       SUM(CASE WHEN no_show_reason = 'Property withdrawn'
                THEN 0 ELSE 1 END)                                    AS eligible,
       SUM(CASE WHEN no_show_reason = 'Renter no show'
                THEN 1 ELSE 0 END)                                    AS no_shows,
       ROUND(100.0 * SUM(CASE WHEN no_show_reason = 'Renter no show' THEN 1 ELSE 0 END)
             / SUM(CASE WHEN no_show_reason = 'Property withdrawn' THEN 0 ELSE 1 END), 1)
                                                                      AS no_show_rate_pct
FROM viewings
GROUP BY property_id
ORDER BY no_show_rate_pct DESC, viewings DESC;

-- 4.2b What is the no-show rate per region, and for the platform overall?
-- Requirement: GROUP BY ROLLUP; regional subtotals plus one grand total, no detail rows.
-- ROLLUP (booking_city, property_id) produces three levels:
--   detail rows       (region + property)    GROUPING(property_id) = 0 -> removed by HAVING
--   region subtotals  (property rolled up)   GROUPING(property_id) = 1, GROUPING(booking_city) = 0
--   grand total       (everything rolled up) GROUPING(booking_city) = 1
SELECT CASE WHEN GROUPING(booking_city) = 1 THEN 'ALL REGIONS'
            ELSE booking_city END                                     AS region,
       CASE WHEN GROUPING(booking_city) = 1 THEN 'grand total'
            ELSE 'region subtotal' END                                AS row_type,
       COUNT(*)                                                       AS viewings,
       SUM(CASE WHEN no_show_reason = 'Property withdrawn'
                THEN 0 ELSE 1 END)                                    AS eligible,
       SUM(CASE WHEN no_show_reason = 'Renter no show'
                THEN 1 ELSE 0 END)                                    AS no_shows,
       ROUND(100.0 * SUM(CASE WHEN no_show_reason = 'Renter no show' THEN 1 ELSE 0 END)
             / SUM(CASE WHEN no_show_reason = 'Property withdrawn' THEN 0 ELSE 1 END), 1)
                                                                      AS no_show_rate_pct
FROM viewings
GROUP BY ROLLUP (booking_city, property_id)
HAVING GROUPING(property_id) = 1
ORDER BY GROUPING(booking_city), booking_city;

-- 4.2c What is the normal no-show rate among high-volume properties?
-- Requirement: WITH clause building a per-property aggregate, then a second
-- aggregation over that result restricted to properties with 10+ viewings.
WITH per_property AS (
    SELECT property_id,
           COUNT(*)                                                   AS viewings,
           SUM(CASE WHEN no_show_reason = 'Property withdrawn'
                    THEN 0 ELSE 1 END)                                AS eligible,
           SUM(CASE WHEN no_show_reason = 'Renter no show'
                    THEN 1 ELSE 0 END)                                AS no_shows
    FROM viewings
    GROUP BY property_id
)
SELECT COUNT(*)                                        AS high_volume_properties,
       SUM(viewings)                                   AS viewings,
       SUM(no_shows)                                   AS no_shows,
       ROUND(100.0 * SUM(no_shows) / SUM(eligible), 1) AS baseline_rate_pct,
       ROUND(AVG(100.0 * no_shows / eligible), 1)      AS avg_of_property_rates_pct,
       ROUND(MAX(100.0 * no_shows / eligible), 1)      AS worst_property_rate_pct
FROM per_property
WHERE viewings >= 10;