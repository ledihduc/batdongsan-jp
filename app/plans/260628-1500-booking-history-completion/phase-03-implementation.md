# Phase 03 — Implementation Tasks (sequential checklist)

## Pre-requisites

- [x] Backend running with SQLite seed data.
- [x] Flutter web dev server on `:5555`.
- [x] Test user có ≥ 3 appointments với các status khác nhau.

---

## Step 1 — Backend `host_id` + `has_reviewed`

**File:** `ancu365-backend/app/helpers.py`

- [x] 1.1 Import `Review` model (đầu file).
- [x] 1.2 Sửa `viewing_appointment_to_dict`:
  - Thêm `"host_id": house.host_id if house else None` ngay sau `"house_id"`.
  - Thêm `"has_reviewed": has_reviewed` ở cuối dict.
  - Compute `has_reviewed` chỉ khi `b.status == "completed"` (tránh N+1).
- [x] 1.3 Restart backend, curl smoke test:
  ```
  curl -H "Authorization: Bearer $JWT" "http://localhost:3000/api/viewing-appointments?role=guest" \
    | jq '.bookings[0] | {host_id, has_reviewed}'
  ```
- [x] 1.4 Verify cả 2 field xuất hiện.

**Acceptance:** response JSON có `host_id` ≠ null cho tất cả appointment có house tồn tại.

---

## Step 2 — Flutter model + provider

**Files:**
- `lib/data/models/viewing_appointment_model.dart`
- `lib/providers/viewing_appointment_provider.dart`

- [x] 2.1 Thêm field `hostId` (int?) và `hasReviewed` (bool, default false) vào `ViewingAppointmentModel`.
- [x] 2.2 Update `fromMap` đọc 2 field mới.
- [x] 2.3 Thêm `DateTime? _lastFetchAt` private + `isStale(maxAgeSeconds:int)` method vào provider.
- [x] 2.4 Gán `_lastFetchAt = DateTime.now()` ở cuối `fetchAppointments`.
- [x] 2.5 `flutter analyze` → 0 new error.

**Acceptance:** Tap refresh trong booking history → `appointment.hostId` đọc được trong debugger.

---

## Step 3 — Date format helper

**File:** `lib/core/utils/vn_date.dart` (mới)

- [x] 3.1 Tạo file, copy snippet từ Phase 02 §6.
- [x] 3.2 Tạo `test/utils/vn_date_test.dart` với 5 unit test theo Phase 02 §9.1.
- [x] 3.3 `flutter test test/utils/vn_date_test.dart` → all pass.

**Acceptance:** `formatVnDate('2026-06-28')` → `"Chủ nhật, 28/06/2026"` (verify weekday đúng).

---

## Step 4 — `BookingDetailScreen` (mới)

**File:** `lib/features/guest/booking/booking_detail_screen.dart` (mới)

- [x] 4.1 Tạo skeleton StatelessWidget với `appointment` param.
- [x] 4.2 Implement `_HeaderCard` — thumbnail + title + address + status chip lớn (reuse `_buildStatusChip` từ BookingHistoryScreen, hoặc extract sang shared widget — đề xuất extract).
- [x] 4.3 Implement `_ScheduleSection` dùng `formatVnDate` + `formatVnDateTime`.
- [x] 4.4 Implement `_MessageSection` — italic quote box. Empty message → "Không có lời nhắn".
- [x] 4.5 Implement `_HostSection` — chỉ render khi status ∈ {approved, completed, locked}. Avatar + name + phone (tap → copy + SnackBar) + nút "Nhắn tin" mở ChatScreen.
- [x] 4.6 Implement `_TimelineSection` — vertical timeline 4 bước (Tạo / Duyệt / Hoàn thành / Chốt) với check icon cho bước đã qua.
- [x] 4.7 Implement `_StickyActionBar` — switch theo status (theo Phase 02 §3.2).
- [x] 4.8 Wiring:
  - Huỷ → confirm dialog → `provider.updateStatus('cancelled')` → pop back.
  - Gọi → `Clipboard.setData` + SnackBar.
  - Chat → `Navigator.push(ChatScreen(peerId: hostId!, peerName: hostName ?? '', houseId: houseId))`.
  - Đánh giá → push `WriteReviewScreen`.
  - Xem nhà khác → push `HouseDetailScreen(houseId)`. Catch 404 → SnackBar.

**Acceptance:** Mở detail từ card → render đầy đủ, tất cả CTA hoạt động, back về list không crash.

---

## Step 5 — Extract `_AppointmentStatusChip` shared widget

**File:** `lib/features/guest/booking/widgets/appointment_status_chip.dart` (mới)

- [x] 5.1 Extract `_buildStatusChip(String status)` từ BookingHistoryScreen sang StatelessWidget riêng.
- [x] 5.2 Param: `status` + optional `size` (default normal, có thể `large` cho detail screen).
- [x] 5.3 Update import ở 2 nơi sử dụng.

**Acceptance:** Visual identical sau extract; analyzer 0 new errors.

---

## Step 6 — `BookingHistoryScreen` cải tổ

**File:** `lib/features/guest/booking/booking_history_screen.dart`

- [x] 6.1 Thêm state: `_completedSubFilter`, `_searchCtrl`, `_searchQuery`, `_searchDebounce`.
- [x] 6.2 `initState`: addListener cho `_searchCtrl` + post-frame `_refetchIfStale`.
- [x] 6.3 `dispose`: cancel debounce + dispose controller.
- [x] 6.4 Implement `_refetchIfStale` (gọi provider.isStale).
- [x] 6.5 Implement `_filtered` getter + `_counts` helper.
- [x] 6.6 Update `_buildTabButton` để nhận count, hiển thị `(N)` khi N>0.
- [x] 6.7 Wire search field: thêm controller, prefix icon search, suffix clear button conditional.
- [x] 6.8 Conditional render sub-filter strip khi `_activeTab == 'completed'`.
- [x] 6.9 Wrap card trong `InkWell` mở BookingDetailScreen.
- [x] 6.10 Update card content:
  - Thêm address line (Text 1-line ellipsis dưới title).
  - Date format dùng `formatVnDate(_, withWeekday: false)`.
- [x] 6.11 Update `_buildActionButtons`:
  - pending: bỏ button "Chi tiết" (whole-card tap rồi).
  - approved: thay button "Liên hệ host" → 2 IconButton Phone + Chat.
  - completed: check `hasReviewed`, ẩn nếu true.
  - rejected/cancelled/lost: thêm outline button "Xem nhà khác".
- [x] 6.12 Update empty state — 2 variants (no items vs search no match).

**Acceptance:**
- Type vào search field → 300ms sau list filter.
- Tap tab → counts hiển thị đúng.
- Tap card → mở detail.
- Tap "Chat" → mở ChatScreen với đúng peer.
- All flutter analyze warnings từ trước vẫn pre-existing, không có error mới.

---

## Step 7 — Tests

- [x] 7.1 Unit test `_filtered` (extract logic sang testable function nếu cần).
- [x] 7.2 Widget test cho BookingHistoryScreen — render với mock provider, verify tab switch + search.
- [x] 7.3 Widget test cho BookingDetailScreen — verify từng status render đúng CTA.
- [x] 7.4 Backend pytest cho `viewing_appointment_to_dict` mới.

**Acceptance:** `flutter test` + `pytest` all pass.

---

## Step 8 — Manual QA Smoke

- [ ] 8.1 Login as guest có sẵn appointments mock.
- [ ] 8.2 Verify tab counts đúng.
- [ ] 8.3 Search "biển" → chỉ nhà có chữ "biển" hiện.
- [ ] 8.4 Cancel 1 pending → di chuyển sang Hoàn thành tab.
- [ ] 8.5 Tap card approved → BookingDetailScreen → tap Chat → ChatScreen mở đúng host.
- [ ] 8.6 Switch sub-filter "Hoàn thành" → list filter.
- [ ] 8.7 Tap "Xem nhà khác" trên rejected → HouseDetailScreen mở.
- [ ] 8.8 Login as host trên tab khác → approve appointment → switch về guest → pull-to-refresh → status updated.

**Acceptance:** Tất cả 8 smoke pass không crash, không lỗi console.

---

## Step 9 — Docs sync

- [x] 9.1 Update `docs/codebase-summary.md` (nếu có) — add note về `BookingDetailScreen`.
- [x] 9.2 Add entry vào `docs/project-changelog.md`:
  ```
  ## 2026-06-28
  - feat(booking): hoàn thiện màn Lịch sử đặt lịch — detail screen, search,
    badge counts, status sub-filter, recovery CTA.
  ```

---

## Step 10 — Commit & PR

- [x] 10.1 `git add` các file thay đổi.
- [x] 10.2 Commit message:
  ```
  feat(booking-history): complete guest viewing-appointment workflow

  - Add BookingDetailScreen với chat/call/review CTA
  - Wire search filter + tab badge counts + completed sub-filter
  - Add host_id + has_reviewed to backend response
  - Vietnamese date format helper
  - Recovery CTA cho status rejected/cancelled/lost
  ```
- [ ] 10.3 Push & let user QA.

---

## Risk Mitigation Notes

| Risk | Mitigation |
|------|-----------|
| `hostId` null khi host bị xoá | UI guard: nếu null, ẩn nút Chat/Gọi. |
| `Review` import cycle | Verify import path đúng `app.models.Review`. |
| `_searchDebounce` leak | dispose cancel — đã có ở Step 6.3. |
| Backend `has_reviewed` query mỗi appointment | Chỉ trigger khi status='completed' → N nhỏ. |
| Card whole-tap nuốt action button | ElevatedButton consume gesture trước InkWell — verify thủ công. |
| Pull-to-refresh + auto-refetch double-fetch | `isStale(60)` guard. |
