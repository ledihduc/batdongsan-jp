---
title: "Phase 05 — Khai báo tạm trú: HTML public-link UUID + 12h reminder + roommates per-record"
description: "Form generator + reminder workflow VN moat — host avoids 3-20M VND fine"
status: pending
priority: P1
effort: 4-5d
branch: TBD
tags: [backend, flutter, compliance, khai-bao-tam-tru, vn-specific]
created: 2026-06-22
---

# Phase 05 — Khai báo tạm trú

**Sized:** 4–5d
**Status:** ⏸ Pending (Ready)
**Blocks:** 06 (Reports show declaration status)
**Blocked by:** 03 (Tenant model required)

## Context links
- BA doc §3 (pháp lý 12h deadline), §4 F (F1-F4), §5 AC (khai báo deadline visibility), §6 (defer API gov + PDF), §9 D3 (HTML public-link), D2 (roommates per-record), §9c (KhaiBaoTamTru schema with public_token)
- Research: `researcher-backend-audit.md` §1 (missing model), `researcher-postgres-migration.md` (UUID column pattern)
- Code files affected: `app/models.py`, `app/routers/host_khai_bao.py` (new), `app/routers/public_khai_bao.py` (new), `lib/features/host/khaibao/` (new sub-module)

## Overview
VN-specific differentiation moat. Khi tạo Contract (nhà trọ) hoặc Reservation (homestay, Phase 07) → tạo `KhaiBaoTamTru` record per Tenant với public_token UUIDv4. Host nhìn dashboard "X khách chưa khai báo" + 12h deadline countdown. Tap row → mở HTML public-link → host print/screenshot → nộp tại bocongan.gov.vn hoặc VNeID app. Tap "Đã khai báo" → mark done.

## Key insights from research
- BA F4 defer: KHÔNG auto-submit gov API (chờ partner)
- D3 sealed: HTML primary, PDF download tuỳ chọn → fallback browser print-to-PDF
- D2 sealed: M:N roommates → mỗi co-tenant 1 record KhaiBaoTamTru riêng (1 contract có N records nếu N tenant)
- Deadline 12h sau check-in (24h vùng xa, áp dụng đồng nhất 12h cho MVP — conservative)
- HTML template generates form theo mẫu Bộ CA (TK1) — pre-filled từ Tenant + HostProfile data
- Dashboard widget: "X chưa khai báo, Y quá hạn 12h" (red badge)

## Requirements

### Functional (from BA user stories)
- **F1:** Tạo Contract (nhà trọ) hoặc Reservation (homestay Phase 07) → auto-create KhaiBaoTamTru records per Tenant → AC: POST contract triggers KhaiBaoTamTru create rows for all tenants, host gets dashboard badge
- **F2:** 12h deadline reminder → AC: 12h after `check_in_at`, status='overdue' nếu chưa declared, badge đỏ + dashboard banner
- **F3:** Host nhiều căn batch view → AC: GET `/api/host/khai-bao?status=pending|overdue` returns sorted list
- **F4:** Defer (gov API integration)

### Non-functional
- Public-link UUID secret, expires 30d
- HTML render mobile-friendly (host xem trên điện thoại + zoom OK)
- No PII leaked in URL path (UUID only, no name/cccd)

## Architecture

### Backend

**New model:**

| Field | Type | Notes |
|---|---|---|
| id | INT PK | |
| host_id | FK User | Indexed for filter |
| tenant_id | FK Tenant | One record per tenant |
| contract_id | FK Contract NULL | For nhà trọ |
| reservation_id | FK Reservation NULL | For homestay (Phase 07) |
| check_in_at | DATETIME | From Contract.start_date OR Reservation.check_in_date |
| declared_at | DATETIME NULL | When host marks done |
| status | ENUM('pending','declared','overdue','skipped') | Computed at query time but persisted for index |
| public_token | UUIDv4 unique | Secret URL |
| public_token_expires_at | DATETIME | check_in_at + 30d |
| created_at | DATETIME | |

**Status logic:**
- `pending`: declared_at IS NULL AND now < check_in_at + 12h
- `overdue`: declared_at IS NULL AND now >= check_in_at + 12h
- `declared`: declared_at IS NOT NULL
- `skipped`: host manually skipped (e.g., guest left early)

Persist `status` column with periodic batch update OR compute on read (MVP: compute on read, no cron per D4).

**New endpoints:**

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/api/host/khai-bao?status=&building_id=` | require_host | Filter pending/overdue |
| GET | `/api/host/khai-bao/{id}` | require_host + owner | Detail with tenant + contract/reservation |
| PATCH | `/api/host/khai-bao/{id}/declared` | require_host + owner | Mark declared, set declared_at |
| PATCH | `/api/host/khai-bao/{id}/skipped` | require_host + owner | Skip with reason (early move-out) |
| POST | `/api/host/khai-bao` | require_host | Manual create (rare; auto-created from Contract trigger) |
| GET | `/public/khai-bao/{token}` | NO AUTH | Render HTML form view |
| GET | `/api/host/khai-bao/dashboard-summary` | require_host | Counts: pending, overdue |

**Service:**

- `app/services/khai_bao_service.py`:
  - `auto_create_for_contract(contract, db)` — called from `contract_service.create_contract`; for each Tenant in pivot, create 1 KhaiBaoTamTru row (idempotent)
  - `auto_create_for_reservation(reservation, db)` — Phase 07 calls
  - `compute_status_now(record)` — returns enum based on check_in_at + declared_at
  - `mark_declared(record_id, host_id, db)` — set declared_at, audit log

**HTML template:** `app/templates/khai_bao_tam_tru.html` Jinja2:
- Pre-filled form mẫu TK1 (Bộ CA):
  - Hosting address (HostProfile)
  - Host info (name, CCCD, phone)
  - Guest info (Tenant fields)
  - Check-in date + expected duration
- Print-friendly CSS (A4 layout)
- Footer: instructions to submit at http://tbltkbtt.bocongan.gov.vn/ or VNeID app

**Migration:** `alembic/versions/0007_khai_bao_tam_tru.py`

**Schemas:** `app/schemas/khai_bao_tam_tru.py`

### Flutter

**New sub-module `lib/features/host/khaibao/`:**

```
lib/features/host/khaibao/
├── screens/
│   ├── khaibao_list_screen.dart       # Tabs: Pending / Overdue / Declared / All
│   └── khaibao_detail_screen.dart      # View form preview + actions
├── widgets/
│   ├── khaibao_status_badge.dart       # Color by status
│   └── khaibao_deadline_countdown.dart # "Còn 4h 32m"
└── providers/
    └── khaibao_provider.dart
```

**Dashboard widget (host_home_screen.dart):**
- Banner đỏ nếu có overdue: "⚠ X khách quá hạn khai báo tạm trú — xem ngay"
- Counter: "Pending: X | Quá hạn: Y"

**Packages:** No new packages; reuse `url_launcher` (Phase 04) for opening public-link in external browser.

### Data flow

```
[Auto-create]
Phase 03: POST /api/host/contracts → contract_service.create_contract()
  → khai_bao_service.auto_create_for_contract(contract)
    → For each Tenant in pivot: INSERT KhaiBaoTamTru(host_id, tenant_id, contract_id, check_in_at=contract.start_date, public_token=uuid4(), expires=+30d)

[Host workflow]
Host opens app → host_home_screen dashboard banner shows "3 quá hạn"
  ↓ tap banner
KhaiBaoListScreen → filter status='overdue'
  ↓ tap row
KhaiBaoDetailScreen → preview tenant info + countdown
  ↓ tap "Xem form khai báo"
url_launcher opens https://app-domain/public/khai-bao/{token} in browser
  → HTML form mẫu TK1 pre-filled
Host taps Print (browser native) → screenshot or saves PDF → submits at bocongan.gov.vn or VNeID app
  ↓ back in app, tap "Đã khai báo"
PATCH /api/host/khai-bao/{id}/declared → status='declared', dashboard counter updates
```

## Related code files

### Backend new files
- `backend/app/repositories/khai_bao_repository.py`
- `backend/app/services/khai_bao_service.py`
- `backend/app/routers/host_khai_bao.py`
- `backend/app/routers/public_khai_bao.py`
- `backend/app/schemas/khai_bao_tam_tru.py`
- `backend/app/templates/khai_bao_tam_tru.html`
- `backend/alembic/versions/0007_khai_bao_tam_tru.py`
- `backend/tests/test_khai_bao_auto_create.py`
- `backend/tests/test_khai_bao_status_computation.py`
- `backend/tests/test_khai_bao_public_link.py`
- `backend/tests/test_khai_bao_roommates.py`

### Backend modified files
- `backend/app/models.py` — add KhaiBaoTamTru class
- `backend/app/services/contract_service.py` — call `khai_bao_service.auto_create_for_contract`
- `backend/main.py` — include 2 new routers (host + public)

### Flutter new files
- `lib/data/models/khai_bao_model.dart`
- `lib/data/repositories/api_khai_bao_repository.dart`
- `lib/domain/repositories/i_khai_bao_repository.dart`
- `lib/providers/khaibao_provider.dart`
- `lib/features/host/khaibao/screens/khaibao_list_screen.dart`
- `lib/features/host/khaibao/screens/khaibao_detail_screen.dart`
- `lib/features/host/khaibao/widgets/khaibao_status_badge.dart`
- `lib/features/host/khaibao/widgets/khaibao_deadline_countdown.dart`

### Flutter modified files
- `lib/main.dart` — add KhaiBaoProvider
- `lib/features/host/host_home_screen.dart` — dashboard banner + counter

## Implementation steps

1. **Backend (model):** Add KhaiBaoTamTru class to `app/models.py` with UUID column (use `from sqlalchemy.dialects.postgresql import UUID` or generic UUID type).
2. **Backend (migration):** `alembic revision -m "khai_bao_tam_tru"`. Indexes on host_id+status, public_token unique, contract_id+tenant_id composite for idempotency check.
3. **Backend (schema):** Pydantic schemas (Create, Update, Response).
4. **Backend (repository):** `khai_bao_repository.py` extends HostScopedRepository.
5. **Backend (service):**
   ```python
   def auto_create_for_contract(contract, db):
       for ct in contract.contract_tenants:  # M:N pivot rows
           existing = db.query(KhaiBaoTamTru).filter_by(contract_id=contract.id, tenant_id=ct.tenant_id).first()
           if existing: continue
           record = KhaiBaoTamTru(
               host_id=contract.host_id,
               tenant_id=ct.tenant_id,
               contract_id=contract.id,
               check_in_at=contract.start_date,
               public_token=uuid.uuid4(),
               public_token_expires_at=contract.start_date + timedelta(days=30),
               status='pending'
           )
           db.add(record)
       db.commit()
   ```
6. **Backend (service compute):** `compute_status_now(record)` returns enum: if `declared_at` → declared; elif now > check_in + 12h → overdue; else pending. Apply in GET response transformer.
7. **Backend (integrate Phase 03):** Edit `contract_service.create_contract` end: `khai_bao_service.auto_create_for_contract(new_contract, db)`.
8. **Backend (router host):** 6 endpoints (list, detail, mark declared, mark skipped, manual create, dashboard summary).
9. **Backend (router public):**
   ```python
   @router.get("/public/khai-bao/{token}", response_class=HTMLResponse)
   def view_khai_bao_public(token: str, db: Session = Depends(get_db)):
       record = db.query(KhaiBaoTamTru).filter_by(public_token=token).first()
       if not record: raise HTTPException(404)
       if record.public_token_expires_at < now_utc(): raise HTTPException(410, "Link hết hạn")
       return templates.TemplateResponse("khai_bao_tam_tru.html", {
           "request": request, "record": record, "tenant": ..., "host": ..., "contract": ...
       })
   ```
10. **Backend (template):** `khai_bao_tam_tru.html` mẫu TK1 với print CSS. Fields: tên chủ nhà, địa chỉ nhà, CCCD chủ nhà, tên khách thuê, CCCD khách, ngày sinh, quê quán, ngày check-in, dự kiến ở tới ngày. Instructions footer.
11. **Backend (tests):**
    - `test_khai_bao_auto_create.py`: create contract with 2 tenants → assert 2 KhaiBaoTamTru rows
    - `test_khai_bao_status_computation.py`: simulate now > check_in+12h → status='overdue'
    - `test_khai_bao_public_link.py`: valid token → 200 HTML; expired → 410; invalid → 404
    - `test_khai_bao_roommates.py`: 3 roommates contract → 3 records all status pending
12. **Backend (verify):** pytest green.
13. **Flutter (model):** `khai_bao_model.dart`.
14. **Flutter (repo + provider):** Standard pattern.
15. **Flutter (widgets):**
    - `khaibao_status_badge.dart` — color: pending=gray, overdue=red, declared=green
    - `khaibao_deadline_countdown.dart` — Timer.periodic 1min update "Còn Xh Ym" hoặc "Quá hạn Xh"
16. **Flutter (screens):**
    - `khaibao_list_screen.dart` — TabBar 4 tabs filter by status
    - `khaibao_detail_screen.dart` — tenant info preview + "Xem form khai báo" (url_launcher) + "Đã khai báo" button
17. **Flutter (host_home):** Add dashboard banner + counter widget. Banner red nếu overdue > 0.
18. **Flutter (main):** Register KhaiBaoProvider.
19. **Flutter (analyze):** 0 errors.
20. **E2E smoke:**
    - Phase 03 flow: create contract with 2 tenants → backend auto-create 2 KhaiBaoTamTru
    - Dashboard shows badge "2 pending"
    - Tap → list → 2 rows pending with countdown
    - Tap row → detail → "Xem form khai báo" → browser opens HTML form pre-filled
    - Tap "Đã khai báo" → status declared → list updates → dashboard counter -1
    - Simulate check_in_at - 13h: pending → overdue (red badge)

## Todo list
- [ ] Backend: KhaiBaoTamTru model
- [ ] Backend: alembic 0007 migration
- [ ] Backend: schema + repository
- [ ] Backend: khai_bao_service with auto_create + status computation
- [ ] Backend: integrate auto_create into contract_service.create_contract
- [ ] Backend: host router (6 endpoints) + public router
- [ ] Backend: HTML template TK1 form
- [ ] Backend: 4 test files
- [ ] Flutter: model + repository + provider
- [ ] Flutter: status_badge + countdown widgets
- [ ] Flutter: list + detail screens
- [ ] Flutter: host_home dashboard banner + counter
- [ ] E2E smoke test

## Success criteria (testable)
- AC1 (auto-create): contract with 3 tenants → 3 KhaiBaoTamTru rows immediately
- AC2 (deadline visibility): simulate now = check_in + 13h, declared_at IS NULL → status='overdue' returned by GET
- AC3 (public link): GET /public/khai-bao/{valid_token} → 200 HTML with pre-filled fields; expired → 410
- AC4 (mark declared): PATCH /declared → declared_at set, status='declared', dashboard counter updates
- AC5 (M:N roommates): contract 2 primary + 2 co-tenants → 4 records all created
- AC6 (dashboard): host with 2 overdue → banner shows red "⚠ 2 quá hạn"
- AC7 (no PII in URL): public URL contains only UUID; tenant name/CCCD only in rendered HTML
- AC8 (isolation): Host A queries /api/host/khai-bao → only A's records
- Demo: create contract → see dashboard → open form → click "Đã khai báo"

## Risk assessment
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Status computation drift (manual mark + computed status conflict) | 30% | LOW | Compute at read time using declared_at; don't persist status column or update via trigger |
| HTML form mẫu TK1 không khớp form gov | 50% | MED | Use TK1 latest version (research Bộ CA website 2025-2026); document version in template; allow PDF export defer |
| Public link guessing / scraping | 5% | LOW | UUIDv4 secure random; rate-limit /public route; 30d expiry |
| Foreigner guest (English) khai báo | 30% | LOW | English template defer per BA §6; document as known limitation |
| Reservation auto-create (Phase 07) not yet integrated | 100% | LOW | Phase 05 only handles Contract trigger; Phase 07 adds Reservation trigger |
| Timezone for 12h deadline | 20% | MED | Use UTC consistently; display in VN time (UTC+7) on Flutter |

## Security considerations
- Public route NO auth, but UUID secret token (entropy 122 bits)
- HTML template Jinja2 autoescape ON (no XSS even if tenant name has special chars)
- Token expires 30d after check-in to limit window
- Rate-limit /public/khai-bao/* via slowapi (max 30 req/min per IP)
- PDPL: HTML form shows full CCCD (required for gov form) — acceptable since only host can access link, but warn host not to share publicly
- Audit log: mark_declared writes to `change_logs` for dispute prevention

## Next steps
- Unblocks Phase 06 (reports include declaration compliance stats)
- Unblocks Phase 07 (Reservation auto-create extension)
- Dependencies for next: nothing critical; Phase 06 parallel-ready
