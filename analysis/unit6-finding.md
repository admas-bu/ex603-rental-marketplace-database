# Is the Platform Getting Better or Worse?

## The short answer

The no-show problem is **not getting worse**. It has held steady at about 6% all year. The bigger risk for next quarter is not renters missing viewings. It is **not enough viewings being booked**.

## The no-show rate is flat

Over 2023, renters missed 12 of 193 viewings, a rate of 6.2% (query 6.2B). The rate stayed between 5% and 8% from February to December, after a high start in January when only 20 viewings had been counted (query 6.2B).

The second half of the year was slightly better than the first: 5 no-shows out of 95 viewings (5.3%), compared with 7 out of 98 (7.1%) (query 6.2B, June and December rows). October and November had no no-shows at all (query 6.3B). That is encouraging, but the difference between the two halves is two missed viewings, which is too small to call an improvement.

Month-by-month numbers are misleading at this size. The monthly rate jumps from 0% to 18% and back because a month has between 0 and 2 no-shows (query 6.3B). Nobody should act on a single month.

The problem is concentrated, not platform-wide. Properties 2 and 3 account for 5 of the 12 no-shows (query 4.2a, `q4_2.sql`). Property 2's viewings also vary a lot in length, from 15 to 48 minutes between one viewing and the next, which suggests viewings there are not run the same way each time (query 6.2A).

## Booking volume is the bigger risk

Against a target of 50 viewings per quarter, the platform reached 53 in Q1 and 51 in Q3, but missed in Q2 (48) and Q4 (48) (queries 6.2B and 6.3B).

- **Q4 fell behind early.** By mid-November only 26 viewings had been booked, about half the target, and the quarter finished two short (query 6.2B).
- **Bookings halved in March** (down 47.6%, from 21 to 11) and stayed at 11 in April (query 6.3B).
- **Three properties went more than three months without a single viewing** (properties 9, 12 and 5), and all three gaps overlap March and April. The rest of the platform kept booking during those gaps, so this was not a data problem (query 6.2C).
- **Two properties (14 and 15) had no viewings all year** (query 6.1b).

## What the team should do next quarter

1. **Track bookings against target every week.** A quarter needs about four bookings a week to reach 50. If the running total falls behind pace for two weeks in a row, find out why while there is still time to recover.
2. **Fix the listings that are getting no interest.** Review properties 14 and 15 from a renter's point of view, and contact the owners of 9, 12 and 5 to confirm their listings are active and accepting viewings.
3. **Keep the focus on properties 2 and 3 for no-shows.** Add a confirmation reminder the day before each viewing and use one consistent agent at property 2. Compare their rate at the end of the quarter with the rest of the platform.
4. **Change how the no-show rate is reported.** Show it by quarter, or over the last 30 viewings, instead of by month. Flag a property only if its rate stays above 12% (about twice the platform average) for two quarters.

## What this data cannot tell us

The data covers a single year and only 12 no-shows. That is enough to say the rate is not rising, but not enough to prove it is falling. It also cannot explain *why* bookings dropped in March and April. Answering that needs data the platform does not record yet, such as how many renters searched for or viewed each listing without booking.