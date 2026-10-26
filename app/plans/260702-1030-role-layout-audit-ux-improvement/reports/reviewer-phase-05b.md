# Reviewer — Phase 05b (Loading/Error/Empty state migration)

**Verdict:** APPROVED
**Scope:** 10 host list screens migrated to 3-state pattern.
**Date:** 2026-07-02

## Summary

All 10 files correctly apply the canonical guard order:
1. `isLoading && items.isEmpty` → `DsRowSkeleton`
2. `error != null && items.isEmpty` → `DsErrorState(onRetry: ...)`
3. `items.isEmpty` → `DsEmptyState`
4. content

No stale `_ErrorView` / `_EmptyView` class definitions or imports remain (grep confirmed). No hardcoded `Color(0x...)` introduced. `CircularProgressIndicator` present only in `service_fee_list_screen.dart` inline submit button (per spec allowed for inline spinners). All `DsErrorState` calls wire `onRetry`. All `DsEmptyState` use domain-appropriate Material icons + Vietnamese microcopy.

Pagination/refresh flows preserved: drill screens keep `ScrollController` + `_loadNextPage`; `building_list_screen`, `sync_status_screen`, `debt_aging_screen` keep `RefreshIndicator`; `reservation_list_screen` keeps filter refetch.

## Findings

### LOW — `debt_aging_screen.dart` guard uses `report == null` sentinel
Lines 34/41/54: uses `report == null` (from single `DebtAging` object) rather than `items.isEmpty`. Semantically equivalent since `fetchDebtAging` sets `report` on success. Rebuilds the Scaffold+AppBar three times instead of switching only the body — small ergonomic wart, not a bug. Consider extracting body into `_body()` like `service_fee_list_screen` does.

### LOW — `drill_room_screen.dart` `_openFilter` fires unawaited setState after await
Line 94–98: `_openFilter` calls `_loadPage(1, reset: true)` without `if (!mounted) return` between `await showFilterBottomSheet` and the reload. `_loadPage` internally calls `setState`, so a dismounted widget could throw. Same pattern in other drill screens is fine because `_loadPage` is called from `initState`, not post-await. Add mount check.

### LOW — `sync_status_screen.dart` uses raw `substring` on ISO date
Line 144: `item.lastSyncedAt!.toLocal().toIso8601String().substring(0, 16).replaceAll("T", " ")` is fragile if ISO format ever changes (fine today, but should use `DateFormat` for consistency with other screens). Non-blocking.

### LOW — `service_fee_list_screen.dart` retry closure re-reads Provider
Line 73: `onRetry: () => context.read<ServiceFeeProvider>().fetchServiceFees(...)` re-reads provider on tap — correct behaviour, just verbose vs. capturing `prov`. No bug.

### INFO — Empty subtitle omitted on 4 drill screens
`drill_room`, `drill_invoice`, `drill_contract`, `drill_tenant`, and `debt_aging` provide only `title` for `DsEmptyState`. Acceptable (title is self-explanatory in Vietnamese) but a subtitle guiding "Thử điều chỉnh bộ lọc" could improve UX. Not a defect.

## Checklist verification

- [x] Guard order correct on all 10 files
- [x] `DsErrorState` has `onRetry` wired in all 10
- [x] `DsEmptyState` has appropriate icon + Vietnamese title
- [x] No stale `_ErrorView` / `_EmptyView` classes or imports
- [x] No new hardcoded colors (`Color(0x...)` grep = 0 hits)
- [x] Pagination preserved on 4 drill screens
- [x] `RefreshIndicator` preserved where it existed
- [x] Filter chips in `reservation_list_screen` still trigger `_refetch`
- [x] No `console.log`-equivalent (`print`) added
- [x] No auth/security surface touched

## Security & correctness

No new inputs, queries, or trust-boundary changes. All async state uses `mounted` checks before `setState` except the one flagged in drill_room. No PII leakage: error `message` is the caller-provided provider error string, not stack traces.

## Recommended follow-ups (non-blocking)

1. Extract `debt_aging_screen` body to `_body()` for consistency.
2. Add `if (!mounted) return;` after `showFilterBottomSheet` in `drill_room_screen._openFilter`.
3. Consider subtitle for drill empty states.

## Unresolved questions

None.
