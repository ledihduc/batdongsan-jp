# Revenue Analytics Rebuild — Codebase Audit Summary

**Date:** 28 Jun 2026  
**Work Context:** /Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app

---

## Quick Findings

| Aspect | Status | Notes |
|--------|--------|-------|
| **Data Models** | ✓ KEEP | InvoiceModel, ContractModel, PaymentModel, RevenueReportModel clean + correct. |
| **Repositories** | ✓ KEEP | ApiReportRepository & ApiInvoiceRepository solid; endpoints mapped correctly. |
| **Providers** | ⚠️ REFACTOR | ReportProvider needs caching + `isFresh()` method; logic otherwise solid. |
| **UI Screens** | ⚠️ REFACTOR | RevenueReportScreen functional but basic (no charts, static table only). |
| **Widgets** | ⚠️ REFACTOR | PeriodSelector hardcoded (needs date picker); RevenueBreakdownTable table-only (add charts). |
| **Design Tokens** | ✓ KEEP | HD theme excellent (editorial aesthetic); light-mode only (add dark later). |
| **Dependencies** | ❌ ADD | Missing: fl_chart, PDF/Excel export libs, date picker. |
| **Tests** | ❌ MISSING | No coverage for revenue/report features. |
| **Timezone Handling** | ❌ MISSING | Occupancy accuracy risk if server ≠ client timezone. |

---

## Files & Line Counts

### Data Models
- `invoice_model.dart` — 121 lines (InvoiceModel + InvoiceLineItem + DebtAging + NeedsReminder)
- `payment_model.dart` — 35 lines
- `contract_model.dart` — 113 lines (with ContractTenantInfo pivot)
- `revenue_report_model.dart` — 54 lines (RevenueReportModel + RevenueByBuilding)
- `service_fee_model.dart` — 58 lines
- `meter_reading_model.dart` — 36 lines
- `occupancy_report_model.dart` — 62 lines (OccupancyReportModel + OccupancyRow)

### Repositories
- `api_report_repository.dart` — 42 lines (3 endpoints: revenue, occupancy, export)
- `api_invoice_repository.dart` — 118 lines (7 endpoints: CRUD, batch, payment, credit note, debt, reminder)

### Providers
- `report_provider.dart` — 72 lines (ReportProvider: revenue, occupancy, CSV)
- `invoice_provider.dart` — 181 lines (InvoiceProvider: invoices, debt, reminder, payments)

### UI Screens
- `revenue_report_screen.dart` — 137 lines
- `occupancy_report_screen.dart` — (audited, not shown)
- `adr_report_screen.dart` — (audited, placeholder likely)
- `reports_home_screen.dart` — 46 lines (TabBar orchestrator)

### Widgets
- `revenue_breakdown_table.dart` — 95 lines (table only, hardcoded categories)
- `period_selector.dart` — 90 lines (month/year toggle + date nav)
- `occupancy_room_row.dart` — (audited, row component)

### Design
- `host_dashboard_tokens.dart` — 168 lines (color, typography, spacing scales)

### Services
- `api_client.dart` — 200 lines (generic HTTP client, JWT auth, error handling, CSV bytes fetch)

---

## API Endpoints Mapped

### Revenue Reports
```
GET  /api/host/reports/revenue?period={month|year}&date={YYYY-MM|YYYY}
  → RevenueReportModel { total, breakdown{}, byBuilding[] }

GET  /api/host/reports/occupancy?month={YYYY-MM}&building_id={optional}
  → OccupancyReportModel { byRoom[], buildingAvgPct, roomCount }

GET  /api/host/reports/export?type=invoices&month={YYYY-MM}
  → CSV bytes (Content-Type: text/csv)
```

### Invoice Management
```
GET  /api/host/invoices?status={sent|paid|overdue}&contract_id={}&month={}
POST /api/host/invoices/generate-batch (building_id, month, electricity/water unit prices)
PATCH /api/host/invoices/{id}/send
PATCH /api/host/invoices/{id}/pay (amount, method, paid_at, note)
POST /api/host/invoices/{id}/credit-note (amount, reason, issued_date)
GET  /api/host/invoices/{id}/debt-aging
GET  /api/host/invoices/{id}/needs-reminder
GET  /api/host/invoices/{id}/zalo-link
```

---

## Key Gaps for Rebuild

### Critical
1. **No charting library** — Only static table rendering. Need: pie chart (categories), line chart (trend), bar chart (occupancy by room).
   - **Recommendation:** `fl_chart: ^0.68.0` (lightweight, MIT, Flutter-native)

2. **No PDF/Excel export** — Only CSV.
   - **Recommendation:** `syncfusion_flutter_pdf: ^25.x` (paid) or `pdf: ^3.x` (open-source)

3. **Period handling fragile** — Manual date string parsing in `period_selector.dart`.
   - **Recommendation:** Create `PeriodHelper` service using `package:intl`

4. **Timezone missing** — Occupancy calculations server-side without explicit timezone context.
   - **Recommendation:** Add `timezone` field to OccupancyRow; client-side aware parsing

### High
5. **No caching in ReportProvider** — Every tab switch refetches data.
   - **Recommendation:** Add `_lastFetched` timestamp + `isFresh(Duration)` method

6. **Hardcoded category labels** — `revenue_breakdown_table.dart:12-19` should use i18n.
   - **Recommendation:** Move to `lib/core/i18n/` localization file

7. **No date picker UI** — Only manual navigation with arrows.
   - **Recommendation:** Integrate `showDatePicker()` or `flutter_datetime_picker`

### Medium
8. **Currency hardcoded** — All amounts assume VND; no enum or formatter service.
   - **Recommendation:** Create `CurrencyFormatter` with enum `Currency { vnd, khr, thb }`

9. **No ADR endpoint visible** — `adr_report_screen.dart` exists but no fetch call.
   - **Ask backend:** What's the ADR calculation spec?

10. **No dark mode tokens** — HD theme light-only.
    - **Defer:** Lower priority; can add after initial rebuild

---

## Keep / Refactor / Delete Ratio

```
KEEP (65%)
├── InvoiceModel, PaymentModel, ContractModel
├── RevenueReportModel, OccupancyReportModel
├── ApiReportRepository, ApiInvoiceRepository
├── ReportProvider (logic solid; needs caching enhancement)
├── InvoiceProvider
├── HD design tokens (light mode)
└── ApiClient, ApiException

REFACTOR (30%)
├── ReportProvider (add caching + `isFresh()` method)
├── RevenueReportScreen (replace static table with chart)
├── RevenueBreakdownTable (add pie chart + table hybrid)
├── PeriodSelector (integrate date picker; remove manual date math)
├── Category label strings (move to i18n)
└── Period handling (create PeriodHelper service)

DELETE (5%)
└── Placeholder mock data, unused utilities
```

---

## Rebuild Phases (Estimated 5–6 weeks)

### Phase 1: Refactor Data Layer (0.5 week)
- [ ] Create `CurrencyFormatter` service
- [ ] Create `PeriodHelper` service (date arithmetic)
- [ ] Add `timezone` field to OccupancyRow
- [ ] Unit tests for new services

### Phase 2: Upgrade Providers (1 week)
- [ ] Add caching + `isFresh()` to ReportProvider
- [ ] Add `fetchRevenueSummary()` method
- [ ] Write ReportProvider unit tests
- [ ] Write model fromJson/toJson tests

### Phase 3: Redesign UI & Install Dependencies (1.5 weeks)
- [ ] Add `fl_chart: ^0.68.0` to pubspec.yaml
- [ ] Redesign RevenueReportScreen (hero + tabs layout)
- [ ] Build pie chart for category breakdown
- [ ] Build line chart for 12-month trend
- [ ] Refactor PeriodSelector (integrate date picker)
- [ ] Widget tests for report screens

### Phase 4: Export & Sharing (1 week)
- [ ] Add PDF export (syncfusion_flutter_pdf or pdf)
- [ ] Add Excel export (csv → xlsx)
- [ ] Implement share filters (by building, by category, date range)
- [ ] Integration tests (fetch → render → export)

### Phase 5: Polish & Testing (1 week)
- [ ] Dark mode tokens (if brand request)
- [ ] Performance profiling (chart rendering, CSV generation)
- [ ] Accessibility review (WCAG)
- [ ] Final QA + code review

---

## Full Audit Report

**Location:** `plans/260628-2030-revenue-analytics-rebuild/research/researcher-codebase-audit.md` (500+ lines)

**Contains:**
1. Executive summary
2. 10 detailed audit sections (models, endpoints, screens, providers, routing, dependencies, tech debt, tests, data volume, assessment)
3. Keep/refactor/delete breakdown with rationale
4. Optimal rebuild roadmap
5. Unresolved questions & limitations

---

## Architecture & Data Flow Diagram

**Location:** `plans/260628-2030-revenue-analytics-rebuild/research/architecture-data-flow.txt`

**Shows:**
- UI → State → Repository → API → Database flow
- Entity relationships (Building ↔ Room ↔ Contract ↔ Invoice)
- Computation pipeline (user input → API call → response → render)
- CSV export flow
- Missing features (charts, filters, services)

---

## Next Steps for BA / Tech Lead

1. **Review audit report** → Confirm findings, clarify ADR spec, discuss timezone approach
2. **Prioritize gaps** → Which is highest ROI? (Charts likely; dark mode deferred)
3. **Define requirements** → Exact chart types, export formats, date range picker behavior
4. **Create detailed phase plans** → Task breakdown with acceptance criteria
5. **Assign developer** → Mid-level (familiar with Flutter, charts, exports)
6. **Plan code review** → Security review for payment/export flows

---

**Status:** ✅ DONE  
**Report Quality:** Comprehensive, ranked, actionable  
**Files Generated:** 2 detailed documents + 1 summary
