---
title: "Phase 06 — Reports + Zalo deep-link + Notifications + Cần action dashboard"
description: "Table-view reports (revenue/occupancy/ADR), Zalo deep-link builder, CSV export, dashboard 'cần action' list"
status: pending
priority: P2
effort: 5-6d
branch: TBD
tags: [backend, flutter, reports, zalo, notifications, dashboard]
created: 2026-06-22
---

# Phase 06 — Reports + Zalo + Notifications + Cần action

**Sized:** 5–6d
**Status:** ⏸ Pending (Ready)
**Blocks:** None (polish phase)
**Blocked by:** 03 (Contract), 04 (Invoice), 05 (KhaiBaoTamTru)

## Context links
- BA doc §4 G (Reports G1-G4), D5 (dashboard cần nhắn), F2 (khai báo reminder UI), §5 AC, §6 (chart defer, push defer, Zalo Business defer), §9 D4 (no cron, manual + dashboard list)
- Research: `researcher-backend-audit.md` §1 (Notification model exists, no FCM), `researcher-flutter-audit.md` §10 (polling notifications)
- Code files affected: `app/services/report_service.py` (new), `app/utils/zalo.py` (Phase 04 created), `lib/features/host/reports/` (new), `lib/features/host/dashboard/` (refactor host_home)

## Overview
Phase polish — không feature mới critical, focus DX:
1. Reports table-view: doanh thu tháng/năm, occupancy %, ADR (homestay)
2. CSV export hoá đơn → host gửi kế toán
3. Zalo deep-link builder integration (Phase 04 util) tích hợp tới UI Reports + Reminder
4. "Cần action" dashboard list: contracts sắp hết hạn, invoices quá hạn, khai báo overdue → host tap row → mở context action
5. In-app notifications polish (FCM push defer per BA)

## Key insights from research
- Existing `Notification` model + provider polls DB every ~5s → adequate MVP, FCM defer
- BA G4 sealed: CSV export OK, PDF defer
- BA D4 sealed: NO cron. Dashboard "cần action" computed at read time
- Chart UI defer → use table format
- Backend Notification.type field accepts string, easy to extend with new types

## Requirements

### Functional (from BA user stories)
- **G1:** Doanh thu tháng/năm → AC: GET `/api/host/reports/revenue?period=month|year&date=YYYY-MM` returns total + breakdown (rent, utilities, services, homestay)
- **G2:** Occupancy → AC: GET `/api/host/reports/occupancy?building_id=&month=` returns % per room + building avg
- **G3:** ADR/RevPAR (homestay) → AC: GET `/api/host/reports/adr?house_id=&period=` returns avg daily rate
- **G4 (SHOULD):** CSV export → AC: GET `/api/host/reports/export?type=invoices&month=` returns CSV file with line items
- **D5:** Dashboard "cần action" → AC: GET `/api/host/dashboard/action-items` returns:
  - Contracts expiring within 30d
  - Invoices overdue (>due_date)
  - KhaiBaoTamTru overdue
  - Rooms in maintenance
- **F2:** 12h khai báo reminder UI (already from Phase 05 banner, polished here)

### Non-functional
- Reports query <2s for host with 100 rooms (use indexed columns + aggregation)
- CSV export streamable (large datasets)
- Notification UI updates within 5s of state change (existing polling)

## Architecture

### Backend

**New endpoints:**

| Method | Path | Auth | Returns |
|---|---|---|---|
| GET | `/api/host/reports/revenue?period=month\|year&date=` | require_host | `{total, breakdown: {rent, utilities, services, homestay}, by_building: [...]}` |
| GET | `/api/host/reports/occupancy?building_id=&month=` | require_host | `{building: {avg_occupancy_pct, total_rooms, occupied_days}, by_room: [...]}` |
| GET | `/api/host/reports/adr?house_id=&period=` | require_host | `{adr, revpar, occupied_nights, total_nights}` (Phase 07 data — graceful if no homestay) |
| GET | `/api/host/reports/export?type=invoices\|contracts&month=` | require_host | StreamingResponse CSV file |
| GET | `/api/host/dashboard/action-items` | require_host | `{expiring_contracts: [...], overdue_invoices: [...], overdue_khai_bao: [...], maintenance_rooms: [...]}` |
| POST | `/api/host/invoices/{id}/send-zalo-reminder` | require_host | Body: {tenant_id}, returns Zalo deep-link string for host to tap |
| GET | `/api/host/notifications/host-actions` | require_host | List notifications grouped by category |

**Services:**

- `app/services/report_service.py`:
  - `revenue_report(host_id, period, date_str)` — SUM invoices.total_amount + breakdown by line_item.category, group by month/year
  - `occupancy_report(host_id, building_id, month_str)` — for each room, count days status='occupied' / total days in month
  - `adr_report(host_id, house_id, period)` — Phase 07 Reservation data; return null if no reservations
  - `export_invoices_csv(host_id, month_str)` — yield CSV rows (streamable)

- `app/services/dashboard_service.py`:
  - `action_items(host_id)` — query 4 categories, return list with row count + details (first 10 each)

**Zalo integration (extend Phase 04 util):**

```python
# app/utils/zalo.py (existing)
def build_zalo_share_link(phone: str, message: str) -> str: ...

# NEW: Template messages
def template_invoice_reminder(tenant_name, amount, due_date, link) -> str:
    return f"Anh/chị {tenant_name}, hoá đơn tháng này: {amount:,} VND, hạn {due_date}. Xem chi tiết: {link}"

def template_contract_expiring(tenant_name, end_date) -> str:
    return f"Anh/chị {tenant_name}, HĐ thuê hết hạn {end_date}. Báo lại nếu gia hạn nhé."
```

**Notification types added:**
- `invoice_overdue_reminder` — generated when host opens dashboard
- `contract_expiring_30d`
- `khai_bao_overdue`

(No cron generates; dashboard computes on-the-fly per D4.)

**Migration:** No new tables; possibly index additions for report queries (`alembic/versions/0008_report_indexes.py`):
- Index on `invoices(host_id, period_start)`
- Index on `contracts(host_id, end_date)`
- Index on `khai_bao_tam_tru(host_id, check_in_at, status)`

**Schemas:** `app/schemas/report.py`, `dashboard.py`

### Flutter

**New sub-module `lib/features/host/reports/`:**

```
lib/features/host/reports/
├── screens/
│   ├── reports_home_screen.dart        # Period selector + 3 tabs (revenue/occupancy/adr)
│   ├── revenue_report_screen.dart      # Table view
│   ├── occupancy_report_screen.dart
│   ├── adr_report_screen.dart
│   └── export_csv_screen.dart          # Date range + type picker
└── widgets/
    ├── revenue_breakdown_table.dart
    ├── occupancy_room_row.dart
    └── period_selector.dart
```

**Refactor `lib/features/host/dashboard/` (extracted from host_home_screen):**

```
lib/features/host/dashboard/
├── screens/
│   └── host_dashboard_screen.dart      # Refactored host_home
└── widgets/
    ├── action_items_section.dart        # Expandable list
    ├── action_item_card.dart            # Tap → navigate to context
    └── stats_summary_row.dart           # Total rooms / occupied / revenue MTD
```

**New provider:**
- `lib/providers/report_provider.dart` — caches recent reports
- `lib/providers/dashboard_provider.dart` — action items fetch

**Packages:**
- `csv: ^6.0.0` — parse CSV preview
- `file_saver: ^0.2.14` — download CSV on Flutter

### Data flow

```
[Reports]
Host taps "Báo cáo" in dashboard
ReportsHomeScreen → period picker (month/year) + tab (Revenue/Occupancy/ADR)
  ↓ tap Revenue tab
GET /api/host/reports/revenue?period=month&date=2026-07
  → table: row per building + breakdown columns
  ↓ tap "Xuất CSV"
GET /api/host/reports/export?type=invoices&month=2026-07
  → streaming CSV download → file_saver → share to email/cloud

[Dashboard cần action]
Host opens app → HostDashboardScreen
  → GET /api/host/dashboard/action-items
  → 4 sections rendered:
    1. "X hợp đồng sắp hết hạn" → tap row → navigate Phase 03 ContractDetailScreen
    2. "Y hoá đơn quá hạn" → tap row → Phase 04 InvoiceDetailScreen + auto-suggest "Nhắc qua Zalo"
    3. "Z khai báo quá hạn" → tap row → Phase 05 KhaiBaoDetailScreen
    4. "W phòng đang sửa" → tap → Phase 03 RoomDetailScreen
  ↓ tap "Nhắc qua Zalo" on invoice row
POST /api/host/invoices/{id}/send-zalo-reminder
  → returns deep-link string
  → url_launcher opens zalo.me/{phone}?text=... in Zalo app
```

## Related code files

### Backend new files
- `backend/app/services/report_service.py`
- `backend/app/services/dashboard_service.py`
- `backend/app/routers/host_report.py`
- `backend/app/routers/host_dashboard.py`
- `backend/app/schemas/report.py`
- `backend/app/schemas/dashboard.py`
- `backend/alembic/versions/0008_report_indexes.py`
- `backend/tests/test_revenue_report.py`
- `backend/tests/test_occupancy_report.py`
- `backend/tests/test_csv_export.py`
- `backend/tests/test_dashboard_action_items.py`

### Backend modified files
- `backend/app/utils/zalo.py` — add template messages (Phase 04 already has builder)
- `backend/app/routers/host_invoice.py` — add `send-zalo-reminder` endpoint
- `backend/main.py` — include 2 new routers

### Flutter new files
- `lib/data/models/revenue_report_model.dart`
- `lib/data/models/occupancy_report_model.dart`
- `lib/data/models/dashboard_action_items_model.dart`
- `lib/data/repositories/api_report_repository.dart`
- `lib/data/repositories/api_dashboard_repository.dart`
- `lib/providers/report_provider.dart`
- `lib/providers/dashboard_provider.dart`
- All `lib/features/host/reports/*` and `lib/features/host/dashboard/*` files

### Flutter modified files
- `lib/main.dart` — add 2 providers
- `lib/features/host/host_home_screen.dart` — refactor: extract dashboard widgets into sub-module, slim down 641 lines
- `pubspec.yaml` — csv, file_saver

## Implementation steps

1. **Backend (service report):**
   ```python
   def revenue_report(db, host_id, period, date_str):
       year, month = parse(date_str)
       if period == "month":
           q = db.query(InvoiceLineItem.category, func.sum(InvoiceLineItem.amount)) \
                 .join(Invoice).filter(Invoice.host_id == host_id, extract('year', Invoice.period_start) == year, extract('month', Invoice.period_start) == month, Invoice.status == 'paid') \
                 .group_by(InvoiceLineItem.category)
           breakdown = {row[0]: float(row[1]) for row in q.all()}
           return {"total": sum(breakdown.values()), "breakdown": breakdown}
       # year case similar
   ```
2. **Backend (service occupancy):** For each Room in building (queried via Building.host_id), compute occupied_days = days in month where (status='occupied' OR contract active spans day) / total days in month.
3. **Backend (service ADR):** Phase 07 dependent; if no Reservation table yet, return null gracefully. After Phase 07: SUM(reservation.total_amount) / SUM(reservation.nights) = ADR; RevPAR = revenue / total_room_nights.
4. **Backend (service CSV export):**
   ```python
   def export_invoices_csv(db, host_id, month_str):
       def iter_csv():
           yield "Invoice#,Tenant,Room,Period,Total,Status,Paid At\n"
           q = db.query(Invoice).filter(...).order_by(Invoice.period_start)
           for inv in q:
               yield f"{inv.invoice_number},{inv.contract.tenants[0].full_name},{inv.contract.room.code},{inv.period_start}-{inv.period_end},{inv.total_amount},{inv.status},{inv.paid_at or ''}\n"
       return StreamingResponse(iter_csv(), media_type="text/csv", headers={"Content-Disposition": f"attachment; filename=invoices-{month_str}.csv"})
   ```
5. **Backend (service dashboard):**
   ```python
   def action_items(db, host_id):
       expiring = db.query(Contract).filter(Contract.host_id == host_id, Contract.status == 'active', Contract.end_date <= now() + timedelta(days=30)).limit(10).all()
       overdue_inv = db.query(Invoice).filter(Invoice.host_id == host_id, Invoice.status == 'sent', Invoice.due_date < now()).limit(10).all()
       overdue_kbtt = db.query(KhaiBaoTamTru).filter(KhaiBaoTamTru.host_id == host_id, KhaiBaoTamTru.declared_at.is_(None), KhaiBaoTamTru.check_in_at < now() - timedelta(hours=12)).limit(10).all()
       maintenance = db.query(Room).join(Building).filter(Building.host_id == host_id, Room.status == 'maintenance').limit(10).all()
       return {"expiring_contracts": [...], "overdue_invoices": [...], "overdue_khai_bao": [...], "maintenance_rooms": [...]}
   ```
6. **Backend (routers):** host_report.py (4 endpoints) + host_dashboard.py (1 endpoint) + extend host_invoice.py (add send-zalo-reminder).
7. **Backend (zalo template):** Extend `app/utils/zalo.py` with template functions.
8. **Backend (migration):** Index migration `0008_report_indexes.py`.
9. **Backend (tests):**
   - `test_revenue_report.py`: seed 3 paid invoices in July → revenue_report(2026-07) returns correct sum
   - `test_occupancy_report.py`: 5 rooms, 3 occupied 30 days, 2 vacant → occupancy = 60%
   - `test_csv_export.py`: GET CSV → response header `content-type: text/csv`, parse rows match
   - `test_dashboard_action_items.py`: seed expiring/overdue/maintenance → assert counts
10. **Backend (verify):** pytest green.
11. **Flutter (packages):** add csv + file_saver.
12. **Flutter (models):** 3 report models + dashboard model.
13. **Flutter (repos):** 2 api_*_repository files.
14. **Flutter (providers):** report_provider + dashboard_provider.
15. **Flutter (refactor host_home):** extract host_home_screen.dart logic into `dashboard/host_dashboard_screen.dart`. Original 641 lines → split into <200 line files.
16. **Flutter (dashboard widgets):** action_items_section, action_item_card, stats_summary_row.
17. **Flutter (reports screens):** reports_home + 3 detail + export_csv.
18. **Flutter (zalo integration):** In invoice_detail_screen tap "Nhắc qua Zalo" → fetch link → url_launcher → opens Zalo.
19. **Flutter (main):** register providers.
20. **Flutter (analyze):** 0 errors.
21. **E2E smoke:**
    - Host has 2 buildings 6 rooms 4 contracts 8 invoices (mix paid/sent/overdue), 2 khai báo overdue
    - Open dashboard → see 4 sections action items with counts
    - Tap "Báo cáo" → period 2026-07 → revenue table shows total + breakdown
    - Tap "Xuất CSV" → download file → open in Excel ok
    - Tap overdue invoice → "Nhắc qua Zalo" → opens Zalo with pre-filled message

## Todo list
- [ ] Backend: report_service with revenue + occupancy + adr + csv export
- [ ] Backend: dashboard_service action_items
- [ ] Backend: 2 new routers + extend host_invoice
- [ ] Backend: zalo.py template messages
- [ ] Backend: index migration
- [ ] Backend: 4 test files
- [ ] Flutter: csv + file_saver packages
- [ ] Flutter: 4 models
- [ ] Flutter: 2 repositories + 2 providers
- [ ] Flutter: extract dashboard sub-module from host_home (modularization)
- [ ] Flutter: dashboard widgets (action_items_section, card, stats)
- [ ] Flutter: reports sub-module (5 screens + 3 widgets)
- [ ] Flutter: Zalo integration in invoice_detail
- [ ] E2E smoke test

## Success criteria (testable)
- AC1 (G1): GET revenue?period=month&date=2026-07 returns total = sum of paid invoices in July, breakdown matches line items
- AC2 (G2): 5 rooms 3 occupied → occupancy = 60.0
- AC3 (G4): CSV export returns valid CSV, parseable by `csv` package
- AC4 (D5): dashboard action_items returns 4 categories with first 10 each, properly sorted (expiring soonest first, oldest overdue first)
- AC5 (Zalo): tap reminder → url_launcher opens `zalo.me/+84...?text=...` deep-link
- AC6 (modular): host_home_screen.dart < 200 lines after refactor (split into dashboard sub-module)
- AC7 (perf): revenue_report query <2s on host with 100 rooms (use EXPLAIN ANALYZE)
- Demo: full month-end ops workflow → reports → Zalo reminder → CSV export

## Risk assessment
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Report query slow without indexes | 60% | MED | Phase 06 includes index migration; benchmark before merge |
| Phase 07 ADR query references non-existent Reservation table | 100% (in Phase 06) | LOW | Graceful null return; full functionality after Phase 07 |
| CSV streaming memory for large datasets | 20% | LOW | Use generator pattern, not load all in memory; tested |
| Zalo deep-link not opening on iOS (URL scheme) | 30% | LOW | Use `https://zalo.me/...` format works both Android + iOS; url_launcher handles |
| Notification polling battery drain | 30% | LOW | Existing 5s poll is OK MVP; Phase 06+1 evaluate FCM |
| host_home_screen refactor breaks existing flows | 40% | MED | Keep all current functionality intact during extraction; smoke test viewing appointment flow |

## Security considerations
- All reports require_host + auto-filter host_id via repository
- CSV export does NOT include PII beyond what host already has access to (tenant name + amount only, no CCCD)
- Zalo deep-link: phone number in URL fragment (acceptable since host-initiated)
- Notification messages don't include sensitive data (amount OK, not CCCD)
- Audit log: GET reports endpoints DO NOT log to change_logs (read-only)

## Next steps
- Unblocks user-facing T2 polish goals
- Dependencies for next: Phase 07 ADR fully functional after Reservation data exists
- Future: FCM push notifications (defer post-launch)
