---
title: "Phase 09 — Excel TT200 Full 50+ Columns Export"
status: pending
priority: P0
estimated_effort: 5-7d
blocked_by: [phase-00, phase-02]
owner: TBD
---

## Context Links
- BA: US-14, AC-10 (full TT200 spec), AC-15 (perf <3s), Q1 (full 50+ cols)
- BA Leader: §11.1 #1 (accountant review mandatory), §11.1 #6 (immutability legal), §11.3 (re-auth + audit log)
- Phase 00: `reports/phase-00-accountant-booking.md` (sign-off required)

## Overview
- Priority: P0
- Status: pending — BLOCKED until Phase 00 accountant sign-off
- Brief: Backend Excel export per Thông tư 200/2014/TT-BTC: 6 sheets, 50+ columns. Versioned + sha256-hashed for immutability. Audit log per export. Flutter UI w/ re-auth + share flow.

## Key Insights (from research)
- Existing CSV export uses `Generator[str]` + `StreamingResponse`. Excel requires `openpyxl` w/ write-only mode for large datasets.
- Architecture pattern: service returns generator/stream, router wraps in `StreamingResponse`.
- R11 mandates accountant pilot review BEFORE dev start.

## Requirements
### Functional
- Backend service `excel_exporter_tt200` generates xlsx w/ 6 sheets per AC-10:
  1. **Sổ Nhật ký chung** (S03a-DN)
  2. **Sổ Cái TK 511** + **TK 5113**
  3. **Bảng kê hoá đơn** (w/ Trạng thái: Active/Void/Adjusted column)
  4. **Bảng kê thu/chi** (TK 111/112)
  5. **Bảng kê công nợ** (TK 131)
  6. **Bảng kê giảm trừ doanh thu** (TK 521 — refunds from CreditNote)
- Format: VND no decimals, date `dd/mm/yyyy`, MST `xxxxxxxxxx-xxx`.
- Filename: `so-ke-toan-{host_slug}-{YYYY-MM}-v{N}.xlsx`.
- Streaming write (openpyxl `write_only=True`).
- Versioning: `tt200_exports(host_id, period, version, hash, exported_at, file_path?)` table; sha256 of generated file body; re-export same period → version increments.
- Audit log: insert row into `audit_logs` per export attempt (host_id, period, version, success, ip, user_agent).
- Re-auth required: client re-enters password OR biometric before download (BA §11.3).
- Flutter UI: button on analytics home; on tap → re-auth modal → progress indicator → save file via `path_provider` + share via `share_plus`.

### Non-functional
- Server-side generation <3s for 12-month dataset (AC-15).
- Stream — no full-load into memory.
- File integrity verified via sha256 mismatch detection.

## Architecture / Design
- Backend service: `app/services/excel_exporter_tt200.py`; main entry `generate(db, host_id, year_month, version) → tuple[BytesIO, hash]`.
- Router `host_export.py` w/ `POST /api/host/analytics/export/tt200` (POST not GET — has side effect: writes to `tt200_exports` + `audit_logs`).
- Pydantic schema for request (period, force_new_version).
- Migration revision 0018: create `tt200_exports` table.
- Migration revision 0019: create or extend `audit_logs` table (check if exists).

### Key decisions
- **openpyxl `write_only=True`** mode for streaming write.
- **Endpoint = POST** (state change), returns JSON `{version, hash, download_url}`; client then GETs file via signed URL (or backend serves direct stream w/ re-auth-tokened cookie).
- **MVP simpler:** POST returns the file body directly (StreamingResponse w/ Content-Disposition); table row written after stream completes. Tradeoff: cannot retry download w/o regenerating; mitigate by storing file in object storage (future).
- **Re-auth:** client passes `Idempotency-Key` + recent JWT `iat` < 5 min OR `X-Reauth-Token` from re-auth endpoint (new endpoint `POST /api/auth/reauth`).
- **Audit log:** existing `audit_logs` table verified in Phase 00 (R11 grep); if missing, add migration.

## Files
### Modify
- `ancu365-backend/app/main.py` — register router
- `lib/features/host/analytics/screens/analytics_home_screen.dart` — add Export button (top-right action)

### Create
- `ancu365-backend/alembic/versions/0018_create_tt200_exports.py`
- `ancu365-backend/alembic/versions/0019_ensure_audit_logs.py` (conditional: skip if exists)
- `ancu365-backend/app/services/excel_exporter_tt200.py` (main service)
- `ancu365-backend/app/services/_tt200_sheets/sheet_journal.py` (S03a-DN Sổ Nhật ký chung)
- `ancu365-backend/app/services/_tt200_sheets/sheet_general_ledger.py` (TK 511, 5113)
- `ancu365-backend/app/services/_tt200_sheets/sheet_invoice_list.py` (Bảng kê hoá đơn w/ Trạng thái)
- `ancu365-backend/app/services/_tt200_sheets/sheet_cash_book.py` (Bảng kê thu/chi)
- `ancu365-backend/app/services/_tt200_sheets/sheet_receivables.py` (Bảng kê công nợ TK 131)
- `ancu365-backend/app/services/_tt200_sheets/sheet_revenue_deductions.py` (Bảng kê giảm trừ TK 521)
- `ancu365-backend/app/services/audit_log_service.py` (or extend if exists)
- `ancu365-backend/app/routers/host_export.py`
- `ancu365-backend/app/schemas/export.py`
- `ancu365-backend/tests/export/test_excel_tt200_sheets.py` (per-sheet structure)
- `ancu365-backend/tests/export/test_excel_tt200_immutability.py` (sha256 stable; re-export increments version)
- `ancu365-backend/tests/export/test_audit_log.py`
- `lib/features/host/analytics/widgets/export_button.dart`
- `lib/features/host/analytics/widgets/reauth_modal.dart`
- `lib/features/host/analytics/widgets/export_progress_dialog.dart`
- `lib/features/host/analytics/services/export_service.dart` (HTTP call + file save + share)
- `test/widgets/export_button_test.dart`
- `test/services/export_service_test.dart`

### Delete
- Old CSV export endpoint `/api/host/reports/export` retained (legacy users); marked deprecated in Phase 11.

## Implementation Steps
1. Add `openpyxl` to backend `requirements.txt`.
2. Write revision 0018 (`tt200_exports` table: id, host_id, period_yyyymm, version, sha256, exported_at, ip, user_agent).
3. Write revision 0019 conditional `audit_logs`.
4. Implement each sheet generator function returning row iterables. Apply VND/date/MST formatters.
5. Implement main `generate(db, host_id, year_month, version)` orchestrating 6 sheets; compute sha256 streaming via `hashlib`.
6. Implement `audit_log_service.record_export()` w/ insert.
7. Implement `POST /api/host/analytics/export/tt200` w/ re-auth check + StreamingResponse + post-stream commit of tt200_exports row.
8. Implement `POST /api/auth/reauth` returning short-lived (5 min) `X-Reauth-Token` (JWT signed w/ `purpose=export`).
9. Implement Flutter `ExportButton` → opens `ReauthModal` → on success, calls `ExportService.downloadTt200(period)` → progress dialog → save to temp dir → `Share.shareXFiles`.
10. **Accountant pilot review:** generate sample export from staging w/ anonymized data; send to 2-3 kế toán; capture feedback; iterate; record sign-off.

## Todo List
- [ ] `openpyxl` added
- [ ] Migrations 0018 + 0019
- [ ] 6 sheet generators + tests
- [ ] Main `generate()` + sha256
- [ ] `audit_log_service` + tests
- [ ] POST endpoint + re-auth gate
- [ ] `POST /api/auth/reauth` + tests
- [ ] `ExportButton` + `ReauthModal` + `ExportProgressDialog`
- [ ] `ExportService` (download + share)
- [ ] Accountant pilot sign-off documented
- [ ] Versioning verified (re-export creates v2)
- [ ] Coverage ≥80%

## Test Strategy
### Unit
- Each sheet generator: structure (header rows), VND format, date format, MST format.
- `_tt200_sheets/sheet_invoice_list`: void invoice shows Trạng thái=Void; original Active row unchanged.
- sha256 hash stable for same dataset; re-export creates new version row.

### Integration
- POST `/api/host/analytics/export/tt200` w/o re-auth → 403.
- POST w/ re-auth → 200 + file body + `tt200_exports` row created + `audit_logs` row created.
- Re-export same period → `version=2`, hash differs (b/c exported_at differs in metadata).
- IDOR: host_A POST w/ host_B's period → only host_A data in export.

### E2E
- Phase 11 covers download + share flow.

## Success Criteria
- 6 sheets generated per TT200 spec; all 50+ columns present.
- Accountant pilot sign-off documented (R11 cleared).
- Versioning + sha256 verified.
- Audit log row per export.
- Re-auth required; biometric or password.
- Server-side generation <3s for 12-month dataset.

## Risk Assessment
- **R3 — TT200 format reject** → mitigated by accountant pilot pre-launch (Phase 00 condition).
- **R11 — spec inaccurate** → BLOCKED until accountant sign-off.
- **Streaming write memory bloat** → openpyxl write_only mode + flush per sheet.
- **Re-auth UX friction** → biometric preferred; password fallback acceptable.

## Security Considerations
- **PII in export:** MST, tenant names, revenue → re-auth gate mandatory (BA §11.3).
- **Audit log** per export — legal compliance.
- **Immutability:** sha256 + version → tamper-evident.
- **IDOR:** every query filters host_id; explicit test.
- File temporarily stored on device → cleared after share.

## Acceptance Criteria Coverage
- US-14 ✓
- AC-10 (full 50+ cols, 6 sheets, Trạng thái column, immutability) ✓
- AC-15 (perf <3s) ✓
- R3, R11 mitigation ✓

## Definition of Done
- All sheets generate correctly; accountant sign-off attached.
- Re-auth + audit log working.
- Versioning verified.
- Perf benchmark <3s.
- Code reviewed + security review (PII handling).
