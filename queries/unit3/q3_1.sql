
-- 3.1a Find the 10 cheapest available properties.
-- Requirement: SELECT, WHERE, ORDER BY, LIMIT.
SELECT property_id, property_label, city, monthly_rent
FROM properties
WHERE is_available = TRUE
  AND monthly_rent <= 2000
ORDER BY monthly_rent ASC, property_id ASC
LIMIT 10;


-- 3.1b-i What viewing statuses exist?
-- Requirement: SELECT DISTINCT.
SELECT DISTINCT viewing_status
FROM viewings
ORDER BY viewing_status;

-- 3.1b-ii What reasons are associated with each viewing status?
-- Requirement: SELECT DISTINCT on multiple columns.
-- A renter no-show is recorded as a reason, not a status.
SELECT DISTINCT viewing_status, no_show_reason
FROM viewings
ORDER BY viewing_status, no_show_reason;


-- 3.1c-i Which viewings lasted between 30 and 60 minutes?
-- Requirement: Numeric range filter using BETWEEN.
SELECT viewing_id, property_id, renter_id,
       duration_min, viewing_status
FROM viewings
WHERE duration_min BETWEEN 30 AND 60
ORDER BY duration_min DESC;

-- 3.1c-ii Which viewings were cancelled by the renter
-- or had a renter no-show?
-- Requirement: Filter using IN.
SELECT viewing_id, property_id, renter_id,
       scheduled_at, no_show_reason
FROM viewings
WHERE no_show_reason IN ('Renter no show', 'Renter cancelled')
ORDER BY scheduled_at;


-- 3.1d-i Which property labels start with Property_1?
-- Requirement: Text pattern matching using LIKE.
-- Escape the underscore since LIKE treats it as a wildcard.
SELECT property_id, property_label, city
FROM properties
WHERE property_label LIKE 'Property\_1%'
ORDER BY property_id;

-- 3.1d-ii Which viewings have no reason recorded?
-- Requirement: Find missing values using IS NULL.
SELECT viewing_id, viewing_status, no_show_reason
FROM viewings
WHERE no_show_reason IS NULL
ORDER BY viewing_id;

-- 3.1d-iii How can we make missing reasons easier to read?
-- Requirement: Replace NULL values using COALESCE.
SELECT viewing_id,
       viewing_status,
       COALESCE(no_show_reason, 'No reason provided') AS reason
FROM viewings
ORDER BY viewing_id;


-- 3.1e How can we make viewing records easier to understand?
-- Requirement: Computed columns and CASE expressions.
-- Group viewings by time of day, outcome, and duration.
SELECT viewing_id,
       scheduled_at::date AS viewing_date,
       CASE
           WHEN EXTRACT(HOUR FROM scheduled_at) BETWEEN 6 AND 11
               THEN 'Morning'
           WHEN EXTRACT(HOUR FROM scheduled_at) BETWEEN 12 AND 16
               THEN 'Afternoon'
           ELSE 'Evening'
       END AS time_of_day,
       CASE
           WHEN viewing_status = 'attended'
               THEN 'Renter attended viewing'
           WHEN viewing_status = 'disputed'
               THEN 'Renter disputed viewing'
           WHEN no_show_reason = 'Renter no show'
               THEN 'Renter did not show up'
           WHEN no_show_reason = 'Renter cancelled'
               THEN 'Renter cancelled viewing'
           ELSE 'Other'
       END AS outcome,
       ROUND(
           EXTRACT(EPOCH FROM (attended_at - scheduled_at)) / 60
       ) AS attendance_delay_min,
       CASE
           WHEN duration_min IS NULL THEN 'Unknown duration'
           WHEN duration_min = 0 THEN 'Viewing did not take place'
           WHEN duration_min < 15 THEN 'Quick viewing'
           WHEN duration_min < 30 THEN 'Standard viewing'
           ELSE 'Long viewing'
       END AS viewing_length
FROM viewings
ORDER BY scheduled_at
LIMIT 20;
