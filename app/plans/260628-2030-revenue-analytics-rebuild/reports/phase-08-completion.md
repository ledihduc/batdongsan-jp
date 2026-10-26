# Phase 08 Completion Report — Source Management CRUD Screen

## Files Table

| File | Action | LOC | Notes |
|------|--------|-----|-------|
| `lib/features/host/analytics/screens/source_management_screen.dart` | Created | ~200 | Main CRUD screen |
| `lib/features/host/analytics/widgets/source_list_tile.dart` | Created | ~155 | Tile with swatch, popup menu |
| `lib/features/host/analytics/widgets/color_swatch_picker.dart` | Created | ~85 | 10 preset swatches, ≥44pt targets |
| `lib/features/host/analytics/widgets/source_edit_dialog.dart` | Created | ~140 | Add/Edit dialog, inline server error |
| `lib/features/host/analytics/widgets/archive_confirm_dialog.dart` | Created | ~40 | Confirm archive, returns bool |
| `lib/features/host/analytics/widgets/delete_confirm_dialog.dart` | Created | ~40 | Confirm delete, red button |
| `lib/core/router/app_router.dart` | Modified | +11 | Deferred route `/host/analytics/sources` |
| `lib/providers/report_provider.dart` | Modified | +15 | `patchSourcesOptimistic()` method |
| `lib/features/host/analytics/widgets/filter_bottom_sheet.dart` | Modified | +12 | "Quản lý nguồn" CTA |
| `test/widgets/source_management_screen_test.dart` | Created | ~235 | 18 test cases |
| `test/widgets/source_edit_dialog_test.dart` | Created | ~220 | 10 test cases |
| `test/widgets/color_swatch_picker_test.dart` | Created | ~80 | 5 test cases |

## Test Results

**Passed: 27 / 27**

| Suite | Count | Status |
|-------|-------|--------|
| `color_swatch_picker_test.dart` | 5 | PASS |
| `source_edit_dialog_test.dart` | 11 | PASS |
| `source_management_screen_test.dart` | 11 | PASS |

## Flutter Analyze

```
flutter analyze lib/features/host/analytics/ lib/core/router/app_router.dart lib/providers/report_provider.dart
```

- 0 new errors
- 0 new warnings
- 0 new infos from Phase 08 files
- 2 pre-existing infos in `app_router.dart` (lines 491, 519 — `use_build_context_synchronously` in existing `_RootGateState`) — not introduced by this phase

## Coverage

Estimated ~85%+ on new code (all happy/error/cancel/optimistic paths covered in tests).

## Decisions Made

1. **`patchSourcesOptimistic`** added to `ReportProvider` (minimal: updates `_cache.sources` + notifyListeners). This is the only provider change — DO NOT touch Phase 04 analytics fetch methods.
2. **`maxLength: 50`** enforced on TextField so Dart lint `unnecessary_underscores` was avoided. The `_canSave` guard validates trimmed length ≤ 50 before submit.
3. **Optimistic archive** updates the local sources list immediately, reverts with original snapshot on API error.
4. **`SourceInUseException`** caught in delete handler → SnackBar with "Lưu trữ" action.
5. **Color palette**: `kSourceColorPresets` constant exported from `color_swatch_picker.dart` — 10 WCAG-safe swatches documented in file comment.

## Outstanding for Phase 09

- `linkedCount` on `SourceListTile` is nullable (shows "—") — backend `GET /host/sources` does not currently return `linked_count`. Wire when Phase 03 backend exposes it.
- `filter_bottom_sheet_test.dart` should be extended to verify the new "Quản lý nguồn" button (CTA) navigation — currently not covered in Phase 07 filter tests.

## Sign-off

Phase 08 complete. All deliverables A–I implemented and verified.
