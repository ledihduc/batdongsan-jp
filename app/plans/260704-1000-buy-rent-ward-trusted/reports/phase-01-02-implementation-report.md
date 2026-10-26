# Phase 01+02 Implementation Report

## Phase
- Phase: 01+02 (backend migration + admin trusted endpoint)
- Plan: plans/260704-1000-buy-rent-ward-trusted/
- Status: DONE

## Files Modified
| File | Change |
|------|--------|
| `alembic/versions/0039_listing_v2.py` | CREATED — migration adding 6 cols + composite index + data migration approved→published |
| `app/models.py` | ADD 6 columns to House; change status default pending→published |
| `app/routers/houses.py` | POST default published + tx_type/ward_slug fields; GET approved alias + v2 filters; PUT 24h tx_type rule |
| `app/routers/admin_houses.py` | ADD PATCH /{id}/trusted endpoint (admin only, audit log) |
| `app/helpers.py` | ADD 6 new fields to house_to_dict response |
| `tests/test_houses_transaction_type.py` | CREATED — 11 tests |
| `tests/test_admin_trusted.py` | CREATED — 8 tests |

## Tasks Completed
- [x] Migration 0039_listing_v2.py (dialect-guard, FK on Postgres only, approved→published data migration, reversible downgrade)
- [x] models.py House: 6 new Mapped columns, status default published
- [x] houses.py POST: default status=published, transaction_type, ward_slug, ward_slug_legacy
- [x] houses.py GET: status=approved alias, transaction_type/is_trusted/ward_slug filters, default published
- [x] houses.py PUT: transaction_type editable within 24h (silently ignored after), ward_slug any time
- [x] admin_houses.py: PATCH /{id}/trusted (require_admin, audit_log_service.record + logger.info)
- [x] helpers.py: expose all 6 new fields in house_to_dict
- [x] Schemas: raw dict pattern preserved (consistent with existing admin_houses.py)
- [x] Tests: 19/19 passing

## Tests Status
- Type check: N/A (no mypy configured in project)
- Unit tests: PASS — 19/19
  - test_houses_transaction_type.py: 11 passed
  - test_admin_trusted.py: 8 passed

## Issues Encountered
1. Pre-existing bug in `host_profile_repository.py:54` — `write_change_log()` called with `actor_id=` kwarg but function signature uses `explicit_actor_id=`. NOT in our file ownership scope. Workaround: tests pre-seed HostProfile so the `if not repo.get_by_user_id()` guard is False and the buggy code path is never reached. Documented in tests with comment.

## Next Steps
- Phase 03: Flutter data layer — HouseModel fields (transactionType, isTrusted, wardSlug, wardSlugLegacy), HouseProvider state.
- Pending: `alembic upgrade head` on staging DB to apply 0039_listing_v2.

## Unresolved Questions
- None.
