# Phase 05 — Flutter PlanningMapScreen Đầy Đủ (Map + Search + Sheet + Layer Panel)

## Context Links
- BA: `phase-00-ba-requirements.md` § US-03, US-04, US-05; AC-01..09, AC-10..17 (i18n, dark, a11y, cache)
- Reports: `research/r2-vector-map-tiles-compat.md` §3, §4, §8
- Reference code:
  - Phase 04 `planning_service.dart`, models, POC
  - `ancu365-app/lib/features/map/` (existing map UI patterns)
  - `ancu365-app/lib/features/guest/house_detail/house_detail_screen.dart` (bottom sheet pattern)

## Overview
- Priority: **P0**
- Status: Pending
- Estimate: 2 ngày
- Description: Full-featured `PlanningMapScreen`: map vector + raster, sidebar layer toggle/opacity, search dropdown, bottom sheet parcel detail, error/loading states, disclaimer banner.

## Key Insights
- Cover AC-01..09 + AC-10/11/12/13/14/15/17 (10 AC).
- State management: dùng `provider` (đã có sẵn trong app) — tạo `PlanningMapProvider` với state machine `loading|ready|error`.
- Bottom sheet detail: `showModalBottomSheet` + `DraggableScrollableSheet` cho user drag toàn màn.
- Search: debounce 300ms; trigger `/api/planning/search` khi length ≥ 3.
- Cache tile trên device qua `vector_map_tiles` internal cache + `cached_network_image` cho raster — limit 100MB (AC-14).
- Disclaimer banner ở footer + bottom sheet (2 trong 4 vị trí AC-09; 2 vị trí còn lại ở P06).

## Requirements
### Functional (AC mapping)
- **AC-01:** Tab/icon từ home → mở `PlanningMapScreen` cold start < 3s.
- **AC-02:** Tap parcel → bottom sheet p95 < 1.5s; cache hit < 200ms.
- **AC-03:** Search "Trần Phú Q1" → dropdown gợi ý < 2.5s.
- **AC-05:** Layer toggle + slider opacity 0-100% mượt.
- **AC-06:** Tap/search ngoài bbox HCMC → SnackBar + button "Mở map thường".
- **AC-07:** API fail → error card + button "Thử lại"; 3 retry → message cuối.
- **AC-08:** Skeleton hiển thị < 200ms.
- **AC-09:** Disclaimer ở footer screen + bottom sheet (2/4 vị trí).
- **AC-10:** i18n VI primary, EN fallback.
- **AC-11:** Dark mode: opacity overlay -10%.
- **AC-12:** TalkBack đọc panel detail; tap target ≥ 48dp.
- **AC-13:** Location denied → vẫn dùng search.
- **AC-14:** Tile cache ≤ 100MB; nút "Xoá cache" trong settings.
- **AC-15:** Bottom sheet show "Cập nhật: dd/mm/yyyy"; warning vàng nếu > 30 ngày.
- **AC-17:** Tap 2 thửa < 500ms → request đầu cancel.

### Non-functional
- 60fps pan/zoom mid-range Android.
- Memory < 350MB (AC-21).
- 5 phút map < 5% pin (AC-22).

## Architecture
```
PlanningMapScreen (StatefulWidget)
 └─ ChangeNotifierProvider<PlanningMapProvider>
     ├─ AppBar (search field + back)
     ├─ Stack
     │   ├─ FlutterMap
     │   │   ├─ TileLayer (OSM raster base)
     │   │   └─ VectorTileLayer (planning, opacity controlled)
     │   ├─ Positioned (top): SearchDropdown (suggestions)
     │   ├─ Positioned (right): LayerControlPanel (toggle + opacity slider)
     │   ├─ Positioned (bottom): DisclaimerBanner
     │   └─ Positioned (center fab): MyLocationButton (optional AC-13)
     ├─ BottomSheet (when parcel selected): ParcelDetailSheet
     │   ├─ Header: zone_name + colored chip
     │   ├─ Body: area, sheet/parcel no, district, fetched_at + warning if > 30 days
     │   ├─ Disclaimer
     │   └─ Actions: "Báo cáo dữ liệu sai" (US-08 trigger, screen ở P07)
     └─ ErrorOverlay / LoadingSkeleton
```

## Related Code Files

### To create
- `ancu365-app/lib/features/planning/planning_map_screen.dart` (main screen)
- `ancu365-app/lib/features/planning/providers/planning_map_provider.dart`
- `ancu365-app/lib/features/planning/widgets/search_dropdown.dart`
- `ancu365-app/lib/features/planning/widgets/layer_control_panel.dart`
- `ancu365-app/lib/features/planning/widgets/parcel_detail_sheet.dart`
- `ancu365-app/lib/features/planning/widgets/disclaimer_banner.dart`
- `ancu365-app/lib/features/planning/widgets/error_card.dart`
- `ancu365-app/lib/features/planning/widgets/loading_skeleton.dart`
- `ancu365-app/lib/features/planning/utils/zone_color_resolver.dart`
- `ancu365-app/lib/features/planning/utils/bbox_guard.dart`
- `ancu365-app/lib/l10n/app_vi.arb` (planning keys)
- `ancu365-app/lib/l10n/app_en.arb` (planning keys)

### To modify
- `ancu365-app/lib/main.dart` → route `/tra-quy-hoach`
- `ancu365-app/lib/features/guest/guest_shell.dart` → add tab/icon "Tra quy hoạch"
- `ancu365-app/lib/features/planning/planning_map_poc_screen.dart` → DELETE (POC done)
- `ancu365-app/lib/main.dart` → remove `/planning-poc` route

### To delete
- `ancu365-app/lib/features/planning/planning_map_poc_screen.dart`

## Implementation Steps

1. **Provider** `planning_map_provider.dart`:
   ```dart
   enum MapState { idle, loading, ready, error }
   class PlanningMapProvider extends ChangeNotifier {
     final PlanningService _svc;
     PlanningMapProvider(this._svc);

     MapState state = MapState.idle;
     ParcelDetail? selectedParcel;
     String? errorMessage;
     int retryCount = 0;
     bool planningLayerVisible = true;
     double layerOpacity = 0.5;
     CancelToken? _parcelToken;

     Future<void> tapParcel(double lat, double lng) async {
       _parcelToken?.cancel('new tap');
       _parcelToken = CancelToken();
       if (!BboxGuard.isInsideHCMC(lat, lng)) {
         errorMessage = 'OUT_OF_BBOX'; state = MapState.error; notifyListeners();
         return;
       }
       state = MapState.loading; notifyListeners();
       try {
         selectedParcel = await _svc.getParcelByPoint(lat, lng,
             cancelToken: _parcelToken);
         state = MapState.ready; retryCount = 0;
       } on DioException catch (e) {
         retryCount++;
         errorMessage = retryCount >= 3
             ? 'Vui lòng kiểm tra mạng hoặc thử lại sau'
             : e.message ?? 'NETWORK';
         state = MapState.error;
       }
       notifyListeners();
     }

     void toggleLayer(bool v) { planningLayerVisible = v; notifyListeners(); }
     void setOpacity(double v) { layerOpacity = v; notifyListeners(); }
   }
   ```

2. **Bbox guard** `utils/bbox_guard.dart`:
   ```dart
   class BboxGuard {
     static const double minLat = 10.35, maxLat = 11.20;
     static const double minLng = 106.30, maxLng = 107.05;
     static bool isInsideHCMC(double lat, double lng) =>
         lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
   }
   ```

3. **Zone color resolver** (R2 §8):
   ```dart
   Color resolveZoneColor(String? hex, {bool dark = false}) {
     Color base = Colors.blue.shade300;
     if (hex != null && hex.isNotEmpty) {
       try { base = Color(int.parse(hex.replaceFirst('#', '0xff'))); }
       catch (_) {}
     }
     // AC-11: dark mode opacity -10%
     return dark ? base.withOpacity(0.4) : base.withOpacity(0.5);
   }
   ```

4. **Screen layout** `planning_map_screen.dart`:
   ```dart
   class PlanningMapScreen extends StatefulWidget {
     final LatLng? initialCenter;  // when opened from house detail
     const PlanningMapScreen({this.initialCenter, super.key});
     // ...
   }
   // build:
   Scaffold(
     appBar: AppBar(title: TextField(/* search */ ...)),
     body: Consumer<PlanningMapProvider>(builder: (ctx, p, _) {
       return Stack(children: [
         FlutterMap(
           options: MapOptions(
             initialCenter: widget.initialCenter ?? LatLng(10.7769, 106.7009),
             initialZoom: 14,
             onTap: (tapPos, latLng) =>
                 p.tapParcel(latLng.latitude, latLng.longitude),
           ),
           children: [
             TileLayer(urlTemplate: '...osm...'),
             if (p.planningLayerVisible)
               Opacity(opacity: p.layerOpacity,
                       child: VectorTileLayer(/* R2 §3 */)),
           ],
         ),
         Positioned(top: 70, child: SearchDropdown(onPick: _flyTo)),
         Positioned(right: 8, top: 100, child: LayerControlPanel()),
         Positioned(bottom: 0, left: 0, right: 0, child: DisclaimerBanner()),
         if (p.state == MapState.loading) LoadingSkeleton(),
         if (p.state == MapState.error) ErrorCard(/* retry */),
         if (p.selectedParcel != null) ParcelDetailSheet(parcel: p.selectedParcel!),
       ]);
     }),
   )
   ```

5. **Search dropdown** `widgets/search_dropdown.dart`:
   - `TextField` + `Debouncer(300ms)` → call `svc.search(q)` → show `ListView` 10 hits.
   - Tap hit → callback `onPick(LatLng)` → map fly to.
   - Out-of-bbox check trên search result (AC-06).

6. **Layer control panel** `widgets/layer_control_panel.dart`:
   - `Switch` toggle planningLayerVisible.
   - `Slider` opacity 0-100 (step 5).
   - Tap target ≥ 48dp (AC-12).

7. **Parcel detail sheet** `widgets/parcel_detail_sheet.dart`:
   ```dart
   DraggableScrollableSheet(
     initialChildSize: 0.4, maxChildSize: 0.9, minChildSize: 0.2,
     builder: (ctx, scrollCtrl) => SingleChildScrollView(
       controller: scrollCtrl,
       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Container(/* color chip + zone_name */),
         Text('Diện tích: ${parcel.areaM2?.toStringAsFixed(1)} m²'),
         Text('Quận: ${parcel.district}'),
         Text('Tờ/thửa: ${parcel.sheetNo}/${parcel.parcelNo}'),
         _buildFreshness(parcel.fetchedAt),  // AC-15 warning > 30 ngày
         const Divider(),
         DisclaimerBanner(),
         TextButton(onPressed: () => Navigator.push(ctx, /* P07 report screen */),
                    child: Text('Báo cáo dữ liệu sai')),
       ]),
     ),
   )
   ```

8. **Disclaimer banner** (AC-09, ubiquitous):
   ```dart
   Container(
     color: Colors.amber.shade50, padding: EdgeInsets.all(8),
     child: Text('Dữ liệu tham khảo. Vui lòng đối chiếu với cơ quan có thẩm quyền.',
                 style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
   )
   ```

9. **Error card** (AC-07):
   - Show `error.code` + retry button.
   - Sau 3 retry → message cuối "Vui lòng kiểm tra mạng hoặc thử lại sau".

10. **i18n** `app_vi.arb` + `app_en.arb`:
    ```json
    {
      "planningMapTitle": "Tra cứu quy hoạch",
      "planningSearchHint": "Tìm địa chỉ tại TP.HCM",
      "planningLayerToggle": "Lớp quy hoạch SDĐ 2030",
      "planningOpacity": "Độ trong suốt",
      "planningDisclaimer": "Dữ liệu tham khảo. Vui lòng đối chiếu với cơ quan có thẩm quyền.",
      "planningOutOfBbox": "Tạm thời chỉ hỗ trợ TP.HCM",
      "planningOpenNormalMap": "Mở map thường",
      "planningRetry": "Thử lại",
      "planningReportError": "Báo cáo dữ liệu sai",
      "planningFreshnessWarning": "Dữ liệu cũ hơn 30 ngày"
    }
    ```

11. **Route + tab entry:**
    ```dart
    // main.dart
    '/tra-quy-hoach': (ctx) => ChangeNotifierProvider(
      create: (_) => PlanningMapProvider(ctx.read<PlanningService>()),
      child: const PlanningMapScreen()),
    ```
    Add icon trong `guest_shell.dart` bottom nav.

12. **Cache management** (AC-14):
    - `vector_map_tiles` có internal cache; expose clear method ở settings:
    ```dart
    // In settings screen (existing)
    ListTile(title: Text('Xoá cache bản đồ'),
             onTap: () => VectorTileProvider.clearAllCache());  // R2 API
    ```

13. **A11y test (AC-12):**
    - Run `flutter test --golden` với `Semantics` wrapper.
    - Manual TalkBack test trên Android.

14. **Verify AC checklist:** Manual QA 12 AC (01-09, 10-15, 17) trên Android emulator.

## Todo List
- [ ] Provider `PlanningMapProvider` với state machine + CancelToken
- [ ] `BboxGuard` util
- [ ] `ZoneColorResolver` (dark mode aware)
- [ ] `PlanningMapScreen` shell
- [ ] `SearchDropdown` widget (debounce + bbox check)
- [ ] `LayerControlPanel` (toggle + opacity slider)
- [ ] `ParcelDetailSheet` (DraggableScrollableSheet)
- [ ] `DisclaimerBanner` widget
- [ ] `ErrorCard` (retry counter)
- [ ] `LoadingSkeleton` (shimmer)
- [ ] i18n VI + EN arb keys
- [ ] Route `/tra-quy-hoach` + tab entry `guest_shell.dart`
- [ ] Settings "Xoá cache bản đồ"
- [ ] A11y test TalkBack + tap target ≥ 48dp
- [ ] Delete `planning_map_poc_screen.dart` + route
- [ ] Manual QA 12 AC pass

## Success Criteria
- 12/12 AC trong scope pass manual QA.
- Cold start < 3s (AC-01) đo stopwatch.
- Parcel tap p95 < 1.5s (AC-02) — log 20 tap.
- Search p95 < 2.5s (AC-03).
- Opacity slider 0-100% mượt 30fps (AC-05).
- Out-of-bbox toast + button (AC-06).
- 3 retry → message cuối (AC-07).
- Disclaimer ở footer + sheet (2/4 vị trí của AC-09; 2 còn lại ở P06).
- TalkBack đọc đủ panel (AC-12).
- Cache clear button hoạt động (AC-14).
- Warning vàng nếu fetched_at > 30 days (AC-15).
- Tap 2 thửa nhanh → KHÔNG race (AC-17).

## Risk Assessment
| Risk | Mức | Mitigation |
|------|-----|-----------|
| Provider rebuild gây jank | Trung | Selector + const widgets; profile DevTools |
| `Opacity` widget tốn GPU | Trung | Wrap chỉ VectorTileLayer; alternative: opacity prop của theme paint |
| DraggableScrollableSheet conflict với map gesture | Trung | Test pan map khi sheet open; set `enableDrag: true` |
| i18n key thiếu fallback → crash | Thấp | Generate `app_localizations.dart` + `MaterialApp.localizationsDelegates` |
| Search debounce + cancel token mismatch | Trung | Centralize trong provider; 1 token cho search, 1 cho parcel |
| Map fly-to animation cancel khi user pan | Thấp | `mapController.move()` không animate dài; OK |
| Bottom sheet not dismissible khi error | Thấp | `useSafeArea: true` + close icon header |

## Security Considerations
- ✅ JWT token tự động qua dio interceptor (P04).
- [ ] Search query KHÔNG log user_id (privacy).
- [ ] Cache disk: chỉ tile data, KHÔNG user query history.
- [ ] Permission location: `geolocator` request runtime; deny → fallback search (AC-13).
- [ ] Disclaimer text từ ARB (i18n), KHÔNG inline string trùng lặp.

## Next Steps
- ✅ Phase 06 (house detail badge + post house warning) start sau khi P05 stable.
- ✅ Phase 07 (admin + report screen) — report button trong sheet đã point sang.
