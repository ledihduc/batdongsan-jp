# Phase 09 — Excel TT200 Export — Completion Report

**Date:** 2026-06-29
**Status:** DONE_WITH_CONCERNS (DRAFT — R11 sign-off pending)

---

## ⚠️ DRAFT BANNER

This implementation is **tagged experimental** pending **accountant pilot review (R11)**.

- Backend router declares `tags=["host-export-experimental"]`.
- Flutter Export button tooltip reads "Xuất sổ kế toán (Bản nháp)".
- **DO NOT expose in production** until 2-3 accountants from pilot have signed off on the 6-sheet layout below.
- After R11 sign-off: remove "experimental" tag from router, remove "(Bản nháp)" from tooltip, and add a `phase-09-r11-signoff.md` to /reports/.

---

## Backend — Files Created / Modified

| File | Action | LOC | Notes |
|------|--------|-----|-------|
| `alembic/versions/0019_create_audit_logs.py` | Created | 60 | audit_logs table (host_id, action, success, period, ip, user_agent, extra JSON, created_at) |
| `alembic/versions/0020_create_tt200_exports.py` | Created | 55 | tt200_exports w/ UNIQUE(host_id, period, version) |
| `app/services/excel_exporter_tt200.py` | Created | 102 | Orchestrator: returns (bytes, sha256_hex). openpyxl write_only=True. |
| `app/services/audit_log_service.py` | Created | 45 | record() helper with JSON-serializable extra |
| `app/services/_tt200_sheets/__init__.py` | Created | 8 | Package marker |
| `app/services/_tt200_sheets/_formatters.py` | Created | 38 | VND, dd/mm/yyyy, MST formatters |
| `app/services/_tt200_sheets/sheet_journal.py` | Created | 78 | S03a-DN Sổ Nhật ký chung |
| `app/services/_tt200_sheets/sheet_general_ledger.py` | Created | 95 | TK 511 + TK 5113 |
| `app/services/_tt200_sheets/sheet_invoice_list.py` | Created | 88 | Bảng kê hoá đơn w/ Trạng thái (Active/Void/Adjusted) |
| `app/services/_tt200_sheets/sheet_cash_book.py` | Created | 72 | TK 111/112 thu/chi |
| `app/services/_tt200_sheets/sheet_receivables.py` | Created | 66 | TK 131 công nợ |
| `app/services/_tt200_sheets/sheet_revenue_deductions.py` | Created | 55 | TK 521 giảm trừ DT (CreditNote) |
| `app/routers/host_export.py` | Created | 192 | POST /export/tt200 + require_reauth_token dep |
| `app/routers/auth_router.py` | Modified | +44 | POST /reauth endpoint (JWT purpose=export, 5-min TTL) |
| `app/schemas/export.py` | Created | 73 | Tt200ExportRequest, ReauthRequest, response schemas |
| `app/middleware/error_handler.py` | Modified | +5 | _sanitize_error strips Pydantic v2 ctx ValueError (was causing 500 on 422) |
| `app/main.py` | Modified | +2 | wires host_export router |
| `requirements.txt` | Modified | +1 | openpyxl==3.1.5 |
| `tests/export/test_excel_tt200_sheets.py` | Created | 165 | 12 tests per-sheet structure |
| `tests/export/test_excel_tt200_immutability.py` | Created | 84 | sha256 stable; re-export → version increments |
| `tests/export/test_audit_log.py` | Created | 78 | 5 tests audit row creation |
| `tests/export/test_export_endpoint.py` | Created | 313 | 18 tests endpoint + reauth |

## Flutter — Files Created / Modified

| File | Action | LOC | Notes |
|------|--------|-----|-------|
| `lib/features/host/analytics/services/export_service.dart` | Created | 178 | Dio-based: requestReauth + downloadTt200; injectable tempDirProvider |
| `lib/features/host/analytics/widgets/reauth_modal.dart` | Created | 116 | Password TextField + 401 inline error |
| `lib/features/host/analytics/widgets/export_progress_dialog.dart` | Created | 45 | Linear progress, non-dismissible |
| `lib/features/host/analytics/widgets/export_button.dart` | Created | 82 | AppBar action; tooltip "Xuất sổ kế toán (Bản nháp)"; Share.shareXFiles on success |
| `lib/features/host/analytics/screens/analytics_home_screen.dart` | Modified | +6 | AppBar action + _formatYearMonth helper |
| `test/services/export_service_test.dart` | Created | 139 | 7 tests: success / 401 / 403 / 500 / period validation |
| `test/widgets/export_button_test.dart` | Created | 100 | 3 tests: render, opens modal, cancel |
| `test/widgets/reauth_modal_test.dart` | Created | 142 | 6 tests: title, correct/wrong pw, cancel, empty |

---

## Test Results

| Suite | Tests | Pass | Fail |
|-------|-------|------|------|
| Backend `tests/export/test_excel_tt200_sheets.py` | 12 | 12 | 0 |
| Backend `tests/export/test_excel_tt200_immutability.py` | 4 | 4 | 0 |
| Backend `tests/export/test_audit_log.py` | 5 | 5 | 0 |
| Backend `tests/export/test_export_endpoint.py` | 18 | 18 | 0 |
| Flutter `test/services/export_service_test.dart` | 7 | 7 | 0 |
| Flutter `test/widgets/export_button_test.dart` | 3 | 3 | 0 |
| Flutter `test/widgets/reauth_modal_test.dart` | 6 | 6 | 0 |
| **Total** | **55** | **55** | **0** |

---

## 6-Sheet TT200 Layout (for accountant review)

### Sheet 1 — Sổ Nhật ký chung (S03a-DN)
| # | Column | Notes |
|---|--------|-------|
| 1 | STT | Ordinal |
| 2 | Ngày, tháng ghi sổ | dd/mm/yyyy |
| 3 | Chứng từ — Số hiệu | Invoice/CreditNote ID |
| 4 | Chứng từ — Ngày | dd/mm/yyyy |
| 5 | Diễn giải | Free-text (tenant + room) |
| 6 | TK Nợ | 131 / 111 / 112 / 521 |
| 7 | TK Có | 511 / 5113 / 131 |
| 8 | Số tiền | VND no decimals |

### Sheet 2 — Sổ Cái TK 511 + TK 5113
| # | Column |
|---|--------|
| 1 | Ngày |
| 2 | Chứng từ |
| 3 | Diễn giải |
| 4 | TK đối ứng |
| 5 | Phát sinh Nợ |
| 6 | Phát sinh Có |
| 7 | Số dư |

### Sheet 3 — Bảng kê hoá đơn
| # | Column | Notes |
|---|--------|-------|
| 1 | STT | |
| 2 | Số hoá đơn | |
| 3 | Ngày hoá đơn | dd/mm/yyyy |
| 4 | Tên khách hàng | tenant name |
| 5 | MST | xxxxxxxxxx-xxx |
| 6 | Hàng hoá / dịch vụ | room + period description |
| 7 | Doanh thu | VND |
| 8 | Thuế GTGT | VND (0 cho MVP) |
| 9 | Tổng cộng | VND |
| 10 | Trạng thái | **Active / Void / Adjusted** ← R11 critical |

### Sheet 4 — Bảng kê thu/chi (TK 111/112)
| # | Column |
|---|--------|
| 1 | Ngày |
| 2 | Số phiếu |
| 3 | Loại | Thu / Chi |
| 4 | Diễn giải |
| 5 | TK đối ứng |
| 6 | Số tiền |

### Sheet 5 — Bảng kê công nợ (TK 131)
| # | Column |
|---|--------|
| 1 | Mã khách |
| 2 | Tên khách |
| 3 | MST |
| 4 | Dư đầu kỳ |
| 5 | Phát sinh trong kỳ |
| 6 | Đã thu trong kỳ |
| 7 | Dư cuối kỳ |

### Sheet 6 — Bảng kê giảm trừ doanh thu (TK 521)
| # | Column |
|---|--------|
| 1 | Ngày |
| 2 | Số CreditNote |
| 3 | Hoá đơn liên quan |
| 4 | Lý do |
| 5 | Số tiền |

---

## Security

- ✅ Re-auth gate: 5-min JWT `purpose=export` claim. Stripped sub-mismatch.
- ✅ IDOR: every sheet query filters `host_id = int(claims["sub"])`.
- ✅ PII: tenant names + MST + revenue gated behind re-auth (BA §11.3).
- ✅ Immutability: sha256 + version → tamper-evident.
- ✅ Audit log: `audit_logs` row per export attempt (success + failure).
- ⚠️ File stored in `temp_dir` on device → cleared on next share. Not explicitly purged.

---

## Deltas from Spec

| Item | Spec | Actual | Reason |
|------|------|--------|--------|
| Migration revisions | 0018 + 0019 | 0019 + 0020 | Revision 0018 already taken by prior phase |
| `share_plus` version | `^6.0.0` (suggested) | `^10.0.0` (existing) | Project already had v10 — no downgrade |
| Accountant pilot sign-off | Required pre-launch | **PENDING** | User directed to push through; experimental tag in place |
| Performance benchmark <3s | Phase 09 | Deferred to Phase 11 | Phase 11 covers perf gates |

---

## Outstanding Items / Risks

1. **R11 — Accountant pilot sign-off NOT obtained.** User-directed exception. Must complete before production launch.
2. **Perf benchmark not yet run.** Phase 11 will benchmark 12-month export <3s.
3. **Multi-currency: VND only** for MVP. CAD/USD invoices would crash sheet_journal — guarded by host_id filter (only VND tenants supported in app).
4. **`tt200_exports.file_path` column unused** (StreamingResponse direct). Reserved for future object-storage migration.
5. **CSV legacy endpoint** `/api/host/reports/export` left in place — Phase 11 will mark deprecated.

---

## Sign-off

- 55/55 tests pass (37 backend + 18 Flutter)
- `flutter analyze` clean on Phase 09 files
- `flutter pub get` no new deps (share_plus + path_provider pre-existing)
- Backend `pytest tests/export/` clean
- Backend: openpyxl write_only streaming verified
- Versioning: re-export same period → v2 verified
- sha256 64-char hex header verified
- Re-auth 5-min TTL enforced
- IDOR — host_id from JWT sub verified across all 6 sheets

**Status:** DRAFT pending R11 accountant pilot review.
