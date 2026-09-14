# Integrity Constraints (Task 1.3)

Every constraint below is enforced by the database, not the application. The goal is that invalid data is impossible to store, not merely unlikely.

## 1. Primary keys

| Relation | Primary key | Justification |
|---|---|---|
| `addresses` | `address_id` | Surrogate. No natural key exists: two rows can legitimately have the same street text (a duplex with `street_line2` distinguishing units). |
| `renters` | `renter_id` | Surrogate. `email` is a candidate key but emails change; a PK that is referenced by millions of `viewings` rows must never change. |
| `properties` | `property_id` | Surrogate, same reasoning. `address_id` is also unique but is a FK, and using a FK as a PK couples the property's identity to its address row. |
| `viewings` | `viewing_id` | Surrogate `bigint`. The natural candidate `(renter_id, property_id, scheduled_at)` is discussed in `/analysis/unit1.md`. |
| `amenities` | `amenity_id` | Surrogate. `name` is unique but a rename should not cascade through the junction table. |
| `listing_amenities` | `(property_id, amenity_id)` | Composite natural key. A property either has an amenity or it does not; there is no meaningful second row, and no surrogate is needed. |

## 2. Foreign keys and ON DELETE behaviour

| Child → Parent | ON DELETE | Justification |
|---|---|---|
| `renters.address_id` → `addresses` | `SET NULL` | A renter is still a valid account without an address on file (they moved, or never supplied one). `address_id` is nullable for this reason. Deleting the address should not delete the person or block the deletion. |
| `properties.address_id` → `addresses` | `RESTRICT` | A listing without a location is meaningless. An address that a property depends on cannot be removed; the property must be handled first. This is the opposite of the renter case because the dependency is essential, not incidental. |
| `viewings.renter_id` → `renters` | `RESTRICT` | Viewings are the analytical record. Deleting a renter must not silently erase history that aggregate queries depend on. A real account-deletion flow should anonymise the renter row (blank the name and email) rather than delete it; the schema forces that conversation rather than making it easy to lose data. |
| `viewings.property_id` → `properties` | `RESTRICT` | Same reasoning. Properties are retired by setting `is_active = false`, not by deletion. The activity flag exists precisely so that deletion is never the right tool. |
| `listing_amenities.property_id` → `properties` | `CASCADE` | A junction row has no meaning without its property. If a property is ever deleted (which RESTRICT on `viewings` will prevent once it has history), its tag rows should go with it. |
| `listing_amenities.amenity_id` → `amenities` | `RESTRICT` | Deleting an amenity that is still attached to listings should fail loudly. If the catalog entry is wrong, rename it or re-tag the listings first. Silent cascade would remove data from listings without anyone asking for that. |

Three different ON DELETE behaviours across six foreign keys is deliberate: each one reflects whether the child can exist without the parent (SET NULL), is meaningless without it (CASCADE), or is valuable history that must outlive it (RESTRICT).

## 3. Uniqueness

| Relation | Constraint | Justification |
|---|---|---|
| `renters` | `UNIQUE (email)` | Email is the login identifier. Two accounts on one email is a support problem waiting to happen. |
| `properties` | `UNIQUE (address_id)` | One listing per address row. Two listings at the same address indicates a duplicate entry. Units in the same building are distinct rows in `addresses` via `street_line2`. |
| `amenities` | `UNIQUE (name)` | Prevents `Pool` and `pool` and `Swimming Pool` drifting into three tags. (Case-insensitive uniqueness via a lowercase expression index is a Unit 2 decision.) |

## 4. NOT NULL

Every attribute marked NN in `schema-definition.md`. The notable choices:

- `viewings.scheduled_at` is NOT NULL but `started_at` and `duration_min` are nullable. A viewing is booked before it happens; the actual timing only exists once it has.
- `properties.address_id` is NOT NULL; `renters.address_id` is nullable. See the ON DELETE table for why.
- `properties.security_deposit` is nullable: not every listing publishes one, and `NULL` ("unknown") is a different fact from `0` ("no deposit required").

## 5. Domain (CHECK) constraints

| Relation | Constraint | Justification |
|---|---|---|
| `properties` | `CHECK (property_type IN ('apartment','condo','townhouse','single_family','duplex','studio'))` | Closed, stable vocabulary. A lookup table would be overkill; see analysis. |
| `properties` | `CHECK (square_feet > 0)` | Zero or negative area is a data entry error. |
| `properties` | `CHECK (bedrooms >= 0)` | Zero is valid (studio); negative is not. |
| `properties` | `CHECK (bathrooms > 0)` | Every habitable unit has at least one. Half-baths are handled by the numeric(3,1) domain. |
| `properties` | `CHECK (monthly_rent > 0)` | Free listings are not a marketplace case. |
| `properties` | `CHECK (security_deposit >= 0)` | Zero is valid; negative is not. |
| `properties` | `CHECK (lease_term_months > 0)` | If stated, must be positive. |
| `properties` | `CHECK (year_built BETWEEN 1600 AND 2100)` | Guards against typos (e.g. `202` or `20025`) without pretending to know the exact bounds. |
| `viewings` | `CHECK (viewing_type IN ('in_person','virtual','self_guided'))` | Closed vocabulary. |
| `viewings` | `CHECK (status IN ('scheduled','completed','cancelled','no_show'))` | Closed vocabulary. |
| `viewings` | `CHECK (duration_min > 0)` | A completed viewing of zero minutes did not happen. |
| `viewings` | `CHECK (rating BETWEEN 1 AND 5)` | Standard five-point scale. |
| `amenities` | `CHECK (category IN ('building','unit','outdoor','policy'))` | Closed vocabulary. |

## 6. Cross-column (table-level CHECK) constraints

| Relation | Constraint | Justification |
|---|---|---|
| `viewings` | `CHECK (status <> 'completed' OR (started_at IS NOT NULL AND duration_min IS NOT NULL))` | A completed viewing must have actual timing. Without this, aggregate queries over `duration_min` would silently exclude completed viewings that were never timed, and the numbers would be wrong without any error. |
| `viewings` | `CHECK (status = 'completed' OR duration_min IS NULL)` | The converse: a cancelled or no-show viewing cannot carry a duration. Together with the rule above, `duration_min` is populated if and only if the viewing was completed. |
| `viewings` | `CHECK (started_at IS NULL OR started_at >= scheduled_at - INTERVAL '1 day')` | A viewing cannot start materially before it was scheduled. The one-day tolerance allows for early arrivals and timezone edge cases without permitting nonsense. |

## 7. Rules deliberately left to the application

Stated here so the boundary is explicit, not accidental.

- **"A renter cannot book the same property twice on the same day."** A business policy, not a data-integrity rule. It may change (allow rebooking after a cancellation), and it depends on the renter's timezone, which the database does not know.
- **"A viewing cannot be scheduled for an inactive property."** Enforceable in the schema only with a trigger, since `is_active` lives on the parent. Also a policy that legitimately has exceptions (an agent scheduling a viewing for a listing about to go live).
- **"Email must be a valid format."** A regex CHECK gives a false sense of security; real validation is confirming the address, which is an application flow.