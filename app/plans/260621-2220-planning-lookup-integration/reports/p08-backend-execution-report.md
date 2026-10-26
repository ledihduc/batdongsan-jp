# P08 Backend Execution Report

**Phase:** phase-08-tests-qa-docs (backend portion)
**Date:** 2026-06-22
**Executor:** Claude Sonnet 4.6 (claude-code)
**Work context:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/`

---

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `tests/__init__.py` | 2 | Package marker |
| `tests/conftest.py` | 152 | Fixtures: FakeSession, TestClient, JWT tokens, canned data |
| `tests/test_planning_parcels.py` | 84 | Parcel by point + parcel by ID tests (12 tests) |
| `tests/test_planning_search.py` | 120 | Nominatim proxy mock tests (9 tests) |
| `tests/test_planning_districts.py` | 68 | District list + layers tests (8 tests) |
| `tests/test_planning_report_error.py` | 90 | Auth + validation for report-error (11 tests) |
| `tests/test_planning_admin.py` | 120 | Admin endpoints 401/403/200 (14 tests) |
| `tests/test_planning_rate_limit.py` | 130 | Limiter config introspection (11 tests) |
| `tests/test_planning_etl_smoke.py` | 65 | ETL smoke (4 tests — all skipped, needs live Postgres) |
| `docs/planning-lookup.md` | 240 | Backend API docs (10 sections) |

## Files Modified

| File | Change | Reason |
|------|--------|--------|
| `requirements.txt` | Added 4 test deps | `pytest==8.3.2`, `pytest-cov==5.0.0`, `pytest-asyncio==0.23.8`, `pytest-mock==3.14.0` |
| `app/helpers.py` | Added `from __future__ import annotations` | Fix Python 3.9 compat (`int | None` union syntax fails on 3.9, prod uses 3.11) |

---

## Test Run Results

```
Platform: Python 3.9.6 (local), pytest 8.3.2
Command: python -m pytest tests/ -v --tb=short

65 passed, 4 skipped, 0 failed in 0.13s
```

### By file:

| File | Passed | Skipped | Failed |
|------|--------|---------|--------|
| test_planning_admin.py | 14 | 0 | 0 |
| test_planning_districts.py | 8 | 0 | 0 |
| test_planning_etl_smoke.py | 0 | 4 | 0 |
| test_planning_parcels.py | 12 | 0 | 0 |
| test_planning_rate_limit.py | 11 | 0 | 0 |
| test_planning_report_error.py | 11 | 0 | 0 |
| test_planning_search.py | 9 | 0 | 0 |
| **TOTAL** | **65** | **4** | **0** |

### Coverage (planning module):

```
Name                               Stmts   Miss  Cover
------------------------------------------------------
app/middleware/error_handler.py       28      7    75%
app/middleware/rate_limit.py          19      0   100%
app/routers/planning.py               73      0   100%
app/services/nominatim_proxy.py       14      8    43%
app/services/planning_service.py      19      0   100%
------------------------------------------------------
TOTAL                                153     15    90%
```

Target was ≥ 80% — **achieved 90%**.

---

## Mock Strategy Chosen

**Approach:** Minimal test FastAPI app + `dependency_overrides` for DB + `AsyncMock` for Nominatim.

**Rationale vs alternatives:**

1. **Did NOT import `main.py`** — `main.py` calls `Base.metadata.create_all(bind=engine)` at module level, which requires a real DB connection even with `DATABASE_URL=postgresql://localhost/fake_test`. Instead, built a minimal `FastAPI` instance in `conftest.py` that includes only the planning router.

2. **`FakeSession` class** — returns `list[dict]` rows via `.mappings().first()` / `.all()` interface. Configured per-test via `fake_db_session.configure(rows)`. Session is `scope=session` (shared) but rows are reset per fixture. This avoids SQLAlchemy ORM entirely.

3. **`AsyncMock` for Nominatim** — `patch("app.services.nominatim_proxy.search")` intercepts the async function. No real HTTP calls. Tests verify correct args passed to mock.

4. **ETL trigger test** — `hcmc_fetcher.py` uses `datetime.UTC` (Python 3.11+). On Python 3.9 this fails. Solved by injecting a `MagicMock` module into `sys.modules["app.services.planning_etl.hcmc_fetcher"]` before the request. This does NOT modify source.

5. **Rate limit 429 smoke** — Full 429 testing (31 requests) is NOT in unit tests. `slowapi` in-memory store shares state across test requests on same IP (127.0.0.1). Hitting the limit would poison later tests. Strategy: structural tests (inspect source for decorator counts, key function unit tests) + note in file that actual 429 is validated in P09 staging.

---

## Deviations from Plan

| Plan item | Actual | Reason |
|-----------|--------|--------|
| "Mock at service level — assert SQL string contains ST_Contains" | Mocked at DB session level (FakeSession) | Simpler: planning_service.py calls db.execute(text(...)); intercepting at session level covers the same coverage goal and is less fragile than asserting SQL strings |
| "set DATABASE_URL=postgresql://localhost/fake_test before import of main.py" | Did NOT import main.py at all | main.py has module-level `create_all()` that immediately connects to DB — even with fake URL it fails. Built minimal test app instead. |
| `pytest-mock==3.14.0` in requirements | Installed but not used (used stdlib `unittest.mock`) | stdlib mock was sufficient; pytest-mock provides `mocker` fixture which is handy but not required for this test set |

---

## Issues Encountered

1. **Python 3.9 vs 3.11**: Source code uses `int | None` union syntax (Python 3.10+) in `app/helpers.py`. Fixed with `from __future__ import annotations`. Dockerfile uses Python 3.11 — no issue in prod.

2. **ETL module import fails on Python 3.9**: `hcmc_fetcher.py` uses `from datetime import UTC` (Python 3.11+). Fixed test with `sys.modules` injection for that specific test. Source unchanged.

3. **`FakeSession.execute()` returns `list[dict]`**: The planning_service constructs `ParcelDetail(**dict(row))`. Since `FakeResult.first()` returns a raw `dict`, this works directly — no need to mimic SQLAlchemy's `RowMapping`.

---

## Tasks Completed

- [x] Test deps added to `requirements.txt`
- [x] `tests/__init__.py` created
- [x] `tests/conftest.py` with FakeSession, client, admin_token, user_token, DB fixtures
- [x] 7 test files created (parcels, search, districts, report_error, admin, rate_limit, etl_smoke)
- [x] `pytest tests/` → 65 passed, 4 skipped, 0 failed
- [x] Coverage ≥ 80% achieved (90% overall, 100% on router + service + rate_limit)
- [x] `docs/planning-lookup.md` created (10 sections)
- [x] `reports/qa-checklist-22ac.md` created

---

## Not Done (Backend portion only)

- Frontend test files (Flutter) — out of scope for this agent (backend-only)
- Manual QA 22 AC — requires real Android device + staging deploy (P09)
- Integration E2E test `planning_e2e_test.dart` — Flutter frontend scope

---

## Open Questions

1. Risky zone codes `{DGT, CXP, DCC, DXH}` are provisional — **must verify with TNMT TP.HCM** before prod launch (documented in planning-lookup.md §6 and §10).

2. `hcmc_fetcher.py` uses `datetime.UTC` (3.11+). If CI runner uses Python 3.9, ETL module import will fail. Recommend adding `from __future__ import annotations` + `timezone.utc` alias to `hcmc_fetcher.py` for backwards compat. Out of scope for P08 test files (don't own that file).

3. `nominatim_proxy.py` coverage is 43% — the `httpx` path is always mocked. A contract integration test against a dev Nominatim instance would close this gap. Deferred to P09.

---

**Status:** DONE
**Summary:** 65/65 non-skipped backend tests pass. 90% coverage on planning module (100% router, 100% service, 100% rate_limit middleware). Docs + QA checklist created. 4 ETL smoke tests correctly skipped pending live Postgres.
**Concerns:** Python version mismatch (local 3.9 vs prod 3.11) required `from __future__ import annotations` fix in helpers.py and sys.modules injection for ETL test. Both are safe — no source logic changed.
