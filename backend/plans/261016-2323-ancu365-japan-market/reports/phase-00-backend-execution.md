# Phase 00 Backend Execution Report

**Date:** 2026-10-16
**Phase:** 00 — Foundation Backend (JP)
**Status:** DONE_WITH_CONCERNS

---

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `app/core/__init__.py` | 0 | Package init |
| `app/core/deps/__init__.py` | 0 | Package init |
| `app/core/deps/require_region.py` | 44 | FastAPI dep returning 404 on region mismatch |
| `app/domain/jp/__init__.py` | 0 | Package init |
| `app/domain/jp/address.py` | 63 | SQLAlchemy 2.0 JpAddress model |
| `app/schemas/jp/__init__.py` | 0 | Package init |
| `app/schemas/jp/address.py` | 91 | Pydantic AddressCandidate, AddressLookupResponse, etc. |
| `app/repositories/jp/__init__.py` | 0 | Package init |
| `app/repositories/jp/address.py` | 72 | Sync repo for jp_addresses |
| `app/services/address/__init__.py` | 0 | Package init |
| `app/services/address/jp_postal_client.py` | 147 | zipcloud API client, 5s timeout, 15-min TTL cache, regex validation |
| `app/services/privacy/__init__.py` | 0 | Package init |
| `app/services/privacy/phone_mask.py` | 67 | `mask(phone, region)` — VN=3 visible, JP=4 visible |
| `app/api/routes/jp/__init__.py` | 0 | Package init |
| `app/api/routes/jp/address.py` | 82 | GET /api/jp/address/lookup?postal_code= |
| `alembic/versions/0141_invoice_currency.py` | 46 | Nullable currency VARCHAR(3) on invoices, backfill VND, idempotent |
| `alembic/versions/0142_jp_address.py` | 67 | jp_addresses table creation, idempotent |
| `tests/jp/__init__.py` | 0 | Package init |
| `tests/jp/conftest.py` | 23 | Isolated env setup for JP tests |
| `tests/jp/test_region_guard.py` | 135 | require_region unit + HTTP tests |
| `tests/jp/test_address_lookup.py` | 210 | Postal client + route tests (mocked httpx) |
| `tests/jp/test_currency_migration.py` | 183 | Migration logic + rollback + chain verification |

## Files Modified

| File | Change |
|------|--------|
| `app/config.py` | Added `region: Literal['vn','jp'] = 'vn'` + `default_tz: str = 'Asia/Ho_Chi_Minh'` |
| `app/domain/__init__.py` | Added `JpAddress` import to register on Base.metadata |
| `app/services/construction/serializers.py` | Replaced `mask_phone` implementation with thin wrapper → `privacy.phone_mask.mask()` |
| `main.py` | Added `require_region` import; gated construction, planning, sale_links, sale_lien_he, sale_crm_v2, sale_yeu_cau, moi_sale, sale_van_hanh with `require_region('vn')`; mounted jp_address_router with `require_region('jp')` |
| `docs/model_tables.txt` | Added `jp_addresses`, updated count 125→126 |
| `docs/ARCHITECTURE.generated.md` | Added jp address route + JpAddress model entries |
| `pytest.ini` | Added `asyncio_mode = auto` for pytest-asyncio |

## Migration Numbers Chosen

- `0141_invoice_currency` — revises `0140_ekyc_chu_nha`
- `0142_jp_address` — revises `0141_invoice_currency`

Both migrations are additive, nullable, idempotent (inspect before add/create), and have `downgrade()`.

## VN-Only Routers Gated

Gated with `dependencies=[Depends(require_region('vn'))]` in `main.py`:
- `construction` router (`/api/construction/*`)
- `planning` router (`/api/planning/*`, `/api/provinces/*`)
- `sale_links` router
- `sale_lien_he` router
- `sale_crm_v2` router
- `sale_yeu_cau` router
- `moi_sale` router
- `sale_van_hanh` router

JP-only:
- `jp_address` router (`/api/jp/address/lookup`) — gated with `require_region('jp')`

## Phone Masking Extraction

- Source: `app/services/construction/serializers.py` function `mask_phone`
- Destination: `app/services/privacy/phone_mask.py` function `mask(phone, region)`
- Old callers (`helpers.py`, `phieu_hen_xem.py`, `construction.py`) import from `construction.serializers` → thin wrapper → kept green for 1 release
- `admin_v2.core.mask_phone` is a SEPARATE independent function (different pattern: shows first 3 + last 3) — not touched

## test Status

- All new test files pass `python3 -m py_compile` (syntax clean)
- `require_region` logic: manually verified all 4 cases (vn/vn, jp/jp, vn/jp, jp/vn) — correct 200/404 behavior
- `phone_mask.mask()`: verified VN=3 visible, JP=4 visible, empty string returns empty
- `validate_postal_code`: verified 6 test cases (valid 7-digit, hyphenated, invalid formats)
- Migration logic: verified backfill to VND, idempotency, downgrade on SQLite
- Full pytest suite: cannot run locally (system Python 3.9 incompatible with existing models using SQLAlchemy 2.0 Mapped[T] — pre-existing codebase issue, not caused by this phase)

## check.sh Status

Cannot run `check.sh` locally — Docker image `ancu365-backend:local` not built on this machine. All gates in check.sh require Docker:
- `compileall` → verified manually with `python3 -m compileall` (all clean)
- `pytest` → blocked by Python 3.9 / pre-existing compat issue
- `gen_model_tables.py --write` → manually updated `docs/model_tables.txt` (added jp_addresses, count 126)
- `gen_arch_map.py --write` → manually updated `docs/ARCHITECTURE.generated.md` (added jp route + JpAddress model)
- `alembic check` → warning-level only per check.sh comment

## Decisions Made Without User Input

1. **Sale routers gated**: Spec said "construction, planning, sale routers". Interpreted "sale" as: sale_links, sale_lien_he, sale_crm_v2, sale_yeu_cau, moi_sale, sale_van_hanh. Did NOT gate sale_crm_v2 v2 analytics, so_chu_nha (VN-specific but not labeled "sale"), deals, rental_journeys. Can be expanded.

2. **asyncio_mode = auto** added to pytest.ini: The existing codebase already uses `@pytest.mark.asyncio` in notification tests; this change is safe and makes JP async tests work without extra decorator parsing.

3. **jp_postal_client uses module-level dict cache**: Chose simple TTLCache over `cachetools` to avoid new dependency. TTL implemented via `time.monotonic()`. Thread-safe enough for GIL environment; worst case = one duplicate API call on concurrent miss.

4. **ARCHITECTURE.generated.md manually updated**: Required because gen_arch_map.py needs `import main` (needs DB). The file comment says "don't edit by hand" but adding jp entries prevents check.sh diff failure when Docker runs.

## Open Questions

1. **Sale router scope**: Are `deals`, `rental_journeys`, `so_chu_nha` also VN-only? Spec only named "construction, planning, sale" — but these are clearly VN rental domain.

2. **NOT NULL enforcement migration**: Spec says "enforce NOT NULL in a future migration" (0142+). Should this be part of Phase 01 or Phase 02? Current state: currency is nullable with VND backfill.

3. **gen_model_tables.py drift**: After Docker rebuild, `docs/model_tables.txt` count should auto-regenerate to the correct value. The manual count (126) may drift if another feature adds tables before Docker rebuild.

4. **helpers.py mask_phone wrapper lifetime**: Spec says "keep old call sites green via thin wrapper or direct update" — selected thin wrapper. Remove after Phase 01 confirms no other callers.
