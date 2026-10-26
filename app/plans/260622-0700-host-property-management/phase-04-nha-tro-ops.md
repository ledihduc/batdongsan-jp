---
title: "Phase 04 — Nhà trọ Ops: Invoice / Payment / Meter / Move-out Prorate"
description: "Invoice immutable after paid, manual generate button, debt aging, move-out prorate, deposit refund, credit notes"
status: pending
priority: P1
effort: 8-10d
branch: TBD
tags: [backend, flutter, nha-tro, invoice, payment, meter]
created: 2026-06-22
---

# Phase 04 — Nhà trọ Ops

**Sized:** 8–10d
**Status:** ⏸ Pending (Ready)
**Blocks:** 06 (Reports needs invoice data), 08 (marketplace integration needs full ops loop)
**Blocked by:** 03 (Contract model required)

## Context links
- BA doc §4 D (Hóa đơn), C5 (move-out prorate), §5 AC (immutable after paid, debt aging buckets), §9 D3 (HTML public-link UUID), D4 (manual button no cron), Q5 (audit trail)
- Research: `researcher-backend-audit.md` §1 missing models
- Code files affected: `app/models.py`, `app/routers/host_invoice.py` (new), `app/services/invoice_service.py` (new), `lib/features/host/billing/` (new sub-module)

## Overview
Đóng vòng tròn ops nhà trọ: tạo hoá đơn tháng (manual button, không cron) → nhập số điện/nước per room → preview line items → host tap "Tạo hoá đơn cho cả dãy" → invoices generated → public-link UUID share Zalo → host mark paid → debt aging report. Move-out prorate logic for partial month. Credit Notes cho adjustment.

## Key insights from research
- BA D3 sealed: HTML public-link với UUID token là primary, PDF defer
- BA D4 sealed: manual button "Tạo hoá đơn tháng X", KHÔNG cron job (avoid APScheduler complexity for MVP)
- Invoice immutable after `paid`: ANY edit → must create `CreditNote` record, original Invoice locked
- Debt aging buckets: 0-30 days / 30-60 / >60 (queried at view time, không pre-compute)
- Move-out C5: prorate rent by day, final meter reading, deposit refund or deduction
- Audit Phase 02 `change_logs` includes Invoice mutations

## Requirements

### Functional (from BA user stories)
- **D1:** Manual button "Tạo hoá đơn tháng X" cho cả dãy → AC: POST `/api/host/invoices/generate-batch` body: {building_id, month: "2026-07"}, returns list of drafts
- **D2:** View invoice với line items → AC: GET `/api/host/invoices/{id}` returns rent + electricity + water + services + total; share via Zalo deep-link + public UUID link
- **D3:** Mark paid → AC: PATCH `/api/host/invoices/{id}/pay`, body: {amount, method: 'cash'|'bank_transfer', note}, Invoice locked
- **D4:** Debt aging report → AC: GET `/api/host/invoices/debt-aging` returns buckets {0-30d, 30-60d, >60d} with total amounts
- **D5:** Dashboard "cần nhắn" list → AC: GET `/api/host/invoices/needs-reminder` returns rooms with unpaid invoices sorted by days overdue
- **C5 (Move-out prorate):** PATCH `/api/host/contracts/{id}/terminate` triggers final invoice → AC: prorate rent (actual_end_date - last_invoice_end_date / 30), final meter reading, deposit refund_amount line item

### Non-functional
- Invoice generation idempotent: same (contract, month) → only 1 draft
- Public-link UUID expires 90 days after invoice created
- All Invoice mutations write change_logs

## Architecture

### Backend

**New models:**

| Model | Fields | Notes |
|---|---|---|
| `Invoice` | id, host_id (FK), contract_id (FK), invoice_number STR unique, period_start, period_end, issued_date, due_date, status ENUM('draft','sent','paid','overdue','cancelled'), total_amount, paid_amount, paid_at NULL, public_token UUID unique, public_token_expires_at, created_at | Immutable after paid; cancelled used for full-void replacement |
| `InvoiceLineItem` | id, invoice_id (FK), category ENUM('rent','electricity','water','service','deposit_refund','damage_deduction','adjustment'), description, quantity, unit_price, amount, sort_order | Children of Invoice |
| `Payment` | id, host_id (FK), invoice_id (FK), amount, method ENUM('cash','bank_transfer','other'), paid_at, note, created_at | Multiple payments allowed for partial pay; status='paid' when sum >= total |
| `MeterReading` | id, host_id (FK), room_id (FK), reading_date, electricity_kwh, water_m3, note, created_at | History per room per period |
| `ServiceFee` | id, host_id (FK), building_id (FK), name, unit_price, billing_cycle ENUM('monthly','one_time'), is_active, created_at | E.g., Internet, Cleaning, Parking |
| `ContractServiceFee` (pivot) | contract_id (FK), service_fee_id (FK), monthly_amount | Per-contract opt-in |
| `CreditNote` | id, host_id (FK), original_invoice_id (FK), amount, reason, issued_date, created_at | Adjustment after invoice paid |

**New endpoints:**

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/api/host/meter-readings?room_id=&period_start=` | require_host | History |
| POST | `/api/host/meter-readings` | require_host | Record reading |
| GET | `/api/host/service-fees?building_id=` | require_host | List |
| POST | `/api/host/service-fees` | require_host | Create |
| POST | `/api/host/contracts/{id}/service-fees` | require_host | Attach service to contract |
| GET | `/api/host/invoices?status=&contract_id=&month=` | require_host | List |
| GET | `/api/host/invoices/{id}` | require_host + owner | Detail with line items |
| POST | `/api/host/invoices/generate-batch` | require_host | Generate drafts for building+month |
| POST | `/api/host/invoices/{id}/preview-recalc` | require_host | Re-calc draft after meter reading changes |
| PATCH | `/api/host/invoices/{id}/send` | require_host + owner | draft→sent, generate public_token expires +90d |
| PATCH | `/api/host/invoices/{id}/pay` | require_host + owner | Record Payment, sum check → status=paid, lock |
| POST | `/api/host/invoices/{id}/credit-note` | require_host + owner + invoice.status=paid | CreditNote for adjustment |
| GET | `/api/host/invoices/debt-aging` | require_host | Bucket aggregation |
| GET | `/api/host/invoices/needs-reminder` | require_host | Sorted overdue list |
| GET | `/public/invoices/{token}` | NO AUTH | Render HTML view; check token expiry |
| GET | `/api/host/invoices/{id}/zalo-link` | require_host + owner | Returns `zalo.me/{phone}?text=...` deep-link string |

**Services:**

- `app/services/invoice_service.py`:
  - `generate_batch(building_id, month, host_id)` — for each active Contract in building, create draft Invoice with line items (rent from contract.monthly_rent, electricity from MeterReading diff, water diff, service fees attached)
  - `recalculate_draft(invoice_id, host_id)` — re-sum line items
  - `send_invoice(invoice_id)` — issue public_token UUID
  - `record_payment(invoice_id, amount, method)` — append Payment row, check sum, lock if fully paid, audit
  - `create_credit_note(invoice_id, amount, reason)` — CreditNote row
- `app/services/move_out_invoice_service.py`:
  - `generate_final_invoice(contract, actual_end_date, deposit_refund_amount, damage_deduction)` — prorate rent (days_used/30 * monthly), final meter, deposit refund (negative amount), damage deduction (positive). Returns Invoice.

**Migration:** `alembic/versions/0006_nha_tro_ops.py` — 7 tables + UUID column + indexes

**Schemas:** `app/schemas/invoice.py`, `meter_reading.py`, `payment.py`, `service_fee.py`, `credit_note.py`

### Flutter

**New sub-module `lib/features/host/billing/`:**

```
lib/features/host/billing/
├── screens/
│   ├── meter_reading_screen.dart           # Grid: rooms × inputs
│   ├── invoice_batch_generate_screen.dart  # Building + month picker
│   ├── invoice_list_screen.dart            # Filter status
│   ├── invoice_detail_screen.dart          # Line items + actions
│   ├── invoice_pay_screen.dart             # Record payment
│   ├── credit_note_form_screen.dart
│   ├── debt_aging_screen.dart
│   └── service_fee_list_screen.dart
├── widgets/
│   ├── invoice_status_badge.dart
│   ├── invoice_line_item_row.dart
│   ├── meter_reading_input_row.dart
│   └── debt_aging_chart.dart  # Table view MVP per BA
└── providers/
    ├── invoice_provider.dart
    ├── meter_reading_provider.dart
    └── service_fee_provider.dart
```

**Utility:**
- `lib/core/utils/zalo_deep_link.dart` — builder fn `buildZaloShareLink(phone, message)` returning `https://zalo.me/{phone}?text=...`

**Packages:**
- `share_plus: ^10.0.0` — share invoice link to Zalo/SMS/Email
- `url_launcher: ^6.3.0` — open zalo deep-link

### Data flow

```
Host: end of month → tap "Tạo hoá đơn tháng 7"
InvoiceBatchGenerateScreen → pick building + month
  ↓ enter meter readings (one row per room)
POST /api/host/meter-readings (batch)
  ↓ tap "Tạo hoá đơn"
POST /api/host/invoices/generate-batch → backend creates N drafts (1 per active contract)
  ↓ Flutter navigates to InvoiceListScreen filtered by status=draft, month=2026-07
  ↓ host reviews + tap "Gửi"
PATCH /api/host/invoices/{id}/send → token issued, status=sent
  ↓ tap "Chia sẻ qua Zalo"
GET /api/host/invoices/{id}/zalo-link → opens zalo.me/{tenantPhone}?text=...
Tenant clicks public link → GET /public/invoices/{token} → HTML invoice view
  ↓ host receives payment
PATCH /api/host/invoices/{id}/pay → Payment row, sum check, lock if full
```

Move-out (continuing from Phase 03 C5 terminate trigger):
```
Phase 03 contract_service.terminate_contract() → calls move_out_invoice_service.generate_final_invoice()
  ↓ creates Invoice with line items:
    - "Tiền nhà (X ngày)" prorate
    - "Tiền điện cuối kỳ" (final meter)
    - "Tiền nước cuối kỳ"
    - "Hoàn trả cọc" (negative amount)
    - "Khấu trừ hư hại" (positive, optional)
  ↓ status=sent, public_token issued
```

## Related code files

### Backend new files
- `backend/app/repositories/invoice_repository.py`
- `backend/app/repositories/meter_reading_repository.py`
- `backend/app/repositories/payment_repository.py`
- `backend/app/repositories/service_fee_repository.py`
- `backend/app/services/invoice_service.py`
- `backend/app/services/move_out_invoice_service.py`
- `backend/app/routers/host_invoice.py`
- `backend/app/routers/host_meter_reading.py`
- `backend/app/routers/host_service_fee.py`
- `backend/app/routers/public_invoice.py` — `/public/invoices/{token}` HTML render
- `backend/app/schemas/invoice.py`, `meter_reading.py`, `payment.py`, `service_fee.py`, `credit_note.py`
- `backend/app/templates/invoice_public.html` — Jinja2 template for HTML rendering
- `backend/app/utils/zalo.py` — `build_zalo_link(phone, message)`
- `backend/alembic/versions/0006_nha_tro_ops.py`
- `backend/tests/test_invoice_generate_batch.py`
- `backend/tests/test_invoice_immutable_after_paid.py`
- `backend/tests/test_move_out_prorate.py`
- `backend/tests/test_debt_aging.py`
- `backend/tests/test_public_invoice_link.py`

### Backend modified files
- `backend/app/models.py` — add 7 model classes
- `backend/app/services/contract_service.py` — call `move_out_invoice_service` in terminate flow
- `backend/main.py` — include 3 new routers + public router
- `backend/requirements.txt` — add `jinja2` (HTML template)

### Flutter new files
See sub-module above (~20 files).

### Flutter modified files
- `lib/main.dart` — add 3 providers
- `lib/features/host/host_home_screen.dart` — add "Hoá đơn" + "Công nợ" dashboard widgets
- `pubspec.yaml` — share_plus, url_launcher

## Implementation steps

1. **Backend (models):** Add 7 models to `app/models.py` with all fields, enums, indexes.
2. **Backend (migration):** `alembic revision -m "nha_tro_ops"`. Manual table CREATEs. Unique index on `(contract_id, period_start, period_end)` for Invoice to prevent dup-month drafts. UUID column for `public_token`.
3. **Backend (schemas):** 5 schema files Pydantic.
4. **Backend (repos):** 4 repository files.
5. **Backend (service invoice):**
   - `generate_batch(building_id, month_str, host_id)`:
     - For each active Contract under building:
       - Get last MeterReading for room → compute electricity_kwh, water_m3 diff with previous month
       - Build line items: rent (contract.monthly_rent), electricity (kwh × unit_price from ServiceFee), water (m3 × unit_price), each ContractServiceFee
       - Sum total
       - Create Invoice (status=draft, period_start=month_first_day, period_end=last_day, due_date=+7d) + LineItems
       - Skip if already exists for (contract, period)
     - Return list
   - `record_payment(invoice_id, amount, method, host_id)`:
     - Validate invoice not cancelled
     - Append Payment row
     - Sum all Payments; if >= total → set status=paid, paid_at=now, lock
     - Write change_logs row
6. **Backend (service move_out):** `generate_final_invoice(contract, actual_end_date, deposit_refund_amount, damage_deduction_amount)`:
   - Calc days_used = (actual_end_date - period_start).days
   - Prorate rent: (days_used / 30) * monthly_rent
   - Get last meter reading vs latest → final electricity + water
   - Line items: rent_prorate, electricity, water, ServiceFees, deposit_refund (negative), damage_deduction
   - Total = sum
   - Invoice status=sent, public_token issued
7. **Backend (utility zalo):** `app/utils/zalo.py`:
   ```python
   def build_zalo_share_link(phone: str, message: str) -> str:
       from urllib.parse import quote
       phone_clean = phone.lstrip('+').lstrip('84').lstrip('0')
       return f"https://zalo.me/+84{phone_clean}?text={quote(message)}"
   ```
8. **Backend (template):** Create `app/templates/invoice_public.html` Jinja2: header, line items table, total, payment instructions placeholder, footer.
9. **Backend (public router):** `app/routers/public_invoice.py`:
   - `GET /public/invoices/{token}` — query by public_token, check `public_token_expires_at > now`, render HTML via Jinja2. NO auth.
10. **Backend (host router invoice):** 9 endpoints (list/detail/generate-batch/send/pay/credit-note/debt-aging/needs-reminder/zalo-link).
11. **Backend (host router meter):** CRUD meter readings.
12. **Backend (host router service_fee):** CRUD service fees + attach to contract.
13. **Backend (integrate move-out):** Update Phase 03 `contract_service.terminate_contract` to call `move_out_invoice_service.generate_final_invoice` after Contract status updated.
14. **Backend (tests):** 5 test files:
    - `test_invoice_generate_batch`: building with 3 active contracts → batch generates 3 drafts; re-run idempotent (still 3)
    - `test_invoice_immutable_after_paid`: PATCH /pay → success, second PATCH /pay → 400 "already paid"; line item edit attempt → 400
    - `test_move_out_prorate`: contract starts 2026-07-01 monthly_rent=3M, terminate 2026-07-15 → final invoice rent = 1.5M (15/30 days)
    - `test_debt_aging`: 3 invoices issued 5d/35d/65d ago all unpaid → buckets {0-30:1, 30-60:1, >60:1}
    - `test_public_invoice_link`: GET /public/invoices/{valid_token} → 200 HTML; expired token → 410 Gone
15. **Backend (verify):** `pytest tests/test_*` → green.
16. **Flutter (packages):** `flutter pub add share_plus url_launcher`.
17. **Flutter (utility):** `lib/core/utils/zalo_deep_link.dart` builder.
18. **Flutter (models):** invoice_model, meter_reading_model, payment_model, service_fee_model, credit_note_model.
19. **Flutter (repos):** 4 api_*_repository files.
20. **Flutter (providers):** invoice_provider, meter_reading_provider, service_fee_provider.
21. **Flutter (screens):** 8 screens. Key UX:
    - `meter_reading_screen`: per-room input row with "previous reading" pre-filled, calc diff inline
    - `invoice_batch_generate_screen`: month picker + building dropdown + preview list before commit
    - `invoice_detail_screen`: line items table + actions: Send/Share Zalo/Mark Paid/Credit Note (if paid)
    - `debt_aging_screen`: table 3 buckets with rooms + amounts (chart defer per BA)
22. **Flutter (widgets):** invoice_status_badge, line_item_row, meter_input_row, debt aging table.
23. **Flutter (host_home):** add "Hoá đơn tháng" entry + "Công nợ" widget showing total debt amount.
24. **Flutter (main):** register 3 providers.
25. **Flutter (analyze):** 0 errors.
26. **E2E smoke:** 
    - Host has 1 building 3 rooms 3 active contracts
    - Tap "Tạo hoá đơn tháng 7" → meter input → generate 3 drafts
    - Tap 1 draft → review → Send → Share Zalo (opens app) → public link opens HTML invoice
    - Tap "Đánh dấu đã thu" → invoice paid, locked
    - View Debt Aging → shows 2 unpaid in 0-30d bucket

## Todo list
- [ ] Backend: 7 models in models.py
- [ ] Backend: alembic 0006 migration
- [ ] Backend: 5 schemas
- [ ] Backend: 4 repositories
- [ ] Backend: invoice_service (generate_batch, record_payment, etc.)
- [ ] Backend: move_out_invoice_service
- [ ] Backend: zalo.py utility
- [ ] Backend: invoice_public.html template
- [ ] Backend: public_invoice router (no auth, render HTML)
- [ ] Backend: host_invoice router (9 endpoints)
- [ ] Backend: host_meter_reading + host_service_fee routers
- [ ] Backend: integrate move_out into Phase 03 contract_service.terminate
- [ ] Backend: 5 test files
- [ ] Flutter: share_plus + url_launcher packages
- [ ] Flutter: zalo_deep_link utility
- [ ] Flutter: 5 models + 4 repositories + 3 providers
- [ ] Flutter: 8 billing screens + 4 widgets
- [ ] Flutter: host_home integration (hoá đơn + công nợ widgets)
- [ ] E2E smoke test full month-end flow

## Success criteria (testable)
- AC1 (D1 manual gen): POST generate-batch creates N drafts (N=active contracts in building); re-run no duplicates
- AC2 (D2 invoice detail): GET returns line items + total = sum line items
- AC3 (D2 Zalo): GET zalo-link returns `zalo.me/+84{phone}?text=...` URL string
- AC4 (D2 public link): GET /public/invoices/{token} returns 200 HTML; expired/invalid token → 410/404
- AC5 (D3 immutability): paid invoice PATCH line items → 400; second PATCH /pay → 400
- AC6 (D4 debt aging): 3 unpaid invoices at different ages → bucketed correctly
- AC7 (D5 needs reminder): sorted overdue list by days_overdue DESC
- AC8 (C5 prorate): terminate mid-month → final invoice rent_amount = (days_used/30) × monthly_rent (within ±1 VND rounding)
- AC9 (audit): payment recording writes change_logs row
- AC10 (credit note): paid invoice POST /credit-note creates row; original invoice still status=paid
- Demo: end-to-end month flow as E2E smoke

## Risk assessment
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Meter reading data gap (no previous reading) | 60% | MED | Allow manual `electricity_kwh_used` override in generate-batch payload |
| Decimal precision (VND) for prorate | 40% | LOW | Use `Decimal` not float; round to whole VND |
| Public token guessing attack | 10% | MED | UUIDv4 secure random; 90d expiry; rate-limit /public route via slowapi |
| Service fee unit_price changes mid-period | 30% | MED | Snapshot unit_price at line item creation (denormalize); document |
| Move-out triggered before final meter reading | 50% | HIGH | Backend validation: terminate flow accepts optional `final_electricity_kwh`, `final_water_m3` in payload; if missing, use last reading and warn |
| Concurrent payment recording | 5% | LOW | DB transaction + row lock on Invoice when computing sum; rare in single-host scenario |

## Security considerations
- All host endpoints `require_host` + repository auto-filter host_id
- Public invoice route `/public/invoices/{token}`: NO auth but token is UUIDv4 secret; expires 90d; rate-limit via slowapi
- Invoice template HTML: escape all user data (Jinja2 autoescape on)
- Audit: every Invoice/Payment/CreditNote mutation writes change_logs (Phase 02 table)
- PDPL: invoice HTML may show tenant CCCD masked (last 4 digits only); full CCCD only in DB

## Next steps
- Unblocks Phase 06 (Reports queries invoice data)
- Unblocks Phase 08 (marketplace draft contract → invoice flow)
- Dependencies for next: KhaiBaoTamTru (Phase 05) is parallel, doesn't depend on Phase 04
