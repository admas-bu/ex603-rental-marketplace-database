# Schema Definition (Task 1.1)

Relation schemas for the Rental Marketplace database. The five theme roles map as follows:

| Role | Relation |
|---|---|
| actor | `renters` |
| producer | `properties` |
| event | `viewings` |
| catalog | `amenities` |
| junction | `listing_amenities` |

One supporting relation, `addresses`, is added because two roles (`renters` and `properties`) share the same address structure. Its justification is in `/analysis/unit1.md`.

Notation: **PK** = primary key, **FK** = foreign key, **NN** = NOT NULL. Domains are PostgreSQL types.

---

## `addresses` (supporting entity)

A postal address, referenced by both renters and properties.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `address_id` | `integer` (generated identity) | NN | Surrogate identifier |
| `street_line1` | `text` | NN | Street number and name |
| `street_line2` | `text` | nullable | Unit, apartment, or suite |
| `city` | `text` | NN | City |
| `state` | `char(2)` | NN | Two-letter state or province code |
| `postal_code` | `text` | NN | Text, not integer: preserves leading zeros and non-US formats |
| `country` | `char(2)` | NN, default `'US'` | ISO 3166-1 alpha-2 code |

**Primary key:** `address_id`

---

## `renters` (actor)

A user who searches the platform and books viewings.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `renter_id` | `integer` (generated identity) | NN | Surrogate identifier |
| `first_name` | `text` | NN | Given name |
| `last_name` | `text` | NN | Family name |
| `display_name` | `text` | NN | Name shown on the platform |
| `email` | `text` | NN | Login and contact email; unique |
| `phone` | `text` | nullable | Text, not numeric: supports country codes and formatting |
| `address_id` | `integer` | nullable | FK → `addresses.address_id` |
| `date_of_birth` | `date` | nullable | Used for age-bracket analysis |
| `joined_at` | `timestamp` | NN, default `now()` | Account creation time |

**Primary key:** `renter_id`
**Candidate key:** `email` (declared UNIQUE, not used as PK; see analysis)

---

## `properties` (producer)

A rental listing available for viewing on the platform.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `property_id` | `integer` (generated identity) | NN | Surrogate identifier |
| `display_name` | `text` | NN | Listing title |
| `description` | `text` | nullable | Free-text listing description |
| `property_type` | `text` | NN | One of: `apartment`, `condo`, `townhouse`, `single_family`, `duplex`, `studio` |
| `square_feet` | `integer` | NN | Interior area; must be positive |
| `bedrooms` | `smallint` | NN | Number of bedrooms; 0 for studios |
| `bathrooms` | `numeric(3,1)` | NN | Number of bathrooms; allows half baths (1.5) |
| `monthly_rent` | `numeric(10,2)` | NN | Asking rent per month; the filtering attribute required by the theme |
| `security_deposit` | `numeric(10,2)` | nullable | Required deposit, if known |
| `is_active` | `boolean` | NN, default `true` | Whether the listing is live; the activity flag required by the theme |
| `available_from` | `date` | nullable | Earliest move-in date |
| `lease_term_months` | `smallint` | nullable | Standard lease length |
| `furnished` | `boolean` | NN, default `false` | Whether the unit is furnished |
| `year_built` | `smallint` | nullable | Construction year |
| `address_id` | `integer` | NN | FK → `addresses.address_id`; unique per property |
| `listed_at` | `timestamp` | NN, default `now()` | When the listing was created |

**Primary key:** `property_id`

---

## `viewings` (event)

The high-volume fact table. One row per scheduled viewing of a property by a renter.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `viewing_id` | `bigint` (generated identity) | NN | Surrogate identifier; `bigint` because this table grows fastest |
| `renter_id` | `integer` | NN | FK → `renters.renter_id` |
| `property_id` | `integer` | NN | FK → `properties.property_id` |
| `viewing_type` | `text` | NN | One of: `in_person`, `virtual`, `self_guided` |
| `status` | `text` | NN | One of: `scheduled`, `completed`, `cancelled`, `no_show` |
| `scheduled_at` | `timestamp` | NN | When the viewing was booked for; the timestamp required by the theme |
| `started_at` | `timestamp` | nullable | When the viewing actually began; set only when completed |
| `duration_min` | `integer` | nullable | Length in minutes; the metric required by the theme; set only when completed |
| `rating` | `smallint` | nullable | Renter's 1–5 rating of the viewing |
| `notes` | `text` | nullable | Free-text notes |

**Primary key:** `viewing_id`

---

## `amenities` (catalog)

The descriptive dimension: tags that classify a property.

| Attribute | Domain | Nullability | Description |
|---|---|---|---|
| `amenity_id` | `integer` (generated identity) | NN | Surrogate identifier |
| `name` | `text` | NN | Amenity name; unique |
| `category` | `text` | NN | One of: `building`, `unit`, `outdoor`, `policy` |

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