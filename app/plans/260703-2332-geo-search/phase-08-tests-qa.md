# Phase 08 — Tests + QA

**Mục tiêu:** phủ regression backward-compat + geo-spatial + client flows.
**Est.:** 1.5 ngày · **Phụ thuộc:** Phase 03–07.

---

## 1. Backend — pytest (PostGIS)
Hạ tầng: `pytest-postgresql` (đã có). Fixture `postgis_engine` bật `CREATE EXTENSION postgis` + `alembic upgrade head`. Marker `@pytest.mark.postgis` để CI SQLite skip được.

**Cross-dialect (SQLite + Postgres):**
1. `GET /api/houses` không param mới → response y hệt trước (**regression/backward-compat**).
2. `?province=tp-ho-chi-minh` → chỉ trả tin `province_code` khớp.
3. Text search vẫn trả cả tin NULL-geom.
4. `create_house` set `province_code` đúng từ `city`; `city` rác → `None` nhưng tin vẫn tạo.

**PostGIS-only (`@postgis`):**
5. Trigger: insert lat/lng → geom set; update → geom đổi; set NULL → geom NULL.
6. Nearby: 3 tin khác cự ly + 1 NULL-geom + 1 ngoài bán kính → đúng tập, **đúng thứ tự gần→xa**, `distance_km` tăng dần, loại NULL-geom + ngoài bán kính.
7. `distance_km` chính xác (2 điểm biết trước, sai số < vài m).
8. `radius_km` biên: tin ngay mép trong/ngoài.
9. `/search-nearby`: mock `nominatim_proxy.search` → verify compose + trả `place`; rỗng → `houses=[], total=0, place=None`.
10. Guard: nearby trên SQLite → 503 `GEO_DB_UNAVAILABLE`; flag tắt → không lộ endpoint.
11. Pagination distance: limit/offset không trùng/sót.

**Backfill script:**
12. Idempotent/resumable: chạy 2 lần → tin `geocoded`/`failed` không gọi lại Nominatim (mock đếm call).
13. Kết quả ngoài `vn_bbox_full` → `failed`, không ghi lat/lng rác.

## 2. Flutter — widget/unit test
- `GeoLocationService`: trả đúng enum cho granted/denied/permanentlyDenied/serviceOff (mock).
- `SearchProvider`: chuyển mode + reset scope đúng; `loadMore` phân nhánh theo mode.
- `GuestSearchScreen`: gõ → hiện đúng sections; race guard (kết quả cũ không ghi đè mới).
- `RadiusChips`/`DistanceBadge`: format VN đúng ("300 m" / "1,2 km").
- Empty states render đúng CTA theo mode.
- `SearchIntent` round-trip qua SharedPreferences.

## 3. Manual AC checklist
Chạy toàn bộ Gherkin scenarios ở `phase-00` (US-01..US-04) trên thiết bị thật (android) + web:
- Địa danh có/không kết quả, disambiguation.
- Tỉnh/quận + biến thể free-text ("Sài Gòn").
- Nearby cấp/từ chối/permanentlyDenied/GPS-off/ngoài-bbox.
- Kết hợp filter; empty states + CTA; list/map toggle; tin NULL-coord ở nhóm phụ.

---

## Definition of Done
- Regression `/api/houses` xanh (backward-compat tuyệt đối).
- Toàn bộ test PostGIS + widget xanh; CI SQLite skip đúng test `@postgis`.
- Manual AC checklist pass, có ảnh chụp/log.
