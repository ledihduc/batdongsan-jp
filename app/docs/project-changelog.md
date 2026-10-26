# Project Changelog

## 2026-06-28

### feat(homestay): Phase 01h — Postgres EXCLUDE USING gist trên reservations

**Backend (Alembic + Postgres)**
- Migration `0011_reservation_exclude_constraint` — DB-level guard chống
  double-booking dưới true concurrency:
  - `CREATE EXTENSION IF NOT EXISTS btree_gist`
  - `ALTER TABLE reservations ADD CONSTRAINT excl_reservations_room_overlap
     EXCLUDE USING gist (room_id WITH =, daterange(check_in_date::date,
     check_out_date::date, '[)') WITH &&) WHERE status IN
     ('pending','approved','checked_in')`
- Postgres-only (dialect guard ở đầu upgrade/downgrade). SQLite dev DB
  no-op, app-level `find_overlapping` vẫn là guard.
- `reservation_service.py` docstring update — bỏ "Phase 01 will install"
  TODO; giữ app-level overlap check để trả 400 thay vì 500 IntegrityError.
- `0009_homestay_core.py` NOTE comment trỏ sang migration 0011.

**Tests**
- 4 test mới `tests/homestay/test_reservation_exclude_constraint.py` —
  raw SQL INSERT bypass service layer để chứng minh DB reject:
  - reject overlap với pending reservation,
  - reject overlap với approved reservation,
  - allow overlap khi row cũ status=cancelled (predicate skip),
  - allow back-to-back same-day (range bound `[)`).
- Skip cleanly khi không có `SMOKE_DATABASE_URL`.
- Total backend pytest collect: 231 (was 227 + 4 new).

**Plan**
- `plans/260622-0700-host-property-management/phase-01h-postgres-concurrency-hardening.md`
  — phase file scoped 0.5d.

### feat(marketplace-integration): Phase 08 — sync ops ↔ marketplace 1 chiều, draft Contract/Reservation từ booking

**Backend (FastAPI + SQLAlchemy)**
- Alembic `0010_marketplace_integration` thêm cột mới:
  - `houses`: `product_type` ('apartment'|'boarding_house'|'homestay' default
    'apartment'), `source_room_id` (FK rooms UNIQUE ondelete SET NULL),
    `last_synced_at`.
  - `rooms`: `is_listed_on_marketplace` (bool), `marketplace_house_id`
    (FK houses), `is_homestay` (bool).
  - `tenants`: `is_placeholder` (bool), `created_from_booking_type`
    (string30), `created_from_booking_id` (int).
  - `contracts`: `source` ('manual'|'marketplace'|'imported' default 'manual').
- `services/marketplace_sync_service.py` — core logic:
  - `sync_room_to_house()` idempotent upsert dựa trên UNIQUE
    `houses.source_room_id`; ghi đè title/price/images khi sync lại,
    preserve description/address/city/district (tôn trọng manual edits).
  - `unpublish_room()` set House.status='hidden'.
  - `list_sync_status()` trả 5 trạng thái: synced / out_of_sync (lệch giá) /
    not_listed / pending / hidden.
  - `_upsert_placeholder_tenant()` dedupe theo (host_id, phone) — không tạo
    bản trùng SĐT trên cùng host.
  - `create_contract_from_appointment()` — guards cross-host 403, phòng
    đang chiếm 409, yêu cầu Room có `source_room_id` (đã publish).
  - `approve_reservation_from_booking()` — validate `Contract.source` /
    Reservation phải đến từ marketplace, proxy sang
    `reservation_service.approve`.
- `routers/marketplace_integration.py` — 5 endpoints dưới
  `/api/host/marketplace`:
  - `POST /rooms/{room_id}/publish`
  - `POST /rooms/{room_id}/unpublish`
  - `GET /sync-status`
  - `POST /contracts/from-appointment/{appointment_id}`
  - `POST /reservations/{reservation_id}/approve-from-booking`
- `schemas/marketplace.py` — Pydantic v2 request/response (PublishRoomRequest,
  PublishRoomResponse, SyncStatusItem, CreateContractFromApptResponse,
  ApproveReservationFromBookingResponse).
- `main.py` mount router `marketplace_integration`.

**Frontend (Flutter)**
- `data/models/marketplace_sync_model.dart` — `SyncStatusItem` (badge
  getter: 'synced'/'out_of_sync'/'not_listed'), `PublishRoomResult`,
  `CreateContractFromApptResult`.
- `data/repositories/api_marketplace_repository.dart` — 5 method bám sát
  endpoint backend.
- `features/host/marketplace/providers/marketplace_provider.dart` —
  ChangeNotifier với `items`/`isLoading`/`error`/`lastPublish`/`lastContract`
  + methods sync/publish/unpublish/contract/approve.
- `widgets/sync_status_badge.dart` — pill badge 5 trạng thái với màu HD
  (positive/warning/inkMuted/accent/hairline).
- 4 screens HD Editorial Cockpit:
  - `sync_status_screen.dart` — list room kèm badge, nút "Đăng"/"Đồng bộ
    lại"/"Ẩn" + confirm dialog unpublish.
  - `publish_room_screen.dart` — ChoiceChip type picker
    (boarding_house/homestay/apartment với VN labels) + title/desc/price
    override.
  - `create_contract_from_appt_screen.dart` — review yêu cầu xem nhà +
    "SẼ XẢY RA" explainer (4 bullet) + xác nhận tạo HĐ nháp.
  - `create_reservation_from_booking_screen.dart` — review reservation +
    nút duyệt (HD.positive).
- `main.dart` — register `MarketplaceProvider`.
- `host_home_screen.dart` — thêm cặp nút "Homestay" + "Đồng bộ MP" trên
  tab Nhà trọ.

**Tests**
- Backend pytest: 14 test mới trong `tests/marketplace/`, skip cleanly
  khi không có `SMOKE_DATABASE_URL`:
  - `test_sync_room_to_house.py` (3): create House với synced fields,
    homestay product_type derivation, unpublish hides.
  - `test_idempotent_sync.py` (3): chỉ tạo 1 House sau 2 lần sync, đổi
    giá pick-up, re-publish sau unpublish trả pending.
  - `test_create_contract_from_appt.py` (3): draft contract created,
    room occupied → 409, cross-host → 403.
  - `test_placeholder_tenant.py` (2): booking origin recorded, phone
    dedupe.
  - `test_approve_reservation_from_booking.py` (3): approve marketplace
    reservation, source guard 400, cross-host 404.
- Total backend pytest collect: 227 (16 homestay + 14 marketplace +
  foundation/nha-tro/khai-bao/reports).

**Plan**
- `plans/260622-0700-host-property-management/phase-08-marketplace-ops-integration.md`
  — phase plan (5-7d).
- Plan parent đã update status: Phase 02-08 ✅ Done, Phase 01 ⏸ Deferred.

### feat(homestay-core): Phase 07 — calendar/pricing/reservation cho homestay

**Backend (FastAPI + SQLAlchemy)**
- Alembic `0009_homestay_core` thêm bảng:
  - `homestay_calendar` — daily availability/price override per room.
  - `pricing_rules` — base / weekend / holiday / manual override với
    priority resolution.
  - `reservations` — booking ngắn ngày với check_in/check_out, status
    machine (pending/approved/checked_in/checked_out/cancelled/rejected).
- `services/reservation_service.py` — anti-overbooking (Postgres EXCLUDE
  USING gist; SQLite fallback overlap-check trong code), pricing
  resolution priority (manual > holiday > weekend > base), rigid 24h
  cancel policy D10 (>24h refund 100%, 0-24h refund 50%, sau check-in
  0%), check-in/check-out workflow tự auto-create khai báo tạm trú nếu
  guest có CCCD.
- 4 routers homestay (calendar / pricing / reservation / check-in-out)
  dưới `/api/host/homestay`.
- Pydantic v2 schemas đầy đủ.

**Frontend (Flutter)**
- Module `features/host/homestay/` — providers (calendar/pricing/
  reservation), repositories, models, 5 screens chính
  (HomestayHomeScreen, CalendarScreen, PricingRulesScreen,
  ReservationListScreen, ReservationDetailScreen) tuân thủ HD Editorial
  Cockpit tokens.
- Entry point trong tab Nhà trọ qua nút "Homestay" trên
  `host_home_screen.dart`.

**Tests**
- 16 test mới `tests/homestay/` — pricing priority resolution, reservation
  concurrent booking (overlap/adjacent/cancelled), check-in/out workflow,
  state machine guards. Skip cleanly khi không có `SMOKE_DATABASE_URL`.

**Plan**
- `plans/260622-0700-host-property-management/phase-07-homestay-core.md`
  — phase plan (9-11d).

### feat(booking-history): hoàn thiện màn Lịch sử đặt lịch (guest view)

**Frontend (Flutter)**
- Thêm `BookingDetailScreen` — header card với thumbnail/status, schedule
  formatted tiếng Việt, message gốc, host block (chỉ hiện khi
  approved/completed/locked) với CTA Gọi/Nhắn tin, timeline 4 bước.
- Sticky action bar theo từng status: Huỷ (pending), Phone+Chat
  (approved/locked), Đánh giá / Đã đánh giá (completed), Xem nhà khác
  (rejected/cancelled/lost).
- Rewrite `BookingHistoryScreen`:
  - Search field debounced 300ms, lọc theo title + address.
  - Badge counts cạnh tên tab.
  - Sub-filter chip strip cho tab Hoàn thành (all / completed / locked /
    cancelled / rejected / lost).
  - Card tap toàn bộ → mở detail screen.
  - Empty state có 2 variant (no items vs search no match).
  - Auto-refetch khi list stale > 60s (kết hợp RefreshIndicator).
- Extract `AppointmentStatusChip` (`widgets/appointment_status_chip.dart`)
  — shared giữa card list và detail header, có hai size normal/large.
- Helper format ngày tiếng Việt: `lib/core/utils/vn_date.dart` —
  `formatVnDate('2026-06-28')` → `"Chủ nhật, 28/06/2026"`.

**Backend (FastAPI)**
- `helpers.viewing_appointment_to_dict` trả thêm `host_id` (lấy từ
  `house.host_id`) và `has_reviewed` (chỉ query Review khi
  `status == 'completed'` để tránh N+1).

**State management**
- `ViewingAppointmentProvider` thêm `isStale(maxAgeSeconds)` + nhớ
  `_lastFetchAt` để chống double-fetch giữa AuthWrapper hydrate và
  `BookingHistoryScreen.initState`.

**Model**
- `ViewingAppointmentModel` thêm field `hostId` (int?) và `hasReviewed`
  (bool, default false).

**Tests**
- Flutter: 9 test `vn_date_test.dart`, 9 test `appointment_status_chip_test.dart`.
- Backend pytest: 10 test `test_viewing_appointment_helper.py` (host_id
  derivation, has_reviewed gating theo status, skip query cho non-completed).

**Plan**
- `plans/260628-1500-booking-history-completion/` — BA requirements,
  basic + detailed design, 10-step implementation checklist.
