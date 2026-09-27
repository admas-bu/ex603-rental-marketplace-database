# Schema Definition (Task 1.1, updated in Unit 2)

Relation schemas for the Rental Marketplace database. The five theme roles map as follows:

| Role | Relation |
|---|---|
| actor | `renters` |
| producer | `properties` |
| event | `viewings` |
| catalog | `amenities` |
| junction | `listing_amenities` |

One supporting relation, `addresses`, is added because two roles (`renters` and `properties`) share the same address structure. Its justification is in `/analysis/unit1.md`.

Unit 2 changes: short text domains are now `varchar(n)` with a chosen n; `renters.referred_by_renter_id` (recursive FK) and `properties.rent_per_sqft` (stored generated column) were added. See `/analysis/unit2.md`.

Notation: **PK** = primary key, **FK** = foreign key, **NN** = NOT NULL. Domains are PostgreSQL types.

---

## `addresses` (supporting entity)

A postal address, referenced by both renters and properties.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `address_id` | `integer` (generated identity) | NN | Surrogate identifier |
| `street_line1` | `varchar(120)` | NN | Street number and name |
| `street_line2` | `varchar(60)` | nullable | Unit, apartment, or suite |
| `city` | `varchar(100)` | NN | City |
| `state` | `char(2)` | NN | Two-letter state or province code |
| `postal_code` | `varchar(10)` | NN | Text, not integer: preserves leading zeros and non-US formats |
| `country` | `char(2)` | NN, default `'US'` | ISO 3166-1 alpha-2 code |

**Primary key:** `address_id`

---

## `renters` (actor)

A user who searches the platform and books viewings.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `renter_id` | `integer` (generated identity) | NN | Surrogate identifier |
| `first_name` | `varchar(50)` | NN | Given name |
| `last_name` | `varchar(50)` | NN | Family name |
| `display_name` | `varchar(100)` | NN | Name shown on the platform |
| `email` | `varchar(254)` | NN | Login and contact email; unique; 254 is the RFC 5321 maximum |
| `phone` | `varchar(20)` | nullable | Text, not numeric: supports country codes and formatting |
| `address_id` | `integer` | nullable | FK → `addresses.address_id` |
| `referred_by_renter_id` | `integer` | nullable | FK → `renters.renter_id` (recursive); the renter who referred this one; may not equal `renter_id` |
| `date_of_birth` | `date` | nullable | Used for age-bracket analysis |
| `joined_at` | `timestamp` | NN, default `CURRENT_TIMESTAMP` | Account creation time |

**Primary key:** `renter_id`
**Candidate key:** `email` (declared UNIQUE, not used as PK; see analysis)

---

## `properties` (producer)

A rental listing available for viewing on the platform.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `property_id` | `integer` (generated identity) | NN | Surrogate identifier |
| `display_name` | `varchar(150)` | NN | Listing title |
| `description` | `text` | nullable | Free-text listing description |
| `property_type` | `varchar(20)` | NN | One of: `apartment`, `condo`, `townhouse`, `single_family`, `duplex`, `studio` |
| `square_feet` | `integer` | NN | Interior area; must be positive |
| `bedrooms` | `smallint` | NN | Number of bedrooms; 0 for studios |
| `bathrooms` | `numeric(3,1)` | NN | Number of bathrooms; allows half baths (1.5) |
| `monthly_rent` | `numeric(10,2)` | NN | Asking rent per month; the filtering attribute required by the theme |
| `security_deposit` | `numeric(10,2)` | nullable | Required deposit, if known; `NULL` = unknown, `0` = none required |
| `is_active` | `boolean` | NN, default `true` | Whether the listing is live; the activity flag required by the theme |
| `available_from` | `date` | nullable | Earliest move-in date |
| `lease_term_months` | `smallint` | nullable | Standard lease length |
| `furnished` | `boolean` | NN, default `false` | Whether the unit is furnished |
| `year_built` | `smallint` | nullable | Construction year |
| `address_id` | `integer` | NN | FK → `addresses.address_id`; unique per property |
| `listed_at` | `timestamp` | NN, default `CURRENT_TIMESTAMP` | When the listing was created |
| `rent_per_sqft` | `numeric(8,2)` (generated, stored) | NN | `ROUND(monthly_rent / square_feet, 2)`; derived value stored so it can be indexed and sorted on |

**Primary key:** `property_id`

---

## `viewings` (event)

The high-volume fact table. One row per scheduled viewing of a property by a renter.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `viewing_id` | `bigint` (generated identity) | NN | Surrogate identifier; `bigint` because this table grows fastest; nothing references it |
| `renter_id` | `integer` | NN | FK → `renters.renter_id` |
| `property_id` | `integer` | NN | FK → `properties.property_id` |
| `viewing_type` | `varchar(20)` | NN | One of: `in_person`, `virtual`, `self_guided` |
| `status` | `varchar(20)` | NN | One of: `scheduled`, `completed`, `cancelled`, `no_show` |
| `scheduled_at` | `timestamp` | NN | When the viewing was booked for; the timestamp required by the theme |
| `started_at` | `timestamp` | nullable | When the viewing actually began; set only when completed |
| `duration_min` | `integer` | nullable | Length in minutes; the metric required by the theme; set only when completed |
| `rating` | `smallint` | nullable | Renter's 1–5 rating of the viewing |
| `notes` | `text` | nullable | Free-text notes |

**Primary key:** `viewing_id`
**Indexes:** `(property_id, scheduled_at)`, `(renter_id, scheduled_at)`

---

## `amenities` (catalog)

The descriptive dimension: tags that classify a property.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `amenity_id` | `integer` (generated identity) | NN | Surrogate identifier |
| `name` | `varchar(60)` | NN | Amenity name; unique |
| `category` | `varchar(20)` | NN | One of: `building`, `unit`, `outdoor`, `policy` |

**Primary key:** `amenity_id`

---

## `listing_amenities` (junction)

Many-to-many link between properties and amenities.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `property_id` | `integer` | NN | FK → `properties.property_id` |
| `amenity_id` | `integer` | NN | FK → `amenities.amenity_id` |

**Primary key:** composite `(property_id, amenity_id)`

No additional attributes. A junction row records only that the relationship exists; if the relationship needed its own data it would be modelled as an entity.