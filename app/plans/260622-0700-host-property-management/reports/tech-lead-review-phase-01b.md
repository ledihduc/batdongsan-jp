# Tech Lead Review — Phase 01b Booking → ViewingAppointment Rename

**Reviewer:** code-reviewer (Tech Lead)
**Date:** 2026-06-22
**Verdict:** **CONDITIONAL** — 1 CRITICAL bug in Alembic migration must be fixed before merge. Two HIGH cleanups recommended.

---

## Scope reviewed

- Backend: `app/models.py`, `app/helpers.py`, `app/routers/houses.py`, `app/routers/viewing_appointments.py` (new), `bookings.py` (deleted), `main.py`, `alembic/versions/0003_rename_booking_to_viewing_appointment.py`, `tests/test_smoke_postgres.py`
- Flutter: `viewing_appointment_model.dart`, `i_viewing_appointment_repository.dart`, `api_viewing_appointment_repository.dart`, `viewing_appointment_provider.dart`, `local_booking_repository.dart` (adapter), `host_home_screen.dart`, `booking_history_screen.dart`, `schedule_booking_screen.dart`, `guest_shell.dart`, `profile_screen.dart`, `register_screen.dart`, `main.dart`
- Spec: `phase-01b-booking-rename.md` §Notification type mapping, §Success criteria

---

## CRITICAL

### C1. Alembic migration UPDATE does NOT preserve notification type semantics

**File:** `ancu365-backend/alembic/versions/0003_rename_booking_to_viewing_appointment.py:26-28`

**Problem.** Migration uses `REPLACE(type, 'booking_', 'viewing_appointment_')`, but the new router (per spec §Notification mapping) emits semantically different suffixes for two of the five types:

| Old type (in DB) | REPLACE produces | Router actually emits | Match? |
|---|---|---|---|
| `booking_new` | `viewing_appointment_new` | `viewing_appointment_requested` | **NO** |
| `booking_approved` | `viewing_appointment_approved` | `viewing_appointment_approved` | yes |
| `booking_rejected` | `viewing_appointment_rejected` | `viewing_appointment_rejected` | yes |
| `booking_locked` | `viewing_appointment_locked` | `viewing_appointment_confirmed` | **NO** |
| `booking_lost` | `viewing_appointment_lost` | `viewing_appointment_lost` | yes |

After migration, any pre-existing notification rows with types `booking_new` or `booking_locked` will end up as `viewing_appointment_new` / `viewing_appointment_locked` — strings the new code never emits. Clients filtering or iconizing on these strings will mis-bucket the row.

**Impact.** Production data corruption (notification type string mismatch). Even though spec D9 says "0 production users", the spec itself explicitly defines a 5-row mapping (§Architecture > Notification type mapping); the migration violates that contract on 2/5 rows. The downgrade has the same bug in reverse (`viewing_appointment_requested` would not be reversed back to `booking_new`).

**Fix.** Replace the single `REPLACE` with explicit per-type UPDATE statements:

```python
def upgrade() -> None:
    op.rename_table("bookings", "viewing_appointments")
    # Per-type rewrite (spec §Notification type mapping). REPLACE() is unsafe
    # because two suffixes diverge ("new"→"requested", "locked"→"confirmed").
    op.execute("UPDATE notifications SET type = 'viewing_appointment_requested' WHERE type = 'booking_new'")
    op.execute("UPDATE notifications SET type = 'viewing_appointment_approved' WHERE type = 'booking_approved'")
    op.execute("UPDATE notifications SET type = 'viewing_appointment_rejected' WHERE type = 'booking_rejected'")
    op.execute("UPDATE notifications SET type = 'viewing_appointment_confirmed' WHERE type = 'booking_locked'")
    op.execute("UPDATE notifications SET type = 'viewing_appointment_lost' WHERE type = 'booking_lost'")


def downgrade() -> None:
    op.execute("UPDATE notifications SET type = 'booking_new' WHERE type = 'viewing_appointment_requested'")
    op.execute("UPDATE notifications SET type = 'booking_approved' WHERE type = 'viewing_appointment_approved'")
    op.execute("UPDATE notifications SET type = 'booking_rejected' WHERE type = 'viewing_appointment_rejected'")
    op.execute("UPDATE notifications SET type = 'booking_locked' WHERE type = 'viewing_appointment_confirmed'")
    op.execute("UPDATE notifications SET type = 'booking_lost' WHERE type = 'viewing_appointment_lost'")
    op.rename_table("viewing_appointments", "bookings")
```

(Bonus: literal UPDATEs are also safer than `REPLACE` against any unrelated rows whose type may coincidentally contain the substring `booking_`.)

---

## HIGH

### H1. Dead code: `local_booking_repository.dart` references non-existent SQLite table

**File:** `ancu365-app/lib/data/repositories/local_booking_repository.dart:19,32,46,67,79`

**Problem.** The class was renamed to implement `IViewingAppointmentRepository` and rewritten to query `viewing_appointments` (`SELECT … FROM viewing_appointments b …`, `db.insert('viewing_appointments', …)`, `db.update('viewing_appointments', …)`). But the SQLite schema in `lib/data/database/database_helper.dart:133` still creates a table named `bookings`, and the seed (`_seedData`) inserts into `bookings`. There is no migration path for the local SQLite DB and no `viewing_appointments` table is ever created.

This is dead at the moment because nothing imports `LocalBookingRepository` (provider uses `ApiViewingAppointmentRepository` only). However:
- `grep -rn "LocalBookingRepository" lib` → zero call sites, but the file itself compiles. Any future re-wiring will silently throw `DatabaseException(no such table: viewing_appointments)` at runtime — not at compile time.
- Class name `LocalBookingRepository` no longer matches its interface; misleading.

**Fix (pick one):**
- **(a) Delete** `local_booking_repository.dart` — it is unused and the offline mode is dead. Cleanest.
- **(b) Realign** — rename the class to `LocalViewingAppointmentRepository`, rename file to `local_viewing_appointment_repository.dart`, and either rename the SQLite table in `database_helper.dart` (via `onUpgrade` bump version to 3 + `ALTER TABLE bookings RENAME TO viewing_appointments`) or update queries back to `bookings`.

Recommended: **(a) delete**, since the project is API-first and no Flutter call site uses local mode.

### H2. Alembic indexes still named `ix_bookings_*` after rename

**File:** `ancu365-backend/alembic/versions/0003_rename_booking_to_viewing_appointment.py:24-25`

**Problem.** `op.rename_table()` in Postgres does NOT rename the table's indexes ([PostgreSQL docs — ALTER TABLE](https://www.postgresql.org/docs/current/sql-altertable.html)). After the migration:
- Table: `viewing_appointments` ✓
- Index names still: `ix_bookings_guest_id`, `ix_bookings_house_id`, `ix_bookings_status`

Functionally harmless — queries still use the indexes — but:
- Any future autogenerate run will detect the mismatch between ORM (which expects `ix_viewing_appointments_*` from naming convention) and DB, producing churn migrations.
- Confusing for ops/DBA tools.

**Fix.** Add to the upgrade:
```python
op.execute('ALTER INDEX IF EXISTS ix_bookings_guest_id RENAME TO ix_viewing_appointments_guest_id')
op.execute('ALTER INDEX IF EXISTS ix_bookings_house_id RENAME TO ix_viewing_appointments_house_id')
op.execute('ALTER INDEX IF EXISTS ix_bookings_status   RENAME TO ix_viewing_appointments_status')
```
And the reverse in downgrade. `IF EXISTS` is added so the migration is idempotent across SQLite (no-op) and Postgres.

---

## MEDIUM

### M1. JSON response key still `"bookings"` / `"booking"` after rename

**File:** `ancu365-backend/app/routers/viewing_appointments.py:25, 57, 123`

```python
return {"bookings": [helpers.viewing_appointment_to_dict(db, b) for b in q.all()]}
…
return {"booking": helpers.viewing_appointment_to_dict(db, b)}
```

Flutter (`api_viewing_appointment_repository.dart:19`) reads `response['bookings']`, so this is intentional API-compat (mobile-only client per spec §Risk H4). Acceptable trade-off for now, but **document the deferred key rename** in `plan.md` under Phase 02 (or 08), otherwise it becomes hidden tech debt. Suggest:
- File a follow-up task: "Rename JSON response keys `bookings` → `viewing_appointments`, `booking` → `viewing_appointment` in router + Flutter repo (coordinated)."

### M2. Path parameter naming asymmetry in PATCH endpoint

**File:** `ancu365-backend/app/routers/viewing_appointments.py:60-61`

```python
@router.patch("/{appointment_id}/status")
def update_status(appointment_id: int, …):
    b = db.get(models.ViewingAppointment, appointment_id)
```

The path param uses `appointment_id` (good), but the local var is still `b` (a leftover from "booking"). Cosmetic, but combined with `helpers.viewing_appointment_to_dict(db, b)` calls in the file (parameter is `b`), the variable name `b` is now context-free. Consider `va` or `appointment` for readability. Not blocking.

### M3. `booking_date` / `booking_time` columns kept as-is

**File:** `ancu365-backend/app/models.py:114-115`, `app/helpers.py:67-68`, Flutter model fields

Spec §Implementation steps line 112 explicitly says "Keep all column names same" — confirmed intentional to avoid a schema column-rename migration. Consistent with M1 (defer JSON key rename). Tracker note same as M1.

### M4. `tests/test_smoke_postgres.py` helper still named `_make_booking`

**File:** `ancu365-backend/tests/test_smoke_postgres.py:88, 227, 244, 260, 299-300`

Helper builds a `models.ViewingAppointment` but is still called `_make_booking()`. Variable `booking` is reused throughout. Tests pass functionally (they were renamed at the class level, e.g. `TestViewingAppointmentStatusTransitions`), but mixed terminology in tests will confuse future readers. Suggest rename `_make_booking → _make_appointment` and `booking → appt`. Not blocking — tests are green.

---

## LOW

### L1. Vietnamese strings reference "lịch hẹn" / "Đặt lịch" — intentionally unchanged

Spec confirms display copy stays in Vietnamese (e.g. `"Đặt lịch xem nhà"`, `"Yêu cầu xem nhà đã được duyệt"`). No action needed; flagged for transparency.

### L2. Flutter dart-side filename `local_booking_repository.dart` keeps "booking" but implements new interface

See H1 — if not deleted, rename the file to match the class name per kebab-case convention.

### L3. Tag string on router prefix

`router = APIRouter(prefix="/api/viewing-appointments", tags=["viewing-appointments"])` — tag uses hyphen which renders fine in Swagger but is inconsistent with other tags (`tags=["bookings"]` in old). Cosmetic; OK.

---

## Positive observations

- Backend router rewrite is **clean and lossless**: every `models.Booking` reference moved to `models.ViewingAppointment`, every notification literal updated per spec mapping (5/5 in the router itself — only the migration is buggy).
- Flutter side: **zero stale identifiers** — `grep -rn "BookingProvider\|BookingModel\|IBookingRepository\|ApiBookingRepository" lib/` returns 0 hits.
- API path migration is **complete**: every `/api/bookings` call replaced with `/api/viewing-appointments` (verified via grep — only the new repo references the new path; no caller missed).
- `main.py` import + `include_router` updated atomically; no orphan route registration.
- `houses.py` cascade-delete query correctly references `models.ViewingAppointment`.
- The seeded migration baseline (`bef9a3d80bf2`) still creates the old `bookings` table — correct, because 0003 then renames it. The sequence `bef9a3d80bf2 → 0003_rename_booking` is consistent.
- Helper `viewing_appointment_to_dict(db, b)` correctly returns the same JSON schema as the prior `booking_to_dict` — Flutter parsing untouched.
- Backward-compat keys in the JSON response (`"bookings"`, `"booking"`) are a **pragmatic** choice — preserves on-the-wire compat for any cached/un-updated app build.
- Test class rename (`TestBookingStatusTransitions` → `TestViewingAppointmentStatusTransitions`) is correct, though helper internals (M4) are stale.
- No new secrets, no hardcoded credentials, no SQL injection vectors (parameterized everywhere, even the raw migration uses literal constants).
- No auth was lost: original `bookings.py` had **zero** `require_user`/`require_role` decorators — Phase 02 plans to add auth, so the rename is a pure transformation. Verified.
- FK constraints: confirmed `viewing_appointments.house_id` / `guest_id` retain their integer column + index definitions from baseline migration (no FK constraint was ever declared in either old or new schema — model uses plain `Integer` with `index=True`, no `ForeignKey()`, so nothing to lose).

---

## Acceptance criteria verification

| AC | Status | Notes |
|---|---|---|
| AC1 — `psql \dt` shows `viewing_appointments` | ✓ pending migration run | Migration renames correctly; index names lag (H2) |
| AC2 — `grep -r "Booking" backend/app` 0 hits | ⚠️ Partial — `booking_date`/`booking_time` column names retained (intentional per M3); JSON keys `"booking"`/`"bookings"` retained (intentional per M1). No `Booking` class identifier remains | OK with documented deferral |
| AC3 — `grep -r "BookingProvider\|BookingModel" lib` 0 hits | ✓ Verified 0 hits |
| AC4 — `flutter analyze` 0 errors | ✓ per developer report (72 pre-existing info warnings) |
| AC5 — E2E flow guest→host→approve→noti | ⚠️ Untested — block on C1 fix; rerun after migration corrected |
| AC6 — Existing data functional after reseed | ⚠️ Untested — C1 will silently break notification type semantics for any rows that survive |

---

## Required actions before merge

1. **[BLOCKING]** Fix C1: rewrite `0003_rename_booking_to_viewing_appointment.py` upgrade/downgrade to use per-type literal UPDATEs (snippet above).
2. **[BLOCKING]** Run AC5 E2E smoke after C1 fix: create one viewing appointment, approve it, verify the host notification has type `viewing_appointment_requested` and the guest notification has type `viewing_appointment_approved` (not `viewing_appointment_new`/`viewing_appointment_approved`-with-stale-data).
3. **[RECOMMENDED — same PR]** Apply H1: delete `local_booking_repository.dart` (unused).
4. **[RECOMMENDED — same PR]** Apply H2: add `ALTER INDEX … RENAME` statements to the migration.
5. **[FOLLOW-UP TICKET]** File M1 deferred JSON key rename + M3 column rename as a coordinated mobile+backend ticket (call it "Phase 01c — viewing-appointment payload key alignment").

---

## Verdict

**CONDITIONAL** — block merge until C1 is fixed and AC5 is re-run green. H1/H2 strongly recommended in the same PR (cheap, removes dead code + ops noise). M-level items can be deferred but **must be tracked** (M1 + M3 in particular — they are intentional API-compat shortcuts that turn into silent debt if forgotten).

---

## Unresolved questions

1. Does any Flutter screen filter notifications by `type` literal string (e.g. `if (notif.type == 'booking_new') …`)? If yes, the same renaming applies on the client side — please confirm via `grep -rn "booking_new\|booking_approved\|booking_rejected\|booking_locked\|booking_lost" lib/`. (Spot-check of `notification_provider.dart` suggested no, but worth a confirming grep.)
2. Per spec §Risk row 2 ("Notification type cache in Flutter NotificationProvider"), is there any locally cached notification list in shared_prefs/hive that would need invalidation? If so, ship a one-shot cache-clear on app start after this release.
3. Index rename (H2) — should we adopt SQLAlchemy `naming_convention` in `Base.metadata` so future autogenerate produces consistent index names? Out of scope for this phase, but worth a follow-up.
