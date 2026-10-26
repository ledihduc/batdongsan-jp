# Phase 08 — Accessibility + Polish Report

**Date:** 2026-07-03
**Status:** DONE

## Files Modified

| File | Change |
|------|--------|
| `lib/features/host/billing/screens/invoice_list_screen.dart` | tooltip: 'Tạo hàng loạt' on add_box_outlined |
| `lib/features/host/billing/screens/meter_reading_screen.dart` | tooltip: 'Thêm' on add |
| `lib/features/host/homestay/screens/room_calendar_screen.dart` | tooltip: 'Tháng trước/sau' on chevron_left/right |
| `lib/features/host/homestay/screens/unified_calendar_screen.dart` | tooltip: 'Tháng trước/sau' on chevron_left/right |
| `lib/features/host/profile/my_listings_screen.dart` | tooltip: 'Làm mới' + Semantics(label: h.title) on CachedNetworkImage |
| `lib/features/host/analytics/screens/occupancy_heatmap_screen.dart` | tooltip: 'Tháng trước/sau' on chevron_left/right |
| `lib/features/host/analytics/screens/analytics_filters_bar.dart` | tooltip: 'Kỳ trước/sau' on chevron_left/right |
| `lib/features/host/analytics/widgets/reauth_modal.dart` | tooltip: 'Hiện/Ẩn mật khẩu' on visibility toggle |
| `lib/features/host/dashboard/widgets/hd_listing_row.dart` | Semantics(label: house.title) on CachedNetworkImage; added label param to _Thumbnail |
| `lib/features/guest/home/advanced_filter_screen.dart` | tooltip: 'Quay lại' + 'Đặt lại' |
| `lib/features/guest/home/guest_home_screen.dart` | tooltip: 'Tin nhắn', 'Thông báo', 'Xóa tìm kiếm'; Semantics on house card image |
| `lib/features/guest/booking/booking_history_screen.dart` | tooltip: 'Xóa tìm kiếm'; Semantics on house thumbnail |
| `lib/features/guest/booking/booking_detail_screen.dart` | Semantics on house hero image |
| `lib/features/guest/review/write_review_screen.dart` | tooltip: '${star} sao' on star rating buttons |
| `lib/features/guest/wishlist/wishlist_screen.dart` | tooltip: 'Bỏ yêu thích'; Semantics on house thumbnail |
| `lib/features/guest/house_detail/house_detail_screen.dart` | tooltip: 'Quay lại', 'Chia sẻ'; Semantics on carousel images |

## Task Summary

- **IconButton tooltips added:** 20 (across 14 files, 16 distinct files total)
- **CachedNetworkImage semantics added:** 7 files (all via `Semantics(label:, child: CachedNetworkImage(...))` — CachedNetworkImage v3.4.1 has no `semanticsLabel` param)
- **design_tokens.dart guard comment:** Already present (`⚠️ Do NOT pair inkMuted with paperSunken`) — no change needed
- **docs/accessibility-checklist.md:** Already exists with full WCAG AA content — no change needed

## Analyze Summary

`dart analyze lib/` — **0 errors, 0 warnings, 204 info-level** (all pre-existing, unrelated to this phase; pre-edit count was 211 errors including 7 error-level issues introduced by incorrect `semanticsLabel` param; all 7 resolved by switching to `Semantics()` wrapper).

## Notes

- `CachedNetworkImage` v3.4.1 does not expose `semanticsLabel` — used `Semantics(label:, child:)` wrapper per accessibility-checklist guidance.
- No new colors, tokens, or widgets introduced.
- All tooltip strings are Vietnamese matching the action.
- Stayed within 20-file cap (16 files touched).
