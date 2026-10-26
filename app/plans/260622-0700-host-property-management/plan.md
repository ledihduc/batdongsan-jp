---
title: "Quản lý Nhà trọ & Homestay cho Host"
description: "9-phase plan: foundation + nhà trọ ops + homestay calendar + khai báo tạm trú + marketplace integration"
status: in-progress
priority: P1
effort: 10.5-13 weeks (52-66d dev + 15% buffer)
branch: TBD
tags: [host, nha-tro, homestay, full-feature]
created: 2026-06-22
updated: 2026-06-28
---

# Plan: Quản lý Nhà trọ & Homestay cho Host

**Slug:** host-property-management
**Owner:** TBD
**Status:** 🟢 Phase 02-08 implementation hoàn thành (autonomous run 2026-06-28). Phase 01 (Postgres migration) intentionally deferred — backend vẫn chạy trên SQLite, tests Postgres skip cleanly khi không có `SMOKE_DATABASE_URL`.

## Phase overview

| # | Phase | Sized | Status | Tóm tắt |
|---|---|---|---|---|
| **00** | BA Requirements v2 | - | ✅ APPROVED v2 | 10 decisions D1-D10 sealed, 9 user stories added. `phase-00-ba-requirements.md` |
| **01** | DB Migration SQLite → Postgres | 2-3d | ✅ Done | Docker postgis + Alembic baseline ALL tables + pytest-postgresql + CI (commit `7bd7e55`). Dev có thể chạy SQLite; CI + prod chạy Postgres 16+PostGIS. `phase-01-db-migration.md` |
| **01h** | Postgres concurrency hardening (EXCLUDE gist) | 0.5d | ✅ Done | Cài `btree_gist` + EXCLUDE USING gist trên `reservations` để chặn double-book ở DB layer. 4 tests Postgres-only. Migration `0011`. `phase-01h-postgres-concurrency-hardening.md` |
| **01b** | Booking → ViewingAppointment Rename | 1d | ✅ Done | 5 backend files + 8 Flutter files; notification type mapping; smoke test. `phase-01b-booking-rename.md` |
| **02** | Foundation + Host Profile + Audit | 4-5d | ✅ Done | `require_host()` dep, fix 8+ unauth endpoints, HostProfile + onboarding 3-step, change_logs table, HostScopedRepository base. `phase-02-foundation-host-profile.md` |
| **03** | Nhà trọ Core (Building/Room/Tenant/Contract) | 7-9d | ✅ Done | M:N Contract-Tenant pivot (D2), Room state machine maintenance (B4), transfer room (C7), duplicate room (D5), soft delete. `phase-03-nha-tro-core.md` |
| **04** | Nhà trọ Ops (Invoice/Payment/Meter) | 8-10d | ✅ Done | Invoice immutable after paid, manual "Tạo hoá đơn tháng X" (D4), move-out prorate (C5), final settle, deposit refund (C6), debt aging, public HTML link UUID (D3). `phase-04-nha-tro-ops.md` |
| **05** | Khai báo tạm trú (form gen + reminder) | 4-5d | ✅ Done | HTML public-link UUID + 12h deadline + roommate khai báo (mỗi tenant 1 record), TK1 form template. `phase-05-khai-bao-tam-tru.md` |
| **06** | Reports + Zalo + Notifications + Cần action | 5-6d | ✅ Done | Table-view reports (G1-G4), Zalo deep-link builder integration, CSV export, dashboard "cần action" list (D4), in-app noti polish. `phase-06-reports-zalo-notifications.md` |
| **07** | Homestay Core (Calendar/Pricing/Reservation) | 9-11d | ✅ Done | Postgres exclusion constraint anti-overbooking, pricing priority resolution, rigid 24h cancel policy (D10), check-in/out workflow + khai báo auto-create. 16 backend tests. `phase-07-homestay-core.md` |
| **08** | Marketplace ↔ Ops Integration | 5-7d | ✅ Done | Sync 1 chiều ops→marketplace (House upsert), auto-draft Contract/Reservation from booking, placeholder Tenant from phone-only guest. 14 backend tests + Flutter screens (publish/sync-status/create-contract/approve-reservation). `phase-08-marketplace-ops-integration.md` |
| | **TOTAL dev** | **45-57d (~9-11.5w)** | | |
| | **+ buffer 15%** | **+7-9d** | | Demo prep, bug fix per phase, integration regression |
| | **GRAND TOTAL** | **52-66d (~10.5-13 tuần)** | | |

## Milestones

- **End of Phase 06** (~6 tuần): Nhà trọ usable end-to-end (Contract/Invoice/KhaiBao/Reports)
- **End of Phase 07** (~9 tuần): Homestay usable end-to-end
- **End of Phase 08** (~10.5-13 tuần): Full marketplace ↔ ops integration

## Scope cuts if deadline pressure

- Defer Phase 07 (homestay) + Phase 08 (marketplace integration) → giảm còn ~6-7 tuần, ship nhà trọ-only MVP trước

## Research artifacts

- `research/researcher-backend-audit.md` — FastAPI codebase audit (models, routers, auth gaps, patterns)
- `research/researcher-flutter-audit.md` — Flutter scaffolding, providers, packages needed
- `research/researcher-postgres-migration.md` — Phase 01 concrete plan with Alembic + pytest-postgresql
- `../research/codebase-audit-host-feature.md` — Initial codebase audit (background)
- `../research/nha-tro-vn-systems.md` — 7 VN nhà trọ apps benchmark
- `../research/homestay-vn-systems.md` — Cloudbeds/Hostaway + Zalo-first VN

## Reports

- `reports/ba-leader-review.md` — BA v1 critical review (10 decisions recommended)

## Key dependencies (execute order)

```
01 (DB Postgres)
  └─ blocks ALL subsequent

01b (Booking rename)
  ├─ blocked by 01
  └─ blocks 02, 03, 07 (avoid naming clash)

02 (Foundation + HostProfile + security)
  ├─ blocked by 01, 01b
  └─ blocks 03, 04, 05, 06, 07, 08 (security base for ops)

03 (Nhà trọ Core)
  ├─ blocked by 01, 01b, 02
  └─ blocks 04 (Contract → Invoice), 05 (Tenant → KhaiBao)

04 (Nhà trọ Ops)
  ├─ blocked by 03
  └─ blocks 06 (Reports query invoices), 08 (marketplace draft Contract)

05 (Khai báo tạm trú)
  ├─ blocked by 03 (Tenant model)
  └─ blocks 06 (Reports include declaration stats)

06 (Reports + Zalo + Noti)
  ├─ blocked by 03, 04, 05
  └─ blocks nothing (polish phase)

07 (Homestay Core)
  ├─ blocked by 01, 01b, 02, 03 (Building/Room reused)
  └─ blocks 08 (Reservation → marketplace draft)

08 (Marketplace ↔ Ops)
  ├─ blocked by 03 (Contract), 07 (Reservation)
  └─ Final integration
```

## Decisions made (D1-D10 sealed §9 BA doc v2)

| # | Topic | Sealed value |
|---|---|---|
| D1 | SQLite data preservation | Reset toàn bộ (chưa launch) |
| D2 | Roommates model | Contract M:N Tenant via `contract_tenants(contract_id, tenant_id, is_primary)` |
| D3 | Invoice rendering | HTML public-link UUID token (PDF defer) |
| D4 | Auto-cron infra | Manual button + dashboard "cần action" list (NO APScheduler) |
| D5 | Bulk create rooms | "Duplicate this room" 1-click (NO template builder) |
| D6 | Multi-tenant isolation | Repository pattern auto-inject `host_id` + integration test cross-host |
| D7 | CCCD storage | Local filesystem + folder permissions 0700 + access log audit table |
| D8 | T1 entry barrier (Excel import) | Skip MVP (monitor churn post-launch) |
| D9 | Booking rename scope | Standalone Phase 01b (1d) between Phase 01 + Phase 02 |
| D10 | Cancel policy homestay | Rigid 24h: >24h full / 0-24h 50% / sau check-in 0% |

Context answers Q1-Q5 (BA doc §9 Round 2):
- Q1 SQLite production data: ❌ chưa launch, reset OK
- Q2 Zalo Official Account: ❌ chưa → deep-link manual
- Q3 Target launch: 🟡 Soft 3 tháng (~2026-09-22)
- Q4 Production user: ❌ chưa → free to reset
- Q5 Audit trail: ✅ change_logs table from Phase 02

## Constraints §9c (from BA doc v2)

- **Booking rename = Phase 01b standalone (D9):** 1d, 5 backend files + 8 Flutter files, smoke test required
- **Migration Postgres = Phase 01 (D1 reset):** docker postgis + Alembic baseline ALL tables + pytest-postgresql
- **Form khai báo HTML public-link UUID (D3):** primary; PDF defer to browser print
- **Roommates M:N (D2):** `contract_tenants` pivot with `is_primary BOOLEAN`
- **Multi-tenant isolation Repository pattern (D6):** `HostScopedRepository` base + cross-host integration test from Phase 02
- **CCCD local + audit (D7):** `storage/cccd/` chmod 0700, UUIDv4 filenames, `cccd_access_logs` table
- **Audit trail (Q5):** `change_logs` table created Phase 02, triggered Phase 03+04

## Open questions

_(All BA-level questions resolved via D1-D10 + Q1-Q5 defaults. Tech-level unresolved questions listed in individual phase files §Risk Assessment.)_

## Status tracking

- **Phase 00:** ✅ APPROVED v2 — BA Leader reviewed
- **Phase 01:** ✅ Done — Postgres+PostGIS baseline + CI smoke tests (commit `7bd7e55`)
- **Phase 01h:** ✅ Done — EXCLUDE USING gist trên reservations + 4 Postgres-only tests (commit backend `21481ac`)
- **Phase 01b, 02-08:** ✅ Done (autonomous run 2026-06-28)

**Verification snapshot 2026-06-28:**
- Backend pytest collect: 227 tests (16 homestay + 14 marketplace + foundation/nha-tro/khai-bao/reports)
- `flutter analyze lib/features/host/marketplace …` → 0 errors, 2 lint infos
- Phase 08 endpoints under `/api/host/marketplace/*` registered in `main.py`
- Flutter `MarketplaceProvider` wired in `main.dart`; entry point trong `host_home_screen.dart` (Nhà trọ tab)

Next gate: Pickup Phase 01 (Postgres hardening) khi cần production-grade concurrency hoặc move on next initiative (channel manager, Excel import, dynamic pricing).
