# Tech Lead Review — Phase 09 / 10 / 11

**Date:** 2026-06-29
**Reviewer:** Tech Lead (code-reviewer agent)
**Scope:** Phase 09 (TT200 Excel export), Phase 10 (offline/stale badges), Phase 11 (telemetry + perf + IDOR)
**Verdict:** **CONDITIONAL** → **APPROVED (post-remediation 2026-06-29)**

---

## Remediation Status (2026-06-29)

| # | Issue | Status | Verification |
|---|-------|--------|--------------|
| CRITICAL #1 | `force_new_version` dead code | ✅ FIXED | Field removed from schema + router + Flutter ExportService |
| CRITICAL #2 | Race on UNIQUE constraint | ✅ FIXED | 3-retry loop with IntegrityError catch + 503 on exhaustion + new test |
| HIGH #3 | Exception text leak in 500 | ✅ FIXED | Generic "Export failed" + `logger.exception` server-side + new test |
| HIGH #4 | Network errors not caught in 4 fetch methods | ✅ FIXED | `_runWithOfflineGuard` helper applied to all 5 fetchers + 8 new tests |
| HIGH #5 | ExportService HTTP client leak | ✅ FIXED | Registered as Provider in main.dart + dispose() + lookup via Provider.of |

**Post-remediation tests:** Backend 57/57 pass · Flutter targeted 41/41 pass · Full Flutter suite 0 new regressions (17 pre-existing failures unchanged: planning_map_provider, permission_events, widget smoke).

**Remaining items:** MEDIUM/LOW findings (#7–#17) deferred per review scope. Pre-production gates (R11 accountant sign-off, Postgres staging perf, device-pilot E2E) unchanged.

---

## Executive Summary

Implementation quality is high: 6-sheet TT200 generator, re-auth gate, audit log, immutability table, IDOR regression suite, perf benchmarks, telemetry — all delivered with passing tests (43 backend export + 17 Flutter Phase 10 + 24 Phase 11 = 84+ green). Module sizes are well under the 200-LOC guideline. Security perimeter is correct on the happy path: every sheet generator takes `host_id` as a typed parameter, re-auth JWT is verified end-to-end, audit logs fire on success AND failure paths, sha256 + version table give legal-grade tamper evidence.

The CONDITIONAL verdict is driven by two production-blocking concerns and three pre-existing acknowledged gaps:

1. **Production-blocking (must fix before merge to production):** (a) `force_new_version=False` dead-code path that always increments version (correctness bug + race), (b) raw exception text leaked in 500 response from export endpoint.
2. **Pre-existing acknowledged risks (do NOT re-block, but block production launch per existing gate):** (a) R11 accountant pilot sign-off still pending — phase 09 self-declares DRAFT/experimental and Flutter UI tooltip says "Bản nháp", (b) iPhone SE / Samsung A14 device E2E + heatmap fps benchmarks deferred to device-pilot phase, (c) Postgres perf verification deferred to staging.

The team has been honest about deferrals and self-tagged the experimental router — that lowers the risk profile substantially. With items (1a)+(1b) fixed and the existing gates respected (R11 sign-off + device pilot + staging perf), this is approvable for a controlled release.

---

## Findings by Severity

### CRITICAL (must fix before merge to main)

1. **`force_new_version=False` is dead code; version always increments.** `app/routers/host_export.py:128-132`. Both branches compute `max_version_row.version + 1`, so the flag has no behavioral effect. Either (a) honour the flag by returning the existing latest version metadata without inserting a new row when `force_new_version=False` AND a row exists for the period, or (b) remove the flag from `Tt200ExportRequest` and document the semantic ("every call creates a new immutable version") in the OpenAPI description. Without a fix the public contract is misleading, and clients calling `force_new_version=False` thinking it's idempotent will produce duplicate audit rows + storage churn.

   **Recommendation:** Option (b) is cleaner — immutability per AC-10 implies "every export is a new version". Remove the flag and update tests / Flutter `ExportService.downloadTt200(forceNewVersion)` to match.

2. **Race condition on (host_id, period) UNIQUE constraint will produce 500s.** Two concurrent export calls for the same period both read `max_version_row` and both write `version = existing+1`. The DB UNIQUE constraint `uq_tt200_exports_host_period_version` will reject the second INSERT with IntegrityError, which propagates as `HTTPException(500, "Export failed: ...")` — bad UX and leaks SQL detail. Fix: wrap the SELECT + INSERT in a row-lock (`SELECT ... FOR UPDATE` on Postgres) OR catch `IntegrityError`, increment version, retry once. Either pattern with a max-retry guard.

### HIGH (should fix before production)

3. **500 error response leaks exception text.** `host_export.py:179` → `raise HTTPException(500, f"Export failed: {exc}")`. The middleware `unhandled_exception_handler` suppresses tracebacks in production but this codepath builds the exception text into the HTTP detail BEFORE the middleware — so `IntegrityError: (sqlite3.IntegrityError) UNIQUE constraint failed: ...` would be returned to the client. Replace `f"Export failed: {exc}"` with a generic string and log `exc` server-side only. Pattern already used elsewhere in the codebase (see `error_handler.py:69-72`).

4. **`fetchTrend`/`fetchHeatmap`/`fetchSources`/`fetchSourceBreakdown` do not catch `SocketException`/`TimeoutException`.** `lib/providers/report_provider.dart:187-292`. Only `fetchAnalyticsSummary` (lines 167-179) sets `_offline=true` on network errors. The other fetch methods will propagate the raw exception up to the caller, surface as red error states despite the offline badge mechanic being designed to show cached data. AC-13 ("offline mode") + BA Leader §11.2#3 are partially satisfied. Hoist the network-error catch into a shared helper:
   ```dart
   Future<T?> _runWithOfflineGuard<T>(Future<T> Function() body) async {
     try { final r = await body(); _offline = false; return r; }
     on SocketException { _offline = true; return null; }
     on TimeoutException { _offline = true; return null; }
   }
   ```

5. **`force_new_version` confusion in Flutter client.** `lib/features/host/analytics/services/export_service.dart:143` — the Dart-side parameter `forceNewVersion` is wired through the body but `ExportButton.downloadTt200()` always passes default false. If the backend honours it per CRITICAL #1 fix, the UI needs a "re-export same period" toggle; if it doesn't, drop the parameter. Either way, Flutter + backend must stay in sync.

6. **`ExportButton.exportService` constructor injection bypassed.** `lib/features/host/analytics/widgets/export_button.dart:22-28`: `_service` getter falls back to `ExportService()` when `_exportService` is null. ReauthModal:31 does the same. Production code paths always construct a new `ExportService` per click, which opens a new `http.Client` and never closes it. Long-running app sessions leak HTTP connections. Either (a) inject ExportService via Provider (preferred — matches TelemetryService pattern), or (b) make `ExportService()` a singleton with `http.Client.close()` in dispose. Tests already inject, so production behavior diverges.

### MEDIUM (consider before V2)

7. **Defense-in-depth `host_id` filter missing on invoice number lookup.** `sheet_revenue_deductions.py:53-60` queries `Invoice.id.in_(original_ids)` without the redundant `host_id == host_id` filter. FK integrity from already-filtered credit_notes guarantees correctness today, but defense-in-depth + future codebase evolution warrants the explicit filter. Same pattern is correctly applied in `sheet_invoice_list.py:74` (`models.CreditNote.host_id == host_id`). One-line fix.

8. **`_PERIOD_RE` validates `period` field but `TestExportIDOR` sends `year_month`.** `tests/analytics/test_idor_regression.py:312` sends `{"year_month": "2026-07"}` — the schema field is `period`. The test still passes because the 403 reauth gate fires first, but the test does NOT exercise body validation. Add an explicit test that sends a valid reauth token + bad period to assert 422 with `VALIDATION_ERROR` envelope.

9. **`reauth` endpoint accepts `purpose=export` token from non-host users.** `auth_router.py:97-141` uses `Depends(auth.require_user)` not `require_host`. The reauth token then signs `role=claims.get("role","host")` defaulting to "host" — so a guest could obtain a token with role=guest, but `host_export.py:50` uses `Depends(auth.require_host)` which gates the export. Currently safe, but the reauth endpoint should match the resource it protects: change to `require_host`, or pin `role="host"` in the issued claim regardless of caller role. Minor since the export endpoint already enforces host.

10. **`jwt_secret` default value is a placeholder.** `app/config.py:7` — `jwt_secret: str = "urbannest-dev-secret-change-me"`. Not new in Phase 09 but worth flagging since Phase 09 introduces a second JWT class (reauth tokens). Ensure ops sets `JWT_SECRET` env var in all deployed environments; consider failing app startup if value matches the default in non-dev environments.

11. **Audit log `record()` commits internally even when called from a routed transaction.** `audit_log_service.py:56` calls `db.commit()`. In `host_export.py` this is called AFTER the `tt200_exports` insert and commit, so the second commit is a no-op transaction — fine. But on the failure path (line 167), the previous transaction may have been left dirty by the `excel_exporter_tt200.generate()` failure. Audit log commit could succeed while the export row was rolled back — actually the desired behavior — but the inverse (export committed, audit failed silently in the `except Exception: pass`) leaves an unauditable export row. Consider linking audit row insert into the same transaction as the export row OR logging the audit-log failure to stderr.

12. **`_StatusBadgeRow._isStale` uses `DateTime.now()` (local wall clock) but `lastSuccessfulFetchAt` was captured with `DateTime.now()` in provider.** Both are local-time, so the diff is correct in practice. But Vietnam app + UTC-stored backend has consistently been "use TzHelper.hcmNow()" per Q6 — stale-check should use the same helper for consistency.

### LOW (style / nitpicks)

13. **Duplicate `IDOR` literal in IDOR test class names** — minor inconsistency: some classes named `TestSummaryIDOR`, others `TestTrendIDOR` — fine, just noting.
14. **Phase 11 report claims "9 analytics + 4 source + export = 11 IDOR tests"** but actual analytics endpoints are 5 (`summary`, `revenue-trend`, `occupancy-heatmap`, `source-breakdown`, `drill-down`). Plan and reports inconsistent on count. The implementation covers the actual 5. Adjust plan or report wording.
15. **`ExportService._tempDirProvider` field cannot be made `final`** — it's actually `final` already (line 79). Skip.
16. **No `dispose()` on `ExportService`** to close the underlying `http.Client`. Pairs with HIGH #6.
17. **Hard-coded VN strings remain in offline_badge / stale_cache_badge / reauth_modal / export_progress_dialog.** Phase 10 explicitly deferred i18n .arb extraction, so this is acknowledged. Add to V2 backlog.

---

## BA Acceptance Criteria Verification

| AC | Status | Evidence |
|----|--------|----------|
| AC-10 (TT200 6 sheets) | ✓ | 6 sheet generators in `app/services/_tt200_sheets/`: `sheet_journal.py`, `sheet_general_ledger.py`, `sheet_invoice_list.py`, `sheet_cash_book.py`, `sheet_receivables.py`, `sheet_revenue_deductions.py`. `sheet_invoice_list.py:18-28` includes "Trạng thái" column (Active/Void/Adjusted). VND/DD-MM-YYYY/MST formatters centralized in `_formatters.py`. **CAVEAT:** R11 accountant pilot sign-off PENDING — feature self-tagged experimental. Column layouts marked DRAFT in code comments. |
| AC-13 (states) | ✗ partial | Empty/Error/Loading from Phase 05–08 ✓. Offline badge wired in `analytics_home_screen.dart:131-134, 477` ✓. BUT `fetchTrend/fetchHeatmap/fetchSources/fetchSourceBreakdown` do NOT catch network errors (HIGH #4) — only `fetchAnalyticsSummary` triggers `_offline=true`. |
| AC-15 (perf) | ✓ partial | `tests/analytics/test_perf_p95.py` measures `summary` / `revenue_trend` / `source_breakdown` via `pytest-benchmark.pedantic` on 1000-invoice fixture, asserts mean <0.8s. `tests/export/test_export_perf.py` generates 12-month dataset (720 invoices) and asserts mean <3s. SQLite mean 2.9ms/9.6ms/0.6ms for analytics and "<3s" for export. **CAVEAT:** measured on SQLite in-memory, NOT Postgres — Phase 11 report explicitly flags Postgres staging verification as required. Device-side render perf (Samsung A14, iPhone SE) deferred. |
| AC-16 (IDOR) | ✓ | `tests/analytics/test_idor_regression.py` covers all 5 analytics GET endpoints + 3 source mutation endpoints + 1 export endpoint = 9 endpoints. host_A JWT must not see host_B 5M VND across summary, trend, source breakdown, heatmap, drill-rooms. Each TT200 sheet generator filters on host_id (verified in grep: every primary query has `host_id == host_id`). |
| AC-17 (stale cache) | ✓ | `StaleCacheBadge` wired in `analytics_home_screen.dart:480`. Provider tracks `_lastSuccessfulFetchAt` (line 65) set on summary success (line 166). 5-minute threshold in `_StatusBadgeRow._isStale` (line 462). NOTE: only summary updates the timestamp — if user only fetches trend or heatmap, the "last successful" is never updated. Acceptable for MVP since summary is the entry point. |

---

## Security Audit Summary

- **IDOR coverage:** Every sheet generator function has `host_id: int` param and every primary SELECT has `WHERE host_id = host_id` (verified by grep across all 6 sheets). Defense-in-depth gap in `sheet_revenue_deductions.py:53-60` (MEDIUM #7). IDOR regression test covers 9 endpoints — passes 11/11.
- **Re-auth gate:** `require_reauth_token` dependency at `host_export.py:48-88` validates: (1) header present → 403, (2) JWT decode succeeds → 403 on failure, (3) `purpose == "export"` → 403, (4) `sub` matches authenticated host's `sub` → 403. JWT signed with `settings.jwt_secret` (HS256). 5-minute TTL enforced via `exp` claim. Comprehensive.
- **PII handling:** TT200 sheets contain tenant names + invoice numbers + revenue amounts → gated behind re-auth (BA §11.3 ✓). MST is currently blank in `sheet_invoice_list.py:116` (tenants not required to have MST in nhà trọ). Audit log row created on EVERY export attempt (success + failure paths). No PII in telemetry events (`analytics_opened`, `kpi_drilled`, `export_clicked`, `filter_applied`, `period_swiped` — only `period`, `kpi`, `direction`).
- **Audit log:** `audit_log_service.record()` invoked on success path (host_export.py:153) AND on failure path (host_export.py:167). Failure-path audit wrapped in inner try/except so audit log failures don't swallow the original exception. `audit_logs` table has indexed `(host_id, action, created_at)` for compliance queries. Schema correct.
- **No secrets in code:** `jwt_secret` placeholder default in `config.py:7` — MEDIUM #10 calls this out. No other hardcoded secrets found in Phase 09/10/11 files.
- **Input validation:** `Tt200ExportRequest.period` enforces regex `^\d{4}-\d{2}$` + 2000–2100 range + 01–12 month. `ReauthRequest.check_has_credentials()` raises ValueError converted to HTTP 400 in router. Both correct.

---

## Architecture & Code Quality

- **File sizes:** All Phase 09 service files ≤137 LOC (well under 200-line guideline). `host_export.py` at 191 LOC is right at the edge — splitting the re-auth dependency into its own module would be reasonable but not required.
- **N+1 query risk:** `sheet_invoice_list.py:86-99` batches tenant lookup with single JOIN — good. `sheet_receivables.py:59-72` same pattern. `sheet_revenue_deductions.py:54-60` same pattern. No N+1 detected.
- **Streaming write:** Comment at `excel_exporter_tt200.py:48` documents the deliberate choice to use standard Workbook (not write_only=True) because write_only is incompatible with `ws.append()` row generators. Tradeoff acknowledged. For ~1000-invoice monthly datasets this is acceptable; for 10k+ invoices a streaming-friendly refactor would be needed.
- **Transaction lifecycle:** `host_export.py` commits the export row + audit log row separately. Per MEDIUM #11, the partial-failure window between commits is small but non-zero.
- **Provider pattern:** TelemetryService correctly registered in `main.dart:285`. AnalyticsHomeScreen uses `Provider.of<TelemetryService>(context, listen: false)` — non-listening read, correct since telemetry is fire-and-forget.
- **Dart immutability:** Models and DTOs use `const` + `final` consistently in reviewed files. `TelemetryService._queue` is a mutable `List<TelemetryEvent>` exposed via `List.unmodifiable` — correct read-only contract.
- **No untyped `dynamic` overuse:** ExportService, ReauthModal, ExportButton all typed. `jsonDecode(...) as Map<String, dynamic>` is unavoidable for JSON decode.
- **No `print()` debug:** Verified no `print()` in production code; `debugPrint` only used in TelemetryService (Phase 11 stub).

---

## Tests

| Suite | Tests | Pass | Notes |
|-------|-------|------|-------|
| Backend `tests/export/` (re-run on review) | 43 | 43 | report claimed 42 — one extra found, all green |
| Backend `tests/analytics/test_perf_p95.py` | 3 | 3 | SQLite mean 2.9/9.6/0.6 ms |
| Backend `tests/analytics/test_idor_regression.py` | 11 | 11 | All 9 analytics + 4 source endpoints + export reauth gate |
| Backend `tests/export/test_export_perf.py` | 1 | 1 | 12-month <3s |
| Flutter Phase 09 (`export_service`, `export_button`, `reauth_modal`) | 16 | 16 | per completion report |
| Flutter Phase 10 (`offline_badge`, `stale_cache_badge`, `report_provider_offline`) | 17 | 17 | per completion report |
| Flutter Phase 11 (`telemetry_service`) | 9 | 9 | per completion report |

Coverage: Phase 02/03/09 combined target modules at 92% (target ≥80%) — met.

---

## Deferred / Acknowledged Risks

The team has been explicit about deferrals; these are NOT new findings, they are existing acknowledged gates:

| # | Item | Owner | Block on |
|---|------|-------|----------|
| 1 | R11 — TT200 accountant pilot sign-off | USER outreach | Production launch (Phase 09 self-tagged "experimental" + Flutter tooltip "Bản nháp") |
| 2 | Postgres staging perf verification | OPS | AC-15 final sign-off |
| 3 | Flutter integration_test E2E (8 flows) on physical devices | Device-pilot phase | AC-13/AC-15 device sign-off |
| 4 | Heatmap fps benchmark on Samsung A14 + iPhone SE | Device-pilot phase | AC-08 perf sign-off |
| 5 | i18n .arb extraction (analytics module) | V2 | i18n completeness |
| 6 | 5 SVG empty-state illustrations | V2 | UX polish |
| 7 | Legacy `host_report.py` router + `api_report_repository.dart` cleanup | post-launch ticket | Code-debt cleanup |

All 7 items appear in completion reports with rationale. They are reasonable scope cuts for a CLI session.

---

## Recommendation

**CONDITIONAL APPROVAL** — block merge to main on the two CRITICAL items (#1 dead-code force_new_version, #2 race + #3 exception leak treated as one fix), then proceed.

**Pre-merge fix list (estimated effort: <1 day):**

1. Either remove `force_new_version` from `Tt200ExportRequest` + Flutter `ExportService.downloadTt200` + relevant tests, OR implement the intended idempotent path that returns existing version metadata without re-inserting.
2. Wrap version computation + INSERT in a row-lock or catch IntegrityError + retry-once pattern.
3. Generic 500 response: replace `HTTPException(500, f"Export failed: {exc}")` with `HTTPException(500, "Export failed")` and log `exc` server-side.
4. Hoist network-error catch into a shared helper in `ReportProvider` and apply to all four v2 fetch methods (HIGH #4). One-screen change.
5. Either dispose `http.Client` properly OR register `ExportService` as a Provider (HIGH #6) — pick one and stay consistent.

**Pre-production gates (existing, not re-imposed):**

- R11 accountant pilot sign-off → remove `tags=["host-export-experimental"]` from router + `(Bản nháp)` from tooltip + add `phase-09-r11-signoff.md`.
- Postgres staging perf benchmark for AC-15.
- Physical-device E2E + heatmap fps for AC-13/AC-15/AC-08.

With these fixed + gates respected, the implementation is production-ready. The team's discipline around self-tagging experimental + explicit deferral documentation is exactly what we want to see — easy to give a CONDITIONAL approval here rather than a REJECT because the unknowns are well-flagged rather than hidden.

---

## Unresolved Questions

1. Should `force_new_version` be removed or made functional? Caller intent unclear — was Flutter UI supposed to expose a "re-export same period" button?
2. Are concurrent exports for the same `(host_id, period)` a realistic threat? If host can only export from one device at a time the race is theoretical — but unlikely to stay theoretical once a 3rd-party accountant integration calls the endpoint.
3. Does ops have a process for setting `JWT_SECRET` in production? If yes, MEDIUM #10 is closed; if no, add a startup assertion.
4. Phase 11 perf report claims SQLite numbers — when does Postgres staging verification happen? Phase 12? Pre-prod?
