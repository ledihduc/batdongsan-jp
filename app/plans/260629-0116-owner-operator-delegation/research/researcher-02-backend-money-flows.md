# Researcher 02 — Backend Property/Contract/Invoice/Money Flows

**Date:** 2026-06-29  
**Focus:** FastAPI + SQLAlchemy backend infrastructure relevant to BA v4 delegation feature  
**Stack:** PostgreSQL (primary), SQLite (dev fallback), APScheduler (background jobs), HostScopedRepository pattern

---

## A. Property Entity

**Model:** `Building` (app/models.py:282–298)  
**Type:** Rental property ownership unit (rental complex, boarding house, or building)

| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `host_id` | INT FK→users.id | Required; ondelete=CASCADE. 1 building = 1 owner today. No multi-owner support. |
| `name` | STR(300) | Descriptive (e.g., "Nhà trọ Ngô Quyền, phòng A"). |
| `address` | STR(500) | Full street address. |
| `city` | STR(100) | Parsed (e.g., "Hồ Chí Minh"). |
| `district` | STR(100) | Parsed (e.g., "Quận 1"). |
| `ward` | STR(100) | Parsed (e.g., "Phường Bến Nghé"). |
| `note` | TEXT | Optional metadata. |
| `created_at` | DateTime | Indexed. |
| `updated_at` | DateTime | Indexed. |

**Schema implications:**
- **No property-level metadata table** — district/ward stored as plain strings, not indexed entities.
- **AC-55c `pre_file_accepted` district flag** → need NEW column `district_pre_file_accepted: bool = nullable` on `Building` OR separate lookup table mapping district→pre_file_accepted. Recommended: column on `Building` (simpler, faster).
- **AC-64 sole ownership attestation** → no column today. Need: add `sole_ownership_attested_at: DateTime = nullable` to `Building`.
- **No geographic indexing** — city/district are plaintext. PostGIS geo functions available (planning module) but not used for properties yet.
- **Multi-owner refusal (D4):** Schema enforces 1-to-1 today (host_id unique per building is NOT enforced, but deletion cascades). For v1, accept refusal in UI only; do NOT add co-owner support.

---

## B. Contract / Lease / Tenancy

**Model:** `Contract` (app/models.py:369–412)  
**M:N Tenant junction:** `ContractTenant` (app/models.py:415–435)

### Contract
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `host_id` | INT FK | Required; ondelete=CASCADE. |
| `room_id` | INT FK | Required; ondelete=RESTRICT (prevents room deletion if contract exists). |
| `start_date` | STR(20) | ISO date YYYY-MM-DD. |
| `end_date` | STR(20) | ISO date YYYY-MM-DD. |
| `monthly_rent` | FLOAT | In VND whole units. |
| `deposit` | FLOAT | Upfront (typically 0-2 months rent). |
| `status` | STR(20) enum | `draft \| active \| expired \| terminated`. Indexed. |
| `terminated_at` | STR(20) | ISO date; set when status→terminated. |
| `actual_end_date` | STR(20) | Move-out date if early termination. |
| `deposit_refund_amount` | FLOAT | Computed post-move-out. |
| `damage_note` | TEXT | |
| `damage_photos` | JSONList | Stored as JSON array of file paths. |
| `handover_photos` | JSONList | |
| `source` | STR(20) | `manual \| marketplace \| imported`. Legacy dual-write (will drop in Phase 3.5). |
| `source_id` | INT FK→revenue_sources.id | NOT NULL (enforced by migration 0018:app/models.py:405–406). Links to analytics channel. |
| `created_at`, `updated_at` | DateTime | Indexed. |

### ContractTenant (M:N junction)
| Field | Type | Notes |
|-------|------|-------|
| `contract_id` | INT PK FK | |
| `tenant_id` | INT PK FK | Composite PK — no surrogate ID. |
| `is_primary` | BOOL | True for payer; typically 1 per contract. |
| `joined_at` | STR(20) | ISO date; when tenant moves in. |
| `left_at` | STR(20) | ISO date; when tenant moves out. |

**Lifecycle:** draft → active (on start_date) → expired (on end_date) | terminated (early, manual)  
**State validation:** NOT at DB level; enforced by `room_state_service` (app/services/ — not inspected, but comment indicates state machine pattern).

**KB04 implications (AC-55, AC-55b, AC-55c, AC-55d):**
- **Tenant CCCD:** Stored on `Tenant` model (app/models.py:336–366), not `ContractTenant`.
  - `cccd_number_hash`: One-way bcrypt hash, compare-only.
  - `cccd_front_path`, `cccd_back_path`: Server-side file paths (no plaintext returned in API).
  - `is_placeholder`: Flag for marketplace bookings (no User account).
- **Move-in timestamp:** `ContractTenant.joined_at` (ISO date) — NOT millisecond-precision datetime. For AC-55b 6h SLA post-move-in, app must add logic to track actual move-in **time** (not just date). TODAY: only date precision exists.
- **Pre-file workflow:** No `CT01 form_data` column exists. Need: add JSON blob `kb04_form_data: Text = nullable` to `Contract` to store CT01 fields (tenant CCCD, address, move-in date, etc.) for pre-file submission BEFORE move-in.

---

## C. Invoice / Payment / Cash Flow

### Invoice
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `host_id` | INT FK | Required; ondelete=CASCADE. |
| `contract_id` | INT FK | Required; ondelete=RESTRICT. |
| `invoice_number` | STR(50) | Unique, indexed. Format: `INV-202607-C42` (INV + YYYYMM + contract_id). |
| `period_start`, `period_end` | STR(20) | ISO dates defining billing month. |
| `issued_date`, `due_date` | STR(20) | ISO dates. Due date defaults to issued_date + 7 days (app/services/invoice_service.py:32). |
| `status` | STR(20) enum | `draft \| sent \| paid \| overdue \| cancelled`. Indexed. |
| `total_amount` | FLOAT | Whole VND, rounded at generation (app/services/invoice_service.py:37–39). |
| `paid_amount` | FLOAT | SUM of all Payment records for this invoice. |
| `paid_at` | DateTime | Set when status→paid. Immutable after (logic at service layer). |
| `public_token` | STR(36) UUID | UUIDv4 for public /invoices/{token} HTML render (90-day TTL). Nullable, indexed. |
| `public_token_expires_at` | DateTime | Expiry of public link. |
| `commission_rate` | FLOAT | Snapshot at generation time (Phase 04, legacy NULL = no commission). |
| `commission_amount` | FLOAT | Locked at Invoice.paid_at (NOT reversed by CreditNote per Q3 decision). |
| `note` | TEXT | |
| `created_at`, `updated_at` | DateTime | Indexed. |

**Unique constraint:** UNIQUE(contract_id, period_start, period_end) — prevents duplicate drafts for same month (app/models.py:511–514).

### InvoiceLineItem (children of Invoice)
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `invoice_id` | INT FK | ondelete=CASCADE. |
| `category` | STR(30) enum | `rent \| electricity \| water \| service \| deposit_refund \| damage_deduction \| adjustment`. |
| `description` | STR(300) | Display text (e.g., "Tiền điện (50 kWh)"). |
| `quantity` | FLOAT | Usage units (kWh, m³) or 1 for lump-sum. |
| `unit_price` | FLOAT | Price per unit. |
| `amount` | FLOAT | quantity × unit_price (or negative for refunds). |
| `sort_order` | INT | Render order. |

**Generation flow** (app/services/invoice_service.py:69–196):
1. List active contracts for building + month.
2. For each contract:
   - Create draft Invoice (status=draft, paid_amount=0, total_amount=0).
   - Generate line items:
     - Rent: fixed monthly_rent.
     - Electricity/Water: latest_reading − previous_reading (meter_readings table).
     - Service fees: per ContractServiceFee.monthly_amount (snapshot, not synced).
   - Sum amounts → total_amount (rounded VND).
   - Write ChangeLog entry (entity_type='invoice', action='create').
3. **Idempotent:** Re-running same (contract, month) skips if invoice already exists (UNIQUE constraint).

### Payment
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `host_id` | INT FK | Required; ondelete=CASCADE. |
| `invoice_id` | INT FK | Required; ondelete=CASCADE. |
| `amount` | FLOAT | Partial payments allowed; invoice.status→paid when SUM(amount)≥invoice.total_amount. |
| `method` | STR(20) enum | `cash \| bank_transfer \| other`. |
| `paid_at` | DateTime | Default=now. |
| `note` | TEXT | Optional. |
| `created_at` | DateTime | Indexed. |

**Important:** Multiple payments per invoice supported (app/models.py:569). Invoice marks paid when SUM(amount)≥total_amount (no explicit check table — caller must verify).

### CreditNote
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `host_id` | INT FK | |
| `original_invoice_id` | INT FK | RESTRICT (cannot delete paid invoice if credit note exists). |
| `amount` | FLOAT | Negative value recorded, not reversed from invoice.commission_amount. |
| `reason` | TEXT | |
| `issued_date` | STR(20) | ISO date. |
| `created_at` | DateTime | |

**Important:** Original invoice remains status=paid. CreditNote is **not** an adjustment line item — separate record. For ac-33 expected_owner_payout, commission is locked at paid time and NOT affected by later credit notes.

---

## D. Money Audit (Change Log & PDPL)

### ChangeLog
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `entity_type` | STR(50) | `contract \| invoice \| host_profile \| ...` Indexed. |
| `entity_id` | INT | PK of affected row. Indexed. |
| `actor_id` | INT FK | NULL allowed (system actions). |
| `action` | STR(30) | `create \| update \| status_change \| delete`. |
| `before_json` | TEXT | JSON snapshot of state before (NULL for creates). |
| `after_json` | TEXT | JSON snapshot of state after (NULL for deletes). |
| `created_at` | DateTime | Indexed (for audit range queries). |

**Usage pattern** (app/repositories/audit.py):
```python
write_change_log(
    db, 
    entity_type="invoice", 
    entity_id=invoice.id,
    actor_id=host_id, 
    action="create",
    before=None, 
    after={id, status, total_amount, ...}
)
```
Writes to ChangeLog, flushes but does NOT commit (caller owns transaction). Used by invoice_service, host_profile_repository, and must extend for delegation actions (AC-65).

### CCCDAccessLog (PDPL audit for file access)
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `user_id` | INT FK | Actor reading/writing the file. |
| `file_path` | STR(500) | CCCD image path on disk. |
| `action` | STR(20) | `upload \| read \| delete`. |
| `accessed_at` | DateTime | Indexed (for retention queries). |
| `ip_address` | STR(50) | Optional (IPv6 max 45 chars). |

**Compliance:** Every CCCD file operation logged. Supports PDPL Decree 13/2023 minimization audit (AC-43 lockdown audit disclosure).

### AuditLog (App-level compliance audit — Phase 09)
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `host_id` | INT FK | Required; ondelete=CASCADE. |
| `action` | STR(50) | `export_tt200 \| ...` |
| `period` | STR(7) | `YYYY-MM` for export_tt200; NULL for others. |
| `success` | BOOL | Export succeeded? |
| `ip`, `user_agent` | STR | For anti-fraud auditing. |
| `extra` | TEXT | JSON extensibility. |
| `created_at` | DateTime | Indexed. |

**Note:** Separate from ChangeLog (which tracks entity mutations). AuditLog tracks app-level compliance events (exports, admin actions). Index `ix_audit_logs_host_action_created` supports audit range queries.

---

## E. KB04 / Tenant Verification (Residence Declaration)

### KhaiBaoTamTru (CT01 Residence Declaration)
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `host_id` | INT FK | |
| `tenant_id` | INT FK | |
| `contract_id` | INT FK nullable | For nhà trọ contracts. |
| `reservation_id` | INT nullable | Reserved for Phase 07 (homestay). |
| `check_in_at` | DateTime | **Millisecond-precision.** Authoritative move-in moment. |
| `declared_at` | DateTime | When host submitted CT01; NULL until declared. |
| `status` | STR(20) enum | `pending \| declared \| overdue \| skipped`. **Denormalized** (recomputed at read time, but cached in column). |
| `skip_reason` | TEXT | Why host opted out. |
| `public_token` | STR(36) UUID | For unauth CT01 HTML render (90-day TTL). Unique, indexed. |
| `public_token_expires_at` | DateTime | Expiry. |
| `created_at`, `updated_at` | DateTime | Indexed. |

**Unique constraint:** UNIQUE(contract_id, tenant_id) — idempotent auto-create (app/models.py:635–637).  
**Status logic** (app/models.py:620–628):
- **pending:** declared_at IS NULL AND now < check_in_at + 12h
- **overdue:** declared_at IS NULL AND now ≥ check_in_at + 12h
- **declared:** declared_at IS NOT NULL
- **skipped:** host marked as skipped (skip_reason non-empty)

**Authoritative status** recomputed in service layer on every read (no cron). Column persists for index + dashboard count optimization.

**KB04 form fields NOT in schema:** CT01 requires CCCD, address, move-in time, etc. — no dedicated JSON column for CT01 form data. **Need:** add `kb04_form_data: Text = nullable` to store CT01 snapshot (tenant CCCD hash, address_at_move_in, check_in_at, etc.) for pre-file audit trail.

---

## F. State Machines / Workflow Engine

**Status:** No explicit state machine framework (transitions, sagas, temporal logic).

**Patterns found:**
1. **Enum status columns:** Contract.status, Invoice.status, KhaiBaoTamTru.status all use STR enum (not Postgres ENUM type).
2. **Service-layer validation:** room_state_service (referenced in Contract comment, not fully inspected) validates state transitions on writes.
3. **Immutability after key events:** Invoice immutable after status=paid (service layer check; no DB constraint).
4. **Change log audit trail:** Every mutation → ChangeLog entry with before/after JSON (for AC-65 audit disclosure).

**Implications for delegation (D5 AC-43 lockdown + AC-44 archive + AC-58 owner death):**
- No built-in state machine. Must implement lockdown/escalation logic as router guards + service-layer checks.
- No temporal constraints (time-based state transitions). AC-30 72h expire, AC-43 30d lockdown, AC-44 30d→cold archive → need background jobs.

---

## G. Background Jobs Infrastructure

**Scheduler:** APScheduler BackgroundScheduler (in-process, non-blocking)  
**Location:** app/services/planning_etl/scheduler.py:28–73  
**Triggers:** main.py:230–235 (startup), 238–242 (shutdown)

### Current Setup
```python
# app/services/planning_etl/scheduler.py:48–57
_scheduler = BackgroundScheduler(timezone="UTC")
_scheduler.add_job(
    fetch_all_districts,
    trigger="cron",
    hour=19,                    # UTC (02:00 ICT)
    minute=0,
    id="hcmc_daily_etl",
    replace_existing=True,
    misfire_grace_time=3600,    # 1h grace for missed jobs
)
_scheduler.start()
```

**Conditional:** Only starts if CRON_ENABLED=1 AND DATABASE_URL starts with "postgresql" (app/services/planning_etl/scheduler.py:35–43).

### Implications for Delegation
- **AC-30 72h expire:** Can add new_job(..., trigger='cron', hour=0, minute=0, ...) to check KB04 overdue daily + mark status=expired.
- **AC-43 30d lockdown:** Similarly, cron job to un-lock delegation after 30 days (if no fraud).
- **AC-44 30d archive → 4-tier retention:** Cron job to cascade archive (hot 90d → warm 2y → cold 5y → legal hold).
- **AC-58 7-day owner death pause:** Cron to auto-unpause after 7 days.

**Important:** No redis lock for distributed instances. Scale-out (P09) requires Redis-backed lock (not planned for v1).

---

## H. Reporting / Tax Export

### Tt200Export (TT200 tax form immutable versioning)
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `host_id` | INT FK | |
| `period` | STR(7) | `YYYY-MM` for tax period. |
| `version` | INT | Incremented on re-export of same period. |
| `sha256` | STR(64) | Hex digest of xlsx bytes (immutability proof). |
| `exported_at` | DateTime | |
| `ip`, `user_agent` | STR | For audit. |

**Unique constraint:** UNIQUE(host_id, period, version) — prevents duplicate versions (app/models.py:866–870).

**Endpoint:** POST /api/host/analytics/export/tt200 (app/routers/host_export.py — not fully inspected).  
**Immutability:** Every export creates NEW row (no idempotent re-use). Re-exporting same period increments version.

**TT200 infrastructure:** Draft/review phase (Phase 09, per schema comment). Schema exists, but export logic likely incomplete (pending accountant R11 validation).

**CSV/Excel export:** No dedicated export infrastructure found in codebase scan. Recommend: openpyxl or xlsxwriter for .xlsx generation.

---

## I. Tenant Entity

### Tenant
| Field | Type | Notes |
|-------|------|-------|
| `id` | INT PK | |
| `host_id` | INT FK | Required; ondelete=CASCADE. Scoped to owner. |
| `full_name` | STR(300) | |
| `cccd_number_hash` | STR(200) nullable | One-way bcrypt hash (compare-only). |
| `phone` | STR(50) | |
| `email` | STR(200) nullable | |
| `birthday` | STR(20) nullable | ISO date. |
| `address_origin` | STR(500) nullable | Origin address (from CCCD). |
| `cccd_front_path`, `cccd_back_path` | STR(500) nullable | Server file paths. |
| `is_placeholder` | BOOL | True if created from marketplace booking (no User). |
| `created_from_booking_type` | STR(30) nullable | `viewing_appointment \| reservation`. |
| `created_from_booking_id` | INT nullable | ID of source booking. |
| `created_at` | DateTime | |

**KB04 fields present:** CCCD hash + file paths. But **no**: move-in verification timestamp, OCR confidence, document verification status, or audit trail per CCCD upload.

**Important:** Tenant is **reusable** across contracts (one record per real person). But scoped to `host_id` — same physical person may have separate Tenant rows for different hosts (by design, per comment app/models.py:340).

**No user account required** — is_placeholder=True allows marketplace-sourced tenants (phone-only). For KB04, must support unauthenticated tenant CCCD submission? (Needs clarification during tech lead phase.)

---

## Implications for Delegation Feature (BA v4)

### AC-29 Threshold Configuration
- **Current:** No threshold column exists.
- **Add:** `Delegation.auto_approval_threshold: float = 100000000` (default 100M VND per expert recommendation).
- **AC-29a per-delegation override:** UI must allow operator to set threshold. If threshold<0, require 24h owner approval.
- **Schema:** Add `auto_approval_threshold: Float = nullable` to new `Delegation` table (phase-01).

### AC-30 72h Expire / AC-30b Escalation Ladder
- **Workflow:** KB04 pre-file invite (D1 + AC-55b) → if no approval in 6h, escalate to owner admin upload.
- **Infrastructure:** APScheduler can add daily cron job to check KhaiBaoTamTru.declared_at IS NULL AND now > check_in_at + 72h → mark status=expired.
- **D5 lockdown:** 30-day lockdown post-invite (AC-43 3-tier modified). Cron job to check delegation.invited_at + 30d → unlock.

### AC-33 Expected Owner Payout
- **Current:** Invoice.commission_amount exists (locked at paid time).
- **Add:** `expected_owner_payout = Invoice.total_amount - Invoice.commission_amount - platform_fee` (not in schema yet).
- **Platform fee:** Need NEW column `platform_fee_pct: Float` or `platform_fee_amount: Float` on Invoice or Payout table.
- **Forward-compat (NFR-15):** Decide: add to Invoice (denormalized) or Payout (separate entity)? Recommend: new Payout table (phase-02).

### AC-43/AC-43b Lockdown & AC-58 Owner Death Pause
- **AC-43 modified (D5):** Allow KB04 pre-file + fraud termination even during 30d lockdown (with 24h owner approval SLA).
- **AC-58 owner death + 7d pause:** No schema support yet. Need: add `paused_reason: str = nullable` + `paused_until: DateTime = nullable` to Delegation.
- **Cron jobs:** 2 new background tasks (AC-43 unlock after 30d, AC-58 auto-unpause after 7d).

### AC-44 30-day Archive & 4-tier Retention (D9)
- **Policy:** hot 90d / warm 2y / cold 5y / legal hold.
- **Tier transitions:** No existing cron + tier column pattern. Need: add `retention_tier: str = 'hot'` enum + `tier_transitioned_at: DateTime` to ChangeLog / DelegationAudit.
- **Cron job:** Monthly script to cascade tier transitions based on timestamps.
- **Cold storage:** Likely S3 or blob storage (not inspected). Coordinate with infra team.

### AC-55/AC-55b/c/d KB04 Workflow
- **Pre-file submission (AC-55b):** Operator pre-files CT01 BEFORE tenant move-in. Need: add `kb04_form_data: Text = nullable` to Contract (store CT01 snapshot).
- **AC-55c district flag:** Add `Building.district_pre_file_accepted: bool = nullable` (or lookup table mapping district→accepted).
- **AC-55d notarized POA:** Digital consent default (FastCA/VinaCA), notary optional escalation. No schema impact (stored in ChangeLog + audit disclosure UI).
- **D2 owner death + POA upload:** Manual admin upload (24h SLA). Need: new table `OwnerDeathCertificate` or store in DelegationAudit.

### AC-64 Sole Ownership Attestation
- **Add:** `Building.sole_ownership_attested_at: DateTime = nullable` to track when ownership verified.
- **Audit:** ChangeLog entry when attested (before delegation invite sent).

### AC-65 PMC Legal-Rep Change
- **Audit requirement:** Track who is operator + when changed (ChangeLog + audit disclosure UI).
- **No schema change needed** (ChangeLog sufficient). But extend AuditLog to include operator_change_reason.

### NFR-13 Scope-Aware Schema (D6)
- **Decision:** DEFER UI behavior (nesting) to v2. Schema scope-ready v1.
- **Add:** `Delegation.scope_id: int = nullable` FK (to new Scope table: property-level, building-level, room-level).
- **Schema:** New table `Scope` (id PK, delegation_id FK, scope_type enum ['property', 'building', 'room'], target_id int).
- **Unique constraint:** UNIQUE(delegation_id, scope_type, target_id) per BA recommendations.
- **Migration cost:** 2-3 dev-days now → saves 2-3 weeks v2 migration.

### NFR-15 platform_fee_pct Forward-Compat
- **Decision:** No commission v1 (FREE tier). Add platform_fee_pct column to Invoice for v1.5 freemium + v2 commission.
- **Add:** `Invoice.platform_fee_pct: Float = nullable` + `Invoice.platform_fee_amount: Float = nullable`.
- **Calculation:** At invoice generation, compute platform_fee_amount = total_amount × platform_fee_pct (if pct non-null).
- **Immutability:** Lock both commission and platform_fee at Invoice.paid_at.

---

## Known Risks / Gotchas

1. **Move-in timestamp precision:** KhaiBaoTamTru.check_in_at is DateTime (millisecond-precise), but ContractTenant.joined_at is STR(20) ISO date (day-only). For AC-55b 6h SLA post-move-in, need DateTime everywhere (migrate in phase-01).

2. **KB04 form data missing:** No CT01 snapshot column. If pre-file submitted, audit trail lost. Add `Contract.kb04_form_data: Text = nullable` to store CT01 payload.

3. **No explicit transaction isolation:** Invoice generation (app/services/invoice_service.py) uses db.flush() (non-atomic). If exception post-flush, partial state persisted. All services must wrap in try/except + rollback.

4. **Commission immutable after paid:** Invoice.commission_amount locked at Invoice.paid_at, not reversed by CreditNote (per Q3). AC-33 expected_owner_payout must account for this (no retroactive commission adjustment).

5. **ChangeLog JSON serialization:** All mutations serialized to JSON (default=str). Large contracts or invoices may inflate JSON size. Monitor ChangeLog table growth (phase-04 performance tuning).

6. **No distributed scheduler lock:** APScheduler runs in-process. Scale-out (P09 multi-instance) requires Redis lock (not MVP). Acceptable for single-instance v1.

7. **District lookup:** city/district stored as plaintext on Building. For AC-55c pre_file_accepted lookup, need static district map (hardcoded or lookup table). No PostGIS integration for validation.

8. **Payment partial support:** Multiple payments per invoice allowed, but no automatic invoice status transition. Service layer must check SUM(amount)≥total_amount manually (no DB constraint). Risk: invoice stuck in "sent" if payment logic broken.

9. **Scope multi-level not tested:** NFR-13 scope-ready schema (add scope_id FK) is forward-compat, but no test coverage for nesting (building + room delegation simultaneously). Phase-02 behavior (UI, approval) deferred; phase-01 schema only.

10. **CCCD file path storage:** Server-side file paths stored in DB (cccd_front_path, cccd_back_path). If disk location changes (migration, cloud storage), paths break. Add migration strategy (symlinks or S3 redirect).

---

## Recommended Tech Lead Discussion Points

1. **Move-in timestamp precision:** Confirm ContractTenant.joined_at should be DateTime (not STR date) for AC-55b SLA accuracy. If yes, migration needed (phase-01).

2. **KB04 form data column:** Should Contract store kb04_form_data (CT01 snapshot) for pre-file audit trail? If yes, add to phase-01 schema.

3. **Scope-aware schema v1:** Confirm adding `Delegation.scope_id` FK + new Scope table in phase-01 (even if UI deferred to v2). Cost: 2-3 dev-days; saves v2 migration weeks.

4. **Platform fee pct forward-compat:** Add nullable `platform_fee_pct` and `platform_fee_amount` to Invoice phase-01 (for v1.5 freemium + v2 commission, even if v1 FREE tier).

5. **ChangeLog retention + tiering:** Confirm 4-tier retention (D9) applied to DelegationAudit (new table), not ChangeLog (which may be broader). Or extend ChangeLog with retention_tier column for delegation-only rows?

---

**Status:** DONE  
**Summary:** FastAPI backend has mature invoice/payment/audit infrastructure, but lacks delegation-specific schemas (Delegation, Scope, OwnerDeathCertificate, DelegationAudit). APScheduler ready for background jobs (72h expire, 30d lockdown, archive tiers). Key forward-compat gaps: move-in timestamp precision, KB04 form snapshot, scope-aware schema, platform_fee_pct.  
**Report:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/plans/260629-0116-owner-operator-delegation/research/researcher-02-backend-money-flows.md`
