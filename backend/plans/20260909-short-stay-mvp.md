# Short-term stays MVP — 2026-09-09

Scope: backend/app HEAD on `pipeline-4-kenh-20260909`; preserve the existing
long-term pipeline. Implement, review, test and commit each repository. No push
or deployment. Both worktrees were clean before work; no AGENTS.md was found.

## Research and current implementation

- [Go2Joy official operating rules](https://go2joy.vn/vi-vn/regulations-on-operating-website): location and arrival/departure search, room selection, pay-at-property option, partner booking/check-in/cancellation operations and inventory management. Its published free-cancellation windows are 1 hour for hourly, 2 hours for overnight and 12 hours for daily, subject to property terms.
- [Go2Joy product description](https://go2joy.vn/blog/book-phong-chat-cung-go2joy/): hourly, overnight and daily products.
- [Agoda booking confirmation](https://www.agoda.com/info/what-happens-when-my-reservation-is-placed.html): confirmation/voucher follows successful booking; payment and cancellation depend on the booking/property terms. A pending request must not claim to be paid or approved.
- Inspected Reservation, RoomKenh, RoomChiemDung, reservation_service,
  guest_reservation, host_homestay, house search/serialization, Flutter guest
  search/detail/profile, room booking and host homestay management. Existing
  reservations and occupancy use date ranges; guest response exposes host_id;
  existing calendar has one row per room/day and cannot project hourly slots.

## Implementation plan (written before code changes)

1. Add nullable booking mode, local Vietnam check-in/out timestamps, unique
   readable booking code and price snapshot to Reservation; explicit mode rates
   and cancellation windows to RoomKenh; nullable precise timestamps to the
   shared occupancy ledger. Retain every existing column and nightly path.
   Replace date exclusion expressions with timestamp/date-coalescing expressions
   so legacy and long-term date intervals remain protected atomically.
2. Centralize mode validation, quote, policy snapshot, cancellation eligibility
   and safe response serialization. MVP: hourly 1–24 whole hours, overnight
   21:00–09:00 next day, daily 1–30 periods of 24 hours. API accepts zoned times,
   normalizes to Vietnam time, and returns explicit +07:00 timestamps. Never use
   monthly/base prices for these products. Owner configures rates and free-cancel
   windows (defaults 1/2/12 hours); new bookings pay at property, no online charge.
3. Public short-stay room search/detail/quote requires enabled ngan_han and an
   explicit rate. Include location, room type/code, mode, rates and terms without
   owner identity. Add short-stay metadata to linked public house detail.
4. Reuse guest reservation lifecycle for quote-confirm-book, code/status/history
   and eligible cancellation. Add scoped owner/sale operational API for today's
   bookings and approve/reject/check-in/out/cancel, plus manual time blocks.
   Only owner sets rates/policies; sale actions never confirm financial deals,
   change receipts or authorize refunds. Serialize lifecycle changes with locks.
5. Flutter: use HD/Ds widgets; add short-stay search/detail entry points, replace
   room booking form with mode/time/quote/terms confirmation, add profile booking
   history and owner/sale operations + rate configuration + manual blocks. Keep
   unrelated screens and long-term UI intact.
6. Focused backend/API/permission and Flutter model/API/widget tests; isolated
   PostgreSQL migration upgrade/downgrade and true concurrent booking tests.
   Run backend in existing Docker image and Flutter in a clean temporary copy;
   fix failures, review diffs, record results and commit backend/app separately.

## Deliberate MVP boundaries

No online payment/refund execution, coupons, dynamic short-stay prices, automatic
pending-request expiry, external OTA synchronization or redesigned calendar.
Use a precise booking list for short stays. Booking code is a reference, not a
payment receipt. In-app Vietnamese notifications use existing storage.
Downgrade must preserve data: if newer intra-day bookings would conflict under
old date-only constraints, refuse transactionally with a clear remediation
message instead of deleting bookings or weakening legacy protection.

## Validation and review

Implemented and reviewed locally; no deployment or push.

- Added owner-editable room type and rates/windows. Public short-stay catalog and
  `houses?group=stay_short` require enabled inventory and explicit rates; private
  buildings and maintenance rooms cannot be booked. Linked short-stay listings
  expose an assigned sale contact, never the financial owner.
- New bookings use the room's financial owner (including mixed-owner buildings).
  Sale approval never writes a financial Deal or executes a payment/refund.
- Review closed the legacy no-mode pricing bypass: configured new products require
  a mode/quote; old nightly requests prefer the explicit nightly channel rate over
  the ambiguous monthly/base rate. Existing nightly rules and records still work.
- PostgreSQL uncovered pre-existing native DATE parsing errors in nightly check-in,
  calendar and pricing; narrow fixes accept both date objects and ISO strings.
- Flutter final full suite: **1,244 passed**. New feature suite: **10 passed**, also
  run with `TZ=America/New_York`; picker arithmetic uses Vietnam wall-clock values
  independently of device daylight-saving transitions. New feature analyze: clean.
- Full Flutter analyze: **0 errors, 16 existing warnings, 310 infos**. Pristine HEAD
  in a separate temp copy: **0 errors, 16 warnings, 311 infos**. The warnings belong
  to unused code in the existing long-term host screen; no new diagnostics.
- PostgreSQL feature/migration/concurrency suite: **34 passed**; original homestay
  PostgreSQL suite: **20 passed**. Full backend final run: **2,169 passed, 171 skipped** (environment-gated tests;
  the relevant PostgreSQL suites above were executed explicitly).
- Actual Alembic CLI: empty database → HEAD → 0104 → HEAD passed. Tests also cover
  legacy rows, adjacent intra-day slots, downgrade refusal without data loss,
  simultaneous API/service booking attempts and direct mixed-channel DB writers.
- `ruff` on new Python implementation/tests/migration and `git diff --check`: clean.

Test setup: existing `ancu365-backend:staging` image, read-only repository mounts,
`PYTHONDONTWRITEBYTECODE=1`, disposable isolated `postgis/postgis:16-3.4` container.
No production database or deployment container was changed. Initialize the test
`planning` schema/extensions per infra/postgres/init.sql and create alembic_version
with varchar(128), required by old revision names longer than Alembic's default 32.
Set SHORT_STAY_TEST_URL for tests/test_short_stays_postgres.py and
SMOKE_DATABASE_URL for tests/homestay. Flutter runs in a fresh temp copy after pub
get, with a temp-only SQLite hook using the system library (the default binary
fetch stalled); production pubspec/lockfile are unchanged.

Further deferrals: mode-specific revenue/occupancy analytics, flexible overnight
hours beyond 21:00–09:00, automatic pending expiry and rich notification deep links.
Existing nightly management remains available; the new operations list focuses on
bookings with an explicit mode. Old rooms must have explicit new rates configured
before appearing in the new guest catalog.
