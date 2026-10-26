# Planning Lookup Module — Backend Documentation

> Module: `app/routers/planning.py` + `app/services/`
> Status: Production-ready (pending P09 VPS deploy)
> Last updated: 2026-06-22

---

## 1. Overview

The **Planning Lookup** module exposes 9 REST endpoints for tra cứu quy hoạch đất đai TP.HCM (Ho Chi Minh City land-use planning data).

**Data source:** TNMT TP.HCM WFS (Web Feature Service) at `https://geodata-stnmt.tphcm.gov.vn/geoserver/ows`.  
Data is fetched nightly via ETL (APScheduler, 2:00 AM ICT) and stored in PostGIS schema `planning`.

**Key facts:**
- Coverage: 24 districts of HCMC only (BBox: 10.35°N–11.20°N, 106.30°E–107.05°E)
- Spatial queries use PostGIS `ST_Contains` with GIST index — p95 < 1.5s
- Rate limits enforced via `slowapi` — keyed by `user_id` (JWT) or IP (anonymous)
- Auth: JWT Bearer via `app/auth.py` (`require_user` / `require_admin`)
- Addresses search: proxied through internal Nominatim instance (port not exposed)

---

## 2. Endpoint Contract

| # | Method | Path | Auth | Rate Limit | Description |
|---|--------|------|------|------------|-------------|
| 1 | GET | `/api/planning/districts` | Optional | 100/h | List 24 HCMC districts + parcel count |
| 2 | GET | `/api/planning/layers` | Optional | 100/h | Available planning layers + Martin tile URL |
| 3 | GET | `/api/planning/parcels` | Optional | 200/h | Point-in-polygon lookup by `?lat=&lng=` |
| 4 | GET | `/api/planning/parcels/{parcel_id}` | Optional | 200/h | Get parcel detail by ID |
| 5 | GET | `/api/planning/search` | Optional | 200/h (authed) / 30/h (anon) | Nominatim address search proxy |
| 6 | POST | `/api/planning/report-error` | Required (any role) | 10/h | Submit data error report for a parcel |
| 7 | GET | `/api/planning/admin/risky-listings` | Admin only | 60/h | Houses inside risky planning zones |
| 8 | GET | `/api/planning/admin/etl-runs` | Admin only | 60/h | ETL run history (last 50) |
| 9 | POST | `/api/planning/admin/etl-trigger` | Admin only | 5/h | Trigger ETL manually (202 Accepted) |

**Error envelope** (all 4xx/5xx):
```json
{
  "error": {
    "code": "OUT_OF_BBOX",
    "message": "Tạm thời chỉ hỗ trợ TP.HCM"
  }
}
```

**Error codes:**
| Code | HTTP | Meaning |
|------|------|---------|
| `OUT_OF_BBOX` | 422 | Coordinates outside HCMC bounding box |
| `PARCEL_NOT_FOUND` | 404 | No parcel with given parcel_id |
| `NOMINATIM_ERROR` | 502 | Nominatim proxy failed |
| `VALIDATION_ERROR` | 422 | Pydantic validation failure |

---

## 3. Pydantic Schemas

Schemas defined in `app/schemas/planning.py`.

### Response Schemas

**ParcelDetail**
```python
class ParcelDetail(BaseModel):
    parcel_id: str
    zone_code: Optional[str]      # e.g. "ODT", "DGT"
    zone_name: Optional[str]      # e.g. "Đất ở đô thị"
    zone_color: Optional[str]     # Hex color, e.g. "#F5F5F5"
    area_m2: Optional[float]
    sheet_no: Optional[str]
    parcel_no: Optional[str]
    district: Optional[str]
    layer_key: Optional[str]      # "landuse_2030"
    fetched_at: Optional[datetime]
    geometry: dict                # GeoJSON Geometry object
```

**DistrictItem**
```python
class DistrictItem(BaseModel):
    district: str
    parcel_count: int
```

**SearchHit**
```python
class SearchHit(BaseModel):
    display_name: str
    lat: float
    lon: float
    importance: float
```

**RiskyListingItem**
```python
class RiskyListingItem(BaseModel):
    id: int
    title: str
    latitude: Optional[float]
    longitude: Optional[float]
    zone_code: Optional[str]
    zone_name: Optional[str]
```

**EtlRunItem**
```python
class EtlRunItem(BaseModel):
    id: int
    district: str
    layer_key: str
    status: str                   # "success" | "failed" | "running"
    parcels_upserted: Optional[int]
    error_msg: Optional[str]
    started_at: Optional[datetime]
    finished_at: Optional[datetime]
```

### Request Schemas

**ReportErrorBody**
```python
class ReportErrorBody(BaseModel):
    parcel_id: str = Field(..., min_length=1, max_length=100, pattern=r"^[A-Za-z0-9_\-/\.]+$")
    reason: str = Field(..., min_length=1, max_length=500)
    image_url: Optional[str] = Field(default=None, max_length=2000)
```

---

## 4. Rate Limit Table

| Endpoint group | Anonymous (IP-keyed) | Authenticated (user_id-keyed) |
|---------------|---------------------|-------------------------------|
| `/districts`, `/layers` | 100/hour | 100/hour |
| `/parcels`, `/parcels/{id}` | 200/hour | 200/hour |
| `/search` | 200/hour | 200/hour |
| `/report-error` | — (auth required) | 10/hour |
| `/admin/risky-listings`, `/admin/etl-runs` | — (admin required) | 60/hour |
| `/admin/etl-trigger` | — (admin required) | 5/hour |

**Key function logic** (`app/middleware/rate_limit.py`):
- Valid JWT → key = `"user:{sub}"` (rate limited per user_id)
- No JWT or invalid JWT → key = client IP address (fail-open, no block on decode error)

**429 response:** Returns standard error envelope with HTTP 429 (handled by `slowapi._rate_limit_exceeded_handler`).

---

## 5. ETL Operations

### Cron Schedule
APScheduler cron: **2:00 AM ICT daily** (UTC+7 = 19:00 UTC previous day).

Schedule defined in `app/services/planning_etl/scheduler.py`.

### Manual ETL Trigger
```bash
POST /api/planning/admin/etl-trigger
Authorization: Bearer <admin-jwt>
```
Returns `202 Accepted` immediately. ETL runs in background via `BackgroundTasks`.

### Troubleshooting

1. **Check ETL run history:**
   ```sql
   SELECT district, status, parcels_upserted, error_msg, started_at, finished_at
   FROM planning.etl_runs
   ORDER BY id DESC
   LIMIT 10;
   ```

2. **Count parcels per district:**
   ```sql
   SELECT district, COUNT(*) FROM planning.parcels GROUP BY district ORDER BY district;
   ```

3. **Check if WFS is reachable:**
   ```bash
   curl "https://geodata-stnmt.tphcm.gov.vn/geoserver/ows?service=WFS&version=2.0.0&request=GetCapabilities"
   ```

4. **Force re-run for a district:**
   - Use CLI: `python -m app.services.planning_etl --district "Quận 1"`
   - Or trigger via admin API (runs all districts)

5. **ETL logs:** `STDOUT` / `STDERR` captured in Docker container logs.  
   Set `LOG_LEVEL=DEBUG` for verbose WFS request/response logging.

---

## 6. Risky Zone Codes

Current risky zone codes (`app/config.py:risky_zone_codes`):

| Code | Meaning |
|------|---------|
| `DGT` | Đất giao thông (transportation land) |
| `CXP` | Công trình xây dựng phải phá dỡ (demolition required) |
| `DCC` | Đất công cộng (public land) |
| `DXH` | Đất xã hội (social housing land) |

**Warning:** These codes are provisional — based on HCMC 2030 planning documents.  
**Must verify with TNMT TP.HCM** before production launch. See Open Questions §10.

### How to Update Zone Codes

1. Update `risky_zone_codes` in `app/config.py` (or set `RISKY_ZONE_CODES` env var as JSON array)
2. Update `app/services/risky_zones.py:RISKY_ZONE_CODES` if it has a local copy
3. No DB migration required — codes are filtered at query time via `WHERE p.zone_code = ANY(:codes)`
4. Redeploy backend; changes take effect immediately

---

## 7. Privacy Log Policy

**Regulation:** Nghị định 13/2023/NĐ-CP (Nghị định Bảo vệ dữ liệu cá nhân).

**GPS lookup logs:**
- Retained: **≤ 30 days** (then purged from `planning.reports` if applicable)
- User identifier: **hashed** `user_id` in logs — not raw PII
- Coordinates: stored only in `planning.reports.parcel_id` (indirect, not raw GPS)
- No raw lat/lng stored server-side after parcel lookup completes

**Data flow:**
```
User tap (lat, lng) → Backend lookup → Return ParcelDetail → Discard coords
                                                 ↓
                          Optional: user reports error → stores parcel_id + reason
                                                          NOT raw coordinates
```

**Audit:** Any change to GPS data handling must be reviewed against Nghị định 13.

---

## 8. SQLite → PostgreSQL Migration

The planning module requires PostgreSQL with PostGIS extension. It cannot run with SQLite.

### Migration Steps

1. **Set environment variables:**
   ```bash
   DATABASE_URL=postgresql://user:pass@host:5432/ancu365
   PLANNING_DATABASE_URL=  # leave empty to reuse DATABASE_URL
   ```

2. **Install PostGIS** on Postgres:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   CREATE SCHEMA IF NOT EXISTS planning;
   ```

3. **Run Alembic migration:**
   ```bash
   alembic upgrade head
   ```
   Migration: `alembic/versions/0001_planning_reports.py`

4. **Seed initial data** (run ETL):
   ```bash
   POST /api/planning/admin/etl-trigger  # via API
   # or
   python -m app.services.planning_etl  # via CLI
   ```

5. **Validation queries:**
   ```sql
   -- Confirm schema exists
   SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'planning';
   
   -- Confirm tables
   SELECT tablename FROM pg_tables WHERE schemaname = 'planning';
   -- Expected: parcels, etl_runs, reports
   
   -- Confirm GIST index on geometry
   SELECT indexname FROM pg_indexes WHERE tablename = 'parcels' AND indexdef LIKE '%gist%';
   
   -- Test point lookup
   SELECT parcel_id, zone_code FROM planning.parcels
   WHERE ST_Contains(geometry, ST_SetSRID(ST_Point(106.70, 10.77), 4326))
   LIMIT 1;
   ```

6. **Verify conditional loading:**
   - Backend auto-detects `DATABASE_URL` prefix
   - `postgresql://...` → planning routes registered, ETL scheduler started
   - `sqlite://...` → planning routes NOT registered (GeoAlchemy2 incompatible with SQLite)

---

## 9. Tests

### Running Tests

```bash
# Full test suite
cd ancu365-backend
python -m pytest tests/ -v

# With coverage report
python -m pytest --cov=app.routers.planning --cov=app.services.planning_service \
  --cov=app.middleware.rate_limit --cov-report=term-missing tests/

# Collect without running (verify discovery)
python -m pytest tests/ --collect-only

# Run single file
python -m pytest tests/test_planning_parcels.py -v
```

### Test Coverage (Phase 08 results — Python 3.9.6 local)

| Module | Coverage |
|--------|----------|
| `app/routers/planning.py` | **100%** |
| `app/services/planning_service.py` | **100%** |
| `app/middleware/rate_limit.py` | **100%** |
| `app/middleware/error_handler.py` | 75% |
| `app/services/nominatim_proxy.py` | 43% (HTTP path not covered — mocked) |
| **Overall (planning module)** | **90%** |

### Test Files

| File | What it tests |
|------|---------------|
| `tests/conftest.py` | FakeSession, fixtures, minimal test app |
| `tests/test_planning_parcels.py` | Point lookup, bbox guard, parcel-by-ID |
| `tests/test_planning_search.py` | Nominatim proxy mock, error handling |
| `tests/test_planning_districts.py` | District list, layers |
| `tests/test_planning_report_error.py` | Auth, validation, DB commit |
| `tests/test_planning_admin.py` | Admin-only endpoints, 401/403 |
| `tests/test_planning_rate_limit.py` | Limiter config, key function |
| `tests/test_planning_etl_smoke.py` | Skipped (needs live Postgres + WFS) |

### ETL Smoke Tests

ETL tests require live infrastructure — run in P09 staging:
```bash
LIVE_ETL_TEST=1 DATABASE_URL=postgresql://... python -m pytest tests/test_planning_etl_smoke.py -v
```

### Test Strategy Notes

- **No real Postgres in unit tests**: `get_db` is overridden with `FakeSession` via FastAPI `dependency_overrides`
- **No real Nominatim calls**: `nominatim_proxy.search` is patched with `AsyncMock`
- **JWT secret**: `test-secret-xyz-never-use-in-prod` (set via `os.environ["JWT_SECRET"]` in conftest)
- **Minimal test app**: Tests build a minimal `FastAPI` app with only the planning router — avoids `main.py`'s module-level DB init

---

## 10. Open Questions

1. **Risky zone codes**: Current set `{DGT, CXP, DCC, DXH}` is based on provisional HCMC 2030 docs. **Must verify exact codes with TNMT TP.HCM** before production. Wrong codes → missing warnings or false positives.

2. **Firebase Analytics integration**: Parcel lookup events are not yet sent to Firebase. Phase 08 UI tests mock the analytics call. Integration pending discussion with product team — see `docs/features/planning-lookup.md` frontend doc.

3. **nominatim_proxy.py coverage**: 43% — the `httpx.AsyncClient` path is always mocked in tests. A contract test against a real Nominatim instance would increase confidence. Deferred to P09 staging soak.

4. **Freshness of planning data**: `fetched_at` is set during ETL. UI shows warning if `fetched_at > 30 days`. But TNMT data updates on irregular schedule — consider adding a `last_published` field from WFS capabilities response.

5. **Planning schema in multi-tenant setup**: Currently `schema=planning` is hardcoded. If the backend hosts multiple cities in future, the schema name needs to become configurable.
