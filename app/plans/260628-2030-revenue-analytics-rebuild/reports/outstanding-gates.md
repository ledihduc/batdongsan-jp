# Outstanding Gates — External Dependencies

**Date created:** 2026-06-29
**Status:** Awaiting external action — cannot be completed in code-only session

These items are recorded so the team can pick them up without re-reading completion reports. Each gate has a concrete next-action template and a definition of done.

---

## Gate 1 — R11 TT200 Accountant Pilot Sign-off

**Blocks:** Production launch of `/api/host/analytics/export/tt200` endpoint.
**Current status:** Backend + Flutter both tagged `experimental` / `(Bản nháp)`.

### Next action
1. Generate 3 sample TT200 exports from staging with anonymized data:
   - Tháng có hoá đơn bình thường + 2 hoá đơn void
   - Tháng có CreditNote (giảm trừ doanh thu)
   - Tháng full 30 ngày + 12 phòng
2. Email 2-3 kế toán pilot (template below) — attach 3 file Excel.
3. Capture feedback in `plans/260628-2030-revenue-analytics-rebuild/reports/phase-09-r11-feedback.md`.
4. Iterate sheet generators based on feedback (likely small column-order tweaks).
5. Get written sign-off (email/Slack OK). Save to `reports/phase-09-r11-signoff.md`.
6. Remove `tags=["host-export-experimental"]` from `app/routers/host_export.py`.
7. Remove "(Bản nháp)" suffix from `ExportButton` tooltip.
8. Update `plan.md` Phase 09 row → "completed (R11 cleared)".

### Email template (VN)

> Chào anh/chị [tên kế toán],
>
> Em đang xây dựng tính năng xuất sổ kế toán theo Thông tư 200/2014/TT-BTC cho nền tảng ancu365 (quản lý nhà trọ). File Excel có 6 sheet như đính kèm:
> 1. Sổ Nhật ký chung (S03a-DN)
> 2. Sổ Cái TK 511 + TK 5113
> 3. Bảng kê hoá đơn (có cột Trạng thái Active/Void/Adjusted)
> 4. Bảng kê thu/chi (TK 111/112)
> 5. Bảng kê công nợ (TK 131)
> 6. Bảng kê giảm trừ doanh thu (TK 521)
>
> Anh/chị xem giùm em:
> - Layout cột có chuẩn TT200 không?
> - Format số liệu (VND, ngày tháng, MST) đã đúng chưa?
> - Có cột nào thiếu/thừa cho việc khai báo thuế của chủ trọ không?
> - Có thể dùng file này nộp thuế trực tiếp không, hay phải chỉnh sửa thêm?
>
> Em cần ý kiến trước [ngày X] để có thể release production. Phí tư vấn em sẽ thanh toán theo thoả thuận.
>
> Cảm ơn anh/chị,

### Definition of Done
- [ ] 3 sample exports generated from staging
- [ ] 2-3 kế toán nhận file + xác nhận đã review
- [ ] Feedback documented in `phase-09-r11-feedback.md`
- [ ] Required changes (if any) implemented
- [ ] Sign-off email/document attached to `phase-09-r11-signoff.md`
- [ ] Experimental tag + Bản nháp tooltip removed
- [ ] PR opened + merged

---

## Gate 2 — Postgres Staging Perf Verification

**Blocks:** AC-15 final sign-off (performance claim).
**Current status:** SQLite-only benchmarks pass; production Postgres unverified.

### Next action
1. Deploy current main to staging (Postgres prod-clone).
2. Seed 1000 invoices for 1 test host across 12 months.
3. Run perf script (create `scripts/perf_benchmark_postgres.py` mirroring `tests/analytics/test_perf_p95.py` but hitting staging API):
   - 50 iterations of `GET /api/host/analytics/summary?...` — assert p95 < 800ms
   - 50 iterations of `GET /api/host/analytics/revenue-trend?...` — assert p95 < 800ms
   - 10 iterations of `POST /api/host/analytics/export/tt200` (12-month dataset) — assert p95 < 3s
4. Capture EXPLAIN ANALYZE for the slowest 3 queries — verify index usage on `invoices(host_id, period_start)`, `contracts(host_id)`, `tt200_exports(host_id, period, version)`.
5. Write report to `reports/phase-11-postgres-perf-staging.md` with raw numbers.

### Definition of Done
- [ ] Script runs against staging
- [ ] All 3 endpoints meet AC-15 budgets
- [ ] EXPLAIN ANALYZE shows index hits (no full table scans)
- [ ] Report attached with raw + p95 numbers + EXPLAIN excerpts
- [ ] Phase-11 completion report updated to remove "CAVEAT SQLite only"

### If perf fails
1. Add missing indexes via Alembic migration.
2. Re-run staging benchmark.
3. If still failing → escalate to architecture review (possible query rewrite or materialized view).

---

## Gate 3 — Device-Pilot E2E (8 flows)

**Blocks:** Device-level AC-13/AC-15 sign-off + production launch.
**Current status:** All backend + Flutter widget logic tested; physical-device flows deferred from Phase 11.

### Device requirements
- **Samsung Galaxy A14** (Android 13, 4GB RAM) — baseline Android
- **iPhone SE 2nd gen 2020** (3GB RAM) — baseline iOS
- WiFi + 4G (toggle network for offline test)

### 8 E2E flows to test
1. Login → analytics home → 5 KPI render <1.5s với data thật
2. Swipe period → KPI refresh <1s
3. Tap KPI → drill level 1 → tap row → level 2 → breadcrumb → back-to-summary (verify no crash, state preserved)
4. Filter by source + building → drill refetched correctly
5. Open occupancy heatmap → tap cell → bottom sheet shows correct data
6. Source management — add/edit/archive/delete (test linked vs unlinked)
7. Export TT200 → re-auth modal → password → download → share dialog → file opens in Excel/Numbers
8. **Offline mode** — disable network → orange badge appears → cached data still shown → reconnect → badge disappears + refresh

### Heatmap fps (separate)
- Use Flutter DevTools timeline
- Open heatmap with 30 rooms → assert ≥60fps for 5s scrolling
- Open with 50 rooms → assert ≥45fps
- Open with 100 rooms → assert ≥30fps (degraded acceptable)

### Test execution
Write `integration_test/analytics_e2e_test.dart` covering flows 1-8.
Run via `flutter test integration_test/ -d <device_id>` on each device.

### Definition of Done
- [ ] All 8 flows green on Samsung A14
- [ ] All 8 flows green on iPhone SE
- [ ] Heatmap fps targets met (or degraded-mode banner shown when >50 rooms)
- [ ] Screen recording attached for flows 7 (export) + 8 (offline)
- [ ] Report at `reports/phase-11-device-pilot.md` with device IDs + Flutter version + screen recordings

### If fails
- KPI render >1.5s → profile via DevTools, likely lazy-load issue
- Heatmap <30fps → reduce concurrent painters, consider virtualization
- Export share crashes → check `share_plus` version compat

---

## Gate 4 — SVG Empty-State Illustrations

**Blocks:** UX polish only (not production launch).
**Current status:** Icon-based placeholders working; spec called for 5 SVG.

### Next action
1. Procure or commission 5 illustrations (open license OK):
   - `no_invoices.svg` — empty invoice list (e.g. cảnh hoá đơn rỗng)
   - `no_reservations.svg` — empty booking
   - `empty_filter.svg` — filter returned 0
   - `empty_source.svg` — source has no items
   - `no_period_data.svg` — no data for selected period
2. Each asset ≤30KB
3. Sources to consider: unDraw, undraw.co (free open-license), Storyset (free w/ attribution)
4. Add to `assets/illustrations/analytics/` directory
5. Declare in `pubspec.yaml` assets section
6. Add `flutter_svg: ^2.0.0` dependency
7. Update `lib/features/host/analytics/widgets/analytics_empty_state.dart` to accept an optional `assetPath` param and render via `SvgPicture.asset`
8. Wire correct asset per context in screens

### Definition of Done
- [ ] 5 SVG files in repo
- [ ] All under 30KB
- [ ] `flutter_svg` declared
- [ ] AnalyticsEmptyState accepts illustration
- [ ] All 5 empty contexts use appropriate illustration

---

## Gate 5 — i18n .arb Extraction

**Blocks:** i18n completeness for V2 multi-language support.
**Current status:** All analytics module strings inline VN.

### Next action
1. Audit hardcoded VN strings:
   ```bash
   grep -r "Text('[^\$]" lib/features/host/analytics/ | wc -l
   ```
2. Create `lib/l10n/app_vi.arb` with namespace `analytics.*`:
   ```json
   {
     "@@locale": "vi",
     "analyticsHomeTitle": "Phân tích doanh thu",
     "@analyticsHomeTitle": {"description": "Title of analytics home screen"},
     "kpiGross": "Doanh thu gộp",
     "kpiNet": "Doanh thu thuần",
     ...
   }
   ```
3. Create placeholder `lib/l10n/app_en.arb` with empty values (V2 will translate).
4. Configure `pubspec.yaml`:
   ```yaml
   flutter:
     generate: true
   ```
5. Create `l10n.yaml`:
   ```yaml
   arb-dir: lib/l10n
   template-arb-file: app_vi.arb
   output-localization-file: app_localizations.dart
   ```
6. Run `flutter gen-l10n`.
7. Wire `localizationsDelegates` in `MaterialApp`:
   ```dart
   localizationsDelegates: AppLocalizations.localizationsDelegates,
   supportedLocales: AppLocalizations.supportedLocales,
   locale: const Locale('vi'),
   ```
8. Replace each hardcoded string with `AppLocalizations.of(context)!.<key>`.
9. Verify `flutter analyze` + `flutter test` clean.

### Scope discipline
- ONLY extract analytics module strings (Phase 05-11 screens + widgets)
- DO NOT touch other features' strings — V2 task
- DO NOT translate to English — placeholders only

### Definition of Done
- [ ] All analytics module strings in `app_vi.arb`
- [ ] AppLocalizations generated
- [ ] App boots with `Locale('vi')`
- [ ] All analytics screens use `AppLocalizations.of(context)!.<key>`
- [ ] `flutter test` 100% green (no regressions)
- [ ] `app_en.arb` placeholder exists for V2

---

## Cumulative Gate Status

| Gate | Owner | Effort | Blocks |
|------|-------|--------|--------|
| 1. R11 accountant sign-off | USER outreach | 1-2 weeks (waiting on accountants) | Production launch of TT200 export |
| 2. Postgres staging perf | OPS/DevOps | 1 day | AC-15 sign-off |
| 3. Device-pilot E2E + fps | QA + device pool | 2-3 days | Production launch |
| 4. SVG illustrations | Design | 2-3 days | UX polish (not launch-blocking) |
| 5. i18n .arb extraction | Frontend | 1-2 days | V2 multi-language |

**Launch-blocking gates:** 1, 2, 3
**Polish gates (not launch-blocking):** 4, 5

---

## Tracking

When a gate is cleared, update this file with date + reference to the completion artifact. Once all launch-blocking gates clear:
1. Update `plan.md` overall status to "READY FOR PRODUCTION"
2. Remove this file or move to `reports/archive/`
3. Open production deployment ticket
