# Unit 2 — From Diagram to Database

## What changed from Unit 1

There were three main changes when I moved the ERD into actual DDL. I also updated the diagram and `erd.png` to match.

1. **Short text now uses `VARCHAR(n)` with a defined length.** In Unit 1, I used `TEXT` for pretty much every string. After going through the course's type guidance, I changed fields where there is a reasonable limit. For example, `email VARCHAR(254)` documents the expected email limit, while `state CHAR(2)` makes it clear that I am storing state codes. Fields that are actually free-form, like `description` and `notes`, still use `TEXT`.

2. **I added `renters.referred_by_renter_id`**, which is a recursive foreign key back to `renters`. Referrals are pretty common in marketplaces, and this felt like a natural place to introduce a self-reference. The referrer is really a property of the renter, and it also gives me something useful to self-join in a later unit.

3. **I added `properties.rent_per_sqft`** as a stored generated column. I explain the reasoning for storing this below.

There are also two places where I intentionally went a little differently from the course's mapping table.

For `rating`, I used `SMALLINT` with `CHECK (rating BETWEEN 1 AND 5)` instead of `NUMERIC(3,2)`. Since the platform only collects whole-number ratings from 1 to 5, there is no need to store decimal precision that will never be used.

For `viewing_id`, I used `BIGINT` instead of `INTEGER`. `viewings` is basically the fact table and is the table I would expect to grow the fastest. Nothing references `viewing_id`, so this does not create a mismatch with any foreign keys. All FK columns are still `INTEGER` and match the `INTEGER` primary keys they reference.

## Creation order

| #   | Table               | References                | Why it sits here                                                       |
| --- | ------------------- | ------------------------- | ---------------------------------------------------------------------- |
| 1   | `addresses`         | nothing                   | No outgoing dependencies                                               |
| 2   | `amenities`         | nothing                   | No outgoing dependencies                                               |
| 3   | `renters`           | `addresses`, `renters`    | Needs addresses; the self-reference is handled within its own `CREATE` |
| 4   | `properties`        | `addresses`               | Needs addresses                                                        |
| 5   | `viewings`          | `renters`, `properties`   | Needs both sides of the marketplace                                    |
| 6   | `listing_amenities` | `properties`, `amenities` | Junction table, so both sides need to exist first                      |

The reset block drops the tables in the exact reverse order. I also ran the full script twice consecutively against the same database to make sure it could reset and recreate everything without any manual cleanup.

## The derived value

`rent_per_sqft` is defined as:

`GENERATED ALWAYS AS (ROUND(monthly_rent / square_feet, 2)) STORED`

The other option was to calculate this every time it is needed in a query. I decided to store it because rent per square foot is something renters could realistically sort or filter listings by, and a stored generated column can also be indexed.

Since `monthly_rent` and `square_feet` are both `NOT NULL` and have checks requiring them to be greater than zero, the calculation should always have valid inputs.

The tradeoff is a little extra storage per property, but in return the database calculates the value consistently and it cannot be manually written to or get out of sync with the values it comes from.

## The constraints table

| Foreign key                                  | ON DELETE | Reason                                                                              |
| -------------------------------------------- | --------- | ----------------------------------------------------------------------------------- |
| `renters.address_id → addresses`             | SET NULL  | A renter without an address on file is still a valid account                        |
| `renters.referred_by_renter_id → renters`    | SET NULL  | Removing the referrer should not affect the renter they referred                    |
| `properties.address_id → addresses`          | RESTRICT  | A listing without a location does not make much sense                               |
| `viewings.renter_id → renters`               | RESTRICT  | Viewings are historical/analytical records and should not disappear with a renter   |
| `viewings.property_id → properties`          | RESTRICT  | Same idea; listings should normally be retired using `is_active` instead of deleted |
| `listing_amenities.property_id → properties` | CASCADE   | An amenity relationship has no meaning if its listing is gone                       |
| `listing_amenities.amenity_id → amenities`   | RESTRICT  | An amenity that is still being used should not be deleted accidentally              |

### What each choice governs

**A renter's address is deleted (`SET NULL`).**  
The most likely case here is data cleanup or a renter moving without updating their profile. The renter should still keep their account, viewing history, and referral relationships. The only thing that disappears is the link to the old address.

With `RESTRICT`, support would first have to reassign every renter connected to a bad address before removing it. `CASCADE` would be much worse because deleting one address could try to delete every renter living there.

**A referrer's account is removed (`SET NULL`).**  
The renter who was referred should not be affected just because the person who referred them is removed. Their `referred_by_renter_id` simply becomes `NULL`.

Using `RESTRICT` would make referrals a blocker for deleting accounts. `CASCADE` would be even worse because removing one renter could start deleting everyone they referred and potentially continue down the referral chain.

**A property's address is deleted (`RESTRICT`).**  
This is something that should almost never happen, so I want the database to stop it if something tries to do it accidentally. A property without an address cannot really be searched, shown, or visited.

`SET NULL` would mean allowing listings without locations. `CASCADE` could delete the entire listing just because its address was deleted, which is also not the behavior I want.

**A renter or property is removed while viewings exist (`RESTRICT`).**  
This is mainly about protecting historical data. If a renter closes their account or a landlord stops listing a property, their old viewings are still useful for later analysis.

For example, later units may calculate average viewing duration, viewings per listing, or conversion by amenity. With `CASCADE`, deleting a renter or property could silently change those numbers by deleting historical rows.

Instead, the application can anonymize a renter when necessary or set `is_active = FALSE` on a property while keeping its historical records.

**A property is removed while it has amenity tags (`CASCADE`).**  
If a property really is deleted, its rows in `listing_amenities` no longer mean anything. There is no reason to keep a relationship saying a property has "Parking" if that property no longer exists.

Using `RESTRICT` here would just require manually removing those relationships before deleting the property without really protecting anything useful.

**An amenity is removed while listings still use it (`RESTRICT`).**  
This is a little different because removing an amenity could affect many listings. If someone tries to delete something like "In-unit laundry," I do not want that to silently disappear from every listing using it.

`RESTRICT` makes that an intentional operation. The amenity can either be renamed, or the affected listings can be updated first.

## The CHECK constraints

| Constraint                                | Invalid state it prevents                                | How it could otherwise arise                                          |
| ----------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------- |
| `chk_amenities_category`                  | Category outside `building/unit/outdoor/policy`          | Typo like `Building`, or a new category added only in the application |
| `chk_renters_no_self_referral`            | Renter referring themselves                              | Referral form using the current user's ID by mistake                  |
| `chk_properties_type`                     | Property type outside the six supported values           | Free-text or bad application input                                    |
| `chk_properties_square_feet_positive`     | Zero or negative area                                    | An unset form value being stored as `0`                               |
| `chk_properties_bedrooms_nonneg`          | Negative bedroom count                                   | Import or data-entry error; `0` still allows studios                  |
| `chk_properties_bathrooms_positive`       | Zero or negative bathrooms                               | Bad or missing input                                                  |
| `chk_properties_rent_positive`            | Zero or negative rent                                    | Placeholder `0` saved before pricing is entered                       |
| `chk_properties_deposit_nonneg`           | Negative deposit                                         | Sign error; `0` and `NULL` are still allowed                          |
| `chk_properties_lease_term_positive`      | Zero or negative lease term                              | Missing value stored as `0`                                           |
| `chk_properties_year_built_range`         | Invalid year such as `202` or `20025`                    | Data-entry error                                                      |
| `chk_viewings_type`                       | Unsupported viewing type                                 | Free-text or unexpected application value                             |
| `chk_viewings_status`                     | Unsupported viewing status                               | A status added in one part of the application but not another         |
| `chk_viewings_duration_positive`          | Completed viewing with zero or negative duration         | Clock or duration-calculation bug                                     |
| `chk_viewings_rating_range`               | Rating outside 1–5                                       | UI sending `0` instead of `NULL` for no rating                        |
| `chk_viewings_completed_has_timing`       | Completed viewing without timing information             | Status gets updated but the process recording timing fails            |
| `chk_viewings_duration_only_if_completed` | Cancelled/no-show viewing with a duration                | Cancellation happens after a duration was already recorded            |
| `chk_viewings_start_after_schedule`       | Viewing starting more than a day before it was scheduled | Timezone or timestamp bug                                             |

The two cross-column constraints on `viewings` are probably the most important ones here. Together, they enforce that `duration_min` is populated if and only if the viewing is actually `completed`.

That matters once I start doing aggregates in later units. Without these constraints, something like `AVG(duration_min)` could silently ignore completed viewings that are missing a duration or include durations from cancelled viewings. The query would still run and return a number, but the number would be wrong, which is the type of problem I would rather prevent at the database level.
