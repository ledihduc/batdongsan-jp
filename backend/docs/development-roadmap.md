# Development Roadmap — ancu365 Backend

**Last updated:** 2026-06-30  
**Current phase:** Phase 3 (Delegation v1 SHIPPED)

---

## Phase Overview

| Phase | Name | Status | Target | Progress |
|-------|------|--------|--------|----------|
| 1 | Core Booking Platform | ✅ Complete | 2026-05-15 | 100% |
| 2 | Planning Lookup (PostGIS) | ✅ Complete | 2026-06-22 | 100% |
| 3 | Owner-Operator Delegation v1 | ✅ SHIPPED | 2026-06-30 | 100% |
| 4 | Delegation v1.1 (Polish) | 📋 Planned | 2026-07-31 | 0% |
| 5 | Multi-Delegation Support | 📋 Planned | 2026-09-30 | 0% |
| 6 | Advanced Analytics | 📋 Planned | Q4 2026 | 0% |

---

## Phase 1: Core Booking Platform ✅

**Shipped:** 2026-05-15

**Deliverables:**
- User auth (JWT HS256 + bcrypt)
- House CRUD + search filters
- Booking state machine (inquiry → locked → confirmed → checked_in → completed)
- Reviews + ratings
- Wishlists
- Notifications (in-app)
- Chat (REST + WebSocket)
- Image upload + serving

**Database:** 8 core tables (users, houses, bookings, reviews, wishlists, notifications, chat_messages, amenities)

**API:** 16 endpoints covering all core flows

---

## Phase 2: Planning Lookup (PostGIS) ✅

**Shipped:** 2026-06-22

**Deliverables:**
- Land-use planning data for HCMC (24 districts)
- PostGIS spatial search (ST_Contains)
- Nightly ETL from TNMT WFS
- Martin vector tile server
- 9 REST endpoints for parcel lookup + addresses
- Rate limiting (100/h per user)

**Database:** planning.parcels, planning.etl_runs, planning.reports (PostGIS schema)

**Infrastructure:** Martin tile server (Docker), Nominatim geocoding (internal)

---

## Phase 3: Owner-Operator Delegation v1 ✅ SHIPPED 2026-06-30

**Shipped:** 2026-06-30

**Deliverables:**
- Delegation model (owner → operator authorization)
- Invitation workflow (email + SMS)
- KYC + POA (notarized PDF)
- ActorContext (per-request dual-identity)
- Permission presets (full_ops, limited_approval, kb04_fast_track)
- Commission immutability (locked at paid_at)
- Threshold approvals (24h expiry + auto-reject)
- Lockdown (30-day post-termination block)
- Owner death + heir flow
- KB04 fast-track workflow
- Fraud auto-suspension (atomic across delegations)
- Dual audit trail (actor_id + on_behalf_of_user_id)

**Database:** new tables for delegations, delegation_invitations, delegation_approvals, owner_death_certificates, plus extensions to users / host_profiles / change_logs / audit_logs / invoices (migrations 0021–0036)

**Files added:** new packages under `app/services/{delegation,approval,commission,owner_death,kyc,onboarding,retention,notification,pricing,admin}/`, `app/api/`, `app/domain/`, plus schemas

**Test suite (full repo):** 1218 passed, 0 failed, 114 skipped

---

## Phase 4: Delegation v1.1 (Polish) 📋

**Target:** 2026-07-31  
**Status:** Planned

**Scope:**
- Operator self-service termination (currently owner-only)
- Delegation history export (PDF + CSV)
- Commission analytics dashboard (owner view)
- SMS + email templates i18n (Vietnamese + English)
- Batch re-delegation (operator → new operator via existing owner)
- Performance: p99 delegation lookup < 100ms

**New files:**
- `app/services/delegation/termination_self_service.py`
- `app/services/reports/delegation_export_service.py`
- `app/api/routes/delegation_analytics.py`

---

## Phase 5: Multi-Delegation Support 📋

**Target:** 2026-09-30  
**Status:** Planned (depends on Phase 4 completion)

**Scope:**
- Operator can hold multiple active delegations (currently 1:1)
- Delegation composition (union of all presets)
- Conflict resolution (highest permission wins)
- Commission aggregation (sum across delegations)
- Approval queue (single inbox for all delegations)
- Context switching (operator picks active delegation per request)

**Schema changes:**
- Delegation: remove unique(operator_id), add unique(operator_id, owner_id) + index

**Service refactors:**
- ActorContext: load all active delegations, merge permissions
- ApprovalService: query across all operator delegations

---

## Phase 6: Advanced Analytics 📋

**Target:** Q4 2026  
**Status:** Planned (depends on Phases 4–5)

**Scope:**
- Owner performance dashboard (revenue, commission paid, operator KPIs)
- Operator performance dashboard (invoices, approval rate, response time)
- Platform analytics (total delegations, adoption rate, fraud incidents)
- Cohort analysis (new operators, retention, churn)
- Exports: SQL, CSV, Tableau connector

**New files:**
- `app/services/analytics/owner_analytics_service.py`
- `app/services/analytics/operator_analytics_service.py`
- `app/api/routes/analytics.py`

**Database:** events table + fact tables (star schema)

---

## Known Gaps / Tech Debt

| Item | Priority | Owner | Est. Days |
|------|----------|-------|----------|
| Operator self-termination | Medium | TL | 2 |
| Batch re-delegation workflow | Low | TL | 3 |
| Commission refunds (partial termination) | Medium | Dev | 3 |
| Delegations export (PDF + CSV) | Low | Dev | 2 |
| Performance: delegation query optimization | Medium | Perf | 1 |
| i18n SMS/email templates | Medium | Dev | 2 |
| Concurrent delegation + approval race | Low | QA | 2 |

---

## Success Metrics (Phase 3)

| Metric | Target | Status |
|--------|--------|--------|
| Full test suite | 0 failures | ✅ 1218 passed / 0 failed |
| Tech Lead Code Review | APPROVED | ✅ APPROVED post-remediation |
| Security review (CRITICAL/HIGH count) | 0 | ✅ 0 (2 MEDIUM, 2 LOW noted) |
| AC coverage (66 ACs + 15 NFRs + 9 TL decisions) | All met after remediation | ✅ Met |

Performance, deployment, MTTF and adoption metrics → TBD (instrument after first staging rollout).

---

## Dependencies & Blockers

**Phase 3 → Phase 4:**
- None (Phase 4 is independent polish)

**Phase 4 → Phase 5:**
- Multi-delegation schema migration (non-blocking)
- Context switching UX design (frontend)

**Phase 5 → Phase 6:**
- Data warehouse setup (analytics)
- Reporting tools (Tableau or Metabase)

---

## Release Notes (Phase 3)

**Date:** 2026-06-30  
**Version:** 1.0.0  
**Breaking changes:** None

### What's new
- Operators can now manage properties on behalf of owners with full dual-identity audit
- Commission automatically locked at payment time (immutable thereafter)
- Threshold approvals with 24-hour expiry window
- 30-day lockdown prevents rapid re-delegation
- Owner death + heir transition flow
- KB04 fast-track for district-flagged contracts

### Fixes (Phase 3 bugs)
- B1: POA PDF dual-disclosure generation (from contract_pdf_service.py)
- B2: Host immutability enforcement (from marketplace_sync_service.py)

### Known issues
- Operator self-termination not yet available (v1.1)
- Commission refunds require admin manual adjustment (v1.1)
- No batch re-delegation workflow (v1.1)

### Migration notes
- Run `alembic upgrade head` (migrations 0021–0036 auto-create delegation tables)
- No data loss (backward-compatible)
- Existing bookings unaffected

### Next steps
- Phase 4 (v1.1) targets 2026-07-31 (operator polish)
- Phase 5 (multi-delegation) targets 2026-09-30

---
