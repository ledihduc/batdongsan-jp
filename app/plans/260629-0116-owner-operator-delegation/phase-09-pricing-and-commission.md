# Phase 09 — Pricing & Commission Tracking

## Context Links

- BA v4 AC-32 (tenant payment → owner bank account), AC-32b (cash payment evidence + tenant confirm for ≥2M), AC-33 (`expected_owner_payout = total - commission - fees`; v1 platform_fee_pct=0), AC-34 (operator dashboard commission), AC-35 (no auto-transfer v1), AC-36 (owner commission report, TNCN/VAT format), AC-37 (operator commission-loss on tenant shortfall), AC-54 (contract PDF dual-disclosure), NFR-15 (platform_fee_pct forward-compat)
- §13 Q1 (pricing model — FREE v1 → Freemium v1.5 → 0.5% commission v2 → SaaS v3)
- Research: `researcher-02-backend-money-flows.md` §C (Invoice + InvoiceLineItem + Payment + CreditNote schemas; commission_rate + commission_amount already on Invoice, locked at paid_at), §G (APScheduler), §H (Tt200Export pattern)
- Prereq phases: 01 (schema: `invoices.platform_fee_pct`, `invoices.platform_fee_amount`, `delegations.commission_pct`, `delegations.commission_fixed_amount`, `delegations.commission_type` enum; `contracts.kb04_form_data`, `contract_tenants.joined_at_datetime` for AC-55b SLA), 03 (delegation entity with commission fields), 07 (UI consumption)

## Overview

**Priority:** P0 for commission tracking display; P1 for tax export (AC-36)
**Status:** Pending
**Brief:** Track operator commission per invoice (no auto-transfer per AC-35 v1); compute `expected_owner_payout` per AC-33; build operator + owner commission dashboards; generate AC-36 monthly commission report in TNCN/VAT format. Add `platform_fee_pct` columns on `invoices` for NFR-15 v2 forward-compat (v1 default = 0). Hook contract PDF dual-disclosure generation (AC-54) using existing TT200 export pattern.

## Key Insights from Research

- **Invoice already has `commission_rate` + `commission_amount`** (researcher-02 §C): legacy column for Phase 04 analytics; locked at `paid_at`, NOT reversed by CreditNote (Q3 decision in BA). Reuse for delegation commission with semantic shift — `commission_rate` becomes operator commission %, `commission_amount` becomes operator earning.
- **Cash payment workflow exists** (researcher-02 §C — Payment model with `method='cash'`). For AC-32b: extend with `location_lat`, `location_lng`, `evidence_photo_path`, `tenant_confirmation_status` ('pending', 'confirmed', 'disputed') — added in phase-01.
- **TT200 export immutability pattern** (researcher-02 §H): `Tt200Export(host_id, period, version, sha256, exported_at)` UNIQUE(host_id, period, version). Use same pattern for AC-36 commission report immutability: `CommissionReport(host_id, period, version, sha256, exported_at, format='tncn'|'vat')`.
- **No CSV/Excel export infra** (researcher-02 §H): need `openpyxl` for .xlsx generation. Add to requirements.txt.
- **APScheduler ready** for monthly commission report auto-generation if needed (BA AC-36 says "owner can export" — interactive endpoint; v1 = on-demand, not scheduled).
- **Marketplace integration** (researcher-03 §B5): existing `marketplace_integration` router. AC-51 says payout routes to `host_id = owner_id` (immutable, regardless of operator). Verify no path lets operator change payout destination.

## Requirements (mapped to BA v4)

| AC / NFR / US | Covered by step |
|---------------|-----------------|
| AC-32 | Step 5 (payment recording → owner bank; verify owner HostProfile.bank_* is source of truth) |
| AC-32b | Step 5 (cash payment with location + photo; SMS confirm for ≥2M) |
| AC-33 | Step 3 (`expected_owner_payout` computed function; immutable post paid_at) |
| AC-34 | Step 4 (operator commission dashboard endpoint + UI consumption from phase-07) |
| AC-35 | Step 1 (v1 NO auto-transfer — explicit; documentation + audit) |
| AC-36 | Step 6 (commission report export TNCN + VAT formats, .xlsx + .csv) |
| AC-37 | Step 3 (commission-loss on partial payment: commission scales linearly with paid_amount/total_amount) |
| AC-51 | Step 7 (marketplace booking payout immutability — regression test) |
| AC-54 | Step 8 (contract PDF dual-disclosure generator) |
| NFR-15 | Step 2 (platform_fee_pct + platform_fee_amount columns on invoices; v1 default 0; forward-compat) |
| US-O13 | Step 5 (owner revenue lands in owner TKNH; commission tách rời) |
| US-P10 | Step 4 (operator sees commission MTD + payout history) |
| US-T2 | Step 8 (contract PDF dual-disclosure regenerated on operator change mid-contract) |

## Architecture

### Commission computation (per invoice, at paid_at)

```
inputs (from Delegation):
  - commission_type: 'percentage' | 'fixed_amount' | NULL (self-managed)
  - commission_pct: float (e.g., 0.08 = 8%)
  - commission_fixed_amount: int (VND/month) — mutually exclusive with pct

at Invoice.paid_at (immutable post):
  - Invoice.commission_rate = delegation.commission_pct (snapshot)
  - Invoice.commission_amount = compute_commission(invoice, delegation)
  - Invoice.platform_fee_pct = 0 (v1; NFR-15 placeholder)
  - Invoice.platform_fee_amount = 0 (v1)
  - expected_owner_payout(invoice) = invoice.total_amount - invoice.commission_amount - invoice.platform_fee_amount

compute_commission rules:
  if delegation is NULL                            → 0 (self-managed)
  elif commission_type='fixed_amount'              → commission_fixed_amount (one per month per contract, not per invoice)
  elif commission_type='percentage':
       full_commission = invoice.total_amount * commission_pct
       collection_ratio = invoice.paid_amount / invoice.total_amount  (AC-37 commission-loss)
       commission_amount = full_commission * collection_ratio
  else                                              → 0
```

### Payout routing (AC-51)

```
Payment recorded → no immediate transfer (v1 manual). Audit-trace:
  - Payment.received_to = HostProfile.bank_account_number (lookup by host_id = owner_id, IMMUTABLE)
  - Operator NEVER appears as destination
```

### Commission Report (AC-36) immutability pattern

```
CommissionReport(
  id, host_id (owner), operator_id (NULL aggregate or specific),
  period (YYYY-MM), version INT, sha256, exported_at, format ENUM('tncn','vat'),
  file_path STR, ip, user_agent
)
UNIQUE(host_id, operator_id, period, version, format)
```

Re-export same period = new row with version+1; same as Tt200Export pattern.

## Related Code Files

### Create

- `app/services/commission_service.py` — compute_commission(), build_monthly_commission_summary(), build_owner_commission_report()
- `app/services/contract_pdf_service.py` — extends existing PDF generation with dual-disclosure (AC-54)
- `app/routers/commission_router.py` — `/api/commission/operator/{id}/dashboard`, `/api/commission/owner/{id}/report`, `/api/commission/export/tncn`, `/api/commission/export/vat`
- `app/models.py` extension — `CommissionReport` class
- `app/services/payment_evidence_service.py` — cash payment AC-32b (photo + location + SMS confirm)

### Modify

- `app/services/invoice_service.py` — at invoice paid_at, snapshot platform_fee_pct + platform_fee_amount (v1 default 0); compute commission per delegation type (NULL for self-managed); persist commission_amount (existing column reused)
- `app/services/marketplace_integration/...` — verify payout destination is `host_id = owner_id`; AC-51 regression test
- `app/models.py` — extend `Payment` with `location_lat`, `location_lng`, `evidence_photo_path`, `tenant_confirmation_status`, `tenant_confirmation_token` (UUID, 7-day TTL), `tenant_confirmed_at` — added in phase-01
- `app/utils/pdf_builder.py` (if exists) — add dual-disclosure block builder
- `requirements.txt` — add `openpyxl` (Excel export) if not present
- `app/services/planning_etl/scheduler.py` — optional: monthly commission summary snapshot job (phase-09 may or may not schedule; on-demand sufficient v1)

### Delete

- None.

## Implementation Steps

1. **Document explicit no-auto-transfer (AC-35)** — in `commission_service.py` header docstring + `docs/code-standards.md` addition: "v1 = track only. Commission auto-transfer requires NHNN payment intermediary license (O4); v2 Q4 2026 earliest." API endpoints must NEVER call bank API for transfer.

2. **NFR-15 platform_fee_pct columns** — verify phase-01 added `invoices.platform_fee_pct FLOAT NULL DEFAULT 0` + `invoices.platform_fee_amount FLOAT NULL DEFAULT 0`. Update `invoice_service.generate_draft_invoice()` to set both = 0 on create (no behavior change v1). Lock both at `paid_at` (mirrors `commission_amount` immutability). Forward-compat: v2 Q4 2026 sets non-zero per BA Q1; no migration needed.

3. **Commission computation in `invoice_service.mark_paid()`** — extend the `_lock_commission_at_paid_time()` helper (existing per researcher-02 §C):
   ```python
   def _lock_commission_at_paid_time(invoice: Invoice, db: Session) -> None:
       delegation = get_active_delegation_for_owner(invoice.host_id, db)
       if not delegation:
           invoice.commission_rate = None
           invoice.commission_amount = 0
       elif delegation.commission_type == 'fixed_amount':
           invoice.commission_rate = None
           invoice.commission_amount = delegation.commission_fixed_amount  # full monthly fixed amount; allocated per invoice via separate logic
       elif delegation.commission_type == 'percentage':
           invoice.commission_rate = delegation.commission_pct
           full = invoice.total_amount * delegation.commission_pct
           ratio = invoice.paid_amount / invoice.total_amount  # AC-37
           invoice.commission_amount = round_vnd(full * ratio)
       invoice.platform_fee_pct = 0  # v1 (NFR-15)
       invoice.platform_fee_amount = 0
   ```
   Lock with `db.flush()` (transaction-safe per existing pattern).

4. **Operator commission dashboard endpoint** — `GET /api/commission/operator/{operator_id}/dashboard?period=YYYY-MM`:
   - Aggregate sum of `invoices.commission_amount` for invoices where `delegation.operator_id={operator_id}` AND `period_start/end` in month AND status='paid'.
   - Return per-owner breakdown + total + paid-to-date.
   - IDOR: only operator can call for their own ID OR admin (require_operator_or_admin guard).
   - Used by Flutter `OperatorPortfolioScreen` from phase-07.

5. **AC-32 + AC-32b payment recording** — extend `payment_service.record_payment(invoice_id, amount, method, ...)`:
   - For `method='cash'` AND `amount ≥ 2M VND`: require `location_lat/lng` + `evidence_photo_path` (else 400). Generate `tenant_confirmation_token` (UUID, 7d TTL) and send to tenant via SMS+Zalo deep-link (zalo.py existing helper).
   - For `method='cash'` AND `amount < 2M`: location + photo recommended (warn) but not blocking (N5 graceful degradation).
   - For `method='bank_transfer'`: no extra requirement; trust the bank statement reconciliation (manual v1).
   - All payments: `received_to = owner.bank_account_number` snapshot at time of payment (audit immutability).

6. **AC-36 commission report export** — `POST /api/commission/owner/{owner_id}/export?format=tncn|vat&period=YYYY-MM`:
   - Build .xlsx with `openpyxl`: columns per VN tax format (operator name, CCCD/MST, commission gross, TNCN withholding %, net payable). TNCN format = mỗi operator row with `personal_income_tax_withheld = gross * 0.10` (10% standard rate; flag Q5.4 — owner withholds vs operator self-files; v1 defaults to owner-withholding row format, configurable per delegation).
   - Persist row in `commission_reports` table with `version+1` if same period+format already exists.
   - Store sha256 of file bytes for immutability proof.
   - Return signed download URL (7-day TTL) or stream file.
   - Audit log entry: `audit_logs` row with action='export_commission_report', extra={period, format, version}.

7. **AC-51 marketplace payout regression** — write integration test:
   - Owner A delegates to Operator B with permission preset 'operator_full'.
   - Marketplace booking created via existing `marketplace_integration` flow.
   - Verify payment.received_to == HostProfile(owner_id=A).bank_account_number.
   - Operator B mutates property listing → no change to payout destination.

8. **AC-54 contract PDF dual-disclosure** — `contract_pdf_service.generate(contract_id, requesting_actor_ctx)`:
   - Always render owner section: "Chủ sở hữu: [Owner full name] / CCCD: [masked or full per recipient role]".
   - If active delegation present at contract.start_date: also render operator section: "Người đại diện ký kết: [Operator full name] / CCCD: [...]".
   - Cannot be disabled (AC-19 explicitly forbids suppress).
   - For operator-doanh-nghiệp: render company name + GPKD number + legal rep name + legal rep CCCD.
   - Diacritic rendering verified via golden tests (NFR-12).

9. **Tenant payment confirmation webhook** (AC-32b) — `POST /api/public/payments/{token}/confirm`:
   - Public endpoint (no auth, token-protected); rate-limited.
   - Body: `{confirmed: bool, reason: str (if disputed)}`.
   - Updates `payment.tenant_confirmation_status` + `tenant_confirmed_at`.
   - If `confirmed=false` → escalate to operator + owner notification.
   - 7-day TTL; expired = N/A status.

## Todo List

- [ ] Verify phase-01 added platform_fee columns + payment evidence columns
- [ ] Add `openpyxl` dependency (Excel export)
- [ ] Implement commission_service compute + report builders
- [ ] Extend invoice_service.mark_paid() with commission + platform_fee snapshot
- [ ] Implement payment evidence handling (location + photo + SMS confirm)
- [ ] Build commission_router with 4 endpoints (operator dashboard, owner report, export tncn, export vat)
- [ ] Build contract_pdf_service dual-disclosure generator
- [ ] Build tenant payment confirmation public endpoint
- [ ] CommissionReport model + repository helpers
- [ ] AC-51 marketplace payout regression test
- [ ] Unit tests: commission edge cases (partial payment, fixed-amount, NULL delegation)
- [ ] Integration tests: invoice paid → commission locked → report generated
- [ ] PDF golden tests: Vietnamese diacritics render correctly on macOS, Android, iOS

## Success Criteria

- **AC-32:** Payment recorded; `received_to` snapshot = owner bank account; operator cannot mutate destination.
- **AC-32b:** Cash payment ≥ 2M VND blocked without location + photo; SMS sent to tenant; confirmation flow works.
- **AC-33:** `expected_owner_payout` matches formula; v1 always equals `total - commission` (platform_fee=0).
- **AC-34:** Operator dashboard returns commission MTD + per-owner breakdown.
- **AC-35:** No code path invokes external bank API; documented in code-standards.md.
- **AC-36:** Export endpoint produces .xlsx with VN tax-compliant columns; sha256 stored; re-export increments version.
- **AC-37:** Partial payment (paid 70% of invoice) → commission = full × 0.7 (verified in unit test).
- **AC-51:** Marketplace booking payout regression test passes.
- **AC-54:** Generated contract PDF includes owner + operator disclosure blocks; cannot be toggled off.
- **NFR-15:** platform_fee_pct + platform_fee_amount columns present; v1 default 0; v2 inserts non-zero without migration.

## Risk Assessment

- **R1 — Commission semantics change confuses legacy data** (Q3 BA decision says commission_amount locked at paid_at, NOT reversed by CreditNote). Pre-delegation invoices have NULL/0 commission. Mitigation: clear migration log + commission_service compute() returns 0 if no delegation; never overwrite existing commission_amount on historical invoices.
- **R2 — TNCN/VAT format ambiguity** (Q5.4 open): owner-withholds vs operator-self-files. Mitigation: v1 ships owner-withholds format (default); add `delegation.tax_withholding_model` enum column in phase-01 for future toggle.
- **R3 — Cash payment fraud via fake location** (AC-32b): operator photoshops GPS. Mitigation: phase-09 v1 records location + photo only; v2 adds device-attestation + cross-check. Tenant counter-confirm SMS is the v1 anti-fraud lever.
- **R4 — Excel export memory bloat for large reports** (owner with 50 operators × 12 months): mitigation: stream-write via openpyxl `write_only` mode; cap to 12-month window per AC-40.
- **R5 — Dual-disclosure PDF font issues on iOS PDFKit:** mitigation: golden test on iOS 16/17; embed Be Vietnam Pro font in PDF via reportlab pdfmetrics.
- **R6 — Marketplace integration drift:** AC-51 says payout stays with owner; future marketplace refactor could break. Mitigation: integration test in regression suite + code comment annotating immutability requirement.
- **R7 — Tenant confirmation SMS bypass:** if SMS delivery fails, payment evidence weak. Mitigation: notification ladder (phase-08) handles SMS failure → email/Zalo fallback; UI shows "Awaiting confirmation".

## Security Considerations

- **Bank account masking** (AC-53): commission report for owner shows full bank info (owner is the actor); operator dashboard NEVER shows owner full bank. Audit `CCCDAccessLog`-equivalent for any full reveal.
- **Payment evidence PII**: photo path stored on server disk; access requires `host_id == owner_id OR (delegation_active AND permission >= operator_full)`. Audit on each access.
- **Public confirmation token**: 7-day TTL; rate-limit to prevent brute force; one-time-use (subsequent calls 410 Gone).
- **TNCN report contains operator full name + CCCD**: encrypt at rest if stored long-term; serve via signed URL (existing pattern).
- **Commission tampering**: `commission_amount` immutable post `paid_at`. DB trigger or service-layer check; audit log any UPDATE attempt.

## Estimated Effort

**5 dev-days** = 1 BE × 4d + 1 FE × 1d (FE consumes operator dashboard endpoint into phase-07 widgets). Includes commission engine, payment evidence flow, AC-36 export, dual-disclosure PDF, AC-51 regression. PDF golden tests + Vietnamese font verification add some time.

## Next Steps / Dependencies

- **Blocks:** Phase 11 testing (commission scenarios are core regression cases).
- **Blocked by:** Phase 01 (schema columns), Phase 03 (delegation entity with commission fields), Phase 08 (SMS for tenant confirmation), Phase 07 (UI consumes commission dashboard).
- **Independent:** Phase 02, 05, 06.

## Open items flagged

- **Q5.1** — auto-transfer commission v3 (BA out-of-scope); v1 ships track-only per AC-35.
- **Q5.3** — operator cash advance / expense reimbursement (v1.5 decision); not implemented v1.
- **Q5.4** — TNCN/VAT withholding model (owner vs operator) — v1 ships owner-withholds default; add config column for flexibility.
- **Q6.4** — dual-disclosure tenant signature workflow (AC-54 mandates content; legal counsel needed for signing requirement).
- **O4** — NHNN intermediary license for v2 auto-commission; pre-launch validation gate (corporate counsel).
