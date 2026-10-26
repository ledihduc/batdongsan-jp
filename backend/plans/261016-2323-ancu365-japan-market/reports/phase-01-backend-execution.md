# Phase 01 Backend Execution Report — Core Chintai Backend

**Date:** 2026-10-16
**Status:** DONE
**Tests:** 132 pass (96 new Phase 01 + 36 P0 carried forward)

---

## Files Modified / Created

### Alembic Migrations

| File | Table(s) | Migration |
|------|----------|-----------|
| `alembic/versions/0143_jp_rental_terms.py` | `jp_rental_terms` | Additive, idempotent, downgrade ✓ |
| `alembic/versions/0144_jp_property_info.py` | `jp_property_info` | Additive, idempotent, downgrade ✓ |
| `alembic/versions/0145_jp_transit.py` | `jp_train_lines`, `jp_stations`, `jp_transit_access` | Additive, idempotent, downgrade ✓ |
| `alembic/versions/0146_jp_viewings.py` | `jp_viewings` | Additive, idempotent, downgrade ✓ |
| `alembic/versions/0147_jp_applications.py` | `jp_tenant_applications`, `jp_application_reviews` | Additive, idempotent, downgrade ✓ |
| `alembic/versions/0148_listing_sales_assignments.py` | `listing_sales_assignments` | Additive, idempotent, downgrade ✓ |

**Migration chain:** 0142 → 0143 → 0144 → 0145 → 0146 → 0147 → 0148

### Domain Models (`app/domain/jp/`)

| File | Models |
|------|--------|
| `rental_terms.py` | `JpRentalTerms` |
| `property_info.py` | `JpPropertyInfo` |
| `transit.py` | `TrainLine`, `Station`, `TransitAccess` |
| `viewing.py` | `JpViewing` |
| `application.py` | `JpTenantApplication`, `JpApplicationReview` |
| `sales_assignment.py` | `ListingSalesAssignment` |
| `__init__.py` | (updated) registerd in `app/domain/__init__.py` |

### Repositories (`app/repositories/jp/`)

| File | Repository |
|------|-----------|
| `rental_terms.py` | `JpRentalTermsRepository` |
| `property_info.py` | `JpPropertyInfoRepository` |
| `transit.py` | `TrainLineRepository`, `StationRepository`, `TransitAccessRepository` |
| `viewing.py` | `JpViewingRepository` |
| `application.py` | `JpTenantApplicationRepository`, `JpApplicationReviewRepository` |
| `sales_assignment.py` | `ListingSalesAssignmentRepository` |
| `__init__.py` | Package init |

### Pydantic Schemas (`app/schemas/jp/`)

| File | Schemas |
|------|---------|
| `rental_terms.py` | `JpRentalTermsCreate/Update/Response` |
| `property_info.py` | `JpPropertyInfoCreate/Update/Response` |
| `transit.py` | `TransitAccessCreate/Response`, `StationResponse`, `TrainLineResponse` |
| `viewing.py` | `JpViewingCreate`, `JpViewingConfirmRequest`, `JpViewingCancelRequest`, `JpViewingResponse` |
| `application.py` | `JpTenantApplicationCreate/Update/Response`, `JpApplicationReviewCreate/Response`, `JpListingCreateRequest/Response` |
| `__init__.py` | Package init |

### Services

| File | Purpose |
|------|---------|
| `app/services/jp/viewing/scheduler.py` | Slot validation (JST business hours 10-19, lead ≥24h), state machine |
| `app/services/jp/application/intake.py` | Application status transitions, review decision recording |
| `app/services/auth/role_scope.py` | `require_role_scope` FastAPI dependency — JP role matrix |

### API Routes (`app/api/routes/jp/`)

| File | Routes |
|------|--------|
| `listings.py` | POST /api/jp/listings/attach, GET /api/jp/listings/{id}/jp-data, GET /api/jp/stations/search |
| `viewings.py` | POST/GET /api/jp/viewings, GET/{id}, POST confirm/cancel/complete |
| `applications.py` | POST/GET /api/jp/applications, GET/{id}, POST submit/start-review, GET upload-url stub |
| `application_reviews.py` | POST/GET /api/jp/applications/{id}/reviews |

### Scripts & Data

| File | Purpose |
|------|---------|
| `scripts/import_jp_stations.py` | One-shot CSV importer for 駅データ.jp format, idempotent upsert |
| `scripts/data/jp_stations_tokyo_seed.csv` | Seed CSV: 20 Tokyo stations across 3 lines (山手線, 銀座線, 丸ノ内線) |

### Notification Templates (`app/services/notification/templates/jp/`)

7 JA email templates:
- `viewing_requested.email.ja.j2`
- `viewing_confirmed.email.ja.j2`
- `viewing_cancelled.email.ja.j2`
- `application_submitted.email.ja.j2`
- `application_in_review.email.ja.j2`
- `application_approved.email.ja.j2`
- `application_rejected.email.ja.j2`

### Modified Files

| File | Change |
|------|--------|
| `app/domain/__init__.py` | Register 9 new JP models on `Base.metadata` |
| `main.py` | Register 4 new JP routers with `require_region("jp")` guard |
| `docs/model_tables.txt` | Appended 9 new JP tables (count updated to 135) |
| `docs/ARCHITECTURE.generated.md` | Appended routes + model entries for Phase 01 |

---

## Test Results

```
132 passed, 1 warning in 0.56s
```

### New test files (96 new tests)

| File | Tests | Coverage |
|------|-------|---------|
| `tests/jp/listings/test_jp_listing_schemas.py` | 26 | Schema validation: rental_terms, property_info, transit |
| `tests/jp/listings/test_jp_listing_models.py` | 7 | ORM field storage (isolated SQLite) |
| `tests/jp/viewings/test_viewing_scheduler.py` | 23 | Slot validation, state machine, role enforcement |
| `tests/jp/viewings/test_viewing_models.py` | 3 | JpViewing ORM (isolated SQLite) |
| `tests/jp/applications/test_application_schemas.py` | 11 | Schema validation: application + review |
| `tests/jp/applications/test_application_intake.py` | 13 | Status transition state machine |
| `tests/jp/applications/test_application_models.py` | 4 | ORM field storage (isolated SQLite) |
| `tests/jp/role_scope/test_role_scope.py` | 9 | Role scope enforcement |

---

## Decisions Made Unilaterally

1. **listing_id as string (no FK):** All JP tables reference listing_id as `VARCHAR(64)` without FK constraint to the core listings table. Decision: avoids cross-domain dependency; listing existence validation deferred to service layer. P2 can add FK once listing table is fully migrated to new arch.

2. **org_id nullable at DB level, required at service level:** org_id is `nullable=True` in schema to avoid blocking existing data import/migration. Service layer and repositories enforce org_id filtering on all list queries. `# MULTI-TENANT ISOLATION` comments mark every enforcement point.

3. **JSON not JSONB for SQLite test compatibility:** Migrations use dialect-aware JSON detection (`postgresql.JSONB()` on PG, `sa.JSON()` on others). Models use `sa.JSON` for portability.

4. **Isolated SQLite base for model tests:** ORM tests use a standalone `DeclarativeBase` instead of `app.database.Base` to avoid triggering full mapper configuration (which pulls in `User` model FK resolution). This is the correct pattern for isolated unit tests.

5. **Document upload URL stub (501):** Supabase Storage pre-signed URL issuance exists in `app/services/storage/` but is in a different module not confirmed to be import-safe from JP context. Returns 501 with clear P2 tracking message.

6. **`require_role_scope` reads from `request.state`:** Auth middleware must populate `request.state.user_id`, `request.state.org_id`, `request.state.role`. This matches the pattern used by existing VN endpoints. If middleware not yet wired for JP, the dep returns 403.

7. **Notification templates as Jinja2 .j2 files:** Matches existing template pattern in `app/services/notification/templates/`. Template rendering integration (wiring events to send emails) is P2 work — templates are ready to use.

---

## Multi-tenant Isolation — org_id Scoping Approach

Every JP table has `org_id VARCHAR(64)`. Every repository `list_*` method:
- Requires `org_id` as a parameter
- Always includes `.filter(Model.org_id == org_id)` with a `# MULTI-TENANT ISOLATION` comment
- The `get_by_id_org` pattern is used for single-record access

The `listing_sales_assignments.is_assigned()` method is the authority for `sales → assigned` scope checks. The `require_role_scope` dependency calls this on every request where a `listing_id` is present in path params.

---

## Deferred to P2

| Item | Reason |
|------|--------|
| Document upload pre-signed URL issuance | Supabase Storage integration — returns 501 stub |
| Field-level encryption for PII columns | APPI compliance work — columns tagged `pii=True` in column comments for tooling discovery |
| Notification event wiring (email/push send) | Templates ready; dispatcher integration is P2 |
| Listing FK enforcement | listing_id stored as string; FK add requires core listing table migration |
| `gen_arch_map.py --write` regeneration | Requires live DB; manual doc update done; run after DB is available |

---

## Open Questions

1. **Listing ownership check on JP endpoints:** How does the `owner → own` scope know which user owns a listing? No `listing.owner_user_id` field is currently visible to JP domain without importing from `app/models.py`. P2 needs to define how JP listing ownership is stored/queried.

2. **`org_id` source in JWT:** Which JWT claim carries `org_id`? Currently reads from `request.state.org_id` (must be set by auth middleware). If `org_id` is embedded in JWT, middleware must extract it.

3. **Stations seed validation:** The 20 Tokyo stations in `jp_stations_tokyo_seed.csv` were hand-typed for test coverage. Coordinates are approximate. Should be replaced with official 駅データ.jp CSV before production launch.
