# Phase 00 — Backend Foundation (JP)

**Priority:** P0 blocker · **Status:** 📋 Ready · **Est:** 1.5 weeks BE
**Context:** [Gap matrix §2.1 + §3](../../../plans/261016-2323-ancu365-japan-market/research/gap-matrix.md) · [BE scout](../../../plans/261016-2323-ancu365-japan-market/research/researcher-02-backend-scout.md)

## Overview

Unblock all JP-specific work by adding the `region` flag, currency support, timezone handling, address+postal model, and gating VN-only routes. Nothing JP-specific lands after this.

## Key insights

- Dual pattern: **all new code goes in NEW arch** (`app/domain/` + `app/services/` + `app/repositories/` + `app/api/routes/` + `app/schemas/`) per `app/services/delegation/` reference.
- `app/models.py` (53-model god file) is **read-only for JP work** — do not add JP columns there; use `app/domain/jp/`.
- `check.sh` + `gen_arch_map.py --write` gates — must run after every model/route change.
- Migration policy: additive + nullable + idempotent + has `downgrade()`.

## Requirements

**Functional**
- `settings.region: Literal['vn','jp']` from env (`REGION=jp`), FastAPI dep `require_region(expected)` guard.
- `Invoice.currency: str` column (default 'VND', JP writes 'JPY'), migrate existing rows.
- `settings.default_tz` with JP default 'Asia/Tokyo'.
- `JpAddress` model (postal_code, prefecture, city, town, chome, banchi, go, building, kana_* mirror fields).
- 日本郵便 postal API client (`app/services/address/jp_postal_client.py`) with HTTP cache.
- VN-only routers wrapped: `construction`, `planning`, `sale` return 404 when `region=jp`.

**Non-functional**
- All migrations idempotent (`inspect().has_column` before add).
- No breaking changes to VN API shape.
- `pytest` suite still green (192 → ≥192 tests).

## Architecture

```
app/
  core/
    config.py              ← add region, default_tz
    deps/
      require_region.py    ← NEW
  domain/
    jp/
      address.py           ← NEW: JpAddress model
  services/
    address/
      jp_postal_client.py  ← NEW
    privacy/
      phone_mask.py        ← NEW: extracted from marketplace_sync_service
  api/routes/
    jp/
      address.py           ← NEW: /api/jp/address/lookup
alembic/versions/
  00NN_invoice_currency.py
  00NN_jp_address.py
```

## Related code files

**Modify**
- `app/core/config.py` — add `region`, `default_tz`
- `app/models/billing.py:19-40` — add `currency` column via Alembic (no direct edit)
- `app/services/marketplace_sync_service.py` — import phone_mask from new location
- `app/routers/construction.py` — add `require_region('vn')` at router level
- `app/routers/planning*.py` — same
- `app/routers/sale*.py` — same

**Create**
- `app/core/deps/require_region.py`
- `app/domain/jp/address.py`
- `app/services/address/jp_postal_client.py`
- `app/services/privacy/phone_mask.py`
- `app/api/routes/jp/address.py`
- `app/schemas/jp/address.py`
- `app/repositories/jp/address.py`
- `alembic/versions/00NN_invoice_currency.py`
- `alembic/versions/00NN_jp_address.py`
- `tests/jp/test_region_guard.py`
- `tests/jp/test_address_lookup.py`
- `tests/jp/test_currency_migration.py`

## Implementation steps

1. Add `REGION`, `DEFAULT_TZ` to `Settings` in `app/core/config.py`.
2. Create `require_region(expected)` FastAPI dependency returning 404 on mismatch.
3. Write Alembic `00NN_invoice_currency.py` — add nullable `currency VARCHAR(3)`, backfill VN rows to 'VND', then enforce NOT NULL in follow-up migration.
4. Extract phone mask from `marketplace_sync_service.py` → `services/privacy/phone_mask.py` with signature `mask(phone: str, region: str) -> str`. Keep call site unchanged.
5. Create `JpAddress` domain model with full field set + kana mirror.
6. Alembic migration for `jp_addresses` table.
7. Implement `jp_postal_client.py` using `httpx.AsyncClient` + 15 min cache. Use free API `https://zipcloud.ibsnet.co.jp/api/search` (no key needed) — fallback plan if rate-limited: self-host 日本郵便 CSV.
8. Add route `GET /api/jp/address/lookup?postal_code=1500001` → returns address candidates.
9. Wrap VN routers with `Depends(require_region('vn'))` at `include_router` level in `app/main.py`.
10. Run `python scripts/gen_arch_map.py --write` + commit `docs/ARCHITECTURE.generated.md`.
11. Run `./check.sh` + `pytest` + fix any gated-router regressions.

## Todo list

- [ ] Settings extended with region + default_tz
- [ ] `require_region` dependency + unit test
- [ ] Invoice currency migration + rollback tested
- [ ] Phone mask extracted + marketplace_sync still green
- [ ] JpAddress model + table migration
- [ ] 日本郵便 client + 15-min cache + tests
- [ ] `/api/jp/address/lookup` route + schema
- [ ] VN routers gated behind region
- [ ] ARCHITECTURE.generated.md regenerated
- [ ] `./check.sh` green
- [ ] Full pytest green (≥192)

## Success criteria

- `REGION=jp uvicorn app.main:app` → `/api/construction/*` returns 404; `/api/jp/address/lookup?postal_code=1500001` returns JP address.
- `REGION=vn` → VN endpoints still work, JP endpoints return 404.
- Invoice table has `currency` column; existing VN rows = 'VND'.
- `./check.sh` passes.

## Risk assessment

- **Currency migration touches billing** — stage in two migrations (add nullable → backfill → enforce not-null).
- **Phone mask extraction** — leave old function as thin wrapper for 1 release, remove after greps show no callers.
- **Region gate 404 vs 403** — use 404 to not leak JP existence to VN clients.

## Security considerations

- Postal API client: timeout 5s, no user input injected into URL (postal_code validated by regex `^\d{3}-?\d{4}$`).
- Phone mask: locale-aware regex, no PII in logs.

## Next steps

- Unblocks: Phase 01 (listing JP schema), Phase 02 (payment JP currency).
- Precondition: FE must commit i18n Rounds 1-9 before P0 FE kicks off.
