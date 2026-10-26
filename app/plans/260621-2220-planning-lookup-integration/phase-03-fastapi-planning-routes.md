# Phase 03 — FastAPI Planning Routes `/api/planning/*`

## Context Links
- BA: `phase-00-ba-requirements.md` § US-01..05, US-06 (admin), US-07 (anonymous + rate limit), US-08 (report sai), AC-02/03/06/07/15/18/19
- Reports: `research/r1-ancu365-backend-analysis.md` § 3-4 (router pattern, missing rate limit)
- Reference code:
  - `faceconst/backend/app/api/v1/endpoints/planning.py` (nếu có) — adapt
  - `ancu365-backend/app/routers/houses.py` (router pattern hiện hữu)
  - `ancu365-backend/app/auth.py` (sau P01 đã có `require_admin`)

## Overview
- Priority: **P0**
- Status: Pending
- Estimate: 1.5 ngày
- Description: Implement 7 endpoints `/api/planning/*` (lookup + admin + report + Nominatim proxy) với Pydantic schema, rate limit slowapi, response model rõ ràng.

## Key Insights
- ancu365 router pattern hiện không dùng Pydantic; planning route cố tình ĐI NGƯỢC pattern này vì payload phức tạp (GeoJSON, fields nhiều). Trade-off đáng giá theo R1 §3.
- `slowapi` middleware cần khởi tạo ở `main.py` + decorator `@limiter.limit("30/hour")` per endpoint.
- Anonymous endpoint: dùng `optional_user` (đã có); rate limit by IP. Logged-in: 200/hour theo user_id.
- Nominatim proxy bắt buộc (không expose port 8080 public) — endpoint search/reverse forward.
- US-06 admin endpoint cần JOIN `public.houses` + `planning.parcels` qua `ST_Contains(geom, ST_Point(lng, lat))`.

## Requirements
### Functional — Endpoint contract

| Method | Path | Auth | Rate limit | Mô tả |
|--------|------|------|-----------|-------|
| GET | `/api/planning/districts` | optional | 100/h | List 24 quận HCMC + count parcels (cache 1h) |
| GET | `/api/planning/layers` | optional | 100/h | List lớp ("landuse_2030") + Martin tile URL template |
| GET | `/api/planning/parcels/{parcel_id}` | optional | 200/h | Detail 1 thửa: zone_name, zone_code, area_m2, sheet_no, district, fetched_at, geometry GeoJSON |
| GET | `/api/planning/parcels?lat=&lng=` | optional | 200/h | Point-in-polygon: trả parcel chứa toạ độ |
| GET | `/api/planning/search?q=&limit=10` | optional | 30/h anon, 200/h user | Nominatim proxy forward search, filter VN bbox |
| POST | `/api/planning/report-error` | required | 10/h | US-08: form report data sai (parcel_id, reason, optional image) |
| GET | `/api/planning/admin/risky-listings` | admin | 60/h | US-06: list houses ở zone risky (zone_code IN risky_set) |
| GET | `/api/planning/admin/etl-runs` | admin | 60/h | Latest ETL run status (cho monitoring P09) |
| POST | `/api/planning/admin/etl-trigger` | admin | 5/h | Manual trigger ETL (background job qua APScheduler) |

### Non-functional
- p95 < 1.5s parcel lookup cache miss (AC-02), < 200ms cache hit
- p95 < 2.5s search cache miss (AC-03), < 800ms hit
- Bbox guard: tap/search ngoài `[10.35, 106.30, 11.20, 107.05]` → 422 với code `OUT_OF_BBOX` (AC-06)
- Tất cả 4xx có shape: `{error: {code, message, details?}}`
- CORS: dev `*`, prod khóa domain (set ở P09)

## Architecture
```
Flutter app ──HTTPS──▶ nginx :443 ──/api/──▶ FastAPI :8000 ──┬──▶ Postgres planning.parcels (GIST index)
                                                            ├──▶ Nominatim :8080 (internal, proxy only)
                                                            └──▶ APScheduler in-process (ETL cron 2AM ICT)
```

Response flow `/api/planning/parcels?lat=X&lng=Y`:
1. Validate bbox VN-HCMC → else 422
2. SQL: `SELECT * FROM planning.parcels WHERE ST_Contains(geom, ST_SetSRID(ST_Point($lng,$lat), 4326)) LIMIT 1`
3. Serialize Pydantic → GeoJSON geometry (shapely → dict)
4. Add `cache-control: public, max-age=3600` header

## Related Code Files

### To create
- `ancu365-backend/app/routers/planning.py` (main router)
- `ancu365-backend/app/schemas/planning.py` (Pydantic schemas — first Pydantic in repo)
- `ancu365-backend/app/services/planning_service.py` (business logic, DB queries)
- `ancu365-backend/app/services/nominatim_proxy.py` (httpx async client wrap)
- `ancu365-backend/app/services/risky_zones.py` (constants: list zone_code "risky")
- `ancu365-backend/app/middleware/rate_limit.py` (slowapi config)
- `ancu365-backend/app/middleware/error_handler.py` (uniform `{error:{code,message}}` shape)

### To modify
- `ancu365-backend/app/main.py` → register router + slowapi middleware + error handler
- `ancu365-backend/app/config.py` → add `risky_zone_codes: list[str]`, `vn_bbox: tuple`

### To delete
- (none)

## Implementation Steps

1. **Tạo Pydantic schemas** `app/schemas/planning.py`:
   ```python
   from pydantic import BaseModel, Field
   class ParcelDetail(BaseModel):
       parcel_id: str
       zone_code: str | None
       zone_name: str | None
       zone_color: str | None
       area_m2: float | None
       sheet_no: str | None
       parcel_no: str | None
       district: str | None
       fetched_at: datetime
       geometry: dict  # GeoJSON
   class DistrictItem(BaseModel):
       district: str
       parcel_count: int
   class SearchHit(BaseModel):
       display_name: str
       lat: float
       lon: float
       importance: float
   class ReportErrorBody(BaseModel):
       parcel_id: str
       reason: str = Field(max_length=500)
       image_url: str | None = None
   class ErrorEnvelope(BaseModel):
       code: str
       message: str
       details: dict | None = None
   ```

2. **Service layer** `app/services/planning_service.py`:
   ```python
   from sqlalchemy import text
   def lookup_parcel_by_point(db, lng, lat) -> ParcelDetail | None:
       row = db.execute(text("""
         SELECT parcel_id, zone_code, zone_name, zone_color, area_m2, sheet_no,
                parcel_no, district, fetched_at, ST_AsGeoJSON(geom)::json AS geometry
         FROM planning.parcels
         WHERE ST_Contains(geom, ST_SetSRID(ST_Point(:lng, :lat), 4326))
         LIMIT 1
       """), {"lng": lng, "lat": lat}).mappings().first()
       return ParcelDetail(**dict(row)) if row else None
   def list_districts(db) -> list[DistrictItem]:
       rows = db.execute(text("""
         SELECT district, COUNT(*) AS parcel_count
         FROM planning.parcels GROUP BY district ORDER BY district
       """)).mappings().all()
       return [DistrictItem(**dict(r)) for r in rows]
   def risky_houses(db, risky_codes: list[str]) -> list[dict]:
       rows = db.execute(text("""
         SELECT h.id, h.title, h.latitude, h.longitude, p.zone_code, p.zone_name
         FROM houses h
         JOIN planning.parcels p
           ON ST_Contains(p.geom, ST_SetSRID(ST_Point(h.longitude, h.latitude), 4326))
         WHERE p.zone_code = ANY(:codes) AND h.status = 'active'
       """), {"codes": risky_codes}).mappings().all()
       return [dict(r) for r in rows]
   ```

3. **Nominatim proxy** `app/services/nominatim_proxy.py`:
   ```python
   import httpx
   from app.config import settings
   _VN_BBOX = "106.30,10.35,107.05,11.20"  # left, top, right, bottom (per docs)
   async def search(q: str, limit: int = 10):
       async with httpx.AsyncClient(timeout=8.0) as client:
           resp = await client.get(f"{settings.nominatim_url}/search", params={
               "q": q, "format": "json", "limit": limit,
               "viewbox": _VN_BBOX, "bounded": 1,
               "countrycodes": "vn", "addressdetails": 1,
           }, headers={"User-Agent": "ancu365-backend/1.0"})
           resp.raise_for_status()
           return resp.json()
   ```

4. **Rate limit middleware** `app/middleware/rate_limit.py`:
   ```python
   from slowapi import Limiter
   from slowapi.util import get_remote_address
   from fastapi import Request
   def _key_func(request: Request) -> str:
       # If logged-in, key by user_id else by IP
       auth = request.headers.get("authorization", "")
       if auth.startswith("Bearer "):
           # decode without raising; if invalid → fall back IP
           ...
       return get_remote_address(request)
   limiter = Limiter(key_func=_key_func)
   ```

5. **Error handler** `app/middleware/error_handler.py`:
   ```python
   from fastapi import Request
   from fastapi.responses import JSONResponse
   from fastapi.exceptions import RequestValidationError
   async def validation_handler(request: Request, exc):
       return JSONResponse(422, {"error": {"code": "VALIDATION_ERROR",
                                             "message": str(exc), "details": exc.errors()}})
   ```

6. **Router** `app/routers/planning.py`:
   ```python
   router = APIRouter(prefix="/api/planning", tags=["planning"])
   @router.get("/parcels", response_model=ParcelDetail | None)
   @limiter.limit("200/hour")
   def parcel_by_point(request: Request, lat: float, lng: float,
                       db: Session = Depends(get_db)):
       if not (10.35 <= lat <= 11.20 and 106.30 <= lng <= 107.05):
           raise HTTPException(422, {"code": "OUT_OF_BBOX",
                                      "message": "Tạm thời chỉ hỗ trợ TP.HCM"})
       parcel = lookup_parcel_by_point(db, lng, lat)
       return parcel  # None → 200 với body null (Flutter handle)

   @router.post("/report-error", status_code=201)
   @limiter.limit("10/hour")
   def report_error(request: Request, body: ReportErrorBody,
                    claims = Depends(require_user), db = Depends(get_db)):
       # Insert vào table planning_reports (tạo migration alembic mới)
       ...

   @router.get("/admin/risky-listings")
   @limiter.limit("60/hour")
   def admin_risky(request: Request, claims = Depends(require_admin), db = Depends(get_db)):
       return {"items": risky_houses(db, settings.risky_zone_codes)}
   ```

7. **Tạo bảng `planning.reports`** (alembic revision mới):
   ```python
   # alembic/versions/0002_planning_reports.py
   op.create_table("reports", schema="planning",
       sa.Column("id", sa.BigInteger, primary_key=True),
       sa.Column("parcel_id", sa.String, nullable=False),
       sa.Column("user_id", sa.Integer, nullable=False),
       sa.Column("reason", sa.String(500)),
       sa.Column("image_url", sa.String, nullable=True),
       sa.Column("status", sa.String(20), default="new"),
       sa.Column("created_at", sa.DateTime, server_default=sa.func.now()))
   ```

8. **Register vào `main.py`:**
   ```python
   from slowapi.errors import RateLimitExceeded
   from app.middleware.rate_limit import limiter
   from app.routers import planning
   app.state.limiter = limiter
   app.add_exception_handler(RateLimitExceeded, _ratelimit_handler)
   app.include_router(planning.router)
   ```

9. **APScheduler ETL cron** (in-process, simple):
   ```python
   # app/services/planning_etl/scheduler.py — copy từ faceconst
   # main.py startup: scheduler.start() nếu env CRON_ENABLED=1
   ```
   Cron 2AM ICT: `cron(hour=19, minute=0, timezone="UTC")` = 2AM Asia/Ho_Chi_Minh.

10. **Verify với curl:**
    ```bash
    curl -i "http://localhost:8000/api/planning/parcels?lat=10.77&lng=106.69" | jq
    curl -i "http://localhost:8000/api/planning/districts" | jq
    curl -i "http://localhost:8000/api/planning/search?q=Tran+Phu+Quan+1" | jq
    curl -i "http://localhost:8000/api/planning/parcels?lat=21.0&lng=105.8"
    # expect 422 {error: {code: OUT_OF_BBOX, ...}}
    # spam 31 requests:
    for i in {1..31}; do curl -s "http://localhost:8000/api/planning/search?q=test" -o /dev/null -w "%{http_code}\n"; done
    # expect last → 429
    ```

11. **OpenAPI doc check:**
    `http://localhost:8000/docs` show 9 endpoints planning với schema đúng.

## Todo List
- [ ] Tạo schemas Pydantic `planning.py` (ParcelDetail, DistrictItem, SearchHit, ReportErrorBody, ErrorEnvelope)
- [ ] Service `planning_service.py` (3 query: parcel by point, districts, risky houses)
- [ ] Service `nominatim_proxy.py` (forward search VN bbox)
- [ ] Service `risky_zones.py` (constants)
- [ ] Middleware `rate_limit.py` (slowapi key by user_id|IP)
- [ ] Middleware `error_handler.py` (uniform envelope)
- [ ] Router `planning.py` — 9 endpoints
- [ ] Migration alembic `planning.reports` table
- [ ] Register router + middleware vào `main.py`
- [ ] APScheduler cron 2AM ICT ETL daily
- [ ] Verify curl all endpoints + rate limit 429
- [ ] OpenAPI doc show đầy đủ 9 routes

## Success Criteria
- 9 endpoints respond 200 với data hợp lệ (test với 3 quận seeded từ P02)
- Rate limit triggers 429 sau threshold (manual test)
- `/api/planning/parcels?lat=21,lng=105` → 422 với `code: OUT_OF_BBOX`
- `/api/planning/admin/risky-listings` không token → 401; với non-admin token → 403; với admin → 200
- p95 < 1.5s với 100 requests parcel lookup (`ab -n 100 -c 10`)
- Swagger UI `/docs` show đủ 9 endpoints + Pydantic schemas

## Risk Assessment
| Risk | Mức | Mitigation |
|------|-----|-----------|
| ST_Contains slow (60K parcels) | Cao | `CREATE INDEX idx_parcels_geom ON planning.parcels USING GIST(geom)` đã trong postgis_loader.py; verify `EXPLAIN ANALYZE` |
| Nominatim slow ở first call sau idle | Trung | Warm-up call ở startup; cache 5min trong-memory (lru_cache) |
| Rate limit dùng key sai → false positive | Trung | Test với fresh IP + JWT; log key trong response header debug mode |
| GeoJSON serialization OOM với polygon lớn | Thấp | Limit response 1 parcel/call; ST_Simplify với tolerance 0.00001 nếu polygon > 10000 vertices |
| Risky zone code list maintained hardcode | Thấp | Move sang `planning.risky_zone_codes` table sau Phase 2 |
| ETL cron lock file conflict | Thấp | APScheduler in-process; chỉ 1 backend instance MVP — note cho P09 nếu scale-out |

## Security Considerations
- ✅ Auth: reuse `require_user`, `require_admin` từ P01.
- [ ] Pydantic validate tất cả input (lat/lng float, q max_length, parcel_id pattern).
- [ ] SQL: dùng `text(:param)` bound params — KHÔNG f-string concat (vuln SQL injection).
- [ ] Nominatim proxy KHÔNG forward auth header vào upstream.
- [ ] Error envelope KHÔNG leak stack trace ở prod (`ENVIRONMENT=production` → suppress).
- [ ] Rate limit AC-18: anonymous 30/h, logged-in 200/h — test với fresh IP + token.
- [ ] Privacy AC-15: log `parcel_lookup` event chỉ với hashed user_id (SHA256), KHÔNG raw lat/lng — retention 30 ngày (Nghị định 13).
- [ ] CORS: env `BACKEND_CORS_ORIGINS` — prod set domain cụ thể, KHÔNG `*`.

## Next Steps
- ✅ Phase 04 (Flutter data layer) start sau khi endpoint contract stable + Swagger doc verify.
- ✅ Phase 07 (admin + report UI) cần endpoints này — block tới khi P03 done.
