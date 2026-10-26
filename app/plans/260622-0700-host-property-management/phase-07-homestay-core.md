---
title: "Phase 07 — Homestay Core: Calendar + Pricing Rules + Reservation + Concurrent Prevention + Cancel Policy"
description: "Availability per-day, pricing priority resolution, Postgres exclusion constraint anti-overbooking, rigid 24h cancel policy, check-in/out workflow"
status: pending
priority: P1
effort: 9-11d
branch: TBD
tags: [backend, flutter, homestay, calendar, reservation, concurrent]
created: 2026-06-22
---

# Phase 07 — Homestay Core

**Sized:** 9–11d
**Status:** ⏸ Pending (Ready)
**Blocks:** 08 (marketplace integration needs Reservation)
**Blocked by:** 01, 01b, 02, 03 (Building/Room model reused for homestay listings)

## Context links
- BA doc §3b (Homestay nguyên căn/đêm), §4 E (E1-E8 calendar/booking), §5 AC (concurrent prevention, cancel policy enforcement), §6 (channel manager defer), §9 D10 (24h rigid policy)
- Research: `researcher-postgres-migration.md` §5 (exclusion constraint), `researcher-flutter-audit.md` §10 (no calendar package)
- Code files affected: `app/models.py`, `app/routers/host_homestay.py` (new), `lib/features/host/homestay/` (new sub-module)

## Overview
Second product line. Distinct from nhà trọ Contract/Invoice: homestay rents nguyên căn/phòng theo đêm. Build calendar (per-day Availability), pricing rules với priority resolution (base < weekend < holiday < manual), Reservation lifecycle với 24h rigid cancel policy, concurrent booking prevention via Postgres exclusion constraint, check-in/out tap-button workflow.

## Key insights from research
- Postgres `EXCLUDE USING gist (room_id WITH =, daterange &&)` constraint prevents double-booking at DB level — race-condition-proof
- BA D10 sealed: 24h rigid (>24h full refund, 0-24h 50%, after check-in 0%)
- `table_calendar` Flutter package recommended (lightweight, customizable)
- Pricing priority: base < weekend (Fri/Sat) < holiday < manual override
- Cancel policy snapshot: store policy version at reservation creation (host-config defer)
- Unified calendar view (E6): list all houses của host with date headers

## Requirements

### Functional (from BA user stories)
- **E1:** Calendar tháng view per house → AC: GET `/api/host/homestay/houses/{id}/calendar?month=` returns 30+ rows: date, status, price, reservation_id
- **E2:** Block/unblock date range → AC: PATCH `/api/host/homestay/houses/{id}/availability` body: {start_date, end_date, action: block|unblock}
- **E3:** Pricing rules priority → AC: GET calendar at date X returns price computed: base < weekend < holiday < manual_override
- **E4:** Approve/reject booking from marketplace → AC: PATCH `/api/host/homestay/reservations/{id}/status` (approve/reject + reason)
- **E5:** Check-in / check-out tap → AC: PATCH `/api/host/homestay/reservations/{id}/check-in` / `/check-out`, status transitions
- **E6 (T2,T3):** Unified calendar multi-house → AC: GET `/api/host/homestay/unified-calendar?month=` returns all rooms × dates
- **E7 (MUST):** Cancel policy 24h rigid → AC: POST `/api/host/homestay/reservations/{id}/cancel` triggered by guest computes refund: >24h before check-in → 100%; 0-24h → 50%; after check-in → 0%; auto-release calendar slot
- **E8 (SHOULD):** Multiple booking requests same date → AC: list view + 1-click "approve this, reject others"

### Non-functional
- Concurrent booking: 2 requests same date → DB constraint blocks 2nd (returns 409)
- Calendar render <1s for 31-day month
- Cancel refund computed server-side (no client trust)

## Architecture

### Backend

**New models:**

| Model | Fields | Notes |
|---|---|---|
| `Availability` | id, host_id (FK), room_id (FK), date DATE, status ENUM('available','blocked','reserved'), reservation_id (FK NULL), note | Unique (room_id, date); per-day row |
| `PricingRule` | id, host_id (FK), room_id (FK NULL), house_id (FK NULL), rule_type ENUM('base','weekend','holiday','manual'), start_date, end_date, price_per_night, priority INT, weekday_mask SMALLINT NULL, holiday_name VARCHAR NULL | Higher priority wins; weekend uses weekday_mask=bit Sat+Sun |
| `Reservation` | id, host_id (FK), room_id (FK), guest_user_id (FK NULL), guest_name, guest_phone, guest_email NULL, check_in_date, check_out_date, nights, total_amount, deposit_paid, status ENUM('pending','approved','rejected','checked_in','checked_out','cancelled','no_show'), cancel_policy_snapshot JSON, cancelled_at NULL, refund_amount NULL, source ENUM('marketplace','direct','manual'), created_at | check_in_date & check_out_date inclusive/exclusive standard (check-out = day after last stay) |

**Exclusion constraint (Postgres):**

```sql
ALTER TABLE reservations ADD CONSTRAINT reservation_no_overlap
EXCLUDE USING gist (
    room_id WITH =,
    daterange(check_in_date, check_out_date, '[)') WITH &&
) WHERE (status IN ('pending', 'approved', 'checked_in'));
```

This prevents 2 reservations from overlapping for same room while in active states. Postgres-only — confirms Phase 01 migration.

**New endpoints:**

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/api/host/homestay/houses/{id}/calendar?month=YYYY-MM` | require_host + owner | Per-day status + price |
| GET | `/api/host/homestay/unified-calendar?month=` | require_host | All host's homestay rooms × month |
| POST | `/api/host/homestay/houses/{id}/availability` | require_host + owner | Block/unblock range |
| GET | `/api/host/homestay/pricing-rules?house_id=` | require_host | List |
| POST | `/api/host/homestay/pricing-rules` | require_host | Create base/weekend/holiday/manual |
| PATCH | `/api/host/homestay/pricing-rules/{id}` | require_host + owner | Update |
| DELETE | `/api/host/homestay/pricing-rules/{id}` | require_host + owner | Soft delete or hard |
| GET | `/api/host/homestay/reservations?status=&house_id=` | require_host | List |
| POST | `/api/host/homestay/reservations` | require_host | Manual create (rare; marketplace flow in Phase 08) |
| PATCH | `/api/host/homestay/reservations/{id}/status` | require_host + owner | approve / reject |
| PATCH | `/api/host/homestay/reservations/{id}/check-in` | require_host + owner | status→checked_in |
| PATCH | `/api/host/homestay/reservations/{id}/check-out` | require_host + owner | status→checked_out |
| POST | `/api/host/homestay/reservations/{id}/cancel` | require_host + owner OR guest_user_id match | Compute refund server-side |
| POST | `/api/guest/reservations` | require_user | Guest book from marketplace (Phase 08 wires from listing) |

**Services:**

- `app/services/pricing_service.py`:
  - `resolve_price(room_id, date, db)` — query all PricingRule applicable, return highest priority. Default base from House.price.
  ```python
  def resolve_price(room_id, date, db, host_id):
      rules = db.query(PricingRule).filter(
          PricingRule.host_id == host_id,
          or_(PricingRule.room_id == room_id, PricingRule.house_id == ...),
          PricingRule.start_date <= date,
          PricingRule.end_date >= date
      ).order_by(PricingRule.priority.desc()).all()
      for rule in rules:
          if rule.rule_type == "manual": return rule.price_per_night  # always wins
          if rule.rule_type == "holiday": return rule.price_per_night
          if rule.rule_type == "weekend" and date.weekday() in [4, 5]: return rule.price_per_night  # Fri, Sat
          if rule.rule_type == "base": return rule.price_per_night
      return default_base  # fallback House.price
  ```

- `app/services/availability_service.py`:
  - `get_calendar(room_id, month, host_id)` — for each day in month: query Availability + Reservation overlap; compute price; return list
  - `block_range(room_id, start, end, host_id)` — upsert Availability rows status='blocked'

- `app/services/reservation_service.py`:
  - `create_reservation(payload, db, host_id)` — snapshot cancel_policy_v1, compute total_amount via pricing_service, attempt INSERT; catch IntegrityError (exclusion constraint) → return 409 "Phòng đã có đặt khác"
  - `cancel_reservation(reservation_id, actor, db)`:
    ```python
    hours_until_checkin = (reservation.check_in_date - now()).total_seconds() / 3600
    if reservation.status == 'checked_in' or hours_until_checkin < 0:
        refund_pct = 0
    elif hours_until_checkin < 24:
        refund_pct = 0.5
    else:
        refund_pct = 1.0
    refund = reservation.total_amount * refund_pct
    reservation.status = 'cancelled'
    reservation.cancelled_at = now()
    reservation.refund_amount = refund
    # release availability rows
    db.query(Availability).filter(Availability.reservation_id == reservation_id).update({status: 'available', reservation_id: None})
    ```
  - `check_in(reservation_id, host_id)` — status active→checked_in, audit log; also trigger Phase 05 khai_bao_service.auto_create_for_reservation
  - `check_out(reservation_id, host_id)` — status→checked_out

**Migration:** `alembic/versions/0009_homestay_core.py`
- CREATE TABLE availability, pricing_rules, reservations
- Add Postgres extension `btree_gist` (required for exclusion with `=` operator)
- ADD EXCLUSION CONSTRAINT

**Schemas:** `app/schemas/availability.py`, `pricing_rule.py`, `reservation.py`, `calendar.py`

**Integration with Phase 05:**
- `reservation_service.check_in` calls `khai_bao_service.auto_create_for_reservation` (extend Phase 05 service to support Reservation FK)

**Migration Phase 05 alter:** `alembic/versions/0010_kbtt_reservation_fk.py` — ensure khai_bao_tam_tru.reservation_id column exists (already nullable from Phase 05).

### Flutter

**New sub-module `lib/features/host/homestay/`:**

```
lib/features/host/homestay/
├── screens/
│   ├── calendar_screen.dart                # Month calendar per house
│   ├── unified_calendar_screen.dart        # All houses × month
│   ├── block_dates_screen.dart             # Date range picker
│   ├── pricing_rules_list_screen.dart
│   ├── pricing_rule_form_screen.dart       # Type picker + date range + price
│   ├── reservation_list_screen.dart        # Filter status
│   ├── reservation_detail_screen.dart      # Check-in/out actions + cancel
│   └── reservation_calendar_picker_screen.dart  # Visual conflict resolver E8
├── widgets/
│   ├── calendar_day_cell.dart              # Color: available=green, reserved=blue, blocked=gray
│   ├── reservation_status_badge.dart
│   ├── price_tag.dart
│   └── cancel_policy_display.dart          # Show 24h rigid policy text
└── providers/
    ├── homestay_calendar_provider.dart
    ├── pricing_rule_provider.dart
    └── reservation_provider.dart
```

**Packages:**
- `table_calendar: ^3.1.0` — month calendar widget with day customization

### Data flow

```
[Calendar view]
Host taps "Homestay" tab → houses list → tap house
CalendarScreen month view (table_calendar widget)
  ↓ each cell shows: price + status icon (green/blue/gray)
GET /api/host/homestay/houses/{id}/calendar?month=2026-07 → 31 rows
  ↓ tap "Chặn lịch"
BlockDatesScreen → pick range → POST /availability → calendar refreshes

[Pricing rules]
Tap "Giá phòng" → PricingRulesListScreen → tap "+"
PricingRuleFormScreen → type picker (base/weekend/holiday/manual) + date range + price → POST

[Reservation lifecycle]
Marketplace guest sends booking request (Phase 08 wire) → POST /api/guest/reservations
  → backend tries INSERT → exclusion constraint check → if OK status='pending', if conflict 409
ReservationListScreen filter pending → tap row → ReservationDetailScreen
  ↓ tap "Duyệt"
PATCH /status → status='approved', availability rows updated status='reserved'
On check-in date: host taps "Check-in" → PATCH → status='checked_in' + khai_bao_service auto-create
End of stay: tap "Check-out" → status='checked_out'

[Cancel policy]
Guest cancels → POST /reservations/{id}/cancel → backend computes refund per policy
ReservationDetailScreen shows refund_amount + cancelled_at
```

## Related code files

### Backend new files
- `backend/app/repositories/availability_repository.py`
- `backend/app/repositories/pricing_rule_repository.py`
- `backend/app/repositories/reservation_repository.py`
- `backend/app/services/availability_service.py`
- `backend/app/services/pricing_service.py`
- `backend/app/services/reservation_service.py`
- `backend/app/routers/host_homestay.py`
- `backend/app/routers/guest_reservation.py` — public for guests
- `backend/app/schemas/availability.py`, `pricing_rule.py`, `reservation.py`, `calendar.py`
- `backend/alembic/versions/0009_homestay_core.py` (incl btree_gist extension + exclusion constraint)
- `backend/tests/test_pricing_priority_resolution.py`
- `backend/tests/test_reservation_concurrent_booking.py`
- `backend/tests/test_cancel_policy_24h_rigid.py`
- `backend/tests/test_check_in_out_workflow.py`
- `backend/tests/test_calendar_query.py`

### Backend modified files
- `backend/app/models.py` — add 3 models
- `backend/app/services/khai_bao_service.py` — extend with `auto_create_for_reservation` (Phase 05 extension)
- `backend/main.py` — include 2 new routers
- `backend/infra/postgres/init.sql` — `CREATE EXTENSION IF NOT EXISTS btree_gist`

### Flutter new files
See sub-module above (~20 files).

### Flutter modified files
- `lib/main.dart` — register 3 providers
- `lib/features/host/host_dashboard_screen.dart` (Phase 06 refactor) — add "Homestay" entry
- `pubspec.yaml` — table_calendar

## Implementation steps

1. **Backend (extension):** Update `infra/postgres/init.sql` or run inline migration: `CREATE EXTENSION IF NOT EXISTS btree_gist;`
2. **Backend (models):** Add Availability, PricingRule, Reservation models to `app/models.py`.
3. **Backend (migration):** `alembic revision -m "homestay_core"`. Include:
   - CREATE 3 tables with indexes
   - ALTER TABLE reservations ADD CONSTRAINT exclusion (need `op.execute()` for raw SQL exclusion)
   - btree_gist extension (CREATE EXTENSION)
4. **Backend (schemas):** 4 Pydantic schemas.
5. **Backend (repos):** 3 repository files.
6. **Backend (service pricing):** `pricing_service.resolve_price()` with priority resolution.
7. **Backend (service availability):**
   - `get_calendar(room_id, month)` — generate 28-31 day rows; for each: check Availability row (default available if none), check Reservation overlap, compute price
   - `block_range(room_id, start, end)` — upsert
8. **Backend (service reservation):**
   - `create_reservation()` — try INSERT, catch `IntegrityError` for exclusion constraint → raise HTTPException(409)
   - `cancel_reservation()` — compute refund_pct based on hours_until_checkin
   - `check_in()` — update status + call khai_bao_service
   - `check_out()` — update status
9. **Backend (extend khai_bao):** Add `auto_create_for_reservation(reservation, db)` to `app/services/khai_bao_service.py`. Single tenant per reservation (guest_user_id or guest_name+phone as anonymous).
10. **Backend (routers):**
    - `host_homestay.py` — 12 endpoints (calendar, availability, pricing-rules CRUD, reservations CRUD + check-in/out)
    - `guest_reservation.py` — POST /api/guest/reservations (book) + GET /api/guest/reservations (my bookings)
11. **Backend (tests):**
    - `test_pricing_priority_resolution.py`: setup base + weekend + holiday + manual → resolve_price at various dates → assert correct rule wins
    - `test_reservation_concurrent_booking.py`: 2 simultaneous INSERT with overlapping dates → 1 success, 1 IntegrityError → 409. Use threading or asyncio.gather.
    - `test_cancel_policy_24h_rigid.py`: scenarios:
      - 48h before check_in cancel → refund 100%
      - 12h before check_in cancel → refund 50%
      - after check_in cancel → refund 0%
    - `test_check_in_out_workflow.py`: pending → approved → checked_in → checked_out, invalid transitions return 400
    - `test_calendar_query.py`: GET calendar returns 31 rows for July, correct status per day
12. **Backend (verify):** pytest green, including concurrency test must verify exclusion constraint.
13. **Flutter (packages):** `flutter pub add table_calendar`.
14. **Flutter (models):** availability_model, pricing_rule_model, reservation_model, calendar_day_model.
15. **Flutter (repos + providers):** 3 each.
16. **Flutter (widgets):**
    - `calendar_day_cell.dart`: green if available, blue if reserved, gray if blocked, price label
    - `reservation_status_badge.dart`: pending/approved/checked_in/checked_out/cancelled
    - `price_tag.dart`: small VND label
    - `cancel_policy_display.dart`: text block showing "24h: full refund / 0-24h: 50% / after: 0%"
17. **Flutter (screens):**
    - `calendar_screen.dart`: table_calendar widget with day builder using calendar_day_cell
    - `unified_calendar_screen.dart`: ListView of rooms with horizontal scroll of dates (DataTable-like)
    - `block_dates_screen.dart`: date range picker + submit
    - `pricing_rules_list_screen.dart`: list with type filter
    - `pricing_rule_form_screen.dart`: type-specific UI (weekend picks days, holiday picks date)
    - `reservation_list_screen.dart`: tabs by status
    - `reservation_detail_screen.dart`: info + cancel_policy_display + actions (check-in/out/cancel/approve/reject)
    - `reservation_calendar_picker_screen.dart`: E8 multiple requests resolver
18. **Flutter (main):** register 3 providers.
19. **Flutter (host_dashboard):** add "Homestay" entry.
20. **Flutter (analyze):** 0 errors.
21. **E2E smoke:**
    - Host has 1 homestay room
    - Open calendar July 2026 → all green
    - Set weekend pricing rule (Fri/Sat × 1.5) → Friday cells show higher price
    - Block 15-20/7 → cells gray
    - Guest (simulated) sends booking request 22-25/7 → pending
    - Host approves → availability cells turn blue
    - Run concurrent test: 2 guests book same room 22-25/7 → 1 succeeds, 1 gets 409
    - Cancel test: cancel reservation 48h before → refund 100%
    - Check-in flow: tap check-in → status updates → khai_bao_service creates record
    - Check-out → status checked_out

## Todo list
- [ ] Backend: enable btree_gist extension
- [ ] Backend: 3 models (Availability, PricingRule, Reservation)
- [ ] Backend: alembic 0009 with exclusion constraint
- [ ] Backend: 4 schemas
- [ ] Backend: 3 repositories
- [ ] Backend: pricing_service priority resolution
- [ ] Backend: availability_service calendar + block
- [ ] Backend: reservation_service (create, cancel, check-in/out)
- [ ] Backend: extend khai_bao_service for Reservation
- [ ] Backend: host_homestay + guest_reservation routers
- [ ] Backend: 5 test files including concurrency + cancel policy
- [ ] Flutter: table_calendar package
- [ ] Flutter: 4 models + 3 repositories + 3 providers
- [ ] Flutter: 4 widgets
- [ ] Flutter: 8 screens (homestay sub-module)
- [ ] Flutter: dashboard entry + main registration
- [ ] E2E smoke including concurrency simulation

## Success criteria (testable)
- AC1 (E1 calendar): GET calendar returns 31 rows for July, each with status + price
- AC2 (E3 pricing priority): base 500K, weekend 700K, holiday 1M, manual 1.5M on 2026-07-04 (Sat) → resolve_price returns 1.5M
- AC3 (E7 concurrent): 2 threads INSERT same room same dates → 1 succeeds, 1 raises IntegrityError → 409
- AC4 (E7 cancel): 48h before → 100% refund; 12h before → 50%; after check_in → 0%
- AC5 (E5 check-in/out): tap check-in → status checked_in + khai_bao_tam_tru row created for guest
- AC6 (E2 block range): block 15-20 → cells gray; unblock → cells available
- AC7 (E6 unified): host with 3 homestay rooms → calendar shows all 3 × 31 days grid
- AC8 (isolation): Host A queries Host B's calendar → 403
- AC9 (perf): calendar render <1s; concurrent test 2 threads <500ms each
- Demo: full homestay flow as E2E smoke

## Risk assessment
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| btree_gist extension missing in dev Postgres | 30% | HIGH | Phase 01 init.sql includes CREATE EXTENSION; document in README |
| Exclusion constraint slow query | 20% | MED | Index on (room_id, status); benchmark on 10K reservations |
| Cancel policy edge case: timezone | 30% | MED | Use UTC throughout; document VN time display only |
| Calendar UI lag with 100+ rules | 15% | LOW | Cache resolve_price per (room, date); invalidate on rule change |
| Guest cancels without auth (no guest_user_id) | 40% | MED | If reservation.source='direct', cancel via secret token in confirmation email/link |
| Reservation overlap edge: check_out same as next check_in | 30% | MED | Use `daterange [) ` half-open interval (Postgres default); check_out date is exclusive |
| Marketplace book flow missing here (Phase 08) | 100% | LOW | Phase 07 has manual host-create endpoint; Phase 08 wires marketplace |

## Security considerations
- All host endpoints require_host + repository host_id filter
- Guest POST /api/guest/reservations: require_user (logged-in guest); validate guest_user_id == claims.sub
- Cancel: only host OR guest_user_id == claims.sub can cancel; refund computed server-side (never trust client)
- Exclusion constraint enforces no double-booking even if app code bug
- Audit: status changes + cancellations write change_logs
- Khai báo auto-create on check-in: tenant data from Reservation (guest_name, phone) — minimal PII

## Next steps
- Unblocks Phase 08 (marketplace integration → draft Reservation from guest book)
- Dependencies for next: Reservation table populated → ADR report (Phase 06) returns data
