# Plan — Hoàn thiện màn Lịch sử đặt lịch

**Owner:** ducld
**Started:** 2026-06-28
**Status:** ⏳ Awaiting approval

## Vấn đề

`BookingHistoryScreen` (tab `Đặt lịch` ở footer Guest) đang ở trạng thái mock UI:
- Search field không hoạt động (không controller).
- Nút "Chi tiết" / "Liên hệ host" `onPressed: () {}` rỗng.
- Card không tap được vào detail.
- Không có màn `BookingDetailScreen` để xem message gốc, host info, timeline.
- Tab count badges thiếu.
- Date format ISO khô (`2026-06-28`).
- Không auto refetch khi vào lại screen.
- Rejected/cancelled card dead-end.
- Status `lost` / `locked` không phân biệt rõ trong tab "Hoàn thành".

## Mục tiêu

Biến screen thành workflow hoàn chỉnh: list → detail → action (chat / call / review / re-discover), với search/filter/refetch hoạt động đúng.

## Phases

| Phase | File | Mô tả | Status |
|-------|------|-------|--------|
| 00 | [phase-00-ba-requirements.md](phase-00-ba-requirements.md) | BA Requirements: user stories, AC, scope | ✅ Draft |
| 01 | [phase-01-basic-design.md](phase-01-basic-design.md) | Basic Design: IA, UX flow, screen inventory | ✅ Draft |
| 02 | [phase-02-detailed-design.md](phase-02-detailed-design.md) | Detailed Design: code spec, files & LOC | ✅ Draft |
| 03 | [phase-03-implementation.md](phase-03-implementation.md) | Implementation checklist (10 steps) | ⏸ Pending approval |

## Files Impacted

**Backend (Python):**
- `ancu365-backend/app/helpers.py` (+6 LOC)

**Flutter (Dart):**
- `lib/data/models/viewing_appointment_model.dart` (+6)
- `lib/providers/viewing_appointment_provider.dart` (+8)
- `lib/features/guest/booking/booking_history_screen.dart` (~+120 net)
- `lib/features/guest/booking/booking_detail_screen.dart` (+350, mới)
- `lib/features/guest/booking/widgets/appointment_status_chip.dart` (+60, mới — extract)
- `lib/core/utils/vn_date.dart` (+25, mới)

**Tests:**
- `test/utils/vn_date_test.dart` (mới)
- `test/widgets/booking_history_screen_test.dart` (mới)
- `test/widgets/booking_detail_screen_test.dart` (mới)
- `ancu365-backend/tests/test_viewing_appointments.py` (bổ sung 2 case)

**Total est.:** ~575 LOC added across 9 files.

## Key Dependencies

- `Provider`, `CachedNetworkImage`, `ChatScreen`, `HouseDetailScreen`, `WriteReviewScreen` — đã có.
- `url_launcher` — **không** thêm phase này (dùng Clipboard fallback).
- Backend `Review` model — đã có.

## Risk Summary

| Severity | Risk |
|----------|------|
| LOW | `hostId` null khi host bị xoá → UI guard ẩn nút Chat. |
| LOW | Search dấu tiếng Việt match imperfect — lowercase đơn giản phase này. |
| MEDIUM | `has_reviewed` query mỗi appointment — chỉ trigger khi status=completed. |
| LOW | Card whole-tap nuốt action button — verify thủ công. |

## Out of Scope

- Reschedule flow (đổi ngày giờ).
- iCal export.
- Map view của address.
- Native dialer (tel:) — dùng Clipboard.
- Realtime push refresh — pull-to-refresh là đủ.
- Multi-select bulk cancel.

## Next Step

⏸ **Chờ approval** từ user trước khi vào Phase 03 (implementation).

Khi approve: chạy Step 1 (backend) → Step 2 (model/provider) → Step 3 (helper) → Step 4 (detail screen) → Step 5 (extract chip) → Step 6 (history rewrite) → Step 7 (tests) → Step 8 (QA) → Step 9 (docs) → Step 10 (commit).

Ước lượng: ~2–3 giờ thực thi nếu không gặp blocker.
