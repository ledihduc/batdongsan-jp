---
title: "Phase 08 — Marketplace ↔ Ops Integration: 1-way sync + auto-draft from booking"
description: "Ops room → House upsert (1 direction), marketplace booking → draft Contract/Reservation based on product_type, placeholder Tenant from phone-only guest"
status: pending
priority: P2
effort: 5-7d
branch: TBD
tags: [backend, flutter, marketplace, integration, sync]
created: 2026-06-22
---

# Phase 08 — Marketplace ↔ Ops Integration

**Sized:** 5–7d
**Status:** ⏸ Pending (Ready)
**Blocks:** None (final integration phase)
**Blocked by:** 03 (Contract), 04 (Invoice optional), 07 (Reservation)

## Context links
- BA doc §4 H (H1-H2 sync + auto-create draft), §6 (channel manager defer, 1 chiều sync), §9b (Phase 08 marketplace integration)
- Research: `researcher-backend-audit.md` §1 (existing House model with multi-unit fields), §2 (houses router)
- Code files affected: `app/models.py` (add House.product_type), `app/services/marketplace_sync_service.py` (new), `app/routers/marketplace_integration.py` (new), `lib/features/host/marketplace/` (new)

## Overview
Đóng vòng "đăng 1 lần dùng 2 chỗ":
1. **Sync 1 chiều ops → marketplace:** Khi host tạo Room (nhà trọ) hoặc set Room is_homestay (homestay), tự động upsert House listing trên marketplace
2. **Auto-draft from marketplace booking:** Guest book trên marketplace (qua existing viewing_appointments hoặc new reservation flow) → backend tạo draft Contract (nhà trọ) hoặc draft Reservation (homestay) dựa trên House.product_type
3. **Collision handling:** Guest không có account → tạo placeholder Tenant với phone-only

## Key insights from research
- Existing `House` model có `host_id`, `total_units`, `available_units`, `category_id`, `listing_type` — chưa có `product_type` ('boarding_house'|'homestay'|'apartment')
- Sync 1 chiều: KHÔNG reverse (House changes do NOT update Room) — tránh data integrity issues
- Phase 03 Room có `is_listed_on_marketplace BOOL` flag mới (or via House.room_id FK)
- Reservation source='marketplace' (Phase 07) — Phase 08 hook for this
- Contract source ENUM thêm 'marketplace' cho draft (Phase 03 schema extension)

## Requirements

### Functional (from BA user stories)
- **H1:** Tạo Room → marketplace listing auto-sync → AC: POST room with `publish_to_marketplace=true` → House row created/updated with synced fields (price, images, title); ops Room.is_listed=true
- **H2:** Marketplace booking → draft Contract or Reservation → AC:
  - For boarding_house: viewing_appointments approve → auto-create Contract status=draft
  - For homestay: marketplace booking → auto-create Reservation status=pending
- **H2 (collision):** Guest no account → AC: backend creates placeholder Tenant with phone+name only, no User row

### Non-functional
- Sync atomic: room create + house upsert in single transaction
- Idempotent: re-sync doesn't create duplicate House
- Manual override: host can edit House post-sync independently (UI shows "Manual override" badge)

## Architecture

### Backend

**Schema changes:**

| Table | Field | Change |
|---|---|---|
| `houses` | `product_type` | NEW ENUM('boarding_house','homestay','apartment') default 'apartment' |
| `houses` | `source_room_id` | NEW FK Room NULL — tracks ops-synced rooms |
| `houses` | `last_synced_at` | NEW DATETIME NULL |
| `rooms` | `is_listed_on_marketplace` | NEW BOOL default false |
| `rooms` | `marketplace_house_id` | NEW FK House NULL — reverse lookup |
| `tenants` | `is_placeholder` | NEW BOOL default false — marketplace guest without account |
| `tenants` | `created_from_booking` | NEW FK viewing_appointments OR reservations NULL |
| `contracts` | `source` | NEW ENUM('manual','marketplace','imported') default 'manual' |

**New endpoints:**

| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/api/host/rooms/{id}/publish` | require_host + owner | Trigger sync to House |
| POST | `/api/host/rooms/{id}/unpublish` | require_host + owner | Hide listing, set House.status='hidden' |
| POST | `/api/host/marketplace/contracts/from-appointment/{appt_id}` | require_host + owner | Approve viewing appointment + create Contract draft |
| POST | `/api/host/marketplace/reservations/from-booking/{booking_id}` | require_host + owner | Approve marketplace booking + create Reservation draft |
| GET | `/api/host/marketplace/sync-status` | require_host | List rooms vs houses, show out-of-sync |

**Service:**

- `app/services/marketplace_sync_service.py`:
  - `sync_room_to_house(room_id, host_id, db)`:
    ```python
    room = db.query(Room).get(room_id)
    if not room: raise 404
    house = db.query(House).filter(House.source_room_id == room.id).first()
    if house:
        # Update existing
        house.title = room.code  # or building name + room code
        house.price = room.base_price
        house.images = room.images
        house.last_synced_at = now()
    else:
        # Create new
        house = House(
            host_id=host_id,
            title=f"{room.building.name} - {room.code}",
            price=room.base_price,
            images=room.images,
            product_type='boarding_house' if room.building else 'homestay',
            source_room_id=room.id,
            status='pending',  # admin approval
            last_synced_at=now()
        )
        db.add(house)
    db.flush()
    room.is_listed_on_marketplace = True
    room.marketplace_house_id = house.id
    db.commit()
    return house
    ```
  - `unpublish_room(room_id, host_id, db)`:
    - Set House.status='hidden', Room.is_listed=False
  - `create_contract_from_appointment(appt_id, host_id, db)`:
    - Get viewing_appointment (renamed Phase 01b)
    - Get House → check source_room_id
    - If guest is placeholder (no email/cccd): create Tenant with is_placeholder=true, name+phone from appointment
    - Create Contract status='draft', source='marketplace', room_id=house.source_room_id, primary tenant = newly created
    - Return draft Contract for host to complete
  - `create_reservation_from_booking(booking_id, host_id, db)`:
    - Similar but creates Reservation (Phase 07)
    - Check exclusion constraint via reservation_service.create_reservation

**Migration:** `alembic/versions/0011_marketplace_integration.py`
- ALTER TABLE add columns to houses, rooms, tenants, contracts
- Add FK constraints + indexes

**Schemas:** `app/schemas/marketplace.py`

### Flutter

**New sub-module `lib/features/host/marketplace/`:**

```
lib/features/host/marketplace/
├── screens/
│   ├── sync_status_screen.dart            # List rooms vs houses, show out-of-sync
│   ├── publish_room_screen.dart           # Pre-publish review + edit synced fields
│   ├── create_contract_from_appt_screen.dart  # Review appointment → confirm → draft created
│   └── create_reservation_from_booking_screen.dart
└── widgets/
    └── sync_status_badge.dart             # synced | out-of-sync | not-listed
```

**Modify existing screens:**
- `lib/features/host/property/screens/room_form_screen.dart` (Phase 03) — add toggle "Đăng lên marketplace"
- `lib/features/host/host_dashboard_screen.dart` — add "Tin chờ chuyển hợp đồng" widget (list pending appointments + bookings)

### Data flow

```
[Publish flow]
Phase 03 RoomFormScreen → toggle "Đăng lên marketplace" ON → submit
  ↓
POST /api/host/rooms/{id}/publish
  ↓ marketplace_sync_service.sync_room_to_house()
  ↓ creates House (status='pending', admin needs approve)
  ↓ Room.is_listed=true, marketplace_house_id set
Admin approves House → House.status='approved'
Guest sees on marketplace

[Booking → Contract flow (nhà trọ)]
Guest taps House on marketplace → "Đặt lịch xem nhà" → POST /api/viewing-appointments (existing flow)
Host receives notification → opens HostHomeScreen → BookingRequests tab
  → tap "Duyệt + Tạo hợp đồng nháp"
POST /api/host/marketplace/contracts/from-appointment/{appt_id}
  ↓ marketplace_sync_service.create_contract_from_appointment()
  ↓ creates Tenant (is_placeholder if no email) + Contract (status=draft, source=marketplace)
  ↓ host redirected to ContractFormScreen with draft pre-filled
  ↓ host completes (start_date, deposit, etc.) + activates → Phase 03 standard flow

[Booking → Reservation flow (homestay)]
Guest taps House on marketplace (product_type=homestay) → "Đặt phòng" → POST /api/guest/reservations (Phase 07)
  ↓ Phase 07 creates Reservation status='pending'
Host opens HostDashboard → "Reservation pending" widget → ReservationListScreen
  ↓ approve → Phase 07 PATCH /status approved
```

## Related code files

### Backend new files
- `backend/app/services/marketplace_sync_service.py`
- `backend/app/routers/marketplace_integration.py`
- `backend/app/schemas/marketplace.py`
- `backend/alembic/versions/0011_marketplace_integration.py`
- `backend/tests/test_marketplace_sync_room_to_house.py`
- `backend/tests/test_marketplace_create_contract_from_appt.py`
- `backend/tests/test_marketplace_create_reservation_from_booking.py`
- `backend/tests/test_marketplace_placeholder_tenant.py`
- `backend/tests/test_marketplace_idempotent_sync.py`

### Backend modified files
- `backend/app/models.py` — add fields to House, Room, Tenant, Contract
- `backend/app/routers/host_room.py` — add /publish + /unpublish endpoints
- `backend/app/routers/viewing_appointments.py` — optionally trigger sync on approve
- `backend/main.py` — include marketplace_integration router

### Flutter new files
- `lib/features/host/marketplace/screens/sync_status_screen.dart`
- `lib/features/host/marketplace/screens/publish_room_screen.dart`
- `lib/features/host/marketplace/screens/create_contract_from_appt_screen.dart`
- `lib/features/host/marketplace/screens/create_reservation_from_booking_screen.dart`
- `lib/features/host/marketplace/widgets/sync_status_badge.dart`
- `lib/data/repositories/api_marketplace_repository.dart`
- `lib/providers/marketplace_provider.dart`

### Flutter modified files
- `lib/features/host/property/screens/room_form_screen.dart` — add publish toggle
- `lib/features/host/host_dashboard_screen.dart` — add pending appointments widget with "Tạo hợp đồng" action
- `lib/main.dart` — register provider

## Implementation steps

1. **Backend (schema additions):** Add columns to House (product_type, source_room_id, last_synced_at), Room (is_listed_on_marketplace, marketplace_house_id), Tenant (is_placeholder, created_from_booking), Contract (source).
2. **Backend (migration):** `alembic revision -m "marketplace_integration"`. ALTER TABLE statements.
3. **Backend (schemas):** `marketplace.py` with sync request/response.
4. **Backend (service):**
   - `sync_room_to_house()` — upsert logic
   - `unpublish_room()` — hide listing
   - `create_contract_from_appointment()` — placeholder Tenant logic
   - `create_reservation_from_booking()` — calls Phase 07 service
5. **Backend (router):**
   - POST /api/host/rooms/{id}/publish — calls sync service
   - POST /api/host/rooms/{id}/unpublish
   - POST /api/host/marketplace/contracts/from-appointment/{appt_id}
   - POST /api/host/marketplace/reservations/from-booking/{booking_id}
   - GET /api/host/marketplace/sync-status — list out-of-sync rooms
6. **Backend (integrate viewing_appointments):** Add hint in viewing_appointments approve response: `next_action: "create_contract_draft"` with link to Phase 08 endpoint.
7. **Backend (tests):**
   - `test_marketplace_sync_room_to_house.py`: create room with publish → House row exists with synced fields
   - `test_marketplace_create_contract_from_appt.py`: approve appointment → Contract draft + Tenant placeholder
   - `test_marketplace_create_reservation_from_booking.py`: book homestay → Reservation pending
   - `test_marketplace_placeholder_tenant.py`: guest no email → Tenant.is_placeholder=true
   - `test_marketplace_idempotent_sync.py`: 2x sync → 1 House row (UPDATE not INSERT)
8. **Backend (verify):** pytest green.
9. **Flutter (models):** marketplace_sync_status_model.
10. **Flutter (repo + provider):** marketplace_repository + provider.
11. **Flutter (widgets):** sync_status_badge.
12. **Flutter (screens):**
    - `sync_status_screen.dart`: list rooms with badge (synced/not-listed/out-of-sync)
    - `publish_room_screen.dart`: confirm sync with edit fields
    - `create_contract_from_appt_screen.dart`: appointment review → tap confirm → backend creates draft → navigate to Phase 03 ContractFormScreen pre-filled
    - `create_reservation_from_booking_screen.dart`: similar for homestay
13. **Flutter (modify property):** add publish toggle in room_form_screen.dart submit handler.
14. **Flutter (modify dashboard):** add "Yêu cầu chờ chuyển HĐ" widget showing count of appointments approved but no Contract yet.
15. **Flutter (main):** register provider.
16. **Flutter (analyze):** 0 errors.
17. **E2E smoke:**
    - Host creates Room with publish=true → House listing visible on marketplace (admin approve)
    - Guest (other account) sees listing → tap "Đặt lịch xem nhà" → appointment created
    - Host receives notification → opens dashboard → tap appointment → "Duyệt + Tạo HĐ nháp"
    - Backend creates Tenant (placeholder if guest no email) + Contract draft
    - Host fills remaining fields → activates Contract → Room=occupied → House.available_units decrement
    - For homestay: guest books on marketplace → Reservation pending → host approves → calendar marks reserved
    - Re-publish same Room → no duplicate House (idempotent)

## Todo list
- [ ] Backend: schema additions (House, Room, Tenant, Contract)
- [ ] Backend: alembic 0011 migration
- [ ] Backend: marketplace.py schemas
- [ ] Backend: marketplace_sync_service (sync, unpublish, create_contract, create_reservation)
- [ ] Backend: marketplace_integration router (5 endpoints) + host_room publish endpoints
- [ ] Backend: viewing_appointments approve response hint
- [ ] Backend: 5 test files
- [ ] Flutter: marketplace models + repo + provider
- [ ] Flutter: sync_status_badge widget
- [ ] Flutter: 4 screens (sync_status, publish_room, create_contract_from_appt, create_reservation_from_booking)
- [ ] Flutter: modify room_form_screen (publish toggle)
- [ ] Flutter: modify dashboard (pending appointments widget)
- [ ] E2E smoke test

## Success criteria (testable)
- AC1 (H1 sync): POST /rooms/{id}/publish → House row exists with title, price, images from Room; Room.is_listed=true
- AC2 (H1 idempotent): 2x publish same Room → 1 House row (UPDATE on 2nd call)
- AC3 (H1 unpublish): POST /unpublish → House.status='hidden', Room.is_listed=false
- AC4 (H2 contract from appt): appt approved → Contract draft created with source='marketplace', primary tenant = placeholder if guest no email
- AC5 (H2 reservation from booking): homestay booking → Reservation pending, exclusion constraint check passes
- AC6 (collision): guest no account (phone-only) → Tenant.is_placeholder=true, no User row
- AC7 (data integrity): unpublish does NOT delete Contract data if active contract exists
- AC8 (isolation): Host A's Room cannot sync to Host B's House (require_host check)
- Demo: full marketplace → ops flow as E2E smoke

## Risk assessment
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Sync breaks existing House data | 50% | HIGH | Only sync fields explicitly mapped; preserve manual edits via "manual_override" flag |
| Placeholder Tenant duplicate (same phone, multiple bookings) | 40% | MED | Check existing Tenant by phone before create; reuse if found |
| Race condition: 2 publishes concurrent | 10% | LOW | DB transaction + UNIQUE constraint on (source_room_id) on houses |
| Marketplace admin approval flow blocks ops | 30% | MED | Allow host to use Contract draft even if House not approved (separate lifecycles) |
| Contract.source enum addition breaks Phase 03 schema | 20% | MED | Add column with default='manual'; existing rows safe |
| Reservation from booking exceeds House.available_units | 30% | MED | Backend validates available_units > 0 before create Reservation; reject if 0 |
| Phase split needed if too large (>7d) | 50% | LOW | Sub-divide: 08a sync only, 08b auto-draft; document in plan if needed |

## Security considerations
- All endpoints require_host + owner validation (room belongs to host)
- Cross-host sync attempts blocked
- Placeholder Tenant data (name, phone) limited PII; no CCCD until host completes contract
- Audit log: publish/unpublish + create from booking write change_logs
- Marketplace listing approval still requires admin role (existing flow)

## Next steps
- Final phase — completes BA scope
- Future enhancements: channel manager (Airbnb/Booking sync), dynamic pricing, IoT meters
- Post-launch: monitor T1 churn; consider Phase 09 Excel import if needed (per D8)
