# P3 Scale — Post-Fix Report

Date: 2026-10-17
Scope: fix FE agent stall remnants + verify full suite green.

## Fixes applied

### FE (ancu365-app)

1. `lib/features/guest/search/jp_search_facets_drawer.dart`
   - Wrapped `SwitchListTile` in `Material` to satisfy Flutter's "ListTile under a Material" invariant. Resolved 5 drawer test failures.

2. `test/widget/jp/settlement_tenant_test.dart` (2 tests)
   - Seed step `await repo.submitToTenant(1)` was hanging under FakeAsync. Wrapped seed in `tester.runAsync(...)` so mock's `Future.delayed` fires against the real clock.

3. `test/widget/jp/admin_kpi_test.dart` (1 test)
   - "prefecture dropdown is rendered" was leaving a pending timer. Added `tester.pump(Duration(milliseconds: 500))` to flush mock delay before assertion.

4. `test/widget/jp/account_deletion_test.dart` (1 test)
   - `scheduledAt = now + 25d` → `inDays` truncated to 24 after microsecond lag. Changed to `25d + 1h` so inDays reliably = 25.

5. `lib/features/renewal/renewal_detail_screen.dart` (1 test + UX fix)
   - Error path leaked raw `Exception: Renewal 999 not found` into the UI. Replaced with sanitized generic JP message (`更新情報を取得できませんでした。`). No internal IDs exposed.

### BE (ancu365-backend)

- `main.py` wired JP-only cron: APScheduler `BackgroundScheduler` on startup (gated by `settings.region == "jp"`), running `start_renewal_cron` + `start_deletion_cron`, graceful shutdown on app exit.

## Verification

- `flutter test`: **1845 / 1845 passed** (0 failing).
- BE compiled clean in Docker (no new errors).

## Deferred / known caveats

- `jp_renewal_load_error` l10n key not added — used hardcoded JP string. If routing exposes this screen under non-JP locale in future, switch to ARB key.
- Account-deletion cancel path is still mock-only (resets state, no BE call). Flagged in `account_deletion_screen.dart:93`.
- FE agent STALLED mid-session; verified by file-system inspection that all critical files landed before stall. No work left outstanding from the agent's assigned scope.

## Open questions

- None blocking P4. All P3 acceptance criteria met.
