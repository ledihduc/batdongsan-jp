# Phase 08 Code Review — Accessibility Polish

**Reviewer:** code-reviewer (staff engineer, read-only)
**Date:** 2026-07-02
**Verdict:** **CONDITIONAL** — 1 MEDIUM orthography fix + 1 LOW consistency note. No blocking issues.

## Scope

- 20 IconButton tooltips + 7 Semantics wrappers around `CachedNetworkImage`
- 16 files (14 tracked-modified, 2 untracked/moved: `host/profile/my_listings_screen.dart`, `host/analytics/screens/analytics_filters_bar.dart`)
- Behaviour-only surface: tooltip strings + Semantic labels; no state/logic mutation

## Verification counts

| Item | Expected | Found | OK |
|---|---|---|---|
| Tooltip additions (tracked diff) | ~17 | 19 | yes |
| Tooltips in new files (my_listings, filters_bar) | 5 | 5 | yes |
| Semantics(child: CachedNetworkImage) wrappers | 7 | 7 | yes |
| Wrong param (`semanticsLabel:` on CNI) | 0 | 0 | yes |
| English tooltips leaked | 0 | 0 | yes |

All tooltips reviewed match icon action: `Icons.refresh`→"Làm mới"/"Đặt lại", `Icons.chevron_left/right`→"Tháng trước/sau" or "Kỳ trước/sau", `Icons.close`→"Xóa tìm kiếm", `Icons.visibility(_off)`→"Hiện/Ẩn mật khẩu", etc.

## Findings

### MEDIUM — Orthography drift ("Xoá" vs "Xóa")

`lib/features/host/profile/my_listings_screen.dart:190`

```dart
tooltip: 'Xoá tin',
```

Phase 06 glossary mandates 1999 orthography (`hủy` not `huỷ`). By the same rule, prefer `Xóa` over `Xoá`. All other tooltips in this phase (booking_history, guest_home) already use `Xóa tìm kiếm`. This is the only inconsistent instance in Phase 08's diff. Guest booking screens even converted `Huỷ` → `Hủy` in the same commit, so the drift is isolated.

**Fix:** `tooltip: 'Xóa tin'` (1 char change).

### LOW — Placeholder branch skipped in Semantics wrappers

`lib/features/host/dashboard/widgets/hd_listing_row.dart`, `lib/features/host/profile/my_listings_screen.dart`, `lib/features/guest/wishlist/wishlist_screen.dart`

Semantics only wraps the `image != null` / `images.isNotEmpty` branch. The placeholder icon branch has no label — screen readers announce nothing for listings with no photo. Not a regression (pre-existing behaviour), but the phase intent was "image has semantic label" universally. Consider wrapping the ternary as a whole with a fallback label (`h.title`), or moving Semantics up one level.

### LOW — `label: label` when null

`hd_listing_row.dart` `_Thumbnail({this.label})` may pass `null` — Flutter accepts `Semantics(label: null)` as no-op, so no crash. Behaviour matches placeholder-branch note above. No action required.

## Positive observations

- Semantic labels are content-aware: `house.title`, `${house.title} — ảnh ${index + 1}` for carousel, `appointment.houseTitle ?? 'Ảnh phòng'` with null fallback (`houseTitle` is `String?` on `ViewingAppointmentModel`, so fallback is correct)
- Analytics filters bar uses period-appropriate terms ("Kỳ trước/sau") vs calendar screens ("Tháng trước/sau") — good copy discrimination
- Password visibility tooltip is state-aware: `_obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu'`
- No duplicate tooltips added where one existed (Chặn lịch in room_calendar retained)
- No behaviour change, no widget tree restructuring beyond wrapping
- Booking screens also bundled Phase 06 orthography fixes (`Huỷ`→`Hủy`) alongside a11y — appropriate coupling

## Not reviewed (out of scope)

- `occupancy_heatmap_screen.dart` Phase 07 modularization split (extracted `HeatmapErrorView`, `HeatmapGroupView`, `HeatmapGridView`, `HeatmapLegend`) is present in diff but explicitly excluded per review brief
- Design tokens, empty state, contract form, list-state pattern (Phase 05a/05b/07)

## Recommended actions

1. Fix `my_listings_screen.dart:190` → `'Xóa tin'` (MEDIUM, 1 line)
2. (Optional) Widen Semantics scope to cover placeholder branches for listing thumbnails (LOW, 3 files)

## Unresolved questions

- None. Phase 08 diff is self-consistent; the two findings are strictly copy-level.
