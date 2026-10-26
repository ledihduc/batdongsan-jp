---
title: "Phase 01b — Booking → ViewingAppointment Rename"
description: "Standalone rename phase: avoid naming clash with Contract (nhà trọ) + Reservation (homestay)"
status: pending
priority: P1
effort: 1d
branch: TBD
tags: [backend, flutter, refactor, rename]
created: 2026-06-22
---

# Phase 01b — Booking → ViewingAppointment Rename

**Sized:** 1d
**Status:** ⏸ Pending (Ready)
**Blocks:** 02, 03, 07 (downstream phases reference appointment model under new name)
**Blocked by:** 01 (DB migration must be stable first)

## Context links
- BA doc §9 D5+D9 (rename scope), §9c Booking rename constraints
- Research: `research/researcher-backend-audit.md` §5 (5 backend files), `research/researcher-flutter-audit.md` §6 (Flutter 24 mentions)
- Code files affected (backend): `app/models.py`, `app/routers/bookings.py`, `app/routers/houses.py`, `app/helpers.py`, `main.py`
- Code files affected (Flutter): `lib/data/models/booking_model.dart`, `lib/providers/booking_provider.dart`, `lib/data/repositories/api_booking_repository.dart`, `lib/domain/repositories/i_booking_repository.dart`, `lib/features/host/host_home_screen.dart`, `lib/features/guest/booking/booking_history_screen.dart`, `lib/features/guest/guest_shell.dart`, `lib/main.dart`

## Overview
Standalone phase 1d: rename `Booking` (viewing appointment) → `ViewingAppointment` cả ở backend (model, router, helper, notification types) lẫn Flutter (model, provider, repository, screens). Clean separation tránh nhầm lẫn với `Contract` (Phase 03) và `Reservation` (Phase 07).

## Key insights from research
- Backend: 5 files affected (models.py, routers/bookings.py, routers/houses.py:188, helpers.py, main.py)
- Flutter: 8 files affected, `host_home_screen.dart` mention 24 lần (largest hotspot)
- Notification event types `booking_*` → `viewing_appointment_*` cần backward-compat layer nếu Flutter cache event types (low risk vì noti table không index theo type string)
- DB table rename: `bookings → viewing_appointments` qua Alembic migration `0003_rename_booking_to_viewing_appointment.py`

## Requirements

### Functional
- Toàn bộ flow xem nhà (guest request → host approve/reject/lock) không vỡ
- Notification gửi đúng type mới
- Flutter UI hiện đúng status badges như trước

### Non-functional
- 0 regression với existing viewing appointment data
- Migration safe: `ALTER TABLE bookings RENAME TO viewing_appointments`

## Architecture

### Backend
**Model rename:** `Booking` class → `ViewingAppointment`, `__tablename__ = "viewing_appointments"`.

**Router:** `app/routers/bookings.py` → `app/routers/viewing_appointments.py`. Prefix `/api/bookings` → `/api/viewing-appointments` (kebab-case URL).

**Migration:** `alembic/versions/0003_rename_booking_to_viewing_appointment.py`
- `op.rename_table('bookings', 'viewing_appointments')`
- Update existing notification rows: `UPDATE notifications SET type = REPLACE(type, 'booking_', 'viewing_appointment_') WHERE type LIKE 'booking_%'`

**Notification type mapping (backward-compat 1 release):**
| Old | New |
|---|---|
| `booking_new` | `viewing_appointment_requested` |
| `booking_approved` | `viewing_appointment_approved` |
| `booking_rejected` | `viewing_appointment_rejected` |
| `booking_locked` | `viewing_appointment_confirmed` |
| `booking_lost` | `viewing_appointment_lost` |

### Flutter
**Model rename:** `BookingModel` → `ViewingAppointmentModel`, file `booking_model.dart` → `viewing_appointment_model.dart`.

**Provider:** `BookingProvider` → `ViewingAppointmentProvider`, file `booking_provider.dart` → `viewing_appointment_provider.dart`.

**Repository:** `IBookingRepository` → `IViewingAppointmentRepository`, `ApiBookingRepository` → `ApiViewingAppointmentRepository`.

**API path update:** `lib/data/services/api_client.dart` callers update path `/api/bookings` → `/api/viewing-appointments`.

### Data flow
Không thay đổi flow, chỉ rename identifiers. Guest gửi request xem nhà → host approve → status update → notification gửi tới guest.

## Related code files

### Backend new files
- `backend/alembic/versions/0003_rename_booking_to_viewing_appointment.py`
- `backend/app/routers/viewing_appointments.py` (renamed from bookings.py)

### Backend modified files
- `backend/app/models.py` — class rename, `__tablename__` change
- `backend/app/routers/houses.py:188` — `db.query(models.Booking).filter(...).delete()` → `models.ViewingAppointment`
- `backend/app/helpers.py:7,59-80` — `booking_to_dict()` → `viewing_appointment_to_dict()`, import rename
- `backend/main.py:109` — import + include router

### Backend deleted files
- `backend/app/routers/bookings.py` (replaced by viewing_appointments.py)

### Flutter new files
- `lib/data/models/viewing_appointment_model.dart` (renamed)
- `lib/providers/viewing_appointment_provider.dart` (renamed)
- `lib/data/repositories/api_viewing_appointment_repository.dart` (renamed)
- `lib/domain/repositories/i_viewing_appointment_repository.dart` (renamed)

### Flutter modified files
- `lib/features/host/host_home_screen.dart` — 24 mentions, rename references + variable names
- `lib/features/guest/booking/booking_history_screen.dart` — rename references
- `lib/features/guest/guest_shell.dart` — provider reference + tab logic line 42, 54-59
- `lib/main.dart` — MultiProvider entry line 7, 126-129

### Flutter deleted files
- `lib/data/models/booking_model.dart`
- `lib/providers/booking_provider.dart`
- `lib/data/repositories/api_booking_repository.dart`
- `lib/domain/repositories/i_booking_repository.dart`

## Implementation steps

1. **Backend (model):** Edit `app/models.py`: rename class `Booking` → `ViewingAppointment`, `__tablename__ = "viewing_appointments"`. Keep all column names same.
2. **Backend (helper):** `app/helpers.py`: rename `booking_to_dict` → `viewing_appointment_to_dict`, update import.
3. **Backend (cascade):** `app/routers/houses.py:188`: update `models.Booking` → `models.ViewingAppointment`.
4. **Backend (router):** Copy `app/routers/bookings.py` → `app/routers/viewing_appointments.py`. Update:
   - All `models.Booking` → `models.ViewingAppointment`
   - Route prefix `/api/bookings` → `/api/viewing-appointments`
   - Notification types: `booking_new` → `viewing_appointment_requested`, etc. (use mapping table above)
5. **Backend (main):** `main.py`: update import + `app.include_router()` to viewing_appointments.
6. **Backend (delete old):** Remove old `bookings.py`.
7. **Backend (migration):** Generate `alembic revision -m "rename_booking_to_viewing_appointment"`. Hand-write:
   ```python
   def upgrade():
       op.rename_table('bookings', 'viewing_appointments')
       op.execute("UPDATE notifications SET type = REPLACE(type, 'booking_', 'viewing_appointment_') WHERE type LIKE 'booking_%'")
   def downgrade():
       op.rename_table('viewing_appointments', 'bookings')
       op.execute("UPDATE notifications SET type = REPLACE(type, 'viewing_appointment_', 'booking_') WHERE type LIKE 'viewing_appointment_%'")
   ```
8. **Backend (apply):** `alembic upgrade head` → verify `psql -c "\dt"` shows `viewing_appointments`, not `bookings`.
9. **Backend (test):** Smoke test: register guest → POST /api/viewing-appointments → host POST /api/viewing-appointments/{id}/status (approve) → notification gửi đúng type.
10. **Flutter (model):** `lib/data/models/booking_model.dart` → `viewing_appointment_model.dart`. Rename class + all fields keep same names.
11. **Flutter (interface):** `lib/domain/repositories/i_booking_repository.dart` → `i_viewing_appointment_repository.dart`. Rename interface.
12. **Flutter (api repo):** `lib/data/repositories/api_booking_repository.dart` → `api_viewing_appointment_repository.dart`. Update API paths: `/api/bookings` → `/api/viewing-appointments`.
13. **Flutter (provider):** `lib/providers/booking_provider.dart` → `viewing_appointment_provider.dart`. Rename class + fields. Method `fetchBookings(userId, role)` → `fetchAppointments(userId, role)`.
14. **Flutter (host screen):** `lib/features/host/host_home_screen.dart` — replace 24 mentions của `Booking`, `bookings`, `bookingProvider` → corresponding new names.
15. **Flutter (guest screens):** `booking_history_screen.dart` + `guest_shell.dart` — rename references.
16. **Flutter (main):** `lib/main.dart` — update MultiProvider entry, fetch on hydration.
17. **Flutter (build):** `flutter analyze` → 0 errors. `flutter run` → host_home_screen renders, approve/reject works.
18. **E2E smoke:** Guest tap "Đặt lịch xem nhà" → host receives in pending list → approve → guest receives notification "Lịch xem nhà đã được duyệt". All pass.

## Todo list
- [ ] Backend: rename `Booking` class in models.py
- [ ] Backend: rename helper function
- [ ] Backend: update houses.py cascade query
- [ ] Backend: create viewing_appointments.py router with new types
- [ ] Backend: delete old bookings.py
- [ ] Backend: update main.py imports
- [ ] Backend: alembic migration rename_table + notification type update
- [ ] Backend: apply migration, verify schema
- [ ] Backend: smoke test API flow
- [ ] Flutter: rename model file + class
- [ ] Flutter: rename interface file + class
- [ ] Flutter: rename api repository + update paths
- [ ] Flutter: rename provider + update method signatures
- [ ] Flutter: update host_home_screen 24 mentions
- [ ] Flutter: update guest screens
- [ ] Flutter: update main.dart MultiProvider
- [ ] Flutter analyze 0 errors
- [ ] E2E smoke test: viewing appointment full flow

## Success criteria (testable)
- AC1: `psql -c "\dt"` shows `viewing_appointments`, no `bookings` table
- AC2: All `grep -r "Booking" backend/app` returns 0 hits (excluding noti backward-compat string mapping if kept)
- AC3: All `grep -r "BookingProvider\|BookingModel" lib` returns 0 hits
- AC4: `flutter analyze` 0 errors
- AC5: E2E flow: guest request → host approve → both see notification → status updated correctly
- AC6: Existing viewing appointment data (after Phase 01 reset → re-seeded) functional
- Demo: live click-through guest creates appointment, host approves, both UIs reflect new state

## Risk assessment
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Miss a `Booking` reference in deep file | 40% | MED | Grep verification cuối phase; CI catches via flutter analyze |
| Notification type cache in Flutter NotificationProvider | 20% | LOW | Backend migration UPDATE notifications.type → no client cache needed |
| API path change breaks other clients (admin tool?) | 15% | LOW | Backend only has 1 client (mobile app); no public consumers |
| Migration fails on dev environment | 10% | LOW | Test on dev DB before merging |

## Security considerations
- No auth changes; existing endpoints maintain same `require_user()` (or lack thereof — Phase 02 will add auth)
- Migration runs as DB owner: ensure dev/staging access controls

## Next steps
- Unblocks Phase 02 (foundation can proceed with stable naming)
- Unblocks Phase 03 (Contract model can be added without naming clash)
- Unblocks Phase 07 (Reservation model can be added without naming clash)
- Dependencies for next: Phase 02 builds on this rename foundation
