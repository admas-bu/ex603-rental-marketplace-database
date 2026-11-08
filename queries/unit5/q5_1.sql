-- 5.1a Who are the people behind the events?
-- Requirement: three-table INNER JOIN (event + actor + producer).
-- Each viewing with the renter who booked it, the property viewed, and when.
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

-- 5.1b-i What amenities do the Unit 4 flagged properties have?
-- Requirement: producer -> junction -> catalog.
-- Flagged in Unit 4: properties 2 and 3 (act now), property 4 (watch).
SELECT p.property_id,
       p.property_label,
       a.amenity_name,
       la.verified_on
FROM properties p
JOIN listing_amenities la ON la.property_id = p.property_id
JOIN amenities         a  ON a.amenity_id   = la.amenity_id
WHERE p.property_id IN (2, 3, 4)
ORDER BY a.amenity_name, p.property_id;

-- 5.1b-ii Which properties carry the Gym tag, and what are their no-show rates?
-- Requirement: return the producers associated with one catalog tag via the junction.
-- Gym is the one amenity both act-now properties (2 and 3) share.
SELECT p.property_id,
       p.property_label,
       p.city,
       COUNT(v.viewing_id) FILTER (WHERE v.no_show_reason IS DISTINCT FROM 'Property withdrawn') AS eligible,
       COUNT(v.viewing_id) FILTER (WHERE v.no_show_reason = 'Renter no show')                    AS no_shows
FROM amenities a
JOIN listing_amenities la ON la.amenity_id  = a.amenity_id
JOIN properties        p  ON p.property_id  = la.property_id
LEFT JOIN viewings     v  ON v.property_id  = p.property_id
WHERE a.amenity_name = 'Gym'
GROUP BY p.property_id, p.property_label, p.city
ORDER BY no_shows DESC, p.property_id;

-- 5.1c How do the flagged properties compare with similar properties?
-- Requirement: self join on properties.
-- Each flagged property (a) is paired with every other property (b) that is
-- either priced within $200 of it or in the same city. The stats CTE adds
-- each side's no-show rate so the pair can be compared.
WITH stats AS (
    SELECT p.property_id,
           COUNT(v.viewing_id) FILTER (WHERE v.no_show_reason IS DISTINCT FROM 'Property withdrawn') AS eligible,
           COUNT(v.viewing_id) FILTER (WHERE v.no_show_reason = 'Renter no show')                    AS no_shows
    FROM properties p
    LEFT JOIN viewings v ON v.property_id = p.property_id
    GROUP BY p.property_id
)
SELECT a.property_id                                                   AS flagged,
       a.city                                                          AS flagged_city,
       a.monthly_rent                                                  AS flagged_rent,
       ROUND(100.0 * sa.no_shows / NULLIF(sa.eligible, 0), 1)          AS flagged_rate_pct,
       b.property_id                                                   AS peer,
       b.city                                                          AS peer_city,
       b.monthly_rent                                                  AS peer_rent,
       CASE WHEN a.city = b.city THEN 'same city' ELSE 'same price band' END AS peer_because,
       sb.eligible                                                     AS peer_eligible,
       ROUND(100.0 * sb.no_shows / NULLIF(sb.eligible, 0), 1)          AS peer_rate_pct
FROM properties a
JOIN properties b
  ON b.property_id <> a.property_id
 AND (ABS(a.monthly_rent - b.monthly_rent) <= 200 OR a.city = b.city)
JOIN stats sa ON sa.property_id = a.property_id
JOIN stats sb ON sb.property_id = b.property_id
WHERE a.property_id IN (2, 3)
ORDER BY a.property_id, peer_rate_pct DESC NULLS LAST, b.property_id;


-- 5.1d Is the no-show rate higher among the most expensive listings?
-- Requirement: supports the 5.1 self-join finding with pooled rates by price tier.
SELECT CASE WHEN p.monthly_rent > 3000 THEN 'above $3,000' ELSE '$3,000 or less' END AS price_tier,
       COUNT(DISTINCT p.property_id)                                                  AS properties,
       COUNT(v.viewing_id) FILTER (WHERE v.no_show_reason IS DISTINCT FROM 'Property withdrawn') AS eligible,
       COUNT(v.viewing_id) FILTER (WHERE v.no_show_reason = 'Renter no show')                    AS no_shows,
       ROUND(100.0 * COUNT(v.viewing_id) FILTER (WHERE v.no_show_reason = 'Renter no show')
             / COUNT(v.viewing_id) FILTER (WHERE v.no_show_reason IS DISTINCT FROM 'Property withdrawn'), 1) AS rate_pct
FROM properties p
JOIN viewings v ON v.property_id = p.property_id
GROUP BY 1
ORDER BY 1 DESC;