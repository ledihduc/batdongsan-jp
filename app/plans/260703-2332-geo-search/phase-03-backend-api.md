# Phase 03 — Backend: API (mở rộng `/api/houses` + `/search-nearby`)

**Mục tiêu:** endpoint cho 3 chế độ tìm kiếm, backward-compat tuyệt đối, feature-flagged.
**Est.:** 1.5 ngày · **Phụ thuộc:** Phase 01.

---

## 1. Mở rộng `GET /api/houses` (backward-compat)

Router hiện dùng query-params phẳng → **chỉ thêm** params optional, mặc định = hành vi cũ:

```python
    province: str = "",                  # slug tỉnh
    district: str | None = None,         # district_code hoặc free-text
    near_lat: float | None = None,
    near_lng: float | None = None,
    radius_km: float = 5.0,
    sort: str = "",                      # "" = created_at desc (cũ); "distance" = gần→xa
```

### Nhánh không-nearby (giữ ORM cũ 100% + thêm filter)
```python
if province:
    q = q.filter(models.House.province_code == province)
if district:
    q = q.filter(or_(models.House.district_code == district,
                     models.House.district.ilike(f"%{district}%")))
```
`district` chấp nhận cả code lẫn free-text (backfill district_code là giai đoạn 2).

### Nhánh nearby (chỉ khi có `near_lat`+`near_lng`)
Guard PostGIS **trong body** (không ép Depends toàn endpoint — text search vẫn chạy SQLite):
```python
use_nearby = near_lat is not None and near_lng is not None
if use_nearby and not settings.database_url.startswith("postgresql"):
    raise HTTPException(503, detail={"code":"GEO_DB_UNAVAILABLE",
        "message":"Tìm kiếm lân cận yêu cầu PostGIS."})
```
Chuyển sang **raw SQL** với `geography` cast (mét thực):
- Lọc: `h.status=:status AND h.geom IS NOT NULL AND ST_DWithin(h.geom::geography, :pt::geography, :radius_m)` + nối các filter cũ (category/price/area/query ilike/province).
- Sort distance: `ORDER BY h.geom <-> :pt` (**KNN index-assisted**, nhanh hơn `ORDER BY ST_Distance`).
- SELECT thêm `ST_Distance(h.geom::geography, :pt::geography)/1000.0 AS distance_km` + `COUNT(*) OVER() AS total_count`.
- `:pt` = `f"SRID=4326;POINT({near_lng} {near_lat})"`.

**Điểm mấu chốt:** `h.geom IS NOT NULL` loại tin NULL-coord khỏi nearby (D5) — nhánh text-search thường **không** có điều kiện này nên tin NULL vẫn xuất hiện.

> **Refactor:** tách phần nearby thành helper **`_query_houses_nearby(db, near_lat, near_lng, radius_km, sort, limit, offset, **filters)`** để `GET /api/houses` và `/search-nearby` dùng chung.

---

## 2. `GET /api/houses/search-nearby` — tìm theo địa danh (D6)

Server-side compose Nominatim + ST_DWithin (client 1 lượt gọi):

```python
@router.get("/search-nearby")
@limiter.limit("120/hour")
async def search_houses_near_place(
    request: Request,
    place: str = Query(..., min_length=1, max_length=200),
    radius_km: float = Query(3.0, ge=0.1, le=50),
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    _pg: None = Depends(require_postgis),
):
    hits = await nominatim_proxy.search(place, limit=1)
    if not hits:
        return {"place": None, "houses": [], "total": 0}
    lat, lng = float(hits[0]["lat"]), float(hits[0]["lon"])
    result = _query_houses_nearby(db, near_lat=lat, near_lng=lng,
                                  radius_km=radius_km, sort="distance",
                                  limit=limit, offset=offset)
    return {"place": {"display_name": hits[0]["display_name"], "lat": lat, "lng": lng}, **result}
```

> **`require_postgis`**: hiện ở `planning.py`. Chuyển thành dependency dùng chung (vd `app/deps.py`) để cả `houses.py` + `planning.py` share.

---

## 3. Lọc tỉnh/thành (D7)
Không endpoint riêng — client lấy slug từ `/api/planning/provinces/search` (đã có) rồi gọi `GET /api/houses?province=<slug>`.

---

## 4. Pydantic response shapes (`app/schemas/house_search.py`)
`HouseSummary` (+ `province_code`, `latitude`, `longitude`, `distance_km: float|None`), `PlaceRef` (`display_name/lat/lng`), `HouseSearchResponse` (`houses/total/place`).
`distance_km` **chỉ set khi sort=distance / search-nearby**; các đường khác để `None` (client biết có/không ngữ cảnh khoảng cách). Làm tròn 2 chữ số ở serialize.

---

## 5. Feature flag + rate limit (D12)
- `settings.geo_search_enabled: bool = False`. Nhánh nearby + `/search-nearby` check flag → tắt thì `/search-nearby` trả 404/503, nhánh nearby bỏ qua (fallback text). Deploy code trước, bật sau khi backfill xong.
- Rate limit: `/search-nearby` **120/h** (đụng Nominatim chung planning); `/api/houses` giữ nguyên (thêm ~600/h nếu chưa có). Phân biệt anon/JWT như `/planning/search`.
- **Cache** geocode landmark `place → (lat,lng)` (LRU/TTL 24h) — landmark gần như bất biến. Kết quả houses **không** cache (`available_units` động).

---

## 6. Hiệu năng
- Nearby: partial GIST `houses_geom_approved_gist` phục vụ cả `ST_DWithin` (bbox && refine) lẫn KNN `<->`. Mục tiêu < 30ms cho `radius_km ≤ 5` ở quy mô vài chục nghìn tin/tỉnh.
- Pagination distance: giai đoạn 1 OFFSET (đã có); giai đoạn 2 **keyset `(distance, id)`** nếu deep-pagination thành vấn đề.
- Province filter: b-tree partial, < 5ms.

---

## Definition of Done
- `GET /api/houses` không param mới → response byte-identical với trước (regression test xanh).
- `?province=<slug>` lọc đúng; tin province khác bị loại.
- Nearby trả đúng tập trong bán kính, sắp gần→xa, `distance_km` tăng dần, loại tin NULL-geom + tin ngoài bán kính.
- `/search-nearby`: Nominatim có hit → trả `place` + houses; rỗng → `houses=[], total=0, place=None`.
- Nearby trên SQLite → 503 `GEO_DB_UNAVAILABLE`; flag tắt → không lộ endpoint.
