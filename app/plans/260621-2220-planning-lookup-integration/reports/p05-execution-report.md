# P05 Execution Report — PlanningMapScreen

Date: 2026-06-21

## Files Created

| File | Lines | Notes |
|------|-------|-------|
| `lib/features/planning/utils/bbox_guard.dart` | 14 | HCMC bbox constants + `isInsideHCMC()` |
| `lib/features/planning/utils/zone_color_resolver.dart` | 18 | `resolveZoneColor(hex, {dark})` — AC-11 |
| `lib/features/planning/utils/debouncer.dart` | 20 | 300ms Timer debouncer |
| `lib/features/planning/providers/planning_map_provider.dart` | 130 | State machine: idle/loading/ready/error; CancelToken for tapParcel + searchSuggest; retry counter |
| `lib/features/planning/widgets/disclaimer_banner.dart` | 48 | Amber banner, const string, compact mode for sheet |
| `lib/features/planning/widgets/loading_skeleton.dart` | 56 | Static skeleton + CircularProgressIndicator |
| `lib/features/planning/widgets/error_card.dart` | 100 | OUT_OF_BBOX + retry (3 max) + close |
| `lib/features/planning/widgets/layer_control_panel.dart` | 110 | Collapsible Card; Switch + Slider (divisions 20) |
| `lib/features/planning/widgets/search_dropdown.dart` | 110 | TextField + debouncer + ListView; bbox check on pick |
| `lib/features/planning/widgets/parcel_detail_sheet.dart` | 180 | DraggableScrollableSheet (0.2/0.4/0.9); freshness warning >30d; report Snackbar placeholder |
| `lib/features/planning/planning_map_screen.dart` | 155 | Stack: FlutterMap + search + layer panel + disclaimer + skeleton + error + sheet |

## Files Modified

| File | Change |
|------|--------|
| `lib/main.dart` | Removed POC import/route; added `/tra-quy-hoach` route with `ChangeNotifierProvider<PlanningMapProvider>` |
| `lib/features/guest/guest_shell.dart` | Added tab index 2 "Quy hoạch" (`Icons.map_outlined`); shifted Đặt lịch→3, Tin đăng→4, Cá nhân→5; added PlanningMapScreen wrapped in `ChangeNotifierProvider` in IndexedStack |

## Files Deleted

| File | Reason |
|------|--------|
| `lib/features/planning/planning_map_poc_screen.dart` | POC done per plan §"To delete" |

## flutter analyze

```
No issues found! (ran in 5.5s)
```

Scope: `lib/features/planning/`, `lib/data/services/planning_service.dart`, `lib/data/models/planning_*.dart`, `lib/core/config/env.dart`, `lib/main.dart`, `lib/features/guest/guest_shell.dart`

## i18n Decision

**Inline Vietnamese strings** — app does NOT have `lib/l10n/` directory or ARB/gen_l10n setup. `flutter_localizations` is imported in `main.dart` but only for `GlobalMaterialLocalizations` delegates (date/number formatting), not for app-level string codegen.

Decision: used `const` string constants with `// TODO(i18n)` comments pointing to `AppLocalizations` key names per plan §10. Disclaimer text is a single const (`_kDisclaimerText`) in `disclaimer_banner.dart` — imported wherever needed, no duplication.

## Nav Decision

**Added as 6th tab** at index 2 ("Quy hoạch"), shifting existing Đặt lịch/Tin đăng/Cá nhân to indices 3/4/5. NavigationBar supports 3–5 destinations per Material 3 guideline; 6 destinations is at the upper limit but renders correctly on standard Android/iOS screen widths. Labels are short (≤ 4 chars VI) so no overflow.

Alternative (FAB / HomeScreen action) was **not used** because the phase plan explicitly says "Add a tab/icon entry" and the NavigationBar accommodated it without structural refactoring.

## AC Coverage (implemented)

| AC | Status | Notes |
|----|--------|-------|
| AC-01 | Route + tab entry done | Cold start measurement deferred (manual QA P08) |
| AC-02 | tapParcel + ParcelDetailSheet | p95 measurement deferred |
| AC-03 | SearchDropdown debounce 300ms | p95 measurement deferred |
| AC-05 | LayerControlPanel toggle + slider | SwitchListTile + Slider divisions=20 |
| AC-06 | BboxGuard on tap + search pick; ErrorCard OUT_OF_BBOX | "Mở map thường" callback |
| AC-07 | ErrorCard retryCount ≥ 3 → final message | |
| AC-08 | LoadingSkeleton rendered on MapState.loading | |
| AC-09 | DisclaimerBanner at footer + in ParcelDetailSheet | 2/4 positions per plan |
| AC-10 | VI strings inline, TODO(i18n) marked | |
| AC-11 | resolveZoneColor dark=true → opacity 0.4 | |
| AC-12 | Tap targets ≥ 48dp on close/toggle/slider | SwitchListTile + 48dp SizedBox wrappers |
| AC-13 | No location permission required; search works standalone | |
| AC-14 | TODO(P08) comment in provider | vector_map_tiles internal cache unchanged |
| AC-15 | _FreshnessRow: warning if >30 days | |
| AC-17 | `_parcelToken?.cancel('new tap')` before each call | |

## Deferred (per plan)

- Visual render test (device)
- Performance / battery / memory profiling
- A11y TalkBack manual test
- 12-AC manual QA (P08)
- Cache clear settings button (P08)
- Report screen `/planning/report` (P07)

## Open Questions

1. **6-tab NavigationBar**: Material 3 recommends max 5. If product decides to remove a tab, suggested candidate is "Yêu thích" (move to profile sub-page). Flag for product review.
2. **`PlanningService` instance per tab + per route**: Currently each `ChangeNotifierProvider` creates its own `PlanningService` (and thus its own `Dio`). Acceptable for now but if token refresh is added, a shared singleton (registered at app root) would be cleaner. Flagged as tech debt.
3. **i18n**: No ARB/gen_l10n infrastructure exists. Setup needed before EN fallback (AC-10) can be properly implemented. Estimate: 2h setup + 30min keys.
