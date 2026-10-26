# P07 Execution Report — Admin Risky Listings + User Report Error Form

**Date:** 2026-06-21
**Phase:** 07 — Admin Risky Listings Screen + User Report Form (US-06, US-08)
**Status:** DONE

---

## Files Modified

| File | Action | Lines |
|------|--------|-------|
| `lib/data/models/risky_house_model.dart` | CREATED | 33 |
| `lib/data/services/planning_service.dart` | MODIFIED | +35 lines (getRiskyHouses, reportParcelError) |
| `lib/features/admin/planning/risky_listings_screen.dart` | CREATED | 151 |
| `lib/features/admin/admin_home_screen.dart` | MODIFIED | +22 lines (import + _planningTile) |
| `lib/features/planning/report/report_error_screen.dart` | CREATED | 162 |
| `lib/features/planning/widgets/parcel_detail_sheet.dart` | MODIFIED | import + _onReport impl |
| `lib/features/planning/widgets/planning_warning_modal.dart` | MODIFIED | import + report TextButton in actions |

---

## Tasks Completed

- [x] Model `RiskyHouse` with `fromJson` factory
- [x] `getRiskyHouses()` — typed, handles `{items:[...]}` or flat list, 403 → PlanningApiException
- [x] `reportParcelError({parcelId, reason, imageUrl})` — named-param convenience wrapper; backward-compat `reportError(ParcelReport)` retained
- [x] `_planningTile()` in `admin_home_screen.dart` — warning_amber icon, amber-50 background, pushes RiskyListingsScreen
- [x] `RiskyListingsScreen` — FutureBuilder + RefreshIndicator, loading/error/empty/populated states, 403 shows "Bạn không có quyền truy cập"
- [x] `ReportErrorScreen` — multiline reason (min 10, max 500), camera image picker, 5MB size check, upload via `ApiClient.uploadImage`, submit via `reportParcelError`
- [x] Wired button in `parcel_detail_sheet.dart` — replaced Snackbar placeholder with `Navigator.push(ReportErrorScreen)`
- [x] Wired link in `planning_warning_modal.dart` — "Báo cáo nếu thông tin sai" TextButton in actions, only shows when `_parcel != null`
- [x] i18n: const VI strings with `// TODO(i18n)` markers throughout

---

## image_picker Addition

`image_picker: ^1.1.2` was ALREADY in pubspec.yaml (used by `post_house_screen.dart` and `edit_profile_screen.dart`). No pubspec change needed; no `flutter pub get` required.

---

## Admin Tile Insertion

Inserted `_planningTile()` call between `_statsBar()` and `Expanded(TabBarView)` in `AdminHomeScreen.build()`. Method added at line ~146, after `_statsBar()` and before `_statChip()`.

---

## Key Decisions

1. **`reportParcelError` vs overload** — Dart doesn't support method overloading. Kept `reportError(ParcelReport)` for backward-compat; added `reportParcelError({parcelId, reason, imageUrl})` as named-param convenience wrapper. `ReportErrorScreen` calls `reportParcelError`.

2. **Image upload** — Used existing `ApiClient.uploadImage(bytes, filename)` (base64 upload). Instantiated `const ApiClient()` locally, same pattern as `PostHouseScreen`. Size check before upload: `bytes.length > 5*1024*1024` → SnackBar error, no upload.

3. **PlanningService injection** — Local instantiation (`final _service = PlanningService()`), consistent with `PlanningWarningModal` pattern. PlanningService is not registered in global Provider tree.

4. **House detail navigation** — `HouseDetailScreen(houseId: h.id)` via `MaterialPageRoute`. No named route `/house-detail` found in main.dart.

5. **Warning modal report link** — `Navigator.of(context).pop()` first (close dialog), then `Navigator.of(context).push(...)`. Uses `context` captured at `build` time — safe because modal is disposed before push.

---

## Validation

```
flutter analyze --no-fatal-infos \
  lib/features/admin/planning/risky_listings_screen.dart \
  lib/features/planning/report/report_error_screen.dart \
  lib/features/planning/widgets/parcel_detail_sheet.dart \
  lib/features/planning/widgets/planning_warning_modal.dart \
  lib/data/services/planning_service.dart \
  lib/data/models/risky_house_model.dart
→ No issues found.
```

`admin_home_screen.dart` analyze: 4 pre-existing infos (deprecated `withOpacity`, `unnecessary_underscores` in separatorBuilder callbacks) — none introduced by P07.

---

## Deferred (as instructed)

- Live curl test (Docker down)
- Device smoke test
- E2E admin role login (P08 manual QA)
- DB row verification

---

## Open Questions

1. **Backend response shape** — `getRiskyHouses()` handles both `{items:[...]}` and flat `[...]`. Confirm which shape backend actually returns so dead branch can be removed in P08.
2. **Navigator context after dialog pop** — When modal pops then pushes `ReportErrorScreen`, the push uses the original `context` from the modal's `build` method. If `PlanningCheckButton`'s parent widget is disposed before pop completes (edge case), the push may target a detached navigator. Acceptable risk for now; add `if (context.mounted)` guard in P08 if needed.
3. **Camera-only vs gallery** — `ReportErrorScreen` currently uses `ImageSource.camera` only (per plan). If UX review wants gallery option, needs separate ticket.

---

**Status:** DONE
**Summary:** 3 new files created, 4 files modified. Zero analyzer errors in new/modified code. image_picker was pre-existing in pubspec. Admin tile added above tab content. Report button wired in both parcel detail sheet and warning modal.
**Concerns:** None blocking.
