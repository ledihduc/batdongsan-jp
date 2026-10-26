# Plan — Tìm kiếm theo địa danh / tỉnh-thành / quanh đây (Geo-Search) cho ancu365

> Target apps: `ancu365-app` (Flutter — `house_booking`) + `ancu365-backend` (FastAPI + PostGIS + Nominatim). **Share backend** — cùng stack, không tách service.
> Ngày lập: 2026-07-03 · Trạng thái: **Phase 0 — Planning done, ready for dev**
> Nguồn: tổng hợp 3 chuyên gia — BA (yêu cầu nghiệp vụ), Tech Lead (kiến trúc geo-spatial), Chuyên gia UX/relevance tìm kiếm BĐS cho thuê.

---

## 1. Mục tiêu

Bổ sung **3 chế độ tìm kiếm** cho người thuê:

1. **Tìm theo địa danh** — nhập landmark/địa chỉ ("gần Đại học Bách Khoa", "chợ Bến Thành") → geocode → nhà quanh điểm đó, sắp theo khoảng cách.
2. **Tìm theo tỉnh/thành & quận/huyện** — lọc địa giới, không cần GPS.
3. **Tìm quanh đây** — quanh vị trí GPS hiện tại, chọn bán kính, sắp theo khoảng cách.

Kết hợp được với bộ lọc hiện có (giá, diện tích, loại hình, phòng ngủ, từ khoá).

---

## 2. Hiện trạng (đã khảo sát codebase)

**Đã có sẵn — TÁI DÙNG:**
- Backend: FastAPI + SQLAlchemy 2 + **PostgreSQL/PostGIS** (geoalchemy2, shapely) + Martin tiles + **Nominatim tự host** (`app/services/nominatim_proxy.py`, bounded VN bbox, strip Authorization).
- `House` model **đã có `latitude`/`longitude`** (nullable) + `city`/`district`/`address` (free text) + `product_type` (apartment/boarding_house/homestay) + `available_units`, `images`.
- Endpoints: `GET /api/houses` (text ilike + price/area/category, paginated), `GET /api/planning/provinces` + `/provinces/search` (63 tỉnh, fuzzy không dấu, trả `slug`), `GET /api/planning/search` (Nominatim forward geocode), reverse geocode helper, `/api/planning/parcels/bbox` (**pattern PostGIS bbox → GeoJSON để copy**).
- Pattern hạ tầng: `require_postgis` dependency, migration dialect-guard (`op.get_bind().dialect.name`), rate-limit `slowapi @limiter.limit`.
- Flutter: `flutter_map` + `latlong2`, `ProvincePicker` (features/planning), `Debouncer(300ms)`, `PrimingPresenter`/`PrimingOutcome` (permission priming — camera/notification), `SoftReAskBanner`, `HouseCardSkeleton`, design tokens `HD.*`. `HouseProvider.fetchHouses(query,categoryId,min/maxPrice,min/maxArea,limit,offset)` + infinite scroll.

**Khoảng trống — PHẢI LÀM:**
- ❌ Không có cột PostGIS `geom` / GIST index trên `houses`; không có `ST_DWithin` nearby query.
- ❌ Nhiều tin `lat/lng = NULL` (guest-posted + marketplace-synced) → cần backfill geocode.
- ❌ `city`/`district` free-text, chưa chuẩn hoá về mã tỉnh/quận → cần `province_code`.
- ❌ Flutter **chưa có `geolocator`** (chỉ có `permission_handler`, không lấy được toạ độ) → phải thêm dependency.
- ❌ Chưa có location priming sheet, search overlay hợp nhất, radius picker, distance badge.

---

## 3. Quyết định đã chốt (Locked Decisions)

| # | Quyết định | Nguồn |
|---|---|---|
| **D1** | **Share backend** — mở rộng `ancu365-backend`, không tách service. | TL |
| **D2** | `geom geometry(Point,4326)` là cột **dẫn xuất** từ lat/lng, đồng bộ bằng **DB trigger** `BEFORE INSERT/UPDATE` (nguồn sự thật duy nhất, phủ cả marketplace-sync ghi raw SQL). Không dual-write app. | TL |
| **D3** | `geom` **không** khai báo ở ORM (tránh phụ thuộc geoalchemy2 khi dev SQLite); truy cập bằng **raw SQL** bound-param như module planning. | TL |
| **D4** | **`province_code = slug`** sẵn có trong `vietnam-provinces.json` (vd `tp-ho-chi-minh`). Backfill offline từ `city` bằng `provinces_service.search_provinces`. Không bịa hệ mã mới. | TL |
| **D5** | Tin `lat/lng = NULL` **bị loại khỏi nearby/địa danh** (`geom IS NOT NULL`), **vẫn hiển thị** trong text search & lọc tỉnh/thành. Ở nearby, gom nhóm phụ "Cũng ở khu vực này (chưa có bản đồ)" theo tỉnh/district để không giấu inventory. | BA + UX |
| **D6** | Tìm địa danh = **1 endpoint server-side compose** (Nominatim + ST_DWithin), không bắt client gọi 2 lượt. | TL |
| **D7** | Lọc tỉnh/thành = tái dùng `GET /api/houses?province=<slug>`, không endpoint riêng. | TL |
| **D8** | Bán kính: **1 / 3 / 5 / 10 km**, mặc định **3 km**. | BA + UX |
| **D9** | Autocomplete cho **tỉnh/thành** (local, rẻ); **on-submit** cho địa danh (giảm tải Nominatim). Query địa danh trigger từ ≥3 ký tự. | BA + UX |
| **D10** | Sort: **nearby & địa danh → khoảng cách**; tỉnh/thành & từ khoá → recency/giá (giữ hành vi cũ). Tính khoảng cách **server-side** (PostGIS). | BA + UX |
| **D11** | Backfill geocode cho tin NULL-coord: **có**, batch nền throttled/resumable, **ngoài đường tới hạn** release UI. Không chặn tính năng. | BA + TL |
| **D12** | **Feature flag** `settings.geo_search_enabled`. Deploy code trước, bật sau khi backfill xong. Backward-compat tuyệt đối cho `/api/houses`. | TL |
| **D13** | Thêm `geolocator` vào Flutter deps cho "Tìm quanh đây". | UX + TL |

---

## 4. Kiến trúc tổng quan

```
┌──────────────────────── Flutter (ancu365-app) ────────────────────────┐
│ GuestSearchScreen (overlay hợp nhất: tỉnh/quận · địa danh · từ khoá)   │
│ NearbyResultsScreen (radius chips + sort + list/map toggle)           │
│ LocationPicker (tỉnh→quận cascading)  ·  LocationPrimingSheet          │
│ SearchProvider (mode: home|nearby|place|area|query)                   │
│ GeoLocationService (geolocator+permission)  ·  GeocodingService       │
└───────────────────────────────┬───────────────────────────────────────┘
                                │ HTTPS
┌───────────────────────────────▼───────────── ancu365-backend ─────────┐
│ GET /api/houses  (+province, +near_lat/lng, +radius_km, +sort)  ←compat│
│ GET /api/houses/search-nearby?place=  (Nominatim → ST_DWithin)         │
│ helper _query_houses_nearby()  ·  require_postgis  ·  feature flag     │
└───────────────────────────────┬───────────────────────────────────────┘
                                ▼
   PostgreSQL+PostGIS: houses.geom(Point,4326) + GIST · trigger sync geom
   province_code(slug) · geocode_status   |   Nominatim VN (internal)
```

---

## 5. Các Phase

| Phase | Tên | Est. | Phụ thuộc |
|-------|-----|------|-----------|
| 00 | BA requirements (US + AC + edge cases + metrics) | — (done) | — |
| 01 | Backend: data model + migration `0037` (geom, trigger, GIST, province_code, geocode_status) | 1 ngày | 00 |
| 02 | Backend: backfill geocode (Nominatim) + backfill `province_code`; set code khi create/sync | 1 ngày | 01 |
| 03 | Backend: API (`/api/houses` mở rộng + `/search-nearby` + schemas + rate-limit + flag) | 1.5 ngày | 01 |
| 04 | Flutter: data layer (models `distance_km`/codes, repository, `GeoLocationService`, `GeocodingService`, `SearchProvider`) + `geolocator` | 1.5 ngày | 03 |
| 05 | Flutter: `GuestSearchScreen` (overlay hợp nhất) + `LocationPicker` (tỉnh→quận) + recent searches | 2 ngày | 04 |
| 06 | Flutter: "Tìm quanh đây" — `LocationPrimingSheet` + radius chips + `NearbyResultsScreen` + list/map + distance badge | 2 ngày | 04, 05 |
| 07 | Ranking/relevance: sort theo mode + boost + xử lý NULL-coord (2 truy vấn ghép) + empty states | 1 ngày | 03, 06 |
| 08 | Tests + QA (pytest PostGIS + Flutter widget + manual AC checklist) | 1.5 ngày | 03–07 |
| 09 | Rollout: migration → backfill → bật flag; monitoring metrics | 0.5 ngày | 08 |

**Tổng ước tính:** ~12 ngày dev (1 fullstack). Đường tới hạn: 01 → 03 → 04 → 05/06 → 07 → 08. Phase 02 (backfill) chạy **song song**, không chặn release.

---

## 6. Dependencies mới

### ancu365-backend
Không cần package mới — PostGIS/geoalchemy2/shapely/httpx đã có. Chỉ thêm migration + script.

### ancu365-app (pubspec.yaml)
| Package | Lý do |
|---------|-------|
| `geolocator` (^13.x, kiểm tra tương thích Dart 3.12) | Lấy toạ độ GPS cho "Tìm quanh đây" (permission_handler đã có nhưng không lấy vị trí). |
| `flutter_map_marker_cluster` *(tùy chọn, Phase 06 nice-to-have)* | Cluster marker trên map nearby. |

> ⚠️ Kiểm tra ràng buộc SDK: dự án pin nhiều package cho Dart 3.12.2 (vd `permission_handler ^10.4.5`). Chọn phiên bản `geolocator` tương thích trước khi thêm.

---

## 7. Rủi ro & Giảm thiểu

| Rủi ro | Giảm thiểu |
|--------|-----------|
| Độ phủ toạ độ thấp → nearby ít kết quả | Backfill (P02) + nhóm phụ theo tỉnh/district (D5) + empty state "mở rộng bán kính". |
| `city` free-text bẩn không map được slug | `province_code=NULL` vẫn tìm được qua text search cũ — không mất tin. Log tỉ lệ map fail. |
| `geolocator` không tương thích Dart 3.12 pin | Chốt version ở P04 trước khi code UI; fallback picker tỉnh nếu bí. |
| PostGIS-only làm vỡ SQLite dev | Dialect-guard migration + `require_postgis` + check `database_url` trong nhánh nearby. |
| Nominatim nghẽn (dùng chung planning) | Rate-limit `/search-nearby` 120/h, cache geocode landmark TTL 24h, throttle backfill 1 req/s. |
| Deep pagination distance chậm | Giai đoạn 1 OFFSET; giai đoạn 2 keyset `(distance,id)` nếu cần. |

---

## 8. Định nghĩa Hoàn thành (v1)

- 3 chế độ tìm kiếm hoạt động end-to-end, kết hợp được filter cũ.
- `/api/houses` giữ backward-compat 100% (test regression xanh).
- Tin NULL-coord không bị giấu ở browse/tỉnh; bị loại đúng cách ở nearby + có nhóm phụ.
- Permission denied / GPS off **không bao giờ là ngõ cụt** — luôn có fallback picker.
- p95 nearby query < 400ms; geocode < 800ms; 0 lỗi 5xx do geocoder lan ra UI.
- Manual AC checklist (Phase 00) pass; pytest PostGIS + widget test xanh.

---

## 9. Ngoài phạm vi (v1)

Vẽ polygon ranh giới quận/huyện; isochrone ("20 phút đi xe"); autocomplete tự do cho địa danh; đa ngôn ngữ địa danh; saved-search + push khi có tin mới (nice-to-have Phase sau); chuẩn hoá 100% dữ liệu địa giới; personalization/A-B ranking.

---

## 10. Chỉ số thành công

- ≥30% phiên tìm kiếm dùng 1 trong 3 chế độ mới (4 tuần).
- ≥80% lượt nearby/địa danh có ≥1 kết quả.
- Độ phủ toạ độ tin `approved` tăng lên ≥70% sau backfill.
- CTR kết quả geo ≥ CTR text search hiện tại.
- <5% phiên nearby kết thúc ở trạng thái lỗi quyền vị trí.

---

## Phụ lục — file phase
- `phase-00-ba-requirements.md` — US, AC (Gherkin), edge cases, NFR, metrics.
- `phase-01-backend-data-model-migration.md`
- `phase-02-backend-geocode-backfill.md`
- `phase-03-backend-api.md`
- `phase-04-flutter-data-layer.md`
- `phase-05-flutter-search-overlay-pickers.md`
- `phase-06-flutter-nearby-map.md`
- `phase-07-ranking-relevance-empty-states.md`
- `phase-08-tests-qa.md`
- `phase-09-rollout.md`
