# Phase 01 — Core Chintai Backend

**Priority:** P1 · **Status:** 📋 Ready · **Est:** 3 weeks BE · **Depends on:** P0 BE
**Context:** [Gap matrix §2.3, §2.5](../../../plans/261016-2323-ancu365-japan-market/research/gap-matrix.md) · [Spec §4-6](../../../plans/261016-2323-ancu365-japan-market/research/researcher-01-japan-spec-extract.md)

## Overview

Deliver the JP listing data model (間取り/面積/築年数, train access), chintai money fields (shikikin/reikin), 内見 scheduler, 入居申込 application form, and role matrix for 入居者/仲介/オーナー/管理者.

## Key insights

- JP money fields are **high legal risk** — misdisplay is actionable. Use dedicated `JpRentalTerms` sub-model, never overload existing booking price fields.
- Role scoping — 仲介 (sales) is scoped to assigned listings; オーナー to owned; 管理者 global. Match pattern in `app/services/delegation/`.
- Transit dataset = 駅データ.jp (per D7 default) — one-shot import quarterly, not live API.

## Requirements

**Functional**
- `Listing` extended with `jp_rental_terms_id`, `jp_property_info_id`, `transit_access` relation.
- `JpRentalTerms`: 月額家賃, 共益費, 敷金, 礼金, 保証金, 更新料, 仲介手数料率, 保証会社料, 消費税扱い.
- `JpPropertyInfo`: 間取り(enum), 専有面積, 築年数, 構造(RC/木造/鉄骨), 階数, 向き, 入居可能日.
- `TransitAccess` (listing_id, station_id, line_id, walk_min).
- `Station` + `TrainLine` reference tables + import script from 駅データ.jp CSV.
- `Viewing` model + endpoints: tenant creates request with ≤3 slots → agent confirms one → both notified.
- `TenantApplication` with 勤務先/年収/連帯保証人/緊急連絡先 + document upload references.
- Role matrix enforcement via `require_role_scope` dep.

## Architecture

```
app/
  domain/jp/
    rental_terms.py
    property_info.py
    transit.py
    viewing.py
    application.py
  services/jp/
    viewing/              ← scheduler logic
    application/          ← intake + validation
    transit/              ← CSV importer
  api/routes/jp/
    listings.py           ← extended CRUD
    viewings.py
    applications.py
  repositories/jp/*
  schemas/jp/*
scripts/
  import_jp_stations.py
```

## Related code files

**Modify**
- `app/domain/listing.py` (NEW arch target) — add JP relations behind `region=jp` guard
- `app/api/routes/listings.py` — JP response schema when `region=jp`
- `app/services/notification/` — JP event templates

**Create** (all under `app/domain/jp/`, `app/services/jp/`, etc. — do NOT touch `app/models.py`)
- Models + Alembic migrations for each new table
- Full CRUD routes under `/api/jp/listings`, `/api/jp/viewings`, `/api/jp/applications`
- `scripts/import_jp_stations.py` — one-shot CSV import
- Tests under `tests/jp/listings/`, `tests/jp/viewings/`, `tests/jp/applications/`

## Implementation steps

1. Alembic: 5 migrations (rental_terms, property_info, transit_access, stations, train_lines, viewings, applications) — split small, additive.
2. Build domain models + repositories.
3. CSV import script for stations (seed data gated to Tokyo first per launch region TBD).
4. `Viewing` service: slot validation (business hours, lead time ≥24h), confirmation state machine, notification hooks.
5. `TenantApplication` service: field validation, document upload URL issuance (reuse Supabase Storage).
6. Role matrix: extend `app/services/auth/role_scope.py` with 仲介-to-listing assignment table.
7. Extend `/api/jp/listings` to accept + return JP fields; keep VN endpoint shape untouched.
8. Notification templates (JA) for 内見リクエスト, 内見確定, 申込受付, 審査中.
9. `./check.sh` + `gen_arch_map.py --write`.

## Todo list

- [ ] All 7 migrations applied + rollback tested
- [ ] JP listing CRUD green with full field set
- [ ] 内見 state machine covered by tests
- [ ] 申込 upload + validation
- [ ] Role-scope enforcement tests (仲介 cannot see other agents' listings)
- [ ] Station import — Tokyo 23区 seeded
- [ ] JA notification templates registered
- [ ] `./check.sh` green, pytest ≥+40 new tests

## Success criteria

- Agent can create JP listing with full money fields; tenant sees ¥ formatting; search endpoint returns transit filter results.
- 内見 flow end-to-end via API: request → confirm → both notified.
- 入居申込 submits + files upload + status trail.

## Risk assessment

- Transit import correctness — spot-check 20 stations manually before closing.
- Role scope regression on VN — add VN role test to CI.

## Security

- 申込 PII (年収, 保証人) — field-level encryption at rest? Decision deferred to P2 APPI work; for now, flag column with `pii=True` meta.
- Role scope must deny by default; missing scope = 403.

## Next steps

- Unblocks: P2 (screening workflow consumes 申込; invoice consumes rental_terms; viewing feeds IT重説 session).
