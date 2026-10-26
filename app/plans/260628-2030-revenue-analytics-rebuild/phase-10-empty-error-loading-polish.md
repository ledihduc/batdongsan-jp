---
title: "Phase 10 — Empty / Error / Loading / Polish"
status: pending
priority: P1
estimated_effort: 2-3d
blocked_by: [phase-05, phase-06, phase-07, phase-08]
owner: TBD
---

## Context Links
- BA: AC-03 (VND format), AC-13 (states), BA Leader §11.2 #3 (offline mode), §11.2 #6 (i18n)

## Overview
- Priority: P1
- Status: pending
- Brief: Polish pass — skeleton refinement, retry UX, illustrations, VND format consistency, i18n keys prep, offline mode badge.

## Key Insights (from research)
- HD design tokens provide consistent typography + spacing.
- Codebase audit §7 notes hardcoded category labels → move to i18n keys.
- BA Leader §11.2 #3: offline mode = cached last-fetch w/ "Offline — dữ liệu lúc HH:mm" badge.

## Requirements
### Functional
- Skeleton cards for every screen (replace any remaining `CircularProgressIndicator`).
- Retry CTAs use existing `analytics_error_state.dart` widget.
- Empty state illustrations (5 SVG/PNG assets):
  - No invoices yet (US-11b)
  - No reservations yet
  - Filter returned 0 rows
  - Source has no linked items
  - No data for selected period
- VND currency format consistent across all KPI cards, drill rows, chart tooltips (via `CurrencyFormatter`).
- i18n keys (Vietnamese only for MVP; English defer): extract all hardcoded strings into `lib/l10n/app_vi.arb`.
- Offline mode badge: `ReportProvider.offline = true` when ApiClient throws network error; cached data still displayed w/ badge "Offline — dữ liệu lúc HH:mm" (timestamp = last successful fetch).
- Stale cache badge per AC-17: "Dữ liệu có thể cũ đến 5 phút" when displaying cache 5+ min old.

### Non-functional
- All assets ≤30KB each.
- i18n keys named `analytics.*` namespace.
- No `print()` debug statements.

## Architecture / Design
- Centralize state widgets (`AnalyticsSkeleton`, `AnalyticsEmptyState`, `AnalyticsErrorState`, `OfflineBadge`) — reused across all analytics screens.
- `flutter_localizations` (already present); `intl_utils` to generate boilerplate.
- Provider detects network error type → set `offline = true`; UI subscribes via `Consumer`.

### Key decisions
- **i18n scope MVP:** keys created; only `vi.arb` populated; `en.arb` placeholder for V2.
- **Illustrations:** use existing brand assets if available; else procure from `unDraw` (open license) → store in `assets/illustrations/analytics/`.
- **Offline badge:** subtle pill on top of screen; tap → tooltip "Đang offline — kết nối lại để cập nhật".

## Files
### Modify
- All analytics screens (Phase 05-08) — replace hardcoded strings w/ i18n keys
- `lib/providers/report_provider.dart` — add `offline: bool` field + setter on `_handleError(SocketException)`
- `pubspec.yaml` — declare assets path; `flutter_localizations` already there
- `lib/l10n/app_vi.arb` — populated keys
- `lib/main.dart` — wire `localizationsDelegates`

### Create
- `lib/features/host/analytics/widgets/offline_badge.dart`
- `lib/features/host/analytics/widgets/stale_cache_badge.dart`
- `assets/illustrations/analytics/no_invoices.svg`
- `assets/illustrations/analytics/no_reservations.svg`
- `assets/illustrations/analytics/empty_filter.svg`
- `assets/illustrations/analytics/empty_source.svg`
- `assets/illustrations/analytics/no_period_data.svg`
- `lib/l10n/app_vi.arb` (if not exists)
- `test/widgets/offline_badge_test.dart`
- `test/widgets/stale_cache_badge_test.dart`

### Delete
- none

## Implementation Steps
1. Source illustrations (5 assets) — procure or commission; add to `assets/`.
2. Add SVG dependency if needed (`flutter_svg`) OR convert to PNG to avoid new dep.
3. Build `OfflineBadge` + `StaleCacheBadge` widgets.
4. Update `ReportProvider` — detect `SocketException`/`TimeoutException` → set `_offline=true`; reset on next success.
5. Extract all hardcoded VN strings from Phase 05-08 screens into `app_vi.arb`.
6. Run `flutter gen-l10n`; replace strings w/ `AppLocalizations.of(context)!.<key>`.
7. Add badges to `AnalyticsHomeScreen` top bar (offline + stale conditionally).

## Todo List
- [ ] 5 illustrations added
- [ ] `OfflineBadge` + tests
- [ ] `StaleCacheBadge` + tests
- [ ] Provider detects offline + stale
- [ ] All analytics screens use i18n keys
- [ ] `app_vi.arb` complete
- [ ] No hardcoded debug `print()` left
- [ ] `flutter analyze` clean

## Test Strategy
### Unit
- `OfflineBadge` renders when `provider.offline=true`.
- `StaleCacheBadge` renders when cache age > 5 min.
- `ReportProvider` sets `_offline=true` on SocketException.

### Integration
- Simulate network failure → cached data + badge displayed.
- After 5 min, badge appears w/o refetch.

### E2E
- Phase 11.

## Success Criteria
- All states (empty/error/loading/offline/stale) visually consistent.
- All strings i18n-keyed (Vietnamese populated).
- No hardcoded strings in analytics module.
- `flutter analyze` clean.

## Risk Assessment
- **Illustration procurement delay** → fallback: simple icon + text emoji.
- **i18n key scope creep** → limit to analytics module only.

## Security Considerations
- No PII in illustrations or i18n strings.

## Acceptance Criteria Coverage
- AC-03 (VND format consistent) ✓
- AC-13 (empty/error/loading/partial) ✓
- AC-17 (stale cache badge) ✓
- BA Leader §11.2 #3 (offline badge) ✓
- BA Leader §11.2 #6 (i18n key prep) ✓

## Definition of Done
- All screens polished + state-consistent.
- i18n keys extracted.
- Code reviewed.
