-- ============================================================================
-- EX 603 Assignment 2 — schema.sql
-- Theme:  Rental Marketplace
-- Author: Admas Kebede
-- Target: PostgreSQL 14+
-- ============================================================================
-- Run with:   psql -d ex603_rental_marketplace -f schema/schema.sql
-- Re-runnable: the reset block drops every table in reverse creation order.
--
-- Creation order (each table is created only after everything it references):
--   1. addresses          references nothing
--   2. amenities          references nothing
--   3. renters            -> addresses, renters (self, referral)
--   4. properties         -> addresses
--   5. viewings           -> renters, properties
--   6. listing_amenities  -> properties, amenities
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Reset. Reverse creation order, so no dependency blocks a drop.
-- CASCADE is a safety net for anything created outside this script.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS listing_amenities CASCADE;
DROP TABLE IF EXISTS viewings          CASCADE;
DROP TABLE IF EXISTS properties        CASCADE;
DROP TABLE IF EXISTS renters           CASCADE;
DROP TABLE IF EXISTS amenities         CASCADE;
DROP TABLE IF EXISTS addresses         CASCADE;

-- ----------------------------------------------------------------------------
-- 1. addresses — first, because it references nothing.
--    Supporting entity shared by renters (1:N) and properties (1:1).
-- ----------------------------------------------------------------------------
CREATE TABLE addresses (
    address_id    INTEGER GENERATED ALWAYS AS IDENTITY,
    street_line1  VARCHAR(120) NOT NULL,
    street_line2  VARCHAR(60),
    city          VARCHAR(100) NOT NULL,
    state         CHAR(2)      NOT NULL,
    postal_code   VARCHAR(10)  NOT NULL,   -- text: preserves leading zeros
    country       CHAR(2)      NOT NULL DEFAULT 'US',

    CONSTRAINT pk_addresses PRIMARY KEY (address_id)
);

-- ----------------------------------------------------------------------------
-- 2. amenities — second, references nothing. The catalog dimension.
-- ----------------------------------------------------------------------------
CREATE TABLE amenities (
    amenity_id  INTEGER GENERATED ALWAYS AS IDENTITY,
    name        VARCHAR(60) NOT NULL,
    category    VARCHAR(20) NOT NULL,

    CONSTRAINT pk_amenities PRIMARY KEY (amenity_id),
    CONSTRAINT uq_amenities_name UNIQUE (name),
    CONSTRAINT chk_amenities_category
        CHECK (category IN ('building', 'unit', 'outdoor', 'policy'))
);

-- ----------------------------------------------------------------------------
-- 3. renters — the actor. References addresses, and itself for referrals.
--    The recursive FK lives here because "who referred you" is a fact about
--    a renter, and losing the referrer must not affect the referee.
-- ----------------------------------------------------------------------------
CREATE TABLE renters (
    renter_id              INTEGER GENERATED ALWAYS AS IDENTITY,
    first_name             VARCHAR(50)  NOT NULL,
    last_name              VARCHAR(50)  NOT NULL,
    display_name           VARCHAR(100) NOT NULL,
    email                  VARCHAR(254) NOT NULL,     -- RFC 5321 maximum
    phone                  VARCHAR(20),
    address_id             INTEGER,                   -- nullable by design
    referred_by_renter_id  INTEGER,                   -- recursive FK
    date_of_birth          DATE,
    joined_at              TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_renters PRIMARY KEY (renter_id),
    CONSTRAINT uq_renters_email UNIQUE (email),

    CONSTRAINT fk_renters_address
        FOREIGN KEY (address_id) REFERENCES addresses (address_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_renters_referrer
        FOREIGN KEY (referred_by_renter_id) REFERENCES renters (renter_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_renters_no_self_referral
        CHECK (referred_by_renter_id IS DISTINCT FROM renter_id)
);

-- ----------------------------------------------------------------------------
-- 4. properties — the producer. References addresses.
--    Listings are retired with is_active = FALSE, never deleted, once they
--    have viewing history (viewings restricts the delete).
-- ----------------------------------------------------------------------------
CREATE TABLE properties (
    property_id        INTEGER GENERATED ALWAYS AS IDENTITY,
    display_name       VARCHAR(150)  NOT NULL,
    description        TEXT,
    property_type      VARCHAR(20)   NOT NULL,
    square_feet        INTEGER       NOT NULL,
    bedrooms           SMALLINT      NOT NULL,
    bathrooms          NUMERIC(3,1)  NOT NULL,
    monthly_rent       NUMERIC(10,2) NOT NULL,   -- theme filter attribute
    security_deposit   NUMERIC(10,2),            -- NULL = unknown, 0 = none
    is_active          BOOLEAN       NOT NULL DEFAULT TRUE,   -- theme flag
    available_from     DATE,
    lease_term_months  SMALLINT,
    furnished          BOOLEAN       NOT NULL DEFAULT FALSE,
    year_built         SMALLINT,
    address_id         INTEGER       NOT NULL,
    listed_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Derived value, stored: renters sort and filter on it, so it should
    -- be indexable. Inputs are NOT NULL and > 0, so it can never divide by 0.
    rent_per_sqft      NUMERIC(8,2)
        GENERATED ALWAYS AS (ROUND(monthly_rent / square_feet, 2)) STORED,

    CONSTRAINT pk_properties PRIMARY KEY (property_id),
    CONSTRAINT uq_properties_address UNIQUE (address_id),

    CONSTRAINT fk_properties_address
        FOREIGN KEY (address_id) REFERENCES addresses (address_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_properties_type
        CHECK (property_type IN ('apartment', 'condo', 'townhouse',
                                 'single_family', 'duplex', 'studio')),
    CONSTRAINT chk_properties_square_feet_positive  CHECK (square_feet > 0),
    CONSTRAINT chk_properties_bedrooms_nonneg       CHECK (bedrooms >= 0),
    CONSTRAINT chk_properties_bathrooms_positive    CHECK (bathrooms > 0),
    CONSTRAINT chk_properties_rent_positive         CHECK (monthly_rent > 0),
    CONSTRAINT chk_properties_deposit_nonneg        CHECK (security_deposit >= 0),
    CONSTRAINT chk_properties_lease_term_positive   CHECK (lease_term_months > 0),
    CONSTRAINT chk_properties_year_built_range
        CHECK (year_built BETWEEN 1600 AND 2100)
);

-- ----------------------------------------------------------------------------
-- 5. viewings — the event / fact table. References renters and properties.
--    BIGINT key because this table grows fastest; nothing references it,
--    so the type mismatch rule does not apply.
-- ----------------------------------------------------------------------------
CREATE TABLE viewings (
    viewing_id     BIGINT GENERATED ALWAYS AS IDENTITY,
    renter_id      INTEGER     NOT NULL,      -- matches renters.renter_id
    property_id    INTEGER     NOT NULL,      -- matches properties.property_id
    viewing_type   VARCHAR(20) NOT NULL,
    status         VARCHAR(20) NOT NULL,
    scheduled_at   TIMESTAMP   NOT NULL,      -- theme timestamp
    started_at     TIMESTAMP,
    duration_min   INTEGER,                   -- theme metric
    rating         SMALLINT,
    notes          TEXT,

    CONSTRAINT pk_viewings PRIMARY KEY (viewing_id),

    CONSTRAINT fk_viewings_renter
        FOREIGN KEY (renter_id) REFERENCES renters (renter_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_viewings_property
        FOREIGN KEY (property_id) REFERENCES properties (property_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_viewings_type
        CHECK (viewing_type IN ('in_person', 'virtual', 'self_guided')),
    CONSTRAINT chk_viewings_status
        CHECK (status IN ('scheduled', 'completed', 'cancelled', 'no_show')),
    CONSTRAINT chk_viewings_duration_positive CHECK (duration_min > 0),
    CONSTRAINT chk_viewings_rating_range      CHECK (rating BETWEEN 1 AND 5),

    -- A completed viewing must carry actual timing.
    CONSTRAINT chk_viewings_completed_has_timing
        CHECK (status <> 'completed'
               OR (started_at IS NOT NULL AND duration_min IS NOT NULL)),

    -- Only a completed viewing may carry a duration.
    CONSTRAINT chk_viewings_duration_only_if_completed
        CHECK (status = 'completed' OR duration_min IS NULL),

    -- A viewing cannot start materially before it was scheduled.
    CONSTRAINT chk_viewings_start_after_schedule
        CHECK (started_at IS NULL
               OR started_at >= scheduled_at - INTERVAL '1 day')
);

-- Supporting indexes for the query patterns Units 5-6 will use.
CREATE INDEX idx_viewings_property_time ON viewings (property_id, scheduled_at);
CREATE INDEX idx_viewings_renter_time   ON viewings (renter_id, scheduled_at);

-- ----------------------------------------------------------------------------
-- 6. listing_amenities — last. Resolves the M:N between properties and
--    amenities. The primary key is the pair of foreign keys, not a new id.
-- ----------------------------------------------------------------------------
CREATE TABLE listing_amenities (
    property_id  INTEGER NOT NULL,
    amenity_id   INTEGER NOT NULL,

    CONSTRAINT pk_listing_amenities PRIMARY KEY (property_id, amenity_id),

    CONSTRAINT fk_listing_amenities_property
        FOREIGN KEY (property_id) REFERENCES properties (property_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_listing_amenities_amenity
        FOREIGN KEY (amenity_id) REFERENCES amenities (amenity_id)
        ON DELETE RESTRICT
);

-- ============================================================================
-- End of schema.sql
-- ============================================================================