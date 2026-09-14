# Unit 1 — Design Analysis

## Theme choice

I chose **Rental Marketplace** (theme 4). I work on a product in the property management space, so this was a domain where I could make design decisions based on problems I have seen before instead of making assumptions about an unfamiliar industry. The grading requirements are the same across themes, but this one gave me a better foundation for deciding what data matters and how the relationships should work.

## Modelling justification (Task 1.4a)

**Primary keys.** I use generated surrogate integer keys for every main entity and a composite key for the junction table. For `renters`, I considered using `email` because it is already unique, but emails can change. I did not want a value referenced by a high-volume table like `viewings` to also be something that may need to be updated later. Instead, `email` is `UNIQUE`, which still prevents duplicate accounts without making it part of the relationship between tables.

I made the same decision for `amenities`. An amenity name should be unique, but changing something like the display name of an amenity should only require updating that row. It should not require updating every relationship that references it.

For `viewings`, I use a `bigint` surrogate key instead of a composite key like `(renter_id, property_id, scheduled_at)`. I go into that tradeoff more in the reflection below.

`listing_amenities` is different because the relationship itself is what identifies the row. A property either has a specific amenity or it does not, so `(property_id, amenity_id)` is enough to uniquely identify the record. Adding another generated ID would not give me anything useful.

**ON DELETE behaviors.** I use different delete behaviors depending on whether the child record still makes sense without its parent.

For `renters → addresses`, I use `SET NULL` because a renter can still have an account without an address on file. For `properties → addresses`, I use `RESTRICT` because a property listing does not make sense without its address, but I also do not want deleting an address to accidentally delete the property. For `listing_amenities → properties`, I use `CASCADE` because the relationship has no meaning once the property is gone.

The foreign keys from `viewings` use `RESTRICT`. Viewings are historical activity that I want to preserve for analysis. Deleting a renter or property should not quietly remove viewing history and change past reporting.

This is also why `properties` has an `is_active` field. When a listing is no longer available, the normal operation should be to retire it rather than delete it.

**Supporting entity.** The required roles could have been represented with five tables, but I added `addresses` as a supporting entity because both renters and properties need the same address structure. Keeping those fields in one place avoids duplicating the same columns and validation rules across multiple tables.

The relationships are also slightly different depending on how the address is used. Multiple renters can share an address, while a property has one address and that relationship is enforced as unique.

**Enforced in the schema.** I use `CHECK` constraints for small, fixed sets of values such as `property_type`, `viewing_type`, `status`, and amenity `category`. These values are stable and do not currently have any additional data associated with them, so separate lookup tables would add complexity without giving me much value. If those values later needed their own attributes or became configurable, I would move them into tables.

Basic data integrity rules are also enforced in the database. Values such as rent, property area, and viewing duration cannot be negative or otherwise invalid.

The most important constraint is around `viewings.duration_min`. A duration should exist when a viewing is completed and should not exist when the viewing was cancelled, missed, or has not happened yet. I enforce that relationship with table-level `CHECK` constraints.

That matters because `duration_min` will eventually be used in aggregate queries. Without the constraint, bad rows could produce misleading results without causing the query itself to fail.

**Left to the application.** I intentionally leave rules such as preventing double-bookings, preventing viewings on inactive properties, and validating email format to the application.

Those rules are different from basic data integrity because they depend on business policy. For example, whether two viewings on the same day count as a duplicate could depend on their exact time, timezone, or whether the first viewing was cancelled. Those rules may change as the product changes, so I would rather keep them in application logic than make them difficult to change at the database level.

Email validation has a similar problem. The database can enforce uniqueness and require a value, but trying to fully determine whether an email address is valid with a database regex would add complexity without guaranteeing that the address actually works.

## Reflection (Task 1.4b)

The decision I think another designer could reasonably make differently is the primary key for `viewings`.

Instead of a generated `bigint`, the table could use `(renter_id, property_id, scheduled_at)` as a composite primary key. That has a real advantage: the database would automatically prevent the same renter from having two identical bookings for the same property and time.

I still chose the surrogate key because `viewings` is expected to be the highest-volume table and its scheduling data can change. A renter may reschedule a viewing, and with the composite approach that means changing part of the primary key. I prefer identifiers to stay stable even when the data describing the record changes.

The composite key also does not remove the need for additional indexes. Most of the analytical queries I expect to write will filter or group by properties and time ranges, so I will likely need an index such as `(property_id, scheduled_at)` either way.

There is also a product decision hidden inside the composite key. Using it means the database is deciding exactly what counts as a duplicate booking. That becomes less clear once cancellations, rescheduling, and timezones are involved. I would rather make that policy explicit in the application.

The tradeoff is that the database itself does not prevent two otherwise identical viewing rows from being inserted. I am comfortable with that because the surrogate key keeps the identity of a viewing simple and stable, while duplicate-booking behavior can be handled where the rest of the booking rules live.