# P06 Execution Report — House Detail Badge + Post-House Warning

**Date:** 2026-06-21
**Phase:** 06 — Tích hợp Planning vào House Detail + Post House

---

## Files Created

| File | Lines | Notes |
|------|-------|-------|
| `lib/features/planning/utils/risky_zone_codes.dart` | 21 | Const Set + isRisky() helper |
| `lib/features/planning/analytics/planning_events.dart` | 40 | Stub analytics, debugPrint only |
| `lib/features/planning/widgets/planning_badge.dart` | 95 | StatefulWidget, async fetch, fail-silent |
| `lib/features/planning/widgets/planning_warning_modal.dart` | 130 | StatefulWidget, risky/normal/loading/error states |
| `lib/features/planning/widgets/planning_check_button.dart` | 50 | Stateless, disabled when no coords |

## Files Modified

| File | Change |
|------|--------|
| `lib/features/guest/house_detail/house_detail_screen.dart` | Added `planning_badge.dart` import + `PlanningBadge` widget below address block (null-safe guard lat/lng != null && != 0) |
| `lib/features/guest/post/post_house_screen.dart` | Added `planning_check_button.dart` import + `_lat`/`_lng` nullable state fields + `PlanningCheckButton` widget below district/city row |
| `lib/features/planning/planning_map_screen.dart` | Added `houseMarker: bool` param + `MarkerLayer` with red home pin when houseMarker == true |
| `lib/main.dart` | Added `latlong2` import + refactored `/tra-quy-hoach` route to read `ModalRoute.settings.arguments` and pass `initialCenter`/`houseMarker` to PlanningMapScreen |

---

## D4 Confirmation (CRITICAL)

**D4 rule: Risky zone warning NEVER blocks submit. VERIFIED.**

- File: `lib/features/guest/post/post_house_screen.dart`
- **Line 447:** `onPressed: _isSubmitting ? null : _submit`
- Submit button is disabled ONLY when `_isSubmitting == true` (upload in progress)
- Zero reference to `_lat`, `_lng`, `_planningWarning`, or any planning state in submit condition
- `PlanningCheckButton` is a standalone widget — its internal state never propagates to form submit

---

## Tasks Completed

- [x] `RiskyZoneCodes` constant (4 codes: DGT, CXP, DCC, DXH)
- [x] `PlanningBadge` widget (async load + fail-silent + tap → map)
- [x] Insert badge vào `house_detail_screen.dart` (null-safe lat/lng guard)
- [x] `PlanningCheckButton` widget (disabled tooltip khi no coords)
- [x] `PlanningWarningModal` widget (risky → amber banner + analytics once)
- [x] Insert button vào `post_house_screen.dart`
- [x] Verify submit KHÔNG bị disable (D4) — confirmed line 447
- [x] `PlanningAnalytics` stub (debugPrint, FIXME comment Q5)
- [x] Route `/tra-quy-hoach` accept args với initialCenter + houseMarker
- [x] `houseMarker` param + MarkerLayer added to PlanningMapScreen

## Deferred

- i18n ARB keys: const VI strings with `// TODO(i18n)` comments inline — no ARB infra yet
- AC-04 E2E test: manual verify với 10 house seed (P08)
- D4 smoke test on device: manual (P08)
- Analytics integration: pending user answer to Q5 (Firebase vs Mixpanel)
- Geocoding to set `_lat`/`_lng` in PostHouseScreen: `// TODO(geocoding)` comment added — currently null so PlanningCheckButton is always disabled

---

## Analyze Results

```
flutter analyze lib/features/planning/ lib/features/guest/ lib/main.dart

New files (planning/utils/, planning/analytics/, planning/widgets/planning_badge.dart,
           planning_warning_modal.dart, planning_check_button.dart):
  → No issues found.

Full scan:
  → 42 issues: ALL info/deprecated (withOpacity → withValues) + 2 pre-existing warnings
    in _PickedImage (unused optional params) and use_build_context_synchronously.
  → ZERO errors introduced by P06 changes.
```

---

## Architecture Notes

- `PlanningService` is instantiated locally in `PlanningBadge` and `PlanningWarningModal`
  (NOT via global Provider) per P04 design. This is accepted for MVP.
  **Concern (DONE_WITH_CONCERNS):** If PlanningService is needed in 3+ widget types, consider
  registering globally in P07/P08.

- `_lat`/`_lng` in PostHouseScreen are always null until geocoding is added. Button is
  always disabled — correct UX ("Nhập địa chỉ trước" tooltip). User must tap to geocode
  first (future Phase).

---

## Security

- Analytics: NEVER logs raw lat/lng — only zone_code. Verified in `PlanningAnalytics`.
- Modal: fresh fetch each open — no cache (AC-15 freshness satisfied).
- Risky codes hardcoded in FE — accepted for MVP. Must sync manually with backend
  `config.risky_zone_codes`. **Documented risk:** drift between FE and BE until
  `/api/planning/risky-codes` endpoint built in Phase 2.

---

## Open Questions

1. **Q5 (BA):** Firebase Analytics vs Mixpanel — blocks removing FIXME in `planning_events.dart`.
2. **Geocoding:** How should lat/lng be populated in PostHouseScreen? Reverse geocode from
   `_addressCtrl` text? Map picker? Needed to make PlanningCheckButton functional.
