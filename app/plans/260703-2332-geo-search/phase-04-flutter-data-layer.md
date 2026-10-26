# Phase 04 — Flutter: Data layer + Services + SearchProvider

**Mục tiêu:** hạ tầng client cho geo-search, tách state theo mode.
**Est.:** 1.5 ngày · **Phụ thuộc:** Phase 03.

---

## 1. Dependency mới (D13)
- Thêm `geolocator` vào `pubspec.yaml`. **Chốt version tương thích Dart 3.12.2 trước khi code** (dự án pin nhiều package cho SDK cũ — vd `permission_handler ^10.4.5`). Nếu `geolocator` mới yêu cầu SDK cao hơn → chọn bản cũ tương thích hoặc fallback `location`.
- (Tùy chọn Phase 06) `flutter_map_marker_cluster` cho cluster map.

---

## 2. Models
- `HouseModel`: thêm parse `distanceKm` (double?, backend trả khi nearby), `provinceCode`/`districtCode` nếu backend expose.
- `PlaceRef` model (`displayName/lat/lng`) cho kết quả geocode.
- `SearchIntent` (cấu trúc, không chỉ text): `{type: province|place|nearby|query, label, provinceCode?, district?, lat?, lng?, radiusKm?}` — dùng cho recent/saved searches.

## 3. Services (`lib/data/services/`)
- `GeocodingService` — gọi `/api/planning/search` (forward) + reverse; hoặc `/api/houses/search-nearby` (compose). Bọc `Debouncer` sẵn có.
- `GeoLocationService` — bọc `geolocator` + `permission_handler`: `getCurrentPosition()`, check/last-known, xử lý service-off, ngoài bbox VN. Trả kết quả có phân biệt: `granted/denied/permanentlyDenied/serviceOff`.
- `RecentSearchStore` — lưu 8–10 `SearchIntent` vào `SharedPreferences`; `add/list/clear`.

## 4. Repository (`IHouseRepository` + `ApiHouseRepository`)
Thêm:
- `getNearbyHouses({lat, lng, radiusKm, sort, filters, limit, offset})` → `/api/houses?near_lat=&near_lng=&radius_km=&sort=distance`.
- `getHousesByPlace({place, radiusKm, limit, offset})` → `/api/houses/search-nearby`.
- `getHousesByArea({provinceCode, districtCode, filters, limit, offset})` → `/api/houses?province=&district=`.

## 5. State: `SearchProvider` (tách khỏi `HouseProvider`)
`HouseProvider` hiện phẳng (query+category+price+area) — nhồi nearby vào sẽ rối. Tạo `SearchProvider` (hoặc mở rộng có kiểm soát):
- `enum SearchMode { home, nearby, place, area, query }` + `currentMode`.
- Tham số: `nearbyOrigin (LatLng?)`, `radiusKm (default 3)`, `provinceCode?`, `districtCode?`, `placeRef?`, `sort`.
- Methods: `fetchNearby(lat,lng,radiusKm,sort)`, `fetchByPlace(place,radiusKm)`, `fetchByArea(provinceCode,districtCode)`, `setSort(...)`, `setRadius(...)`.
- `loadMore` phân nhánh theo mode (giữ infinite scroll).
- `resetUserScope()` phải reset các field mới (theo pattern `UserScoped` hiện có).

---

## Definition of Done
- `flutter pub get` xanh với `geolocator`; app build được (android + web).
- Unit test service parse `distanceKm`, `SearchIntent` round-trip qua SharedPreferences.
- Repository gọi đúng endpoint + params (mock http).
- `GeoLocationService` trả đúng enum trạng thái cho denied/serviceOff (test với mock).
