---
title: "Phase 03 — Nhà trọ Core: Building / Room / Tenant / Contract"
description: "Models + repo pattern, M:N Contract-Tenant pivot, Room state machine, transfer room, soft delete, audit trail"
status: pending
priority: P1
effort: 7-9d
branch: TBD
tags: [backend, flutter, nha-tro, models, state-machine]
created: 2026-06-22
---

# Phase 03 — Nhà trọ Core

**Sized:** 7–9d
**Status:** ⏸ Pending (Ready)
**Blocks:** 04 (Invoice needs Contract), 05 (KhaiBaoTamTru needs Tenant)
**Blocked by:** 01, 01b, 02

## Context links
- BA doc §4 B (Building/Room), C (Contract/Tenant), §5 AC (state machine valid, soft delete, M:N), §9 D2 (M:N pivot), D5 (duplicate room), Q5 (audit trail)
- Research: `researcher-backend-audit.md` §1 (missing models list), §6 (patterns to follow); `researcher-flutter-audit.md` §11 (host folder organization)
- Code files affected: `app/models.py`, `app/routers/host/*.py` (new), `lib/features/host/property/` (new sub-module)

## Overview
Tạo nền tảng quản lý dãy trọ: Building → Room (state machine, maintenance) → Contract (M:N Tenants với primary contact) → Tenant. Repo pattern auto-isolate host_id. Soft delete Contract. Transfer room giữ contract.

## Key insights from research
- Existing `House` model có `total_units` + `available_units` counters → KHÔNG dùng cho nhà trọ; Building/Room mới granular hơn
- BA D2 sealed: `contract_tenants` pivot table với `is_primary BOOLEAN` (1 primary chịu tiền, co-tenants vẫn khai báo tạm trú riêng)
- BA D5 sealed: "Duplicate this room" 1-click, KHÔNG build template builder
- Room state machine 3 states: `vacant`, `occupied`, `maintenance`. Transitions: `vacant ↔ occupied`, `vacant → maintenance → vacant`
- Contract state: `draft → active → (expired | terminated)`. Soft delete bằng status, KHÔNG xoá DB
- Audit: mọi Contract mutation ghi vào `change_logs` (Phase 02 table)
- Flutter: dùng package mới `table_calendar` (sẽ cần ở Phase 07; Phase 03 chỉ list/grid view), `flutter_form_builder` cho contract forms phức tạp

## Requirements

### Functional (from BA user stories)
- **B1:** Tạo Building với địa chỉ + note → AC: POST `/api/host/buildings` 201, listing in Flutter shows building
- **B2:** Tạo Room riêng (mã, area, capacity, base_price, status) → AC: drill into building → grid of rooms với status badge
- **B3:** Duplicate 1 phòng 1-click → AC: POST `/api/host/rooms/{id}/duplicate` returns new room with same fields + suffix `_copy`
- **B4 (MUST):** Set Room status maintenance với start/end → AC: room badge shows "Đang sửa, ETA dd/MM", dashboard widget counts maintenance rooms
- **C1:** Tạo Contract: chọn room + tenant info + dates + deposit → AC: POST `/api/host/contracts` returns contract + tenant rows; pivot row created
- **C2:** Upload ảnh CCCD + ảnh phòng bàn giao → AC: multi-image upload, paths saved on Contract
- **C3:** Xem status + cảnh báo expiring 30d (dashboard widget) → AC: GET `/api/host/contracts?expiring_within=30` returns list
- **C4:** Batch renewal cho nhiều contract → AC: POST `/api/host/contracts/batch-renew` accepts contract_ids + new_end_date
- **C5 (MUST):** Move-out giữa kỳ → tạo final invoice + prorate + deposit refund → AC: PATCH `/api/host/contracts/{id}/terminate` accepts `actual_end_date`, `deposit_refund_amount`, photos
- **C6 (MUST):** Upload ảnh phòng lúc trả + note hư hại → AC: terminate request includes `damage_photos`, `damage_note`
- **C7 (SHOULD):** Transfer tenant qua phòng khác → AC: PATCH `/api/host/contracts/{id}/transfer-room` accepts `new_room_id`, prorate utility cuối ngày cũ
- **C8 (MUST):** Roommates: 1 contract → nhiều tenant qua pivot, 1 primary → AC: POST contract với `tenants: [{user_data, is_primary}]`, query GET shows all + primary flag

### Non-functional
- Repository auto-inject host_id filter (Phase 02 base class)
- All Contract status transitions write change_logs row
- Soft delete: terminated Contract stays DB, default query filters `status != terminated`
- Pydantic schemas at all routes

## Architecture

### Backend

**New models:**

| Model | Fields | Notes |
|---|---|---|
| `Building` | id, host_id (FK, indexed), name, address, city, district, ward, note, created_at, updated_at | Multi-tenant via host_id |
| `Room` | id, building_id (FK), code, area_m2, capacity, base_price, status ENUM('vacant','occupied','maintenance'), maintenance_start DATE NULL, maintenance_end DATE NULL, images JSON, note, created_at, updated_at | State machine validated in service |
| `Tenant` | id, host_id (FK), full_name, cccd_number_hash, phone, email NULL, birthday, address_origin, cccd_front_path, cccd_back_path, created_at | Reusable across contracts |
| `Contract` | id, host_id (FK), room_id (FK), start_date, end_date, monthly_rent, deposit, status ENUM('draft','active','expired','terminated'), terminated_at NULL, deposit_refund_amount NULL, damage_note NULL, damage_photos JSON NULL, handover_photos JSON, created_at, updated_at | Soft delete via status |
| `ContractTenant` (pivot) | contract_id (FK), tenant_id (FK), is_primary BOOL, joined_at DATE, left_at DATE NULL | Composite PK (contract_id, tenant_id); D2 |

**State machine:**
- Room: `vacant → occupied` (when contract activates), `occupied → vacant` (when contract terminates), `vacant ↔ maintenance` (manual)
- Contract: `draft → active` (host confirms), `active → expired` (end_date passed), `active → terminated` (manual move-out), `terminated` terminal

**New endpoints:**

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/api/host/buildings` | require_host | List host's buildings |
| POST | `/api/host/buildings` | require_host | Create |
| PATCH | `/api/host/buildings/{id}` | require_host + owner | Update |
| DELETE | `/api/host/buildings/{id}` | require_host + owner | Cascade soft-delete rooms |
| GET | `/api/host/buildings/{id}/rooms` | require_host | List rooms |
| POST | `/api/host/buildings/{id}/rooms` | require_host | Create room |
| PATCH | `/api/host/rooms/{id}` | require_host + owner | Update |
| POST | `/api/host/rooms/{id}/duplicate` | require_host + owner | D5 1-click clone |
| POST | `/api/host/rooms/{id}/maintenance` | require_host | Set maintenance with start/end |
| POST | `/api/host/rooms/{id}/maintenance/end` | require_host | Clear maintenance, return to vacant |
| GET | `/api/host/contracts` | require_host | Filters: status, room_id, expiring_within (days) |
| POST | `/api/host/contracts` | require_host | Create with embedded tenants array |
| GET | `/api/host/contracts/{id}` | require_host + owner | Detail with tenants |
| PATCH | `/api/host/contracts/{id}/activate` | require_host + owner | draft→active, Room→occupied |
| PATCH | `/api/host/contracts/{id}/terminate` | require_host + owner | active→terminated, body: actual_end_date, deposit_refund, photos, note |
| PATCH | `/api/host/contracts/{id}/transfer-room` | require_host + owner | C7 transfer logic |
| POST | `/api/host/contracts/batch-renew` | require_host | Body: contract_ids[], new_end_date |
| GET | `/api/host/tenants` | require_host | Reusable tenant list (autocomplete in contract form) |
| POST | `/api/host/tenants` | require_host | Create tenant |

**Repositories:**
- `app/repositories/building_repository.py extends HostScopedRepository[Building]`
- `app/repositories/room_repository.py extends HostScopedRepository[Room]` (host_field via building.host_id join)
- `app/repositories/contract_repository.py extends HostScopedRepository[Contract]`
- `app/repositories/tenant_repository.py extends HostScopedRepository[Tenant]`

**Services (business logic):**
- `app/services/contract_service.py` — activate/terminate/transfer/batch_renew with state machine + audit log
- `app/services/room_state_service.py` — validate transitions, set maintenance window

**Migration:** `alembic/versions/0005_nha_tro_core.py` — create 5 tables + indexes (building.host_id, room.building_id+status, contract.host_id+status+end_date)

**Schemas:** `app/schemas/building.py`, `room.py`, `tenant.py`, `contract.py` (Create/Update/Response variants)

### Flutter

**New sub-module structure `lib/features/host/property/`:**

```
lib/features/host/property/
├── screens/
│   ├── building_list_screen.dart
│   ├── building_detail_screen.dart        # → grid of rooms
│   ├── room_form_screen.dart
│   ├── room_detail_screen.dart            # contracts history + status
│   ├── contract_form_screen.dart          # multi-tenant inputs
│   ├── contract_detail_screen.dart
│   ├── contract_terminate_screen.dart     # C5 move-out flow
│   └── contract_transfer_room_screen.dart # C7
├── widgets/
│   ├── room_status_badge.dart
│   ├── room_grid_card.dart
│   ├── tenant_input_row.dart              # for roommates
│   └── maintenance_date_picker.dart
└── providers/
    ├── building_provider.dart
    ├── room_provider.dart
    └── contract_provider.dart
```

**New repositories + models:**
- `lib/data/models/building_model.dart`
- `lib/data/models/room_model.dart`
- `lib/data/models/tenant_model.dart`
- `lib/data/models/contract_model.dart`
- `lib/data/repositories/api_building_repository.dart`
- `lib/data/repositories/api_room_repository.dart`
- `lib/data/repositories/api_contract_repository.dart`
- `lib/data/repositories/api_tenant_repository.dart`

**Packages to add to pubspec.yaml:**
- `flutter_form_builder: ^9.4.0` — contract form complex validation
- `form_builder_validators: ^11.0.0`

**Modify `lib/features/host/host_home_screen.dart`:**
- Add tab "Nhà trọ" (drill in to BuildingListScreen)
- Dashboard widget: "X phòng đang sửa", "Y hợp đồng sắp hết hạn 30d"

### Data flow

```
Host tap "Nhà trọ" → BuildingListScreen (provider.fetch)
  ↓ tap building
BuildingDetailScreen → Room grid (color = status)
  ↓ tap room
RoomDetailScreen → contracts history + actions (Maintenance / Create Contract)
  ↓ "Tạo hợp đồng"
ContractFormScreen → fill rent/deposit/dates + add tenants (1 primary + N co-tenants)
  ↓ submit
POST /api/host/contracts → backend creates Contract (status=draft) + Tenant rows + pivot rows + change_logs row
  ↓ "Activate"
PATCH /api/host/contracts/{id}/activate → Contract status=active, Room status=occupied
```

Move-out (C5):
```
ContractDetailScreen → tap "Trả phòng"
ContractTerminateScreen → pick actual_end_date + deposit_refund_amount + upload damage_photos + note
  ↓ submit
PATCH /api/host/contracts/{id}/terminate → status=terminated, Room status=vacant, log change
[Note: invoice prorate happens in Phase 04; Phase 03 just sets status + records data]
```

## Related code files

### Backend new files
- `backend/app/repositories/building_repository.py`
- `backend/app/repositories/room_repository.py`
- `backend/app/repositories/contract_repository.py`
- `backend/app/repositories/tenant_repository.py`
- `backend/app/services/contract_service.py`
- `backend/app/services/room_state_service.py`
- `backend/app/routers/host_building.py`
- `backend/app/routers/host_room.py`
- `backend/app/routers/host_contract.py`
- `backend/app/routers/host_tenant.py`
- `backend/app/schemas/building.py`
- `backend/app/schemas/room.py`
- `backend/app/schemas/contract.py`
- `backend/app/schemas/tenant.py`
- `backend/alembic/versions/0005_nha_tro_core.py`
- `backend/tests/test_building.py`
- `backend/tests/test_room.py`
- `backend/tests/test_contract.py`
- `backend/tests/test_contract_state_machine.py`
- `backend/tests/test_contract_transfer_room.py`
- `backend/tests/test_roommates_pivot.py`

### Backend modified files
- `backend/app/models.py` — add 5 model classes
- `backend/main.py` — include 4 new routers

### Flutter new files
See sub-module structure above (~20 files).

### Flutter modified files
- `lib/main.dart` — add BuildingProvider, RoomProvider, ContractProvider
- `lib/features/host/host_home_screen.dart` — add "Nhà trọ" tab + dashboard widgets
- `pubspec.yaml` — flutter_form_builder, form_builder_validators

## Implementation steps

1. **Backend (models):** Add `Building`, `Room`, `Tenant`, `Contract`, `ContractTenant` to `app/models.py`. Composite PK on pivot.
2. **Backend (migration):** `alembic revision -m "nha_tro_core"`. Manual table CREATE statements with FK + indexes + CHECK constraints on Room.status, Contract.status enums.
3. **Backend (schemas):** Create 4 schema files with `*Create`, `*Update`, `*Response` Pydantic classes. Contract schema embeds list of `TenantCreate` with `is_primary` flag.
4. **Backend (repositories):** Implement 4 repositories extending HostScopedRepository.
5. **Backend (service room):** `room_state_service.py` — validate transitions, `set_maintenance(room, start, end)`, `clear_maintenance(room)`.
6. **Backend (service contract):** `contract_service.py`:
   - `create_contract(payload, host_id)` — create Contract + Tenants + pivot + audit log
   - `activate_contract(contract_id, host_id)` — validate state, update Room status, audit
   - `terminate_contract(contract_id, payload, host_id)` — validate active state, update Room→vacant, store photos/note, audit
   - `transfer_room(contract_id, new_room_id, host_id)` — validate new_room.status=vacant, update contract.room_id, audit, mark old_room=vacant + new_room=occupied (or maintain accounting in Phase 04)
   - `batch_renew(contract_ids, new_end_date, host_id)` — bulk update
7. **Backend (router building):** CRUD endpoints with require_host.
8. **Backend (router room):** CRUD + duplicate + maintenance start/end.
9. **Backend (router contract):** CRUD + activate + terminate + transfer + batch-renew. Filter expiring_within for dashboard.
10. **Backend (router tenant):** CRUD for tenant autocomplete.
11. **Backend (audit decorator integration):** Wrap mutation methods in contract_service with `change_logs` writes via repository.audit util (Phase 02).
12. **Backend (tests):** Write 6 test files. Key cases:
    - State machine invalid transitions return 400 (e.g., terminated → active)
    - Soft delete: GET contracts default doesn't return terminated, with filter `include_terminated=true` returns
    - M:N pivot: contract created with 3 tenants (1 primary, 2 co), all 3 rows in `contract_tenants`
    - Transfer room: old_room.status=vacant, new_room.status=occupied
    - Duplicate room: new row with `code + "_copy"`
    - Cross-host isolation: Host A creates building, Host B GET /api/host/buildings → 0 results
13. **Backend (verify):** `pytest tests/test_*` → green; `alembic upgrade head` clean.
14. **Flutter (packages):** `flutter pub add flutter_form_builder form_builder_validators` → `flutter pub get`.
15. **Flutter (models):** Create 4 model classes with `fromJson/toJson`.
16. **Flutter (repos):** Create 4 api_*_repository.dart files calling endpoints.
17. **Flutter (providers):** Create 3 providers (Building, Room, Contract).
18. **Flutter (widgets):** Create reusable widgets (room_status_badge, room_grid_card, tenant_input_row, maintenance_date_picker).
19. **Flutter (screens):** Build 8 screens in order: building_list → building_detail → room_form → room_detail → contract_form → contract_detail → contract_terminate → contract_transfer_room.
20. **Flutter (host_home):** Add "Nhà trọ" entry tab + 2 dashboard widgets (maintenance count, expiring contracts).
21. **Flutter (main):** Add 3 providers to MultiProvider.
22. **Flutter (analyze):** `flutter analyze` → 0 errors.
23. **E2E smoke:** Host creates building → adds 3 rooms → duplicates 1 → sets 1 maintenance → creates contract with 2 roommates (1 primary) → activates → terminates with refund. All steps complete <10 phút.

## Todo list
- [ ] Backend: add 5 models to models.py
- [ ] Backend: alembic 0005 migration with FK + indexes + enums
- [ ] Backend: 4 Pydantic schema files
- [ ] Backend: 4 repository files
- [ ] Backend: room_state_service + contract_service
- [ ] Backend: 4 router files (building/room/contract/tenant)
- [ ] Backend: integrate audit log on contract mutations
- [ ] Backend: 6 test files covering state machine, M:N, transfer, isolation
- [ ] Flutter: add packages
- [ ] Flutter: 4 model files
- [ ] Flutter: 4 repository files
- [ ] Flutter: 3 provider files
- [ ] Flutter: reusable widgets
- [ ] Flutter: 8 screens in property/ sub-module
- [ ] Flutter: host_home integration + dashboard widgets
- [ ] E2E smoke test

## Success criteria (testable)
- AC1 (B1): Host creates building, GET returns building → success in <30s
- AC2 (B4): Set room maintenance, GET returns status='maintenance' with date range
- AC3 (state machine valid): Contract draft→active→expired/terminated only; reverse returns 400
- AC4 (M:N): Contract with 3 tenants creates 3 rows in contract_tenants with 1 is_primary=true
- AC5 (transfer C7): PATCH transfer-room updates contract.room_id, old_room→vacant, new_room→occupied
- AC6 (soft delete): Terminated contract NOT in default GET list; visible with `?include_terminated=true`
- AC7 (audit): Every contract status change creates row in `change_logs` with before/after JSON
- AC8 (isolation): Host A creates building, Host B GET → 0 results; PUT/DELETE returns 403/404
- AC9 (duplicate D5): POST /rooms/{id}/duplicate creates new row with code suffix `_copy`
- AC10 (dashboard): Host with 2 maintenance rooms + 1 contract expiring 25d → dashboard widget counts 2 + 1
- Demo: 10-min flow as above E2E smoke

## Risk assessment
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Repository auto-filter bypassed by direct db.query | 50% | HIGH | Code review enforce; document pattern; lint rule (custom) |
| State machine race condition (2 hosts toggle Room same time) | 10% | LOW | Single host owns building → no concurrent edits expected MVP |
| Composite PK on pivot causes ORM issues | 20% | MED | Use SQLAlchemy ORM relationships test thoroughly |
| Flutter form complexity with N tenants | 30% | MED | flutter_form_builder handles list inputs; test with 5+ tenants |
| Transfer room loses utility accounting | 40% | HIGH | Phase 03 records transfer event; Phase 04 invoice service handles prorate |
| CCCD image upload size large | 30% | LOW | Backend validate file size <5MB, compress in Flutter before upload |

## Security considerations
- All endpoints `require_host` (Phase 02 dep)
- Repository auto-inject host_id; integration test cross-host isolation (extend Phase 02 suite)
- Pydantic schemas validate all input (status enums whitelist, dates non-empty, prices > 0)
- CCCD handover photos go through `cccd_storage` service (0700 perms, audit log)
- Soft delete: terminated contracts retain PII for dispute window — document retention policy

## Next steps
- Unblocks Phase 04 (Invoice/Payment/Meter — builds on Contract)
- Unblocks Phase 05 (KhaiBaoTamTru — needs Tenant)
- Dependencies for next: Contract `monthly_rent` field used by invoice generation
