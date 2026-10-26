# Phase 04 — Flutter Data Layer + Vector Map Tiles POC

## Context Links
- BA: `phase-00-ba-requirements.md` § US-03/04, AC-01/02/05/14/17/20/21
- Reports: `research/r2-vector-map-tiles-compat.md` (toàn bộ — code snippet sẽ paste vào đây)
- Reference code:
  - `ancu365-app/lib/data/services/api_client.dart` (HTTP pattern)
  - `ancu365-app/lib/data/services/admin_api_service.dart` (service pattern)
  - `ancu365-app/lib/data/models/house_model.dart` (model pattern)
  - `ancu365-app/lib/features/map/` (existing map screen — reuse pattern)

## Overview
- Priority: **P0**
- Status: Pending
- Estimate: 1.5 ngày
- Description: Tạo Flutter data layer (models, service) cho planning API + POC `vector_map_tiles 8.0.0` trên `flutter_map 7.0.2`. POC PHẢI verify trước khi commit Phase 05.

## Key Insights
- R2 đã confirm `vector_map_tiles 8.0.0` tương thích `flutter_map ^7.0.2` — code snippet paste từ R2.
- POC làm 1 màn `planning_map_poc_screen.dart` standalone trước → confirm render → mới refactor sang full screen ở P05.
- Dart-based Theme (R2 Option A) cho MVP — defer MapLibre Style JSON.
- `feature['parcel_id']` từ MVT tap → call `/api/planning/parcels/{parcel_id}` để lấy full detail (Martin chỉ trả properties subset).
- AC-17: race condition tap 2 thửa nhanh → dùng `CancelToken` của `http` package (hoặc switch `dio` nếu cần).
- AC-20 (app size): vector_map_tiles 8.0 add ~3-5MB → trong budget +15MB.

## Requirements
### Functional
- Add `vector_map_tiles ^8.0.0`, `dio ^5.7.0` (cancellation), `cached_network_image ^3.4.1`, `geolocator ^12.0.0` (optional) vào `pubspec.yaml`.
- Tạo 5 model classes: `ParcelDetail`, `DistrictItem`, `PlanningLayer`, `SearchHit`, `ParcelReport`.
- Tạo `PlanningService` với 7 method khớp endpoint từ P03.
- POC screen render OSM raster + vector overlay từ Martin; tap parcel → SnackBar show `parcel_id`.

### Non-functional
- App size delta sau add deps ≤ +15MB (AC-20) — đo bằng `flutter build apk --analyze-size`.
- Memory peak khi map mở < 350MB (AC-21).
- POC chạy 60fps trên Android emulator API 33 (mid-range profile).

## Architecture
```
lib/
├── data/
│   ├── models/
│   │   ├── planning_parcel_model.dart
│   │   ├── planning_district_model.dart
│   │   ├── planning_layer_model.dart
│   │   ├── planning_search_hit_model.dart
│   │   └── planning_report_model.dart
│   └── services/
│       └── planning_service.dart       ← uses dio (cancel token)
├── core/
│   └── config/
│       └── env.dart                    ← API_BASE_URL, MARTIN_TILE_URL
└── features/
    └── planning/
        └── planning_map_poc_screen.dart  ← POC only, deleted at P05
```

## Related Code Files

### To create
- `ancu365-app/lib/data/models/planning_parcel_model.dart`
- `ancu365-app/lib/data/models/planning_district_model.dart`
- `ancu365-app/lib/data/models/planning_layer_model.dart`
- `ancu365-app/lib/data/models/planning_search_hit_model.dart`
- `ancu365-app/lib/data/models/planning_report_model.dart`
- `ancu365-app/lib/data/services/planning_service.dart`
- `ancu365-app/lib/core/config/env.dart`
- `ancu365-app/lib/features/planning/planning_map_poc_screen.dart`

### To modify
- `ancu365-app/pubspec.yaml` → add `vector_map_tiles ^8.0.0`, `dio ^5.7.0`, `cached_network_image ^3.4.1`
- `ancu365-app/lib/main.dart` → tạm thời route `/planning-poc` cho QA POC

### To delete
- `ancu365-app/lib/features/planning/planning_map_poc_screen.dart` (xoá sau P05 done)

## Implementation Steps

1. **Update `pubspec.yaml`:**
   ```yaml
   dependencies:
     # existing...
     flutter_map: ^7.0.2  # already
     latlong2: ^0.9.1     # already
     vector_map_tiles: ^8.0.0
     dio: ^5.7.0
     cached_network_image: ^3.4.1
     geolocator: ^12.0.0  # optional, defer if iOS perm overhead
   ```
   Run `flutter pub get`.

2. **Env config** `lib/core/config/env.dart`:
   ```dart
   class Env {
     static const String apiBaseUrl = String.fromEnvironment(
       'API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');  // Android emu
     static const String martinTileUrl = String.fromEnvironment(
       'MARTIN_TILE_URL',
       defaultValue: 'http://10.0.2.2:3001/planning.parcels/{z}/{x}/{y}.pbf');
     static const String hcmcBboxKey = '10.35,106.30,11.20,107.05';
   }
   ```

3. **Models** — example `planning_parcel_model.dart`:
   ```dart
   class ParcelDetail {
     final String parcelId;
     final String? zoneCode;
     final String? zoneName;
     final String? zoneColor;  // '#FF5733'
     final double? areaM2;
     final String? sheetNo;
     final String? parcelNo;
     final String? district;
     final DateTime fetchedAt;
     final Map<String, dynamic> geometry;  // GeoJSON

     const ParcelDetail({
       required this.parcelId, this.zoneCode, this.zoneName, this.zoneColor,
       this.areaM2, this.sheetNo, this.parcelNo, this.district,
       required this.fetchedAt, required this.geometry,
     });

     factory ParcelDetail.fromJson(Map<String, dynamic> j) => ParcelDetail(
       parcelId: j['parcel_id'] as String,
       zoneCode: j['zone_code'] as String?,
       zoneName: j['zone_name'] as String?,
       zoneColor: j['zone_color'] as String?,
       areaM2: (j['area_m2'] as num?)?.toDouble(),
       sheetNo: j['sheet_no'] as String?,
       parcelNo: j['parcel_no'] as String?,
       district: j['district'] as String?,
       fetchedAt: DateTime.parse(j['fetched_at'] as String),
       geometry: j['geometry'] as Map<String, dynamic>,
     );
   }
   ```
   Tương tự cho `DistrictItem`, `PlanningLayer`, `SearchHit`, `ParcelReport`.

4. **Service** `planning_service.dart`:
   ```dart
   import 'package:dio/dio.dart';
   class PlanningService {
     final Dio _dio;
     PlanningService(this._dio);

     Future<ParcelDetail?> getParcelByPoint(double lat, double lng,
                                            {CancelToken? cancelToken}) async {
       try {
         final res = await _dio.get('/api/planning/parcels',
             queryParameters: {'lat': lat, 'lng': lng},
             cancelToken: cancelToken);
         if (res.data == null) return null;
         return ParcelDetail.fromJson(res.data as Map<String, dynamic>);
       } on DioException catch (e) {
         if (CancelToken.isCancel(e)) return null;
         rethrow;
       }
     }

     Future<ParcelDetail> getParcelById(String id) async {
       final res = await _dio.get('/api/planning/parcels/$id');
       return ParcelDetail.fromJson(res.data);
     }

     Future<List<DistrictItem>> listDistricts() async {
       final res = await _dio.get('/api/planning/districts');
       return (res.data as List).map((e) => DistrictItem.fromJson(e)).toList();
     }

     Future<List<SearchHit>> search(String q, {int limit = 10}) async {
       final res = await _dio.get('/api/planning/search',
           queryParameters: {'q': q, 'limit': limit});
       return (res.data as List).map((e) => SearchHit.fromJson(e)).toList();
     }

     Future<void> reportError(ParcelReport report) async {
       await _dio.post('/api/planning/report-error', data: report.toJson());
     }
   }
   ```

5. **POC screen** `planning_map_poc_screen.dart` (copy-adapt từ R2 §3):
   ```dart
   import 'package:flutter/material.dart';
   import 'package:flutter_map/flutter_map.dart';
   import 'package:latlong2/latlong.dart';
   import 'package:vector_map_tiles/vector_map_tiles.dart';
   import 'package:ancu365_app/core/config/env.dart';

   class PlanningMapPocScreen extends StatelessWidget {
     const PlanningMapPocScreen({super.key});

     @override
     Widget build(BuildContext context) {
       return Scaffold(
         appBar: AppBar(title: const Text('Planning POC')),
         body: FlutterMap(
           options: const MapOptions(
             initialCenter: LatLng(10.7769, 106.7009),  // Bến Thành
             initialZoom: 14,
             maxZoom: 18,
           ),
           children: [
             TileLayer(
               urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
               userAgentPackageName: 'com.ancu365.app',
             ),
             VectorTileLayer(
               tileProviders: TileProviders({
                 'planning.parcels': NetworkVectorTileProvider(
                   urlTemplate: Env.martinTileUrl,
                   maximumZoom: 16,
                 ),
               }),
               theme: _buildTheme(),
               // onTap: callback when polygon tapped
             ),
           ],
         ),
       );
     }

     Theme _buildTheme() {
       // Minimal theme: fill + outline
       // Reference R2 §3 Option A
       return Theme(layers: [
         LayerType.fill('parcels-fill',
             paint: Paint()
               ..color = Colors.blue.withOpacity(0.3)
               ..style = PaintingStyle.fill),
         LayerType.line('parcels-outline',
             paint: Paint()
               ..color = Colors.grey.shade700
               ..strokeWidth = 1.0
               ..style = PaintingStyle.stroke),
       ]);
     }
   }
   ```

6. **Wire vào `main.dart`** route `/planning-poc` (tạm):
   ```dart
   '/planning-poc': (ctx) => const PlanningMapPocScreen(),
   ```

7. **POC test matrix:**
   - [ ] Android emulator API 33 (Pixel 5) — render OSM + overlay zoom 12-16
   - [ ] iOS simulator iPhone 14 (iOS 16+) — same
   - [ ] Web (Chrome) — chấp nhận FPS < 30 nếu jank, sẽ note
   - [ ] Pan/zoom 5 phút continuous — không memory leak (Flutter DevTools)
   - [ ] Tile fetch error (Martin offline) — show error overlay, không crash
   - [ ] Tap parcel polygon → console log feature properties (`parcel_id`, `zone_color`)

8. **App size measurement:**
   ```bash
   flutter build apk --release --analyze-size
   # so sánh với baseline pre-Phase 04
   ```
   Pass criterion: delta ≤ +15MB.

9. **Memory profiling** Flutter DevTools:
   - Open POC, pan/zoom 2 phút, snapshot heap
   - Expect peak < 350MB (AC-21)

10. **POC sign-off doc** `plans/.../reports/p04-poc-result.md`:
    - Screenshots (3 platforms)
    - APK size delta
    - Memory peak
    - FPS observation
    - Go/No-Go decision cho P05

## Todo List
- [ ] `pubspec.yaml`: add `vector_map_tiles`, `dio`, `cached_network_image`
- [ ] `lib/core/config/env.dart`
- [ ] 5 model classes (`planning_*_model.dart`)
- [ ] `PlanningService` với 5 method + CancelToken support
- [ ] `PlanningMapPocScreen` (R2 snippet adapted)
- [ ] Route `/planning-poc` trong `main.dart`
- [ ] POC test Android emu — render OK
- [ ] POC test iOS simu — render OK
- [ ] POC test Web — note FPS
- [ ] APK size analyze ≤ +15MB
- [ ] Memory profile peak < 350MB
- [ ] Report `p04-poc-result.md` với Go/No-Go

## Success Criteria
- POC screen render OSM base + planning polygon overlay zoom 12-16
- Tap polygon → log `feature['parcel_id']` đúng từ MVT
- APK size delta ≤ +15MB
- Memory peak < 350MB (DevTools)
- FPS ≥ 30 trên Android emu API 33
- `PlanningService.getParcelByPoint(10.77, 106.69)` trả ParcelDetail hợp lệ
- Go/No-Go report viết xong — DECISION = GO trước khi P05 start

## Risk Assessment
| Risk | Mức | Mitigation |
|------|-----|-----------|
| `vector_map_tiles 8.0` API thay đổi sau pub upgrade | Trung | Lock version `^8.0.0` (range minor); test thật trong POC |
| Theme reference layer không match MVT → render silent fail | Cao | R2 §10 Issue 3: enable `Logger.console()` debug; minimal theme (fill+outline only) |
| MVT endpoint `10.0.2.2:3001` không reach từ iOS simu | Trung | iOS simu dùng `localhost:3001`; Android dùng `10.0.2.2`; env-based |
| App size > 15MB delta | Trung | Tree-shake, defer `geolocator` nếu cần |
| Memory leak pan dài | Trung | R2 §10 Issue 1: dispose handler ở `screen.dispose()` |
| Race condition tap 2 thửa nhanh | Cao | `CancelToken` per tap; AC-17 verify test |
| Web FPS < 30 | Thấp | Acceptable cho MVP — mobile priority; note plan tương lai raster fallback |
| Dio breaking change từ `http` pkg | Thấp | Wrap dio trong service; rest of app vẫn dùng `http` (no migration) |

## Security Considerations
- ✅ JWT token: lấy từ `SessionService` (existing) → inject Bearer header trong dio interceptor.
- [ ] HTTP cleartext: dev `10.0.2.2` OK; prod yêu cầu HTTPS — config `network_security_config.xml` Android.
- [ ] CertificatePinning prod: defer Phase 2 (overkill MVP).
- [ ] Disclaimer pháp lý (AC-09) hiển thị trong POC screen footer.
- [ ] User-Agent header `User-Agent: ancu365-flutter/1.0` để Nominatim không reject.

## Next Steps
- ✅ Phase 05 (full PlanningMapScreen) start sau khi POC Go/No-Go = GO.
- ⚠️ Nếu POC FAIL → activate fallback raster Martin (R2 §7) — thêm 2-3 ngày, lùi P05.
