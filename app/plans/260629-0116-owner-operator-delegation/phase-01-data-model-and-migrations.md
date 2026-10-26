# Phase 01 — Data Model & Migrations

## Context Links
- BA v4: §3 (Model A), §4 (terminology), §10.1 (schema impact), §10.5 (PDPL tiers), §13 D6 (NFR-13), §13 D9 (retention), §6 AC-08/AC-23/AC-31b/AC-52/AC-53/AC-62/AC-64
- Research: `researcher-01-backend-auth-kyc.md` §A/B/D/G; `researcher-02-backend-money-flows.md` §A/B/D/I; `researcher-03-flutter-app.md` (model touchpoints)
- Dependent on phases: NONE (foundation phase)
- Blocks: all subsequent phases

## Overview
- **Priority:** P0 — strict blocker
- **Status:** Pending
- **Effort:** 5 dev-days (1 senior BE)
- **Type:** backend-only
- **Description:** Create new tables for delegation domain + extend existing tables with delegation-aware fields. Zero ALTER on the 20+ `host_id`-keyed business tables (AC-52). All migrations reversible.

## Key Insights from Research
- Latest Alembic head = `0020_create_tt200_exports` (researcher-01 §G). Next = `0021`.
- Existing `users.role` is `String(20)`, not Postgres ENUM (researcher-01 §A). Extending = no DB migration on enum; just whitelist update in Pydantic + register screen.
- `ChangeLog` already has `actor_id` (nullable FK, researcher-02 §D); only need new column for `on_behalf_of` + delegation reference.
- `host_id` immutable assumption is structural: every business table's CASCADE FK depends on it (researcher-01 §A). DO NOT touch.
- `ContractTenant.joined_at` is `STR(20)` ISO date (day precision only — researcher-02 §B). Need DateTime precision for AC-55b 6h pre-file SLA.
- `KhaiBaoTamTru` has no CT01 form_data snapshot column (researcher-02 §E).
- APScheduler running in-process (researcher-02 §G).

## Requirements (mapped to BA v4)

### Functional ACs covered
- **AC-01..AC-08, AC-10b**: schema for invitations, delegations, scope, unique constraint
- **AC-22, AC-23**: audit dual-identity columns
- **AC-31b**: per-delegation threshold columns (5 thresholds, all non-null)
- **AC-49, AC-50/50b, AC-58..AC-58d**: schema for KYC grace, GPKD, owner death cert, executor
- **AC-52**: zero ALTER on the 20+ host_id business tables (CI check)
- **AC-53**: bank account masking → no schema change (read-time mask) but `bank_account_reveal_log` (extend `CCCDAccessLog` pattern) for AC-53 audit
- **AC-55b, AC-55c, AC-55d**: contract `kb04_form_data` JSON, `buildings.district_pre_file_accepted` flag, `delegations.poa_format` enum
- **AC-62**: `ChangeLog` already has `created_at` (server-stamp); add nullable `acted_at` (client-claim) — see audit extension below
- **AC-64**: `users.sole_ownership_attested_at` (per BA v4 — owner-level, not building-level, since it's an account assertion)
- **AC-66**: `delegations.shared_login_disclosure_ack_at`

### NFRs
- **NFR-13** (scope-aware schema): `delegations.scope_type` enum + `delegations.scope_target_ids` JSON array (TL-1 decision in plan.md). Forward-compat for v2 nesting without breaking-change migration.
- **NFR-15** (platform_fee_pct forward-compat): `invoices.platform_fee_pct` and `invoices.platform_fee_amount` nullable columns added now; v1 = 0 / NULL.
- **NFR-03** (audit log p95 < 1s at scale): add composite indexes on `change_logs (on_behalf_of_id, created_at)` and `audit_logs (delegation_id, created_at)`. Partition strategy deferred (BA Appendix B2 = Tech Lead call) — recommend monthly RANGE partitioning on `change_logs.created_at` as separate v1.1 migration once volume hits 1M rows.

### User Stories satisfied
- US-O1..O4 (delegation entity + invitation entity)
- US-O18, US-A6 (owner_death_certificates table)
- US-P3, US-P4 (operator_business_profiles table)
- US-P16 (legal-rep change audit columns)
- US-O19 (poa_format enum)

### Assumptions
- AS-06 (1 user pháp nhân per operator-doanh-nghiệp), AS-14 (FastCA/VinaCA), AS-15 (sole ownership self-declaration)

## Architecture

### New tables

**1. `delegations`** — core delegation record
| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | Use `uuid_generate_v4()` default. UUID (not int) because used in HTTP header (`X-Acting-As-Delegation-Id`). |
| `owner_id` | INT FK → `users.id` (ondelete RESTRICT) | Cannot delete owner with active delegation. |
| `operator_id` | INT FK → `users.id` (ondelete RESTRICT) | |
| `invitation_id` | UUID FK → `delegation_invitations.id` nullable | Backref to originating invite (NULL for admin-created). |
| `status` | STR(30) enum | `pending_op_kyc` \| `active` \| `paused` \| `terminating` \| `terminated` \| `archived`. Indexed. |
| `paused_reason` | STR(50) nullable | `owner_request` \| `kyc_expired` \| `gpkd_revoked` \| `owner_death` \| `fraud_flag` \| `admin_force` |
| `paused_until` | DateTime nullable | For owner-death 7d pause + KYC re-verify 30d window. |
| `role_preset` | STR(30) | `owner_view` \| `operator_full` \| `accountant` \| `viewer` (4 presets per BA §3 + AC-19/20/21). |
| `scope_type` | STR(20) | `all` \| `building_list`. Indexed. (TL-1: v1 only 2 values; v2 adds `room_list`.) |
| `scope_target_ids` | JSONB / TEXT | JSON array of building IDs (NULL when `scope_type='all'`). |
| `commission_pct` | NUMERIC(5,2) nullable | XOR with `commission_fixed_vnd`. |
| `commission_fixed_vnd` | NUMERIC(15,0) nullable | |
| `threshold_monthly_rent_vnd` | NUMERIC(15,0) NOT NULL | AC-24, AC-31b no-default (must be set at invite). |
| `threshold_term_months` | INT NOT NULL | AC-24 |
| `threshold_expense_vnd` | NUMERIC(15,0) NOT NULL | AC-25 |
| `threshold_rent_change_pct` | NUMERIC(5,2) NOT NULL | AC-26 |
| `threshold_refund_vnd` | NUMERIC(15,0) NOT NULL | AC-28 |
| `poa_format` | STR(20) | `digital` \| `notarized` (AC-55d, US-O19). |
| `poa_document_path` | STR(500) nullable | Encrypted-at-rest path (S3 SSE / disk-encrypted volume). |
| `shared_login_disclosure_ack_at` | DateTime nullable | AC-66 (only for operator-doanh-nghiệp). |
| `out_of_office_start` | DateTime nullable | AC-57 |
| `out_of_office_end` | DateTime nullable | |
| `activated_at` | DateTime nullable | |
| `terminate_requested_at` | DateTime nullable | Start of 30d lockdown clock (AC-43). |
| `terminate_reason` | STR(50) nullable | `owner_request` \| `operator_resign` \| `fraud_suspected` \| `legal_dispute` \| `kyc_expired_grace_lapsed` |
| `terminated_at` | DateTime nullable | |
| `archived_at` | DateTime nullable | AC-44 (30d post-termination). |
| `retention_tier` | STR(10) | `hot` (default) \| `warm` \| `cold` \| `legal_hold` (D9, AC-44). |
| `retention_tier_transitioned_at` | DateTime nullable | |
| `created_at` | DateTime | Default `now()`. Indexed. |
| `updated_at` | DateTime | Auto-update. |

Constraints:
- **Partial unique index** on `(owner_id) WHERE status='active'` — enforces AC-08 (1 active delegation per owner). Use `op.execute('CREATE UNIQUE INDEX ... WHERE status = \'active\'')`.
- CHECK constraint: `(commission_pct IS NULL) != (commission_fixed_vnd IS NULL)` — mutually exclusive (AC-04).
- CHECK constraint: `scope_type='all' AND scope_target_ids IS NULL` OR `scope_type='building_list' AND jsonb_array_length(scope_target_ids) > 0`.
- CHECK constraint: `(out_of_office_start IS NULL) = (out_of_office_end IS NULL)` and if both set: `start < end`.

Indexes:
- `(owner_id, status)` for owner dashboard
- `(operator_id, status)` for operator portfolio (NFR-09 p95 ≤ 2.5s on 3G)
- `(status, terminate_requested_at)` for 30d lockdown cron
- `(retention_tier, retention_tier_transitioned_at)` for archive cron

**2. `delegation_invitations`** — invite lifecycle (separate so we can audit declined invites)
| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `owner_id` | INT FK → `users.id` | |
| `invited_phone_or_email` | STR(200) | Single field — server resolves to user_id on accept. |
| `invited_user_id` | INT FK → `users.id` nullable | Set if invited user already has account. |
| `token` | STR(64) UNIQUE | URL-safe random; single-use (AC-01). |
| `token_used_at` | DateTime nullable | Mark when consumed → blocks re-use. |
| `proposed_role_preset` | STR(30) | Same as `delegations.role_preset`. |
| `proposed_scope_type` | STR(20) | |
| `proposed_scope_target_ids` | JSONB | |
| `proposed_commission_pct` / `proposed_commission_fixed_vnd` | NUMERIC | |
| `proposed_thresholds_json` | JSONB | All 5 thresholds bundled. |
| `proposed_poa_format` | STR(20) | |
| `status` | STR(20) | `pending` \| `accepted` \| `rejected` \| `expired` \| `revoked_by_owner`. Indexed. |
| `expires_at` | DateTime | Default `created_at + 7 days` (AC-01). |
| `accepted_at` / `rejected_at` / `revoked_at` | DateTime nullable | |
| `created_at` | DateTime | Indexed. |

Constraints:
- UNIQUE `(owner_id, invited_phone_or_email)` WHERE `status='pending'` — enforces AC-10b (no duplicate pending invite). Re-invite while pending = HTTP 409.

**3. `delegation_approvals`** — approval queue
| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `delegation_id` | UUID FK → `delegations.id` | Indexed. |
| `requester_user_id` | INT FK → `users.id` | = operator_id from delegation at request time (snapshot). |
| `owner_id` | INT FK → `users.id` | Denormalized for fast inbox query. |
| `action_type` | STR(40) | `contract_create` \| `contract_terminate` \| `invoice_high_amount` \| `expense_high_amount` \| `rent_change` \| `refund_high_amount` \| `kb04_fast_track` \| `kb04_pre_file` \| `fraud_termination` \| `threshold_change` ... |
| `entity_type` | STR(30) nullable | E.g., `contract`, `invoice`. Null for `threshold_change`. |
| `entity_id` | INT nullable | |
| `action_payload_json` | JSONB | Full request snapshot (so approval can still be acted on if request payload changes). |
| `requested_amount_vnd` | NUMERIC(15,0) nullable | For high-value biometric trigger (AC-29b). |
| `requires_biometric` | BOOL | Computed at create (amount ≥ 50M VND → true). |
| `status` | STR(20) | `pending` \| `approved` \| `rejected` \| `expired` \| `auto_rejected` \| `cancelled`. Indexed. |
| `sla_class` | STR(20) | `default_72h` \| `kb04_fast_track_6h` \| `fraud_termination_24h` (AC-30, AC-55, AC-43b). |
| `expires_at` | DateTime | Server-computed from `sla_class`. |
| `decided_at` | DateTime nullable | |
| `decided_by_user_id` | INT FK → `users.id` nullable | Normally = owner_id; can be executor (AC-58d). |
| `decision_reason` | TEXT nullable | |
| `escalation_state` | STR(20) | `push_only` \| `push_email` \| `push_email_sms` \| `escalated_admin`. Tracks AC-30b ladder. |
| `last_notified_at` | DateTime nullable | |
| `delivery_channels_used_json` | JSONB | Per AC-31. |
| `lockdown_fraud_termination` | BOOL DEFAULT FALSE | Marks AC-43b case. |
| `created_at` | DateTime | Indexed. |

Indexes:
- `(owner_id, status, expires_at)` — owner inbox + escalation cron
- `(delegation_id, created_at)` — audit
- `(status, expires_at)` WHERE `status='pending'` — expiry cron efficiency

**4. `operator_business_profiles`** — operator doanh-nghiệp KYC (greenfield per researcher-01 §B)
| Column | Type | Notes |
|--------|------|-------|
| `id` | INT PK | |
| `user_id` | INT FK → `users.id` UNIQUE | 1:1 with the legal-rep user (AS-06: 1 pháp nhân = 1 user). |
| `business_name` | STR(300) | |
| `business_registration_number` | STR(50) | GPKD. |
| `gpkd_document_path` | STR(500) | Encrypted-at-rest. |
| `gpkd_industry_codes_json` | JSONB | Validate ngành dịch vụ quản lý BĐS (Q6.3 confirm — store array; flag if missing required code at admin review). |
| `gpkd_issued_at` | DateTime | |
| `gpkd_expires_at` | DateTime nullable | Drives AC-50/AC-61 expiry cron. |
| `legal_representative_name` | STR(300) | |
| `legal_representative_cccd_number_hash` | STR(200) | bcrypt hash (mirror existing CCCD pattern). |
| `legal_representative_cccd_front_path` / `_back_path` | STR(500) | |
| `legal_representative_phone` | STR(50) | |
| `verification_status` | STR(20) | `pending` \| `verified` \| `rejected` \| `revoked` |
| `verified_at` | DateTime nullable | |
| `verified_by_user_id` | INT FK → users.id (admin) nullable | |
| `previous_legal_rep_user_id` | INT FK nullable | For AC-65 audit (most-recent predecessor). |
| `legal_rep_changed_at` | DateTime nullable | AC-65. |
| `created_at` / `updated_at` | DateTime | |

**5. `owner_death_certificates`** — AC-58 admin verification
| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `owner_user_id` | INT FK → `users.id` UNIQUE | |
| `death_certificate_path` | STR(500) | Encrypted-at-rest. |
| `notarized_poa_path` | STR(500) nullable | Heir's POA. |
| `submitted_by_user_id` | INT FK nullable | Heir or admin. |
| `verification_status` | STR(20) | `pending` \| `verified` \| `rejected` |
| `verified_at` | DateTime nullable | 24h admin SLA (US-A7). |
| `verified_by_admin_id` | INT FK nullable | |
| `executor_user_id` | INT FK → users.id nullable | Set after AC-58b onboard. |
| `executor_onboarded_at` | DateTime nullable | |
| `created_at` | DateTime | |

**6. `tenant_authority_flags`** — AC-63 tenant unauthorized-operator report
| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `tenant_id` | INT FK → `tenants.id` | |
| `reported_operator_user_id` | INT FK → `users.id` | |
| `delegation_id` | UUID FK → `delegations.id` nullable | If detected. |
| `report_reason` | TEXT | |
| `status` | STR(20) | `pending` \| `valid` \| `invalid` |
| `reviewed_at` / `reviewed_by_admin_id` | DateTime / INT FK nullable | 48h SLA. |
| `created_at` | DateTime | |

**7. `bank_account_reveal_logs`** — AC-53 PDPL
| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `owner_user_id` | INT FK | |
| `operator_user_id` | INT FK | |
| `delegation_id` | UUID FK | |
| `revealed_at` | DateTime | |
| `consent_token` | STR(64) | One-time owner consent reference. |
| `ip_address` | STR(50) | |

### Extensions to existing tables

**`users`** (researcher-01 §A — table is 49–65):
- `+ is_operator_capable BOOL DEFAULT FALSE` (BA §10.1 — host can also be operator; toggled when KYC complete). NOTE: BA v4 specifies that role "operator" can co-exist with "host" — we keep `role` string-based whitelist `{guest, host, admin, operator}` and add this flag for explicit gating.
- `+ sole_ownership_attested_at DateTime nullable` (AC-64 — attestation lives at user level, applies to all properties).
- `+ business_operator_profile_id INT FK → operator_business_profiles.id nullable` (1:1 backref).

**`host_profiles`** (researcher-01 §B):
- `+ kyc_expires_at DateTime nullable` — drives AC-50 30-day expiry alerts (operator individual case).
- `+ kyc_grace_period_until DateTime nullable` — AC-50 30-day re-KYC grace.

**`buildings`** (researcher-02 §A):
- `+ district_pre_file_accepted BOOL DEFAULT NULL` — AC-55c. NULL = unknown (default 6h approve-then-file); TRUE = O1 confirmed acceptance; FALSE = explicitly rejected.

**`contracts`** (researcher-02 §B):
- `+ kb04_form_data_json JSONB nullable` — CT01 snapshot for pre-file audit (AC-55b).
- `+ kb04_pre_filed BOOL DEFAULT FALSE` — AC-55b marker.

**`contract_tenants`** (researcher-02 §B):
- `+ joined_at_datetime DateTime nullable` — millisecond-precision move-in time (researcher-02 §B gap). Backfill from existing `joined_at` STR(20) date during migration (set time = 00:00:00). NEW writes populate both columns (dual-write transition) until phase-11 verifies switchover.

**`change_logs`** (researcher-02 §D, researcher-01 §D):
- `+ on_behalf_of_user_id INT FK → users.id nullable` — owner id when actor was an operator (AC-23, AC-32).
- `+ acted_via_delegation_id UUID FK → delegations.id nullable` — delegation reference.
- `+ acted_at DateTime nullable` — client-claim time (AC-62). NULL when server-stamp only (server-side actions).
- `+ retention_tier STR(10) DEFAULT 'hot'` — for AC-44 4-tier cron.
- `+ scope_snapshot_json JSONB nullable` — scope_type + target_ids at action time (so revocation/scope change later doesn't invalidate historical query).

**`audit_logs`** (researcher-01 §D, researcher-02 §D):
- `+ actor_user_id INT FK → users.id nullable` — explicit actor (separate from `host_id` which = owner).
- `+ on_behalf_of_user_id INT FK nullable`
- `+ acted_via_delegation_id UUID FK nullable`
- `+ retention_tier STR(10) DEFAULT 'hot'`

**`invoices`** (researcher-02 §C):
- `+ platform_fee_pct NUMERIC(5,4) nullable` — NFR-15, AC-33. v1 = NULL/0.
- `+ platform_fee_amount NUMERIC(15,0) nullable` — locked at `paid_at` (mirror existing commission immutability).

**`notifications`** (researcher-01 §C):
- `+ channel STR(20) DEFAULT 'in_app'` — `in_app` \| `push` \| `email` \| `sms` \| `zalo` (zalo placeholder for v1.1).
- `+ delivery_status STR(20) DEFAULT 'queued'` — `queued` \| `sent` \| `delivered` \| `failed` \| `bounced`.
- `+ external_message_id STR(200) nullable` — vendor message id (SES message id, eSMS ref id) for read-receipt tracking (NFR-14).
- `+ read_receipt_opened_at DateTime nullable` — NFR-14 high-value approval early-SMS trigger.

### Migration ordering (Alembic numbering, after head 0020)

```
0021_create_delegations_and_invitations
0022_create_delegation_approvals
0023_create_operator_business_profiles
0024_create_owner_death_certificates
0025_create_tenant_authority_flags
0026_create_bank_account_reveal_logs
0027_extend_users_for_delegation
0028_extend_host_profiles_kyc_expiry
0029_extend_buildings_district_prefile
0030_extend_contracts_kb04_form_data
0031_add_contract_tenants_joined_datetime  (BACKFILL data)
0032_extend_change_logs_dual_identity
0033_extend_audit_logs_dual_identity
0034_extend_invoices_platform_fee
0035_extend_notifications_channels
```

Each migration:
- Reversible (full `downgrade()` implemented).
- Uses `op.execute()` for partial unique indexes (Alembic helpers don't support `WHERE`).
- For SQLite dev (researcher-01 §G), partial unique indexes degrade to application-layer guard (verify with `dialect_name` check). Postgres-only constraints stay Postgres-only.
- Data backfill (`0031`) wrapped in `with op.batch_alter_table` and chunked (`UPDATE ... WHERE id BETWEEN x AND y`) to avoid table locks on large tenant base.

### Encryption at rest for sensitive fields

- POA documents (`delegations.poa_document_path`)
- GPKD documents (`operator_business_profiles.gpkd_document_path`)
- Death certificates (`owner_death_certificates.death_certificate_path`, `notarized_poa_path`)
- Existing CCCD paths already handled (researcher-01 §B / §I) — same disk strategy.

**Strategy:** store files under `/var/lib/ancu365/sensitive_uploads/{type}/{uuid}.ext` on a disk-encrypted volume (Linux LUKS or AWS EBS encrypted). Path stored in DB; file access mediated by `app/services/sensitive_file_service.py` (NEW, created in this phase as stub) which logs every read via `CCCDAccessLog`-equivalent. No change to filesystem layout for existing CCCD.

### AC coverage matrix (Phase 01 schema contribution)

| AC | How this phase satisfies | Verified by |
|----|--------------------------|-------------|
| AC-01 | `delegation_invitations.token` UNIQUE + `token_used_at` + `expires_at` 7d default | Migration tests |
| AC-04 | CHECK constraint mutually exclusive commission columns | Migration test + insert test |
| AC-07 | No unique on `delegations.operator_id` — multi-owner support | Schema review |
| AC-08 | Partial unique index `(owner_id) WHERE status='active'` | Insert duplicate → integrity error test |
| AC-10b | UNIQUE `(owner_id, invited_phone_or_email) WHERE status='pending'` | Insert test |
| AC-22 | `delegations` separate table; no operator-writable mutation columns exposed (enforced in phase-03) | Schema review |
| AC-23 | `change_logs.on_behalf_of_user_id` + `acted_via_delegation_id` columns | Schema review |
| AC-44 | `delegations.retention_tier` + `archived_at` | Schema review |
| AC-49 | Zero alter on `contracts.host_id` / `tenants.host_id` / `contract_tenants.tenant_id` | CI diff check |
| AC-50/50b | `host_profiles.kyc_expires_at` + `operator_business_profiles.gpkd_expires_at` | Schema review |
| AC-52 | CI lint script: `grep -r "op.alter_column.*host_id" alembic/versions/` returns empty | CI script |
| AC-53 | `bank_account_reveal_logs` table | Migration test |
| AC-55b | `contracts.kb04_form_data_json` + `kb04_pre_filed` | Schema review |
| AC-55c | `buildings.district_pre_file_accepted` | Schema review |
| AC-55d | `delegations.poa_format` + `poa_document_path` | Schema review |
| AC-58 | `owner_death_certificates` table | Schema review |
| AC-62 | `change_logs.acted_at` + existing `created_at` server-stamp | Schema review |
| AC-63 | `tenant_authority_flags` table | Schema review |
| AC-64 | `users.sole_ownership_attested_at` | Schema review |
| AC-65 | `operator_business_profiles.previous_legal_rep_user_id` + `legal_rep_changed_at` | Schema review |
| AC-66 | `delegations.shared_login_disclosure_ack_at` | Schema review |
| NFR-13 | `delegations.scope_type` + `scope_target_ids` JSONB (TL-1) | Schema review |
| NFR-15 | `invoices.platform_fee_pct` + `platform_fee_amount` | Schema review |

## Related Code Files

### To create
- `alembic/versions/0021_create_delegations_and_invitations.py`
- `alembic/versions/0022_create_delegation_approvals.py`
- `alembic/versions/0023_create_operator_business_profiles.py`
- `alembic/versions/0024_create_owner_death_certificates.py`
- `alembic/versions/0025_create_tenant_authority_flags.py`
- `alembic/versions/0026_create_bank_account_reveal_logs.py`
- `alembic/versions/0027_extend_users_for_delegation.py`
- `alembic/versions/0028_extend_host_profiles_kyc_expiry.py`
- `alembic/versions/0029_extend_buildings_district_prefile.py`
- `alembic/versions/0030_extend_contracts_kb04_form_data.py`
- `alembic/versions/0031_add_contract_tenants_joined_datetime.py`
- `alembic/versions/0032_extend_change_logs_dual_identity.py`
- `alembic/versions/0033_extend_audit_logs_dual_identity.py`
- `alembic/versions/0034_extend_invoices_platform_fee.py`
- `alembic/versions/0035_extend_notifications_channels.py`
- `app/models/delegation.py` (NEW — `Delegation`, `DelegationInvitation`, `DelegationApproval` SQLAlchemy ORM)
- `app/models/operator_business.py` (NEW — `OperatorBusinessProfile`)
- `app/models/owner_death.py` (NEW — `OwnerDeathCertificate`)
- `app/models/tenant_authority.py` (NEW — `TenantAuthorityFlag`)
- `app/models/bank_account_reveal_log.py` (NEW)
- `app/services/sensitive_file_service.py` (NEW stub — write/read with audit logging)

### To modify
- `app/models.py` (or split: relevant sections) — add new columns to `User`, `HostProfile`, `Building`, `Contract`, `ContractTenant`, `ChangeLog`, `AuditLog`, `Invoice`, `Notification`. Add SQLAlchemy `relationship()` backrefs where helpful (e.g., `User.delegations_as_owner`, `User.delegations_as_operator`).
- `app/main.py` — register new ORM modules with `Base.metadata` for SQLite `create_all()` dev path (researcher-01 §G).
- `tests/conftest.py` — add fixtures: `make_delegation(owner, operator, status='active', ...)`, `make_invitation(...)`.

### To delete
- None.

## Implementation Steps

1. **Branch + baseline.** Create `feat/p01-data-model` from main. Run `alembic upgrade head` locally to confirm 0020 baseline.
2. **SQLAlchemy models first (TDD).** Write `app/models/delegation.py`, `operator_business.py`, `owner_death.py`, `tenant_authority.py`, `bank_account_reveal_log.py`. Add to `Base.metadata`. Write unit tests that instantiate + assert column types.
3. **Migration `0021`** (`delegations` + `delegation_invitations`):
   - Two `op.create_table()` calls in one revision.
   - Partial unique indexes via `op.execute()`.
   - Downgrade: drop tables (in reverse FK order).
4. **Migration `0022`** (`delegation_approvals`): standalone — depends only on `delegations` + `users`.
5. **Migrations `0023`, `0024`, `0025`, `0026`**: independent tables, one per migration.
6. **Migrations `0027`–`0035`**: column additions to existing tables. Each in its own migration for atomic rollback.
7. **Migration `0031` (joined_at_datetime backfill)**:
   - `op.add_column()` nullable.
   - `op.execute()` chunked UPDATE: `UPDATE contract_tenants SET joined_at_datetime = (joined_at || ' 00:00:00')::timestamp WHERE id BETWEEN :lo AND :hi`. Batches of 10K. Wrap in try/except (data-quality issues).
   - DO NOT drop `joined_at` column in this migration (dual-write transition; drop in v1.1 post-launch).
8. **CI guard `AC-52`** (new script `scripts/check_no_host_id_alter.py`):
   - Greps all migration files in `alembic/versions/` for patterns like `op.alter_column.*host_id`, `op.drop_column.*host_id`.
   - Exit 1 if found.
   - Wire into CI pre-merge check.
9. **Encryption-at-rest setup** (ops doc, not code): document EBS-encrypted volume mount path + LUKS key rotation. Update `docs/deployment-guide.md`.
10. **Sensitive file service stub:** `app/services/sensitive_file_service.py` exposes `store_file(file_bytes, file_type, user_id) -> path` and `read_file(path, accessor_user_id, reason) -> bytes` (logs to `CCCDAccessLog`-equivalent). v1 implementation = local disk; v1.5 = S3 SSE.
11. **Run full test suite.** Including `alembic upgrade head` then `alembic downgrade -1` chain test (smoke).
12. **Document schema** in `docs/system-architecture.md` (delegation domain ERD diagram, additions only).

## Todo List
- [ ] Create branch `feat/p01-data-model` from main
- [ ] Write `app/models/delegation.py` (Delegation, DelegationInvitation, DelegationApproval ORM)
- [ ] Write `app/models/operator_business.py`, `owner_death.py`, `tenant_authority.py`, `bank_account_reveal_log.py`
- [ ] Add new columns to `User`, `HostProfile`, `Building`, `Contract`, `ContractTenant`, `ChangeLog`, `AuditLog`, `Invoice`, `Notification` in existing model files
- [ ] Write migration `0021_create_delegations_and_invitations.py` (with partial unique index)
- [ ] Write migration `0022_create_delegation_approvals.py`
- [ ] Write migrations `0023..0026` (operator_business, owner_death, tenant_authority, bank_reveal)
- [ ] Write migrations `0027..0030` (column extensions to users, host_profiles, buildings, contracts)
- [ ] Write migration `0031` for contract_tenants joined_at_datetime (with backfill)
- [ ] Write migrations `0032..0035` (audit + invoice + notification extensions)
- [ ] Implement `scripts/check_no_host_id_alter.py` CI guard
- [ ] Implement `app/services/sensitive_file_service.py` stub
- [ ] Add ORM fixtures to `tests/conftest.py`
- [ ] Unit test: each migration upgrade + downgrade
- [ ] Unit test: AC-08 partial unique constraint blocks duplicate active delegation
- [ ] Unit test: AC-04 CHECK constraint blocks both-or-neither commission
- [ ] Unit test: AC-10b duplicate pending invite blocked
- [ ] Document delegation ERD in `docs/system-architecture.md`
- [ ] PR review + merge

## Success Criteria
- `alembic upgrade head` runs clean on fresh PostgreSQL → version `0035`.
- `alembic downgrade base` runs clean (full reversibility).
- All 15 migration unit tests pass.
- CI guard script `check_no_host_id_alter.py` passes (zero ALTERs on host_id).
- AC-08 partial unique index rejects 2nd active delegation for same owner (integrity error).
- AC-04 CHECK constraint rejects both-NULL and both-set commission cases.
- AC-10b UNIQUE rejects duplicate pending invite for same (owner, invitee).
- No schema drift on the 20+ `host_id` business tables (researcher-01 §A "20+ tables", verified by CI diff).
- All new tables documented in `docs/system-architecture.md`.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Partial unique index syntax differs in SQLite dev | High | Med | Application-layer guard for SQLite (use `dialect_name` to fall back); Postgres-only constraint stays Postgres-only. Document in migration comment. |
| `contract_tenants.joined_at` backfill on large prod DB locks table | Med | High | Chunked UPDATE 10K/batch; run during low-traffic window; lock-timeout 30s; abort + retry on conflict. |
| JSONB column on `scope_target_ids` not supported on SQLite dev | Med | Low | Use `JSON` type (SQLAlchemy generic). Postgres maps to JSONB; SQLite maps to TEXT. Indexing JSONB key path deferred to v1.1 (no scope check uses array contains in v1 — exact membership check in Python after fetch). |
| `delegations` UUID PK harder to debug than INT | Low | Low | Accept — header transport requires non-guessable id; INT-as-string opens enumeration attack. |
| New columns on `change_logs` increase row size; existing index degrades | Low | Med | Composite index `(on_behalf_of_user_id, created_at)` added; row size growth ~50 bytes acceptable. Defer partitioning to v1.1 NFR-03 trigger (1M+ rows). |
| Encryption-at-rest path migration disrupts existing CCCD files | High | High | DO NOT migrate existing CCCD files in this phase. Encrypted volume = NEW writes only. Existing CCCD stays where it is (already PDPL-compliant per researcher-01 §B). Add separate v1.1 migration if PDPL audit requires retroactive encryption. |
| `is_operator_capable` flag confuses with `role` column semantics | Med | Low | Comment in model + `docs/code-standards.md`: `role` = primary login persona; `is_operator_capable` = can accept delegation invites. Both can be True (host who also operates for others — AC-56). |

## Security Considerations

- **PII exposure:** new sensitive columns (death cert, GPKD, POA, CCCD of legal-rep) — encrypted at rest per `sensitive_file_service`. Read access audited via `CCCDAccessLog`-equivalent extension (covered in phase-02).
- **CCCD hash columns:** mirror existing `cccd_number_hash` bcrypt pattern (researcher-01 §B). Never store plaintext.
- **Bank account masking (AC-53):** schema permits storage of full account; mask is read-layer concern (phase-02 + phase-07 enforce). `bank_account_reveal_logs` audits reveal events.
- **UUID PKs:** `delegations.id` UUID prevents enumeration attack via HTTP header. Use `uuid4` (random, not v1 time-based).
- **Foreign-key cascade:** owner_id / operator_id RESTRICT (not CASCADE) — deletion of a user with active delegation must be explicit error, not silent cascade (prevents accidental delegation orphaning).
- **CHECK constraints** enforce data integrity at DB level (cannot be bypassed by buggy application code).
- **PDPL Decree 13/2023:** new tables in scope for §10.5 4-tier retention; `retention_tier` columns added now, cron implemented in phase-06.

## Estimated Effort

**5 dev-days** = 1 BE × 5d. Covers 5 new tables, ALTER on 6 existing tables, 2-3 Alembic revisions (chunked for safer rollback), ORM model classes, CHECK constraints, retention_tier enum, schema-drift CI check. Includes downgrade scripts + smoke test on staging.

## Next Steps / Dependencies

- **Blocks:** Phase 02 (permission layer needs ORM models), Phase 03 (delegation CRUD), Phase 05 (KYC tables), Phase 06 (death cert), Phase 09 (invoice platform_fee).
- **Parallel-safe with:** Phase 08 (notifications schema = only `notifications` extension here; vendor wiring is separate code path).

## Open items flagged
- Q6.3 (GPKD ngành dịch vụ quản lý BĐS hardcode list) — phase-01 schema reserves `gpkd_industry_codes_json` JSONB; specific code list = phase-05 admin verification logic; legal confirm before phase-05.
