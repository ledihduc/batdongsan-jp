# Phase 06 — Tích Hợp vào House Detail (Badge) + Post House (Warning Modal)

## Context Links
- BA: `phase-00-ba-requirements.md` § US-01, US-02 (locked D4: cảnh báo, không block), AC-04, AC-09 (2 vị trí còn lại)
- Reports: Phase 04 models, Phase 05 screen entry point
- Reference code:
  - `ancu365-app/lib/features/guest/house_detail/house_detail_screen.dart`
  - `ancu365-app/lib/features/guest/post/post_house_screen.dart`
  - `ancu365-app/lib/data/services/planning_service.dart` (P04)

## Overview
- Priority: **P1**
- Status: Pending
- Estimate: 1 ngày
- Description: Inject planning lookup vào 2 màn hiện hữu. House detail: badge zone async load. Post house: button "Kiểm tra quy hoạch" → modal cảnh báo (KHÔNG block submit per D4).

## Key Insights
- US-02 đã GIẢM SCOPE (BA r2): KHÔNG real-time geocoding khi gõ — chỉ user-initiated tap button. Đỡ load Nominatim + đỡ UX phức tạp.
- D4: cảnh báo, không block — UI banner vàng + log analytics event `host_warned_zone_risky`; submit button vẫn enable.
- AC-04: 100% house seed (≥10 mẫu, ≥3 quận) hiển thị badge ĐÚNG zone — yêu cầu seed P02 đã có 3 quận ít nhất.
- Badge load async, KHÔNG block house detail render — nếu API fail, ẩn badge, KHÔNG show error.
- AC-09 disclaimer: badge tap → mở `/tra-quy-hoach` (zoom 16, marker nhà) + warning modal post-house — đủ 4 vị trí (2 trong P05 + 2 trong P06).

## Requirements
### Functional
- **US-01 + AC-04:** Trong `house_detail_screen.dart`, dưới title/address, render `PlanningBadge` async fetched. Tap badge → push `/tra-quy-hoach` với `initialCenter: LatLng(house.lat, house.lng)` + zoom 16 + marker nhà visible.
- **US-02 + D4:** Trong `post_house_screen.dart`, gần ô address, button "Kiểm tra quy hoạch". Tap → modal hiển thị zone tại lat/lng đã nhập:
  - Nếu zone_code IN risky_set → banner vàng "Khu vực này có thể ảnh hưởng kế hoạch sử dụng đất. Bạn vẫn có thể đăng tin." → button "Đã hiểu, tiếp tục".
  - Nếu zone bình thường → "Khu vực này OK. Bạn có thể đăng tin." → button "Đóng".
  - Nếu lat/lng chưa nhập → disable button + tooltip "Nhập địa chỉ trước".
- Log analytics event `host_warned_zone_risky` khi modal show risky.

### Non-functional
- Badge load < 1.5s (cùng AC-02 SLA).
- KHÔNG regress: house detail vẫn render bình thường nếu API fail/timeout.
- Submit button KHÔNG bao giờ disable do warning (D4).

## Architecture
```
HouseDetailScreen
 ├─ existing: image carousel, title, price...
 └─ NEW: PlanningBadge (async)
      └─ on tap → Navigator.push('/tra-quy-hoach', args: LatLng + marker)

PostHouseScreen
 ├─ existing: form fields (title, address, lat, lng, ...)
 ├─ NEW: PlanningCheckButton (next to lat/lng input)
 │   └─ on tap → showDialog(PlanningWarningModal)
 │        ├─ fetch via PlanningService.getParcelByPoint(lat, lng)
 │        ├─ if risky → banner amber + analytics event
 │        └─ button "Đã hiểu" → close
 └─ existing submit button (NEVER disabled by warning per D4)
```

## Related Code Files

### To create
- `ancu365-app/lib/features/planning/widgets/planning_badge.dart`
- `ancu365-app/lib/features/planning/widgets/planning_warning_modal.dart`
- `ancu365-app/lib/features/planning/widgets/planning_check_button.dart`
- `ancu365-app/lib/features/planning/utils/risky_zone_codes.dart` (mirror backend list)
- `ancu365-app/lib/features/planning/analytics/planning_events.dart`

### To modify
- `ancu365-app/lib/features/guest/house_detail/house_detail_screen.dart` (insert badge)
- `ancu365-app/lib/features/guest/post/post_house_screen.dart` (insert check button)
- `ancu365-app/lib/features/planning/planning_map_screen.dart` (accept `initialCenter` + `houseMarker` from P05 — already designed)
- `ancu365-app/lib/l10n/app_vi.arb` + `app_en.arb` → add 4 keys (badgeLabel, warningTitle, riskyText, okText)

### To delete
- (none)

## Implementation Steps

1. **Risky zone codes** `utils/risky_zone_codes.dart`:
   ```dart
   class RiskyZoneCodes {
     // Mirror backend `config.risky_zone_codes` — sync via shared constant doc
     static const Set<String> codes = {
       'DGT',       // Đất giao thông (giải tỏa)
       'CXP',       // Cây xanh công viên
       'DCC',       // Đất công cộng
       'DXH',       // Đất xã hội (công trình HC)
     };
     static bool isRisky(String? code) => code != null && codes.contains(code);
   }
   ```

2. **Badge widget** `widgets/planning_badge.dart`:
   ```dart
   class PlanningBadge extends StatefulWidget {
     final double lat, lng;
     const PlanningBadge({required this.lat, required this.lng, super.key});
     @override State<PlanningBadge> createState() => _PlanningBadgeState();
   }
   class _PlanningBadgeState extends State<PlanningBadge> {
     ParcelDetail? _parcel;
     bool _loading = true;
     @override
     void initState() {
       super.initState();
       _load();
     }
     Future<void> _load() async {
       try {
         _parcel = await context.read<PlanningService>()
             .getParcelByPoint(widget.lat, widget.lng);
       } catch (_) { /* fail silently, AC-04 says don't crash */ }
       if (mounted) setState(() => _loading = false);
     }
     @override
     Widget build(BuildContext context) {
       if (_loading) return const SizedBox(height: 28, width: 120,
           child: LinearProgressIndicator(minHeight: 2));
       if (_parcel == null) return const SizedBox.shrink();
       final isRisky = RiskyZoneCodes.isRisky(_parcel!.zoneCode);
       return InkWell(
         onTap: () => Navigator.pushNamed(context, '/tra-quy-hoach',
             arguments: {'lat': widget.lat, 'lng': widget.lng, 'zoom': 16.0}),
         child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
           decoration: BoxDecoration(
             color: isRisky ? Colors.amber.shade100 : Colors.green.shade100,
             borderRadius: BorderRadius.circular(16)),
           child: Row(mainAxisSize: MainAxisSize.min, children: [
             Icon(Icons.map_outlined, size: 16,
                  color: isRisky ? Colors.amber.shade900 : Colors.green.shade900),
             const SizedBox(width: 6),
             Text('Quy hoạch: ${_parcel!.zoneName ?? "—"}',
                  style: TextStyle(fontSize: 12,
                      color: isRisky ? Colors.amber.shade900 : Colors.green.shade900)),
           ])));
     }
   }
   ```

3. **Insert badge vào `house_detail_screen.dart`:**
   ```dart
   // dưới title + address, trước price
   if (house.latitude != null && house.longitude != null)
     Padding(padding: EdgeInsets.only(top: 8),
             child: PlanningBadge(lat: house.latitude!, lng: house.longitude!)),
   ```

4. **Check button** `widgets/planning_check_button.dart`:
   ```dart
   class PlanningCheckButton extends StatelessWidget {
     final double? lat, lng;
     const PlanningCheckButton({this.lat, this.lng, super.key});
     @override
     Widget build(BuildContext context) {
       final enabled = lat != null && lng != null;
       return Tooltip(
         message: enabled ? '' : 'Nhập địa chỉ trước',
         child: OutlinedButton.icon(
           icon: const Icon(Icons.map_outlined),
           label: const Text('Kiểm tra quy hoạch'),
           onPressed: enabled ? () => _show(context) : null,
         ),
       );
     }
     Future<void> _show(BuildContext ctx) async {
       showDialog(context: ctx, builder: (_) =>
           PlanningWarningModal(lat: lat!, lng: lng!));
     }
   }
   ```

5. **Warning modal** `widgets/planning_warning_modal.dart`:
   ```dart
   class PlanningWarningModal extends StatefulWidget {
     final double lat, lng;
     const PlanningWarningModal({required this.lat, required this.lng, super.key});
     // ...
   }
   class _PlanningWarningModalState extends State<PlanningWarningModal> {
     ParcelDetail? _parcel;
     String? _error;
     bool _loading = true;
     // initState → load
     // build:
     @override
     Widget build(BuildContext context) {
       return AlertDialog(
         title: const Text('Kiểm tra quy hoạch'),
         content: _loading
             ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
             : _error != null
                 ? Text('Không tải được: $_error')
                 : _buildBody(),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context),
                      child: const Text('Đã hiểu')),
         ],
       );
     }
     Widget _buildBody() {
       if (_parcel == null) return const Text('Không tìm thấy thông tin quy hoạch.');
       final risky = RiskyZoneCodes.isRisky(_parcel!.zoneCode);
       if (risky) {
         // AC log analytics
         PlanningAnalytics.logRiskyWarning(_parcel!.zoneCode);
       }
       return Column(mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start, children: [
         if (risky)
           Container(padding: const EdgeInsets.all(8),
               color: Colors.amber.shade50,
               child: Text('Khu vực này có thể ảnh hưởng kế hoạch sử dụng đất ($_parcel.zoneName). Bạn vẫn có thể đăng tin nhưng nên cân nhắc.',
                   style: TextStyle(color: Colors.amber.shade900))),
         const SizedBox(height: 8),
         Text('Zone: ${_parcel!.zoneName ?? "—"} (${_parcel!.zoneCode ?? "—"})'),
         Text('Diện tích: ${_parcel!.areaM2?.toStringAsFixed(1) ?? "—"} m²'),
         Text('Quận: ${_parcel!.district ?? "—"}'),
         const SizedBox(height: 8),
         const DisclaimerBanner(),
       ]);
     }
   }
   ```

6. **Insert check button vào `post_house_screen.dart`:**
   - Tìm phần input lat/lng (hoặc map picker).
   - Add bên dưới:
     ```dart
     Padding(padding: EdgeInsets.only(top: 8),
         child: PlanningCheckButton(lat: _lat, lng: _lng)),
     ```
   - Verify submit button KHÔNG bị disable do warning (D4 — check existing logic không add new disable condition).

7. **Analytics events** `analytics/planning_events.dart`:
   ```dart
   class PlanningAnalytics {
     // Stub if Firebase/Mixpanel not yet integrated
     static void logRiskyWarning(String? zoneCode) {
       // ignore: avoid_print
       print('[analytics] host_warned_zone_risky zone=$zoneCode');
       // TODO: hook to Firebase Analytics when configured
     }
     static void logBadgeTap(String? zoneCode) {
       print('[analytics] planning_badge_tap zone=$zoneCode');
     }
   }
   ```
   → Trả lời pending Q5 của BA (analytics platform) — block tới khi user xác nhận.

8. **i18n updates** (thêm vào `app_vi.arb`):
   ```json
   {
     "planningBadgeLoading": "Đang tải...",
     "planningCheckButton": "Kiểm tra quy hoạch",
     "planningCheckRequireAddress": "Nhập địa chỉ trước",
     "planningRiskyWarning": "Khu vực này có thể ảnh hưởng kế hoạch sử dụng đất.",
     "planningOkText": "Đã hiểu"
   }
   ```

9. **Route `/tra-quy-hoach` chấp nhận args:**
   ```dart
   // main.dart routes:
   '/tra-quy-hoach': (ctx) {
     final args = ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
     return ChangeNotifierProvider(
       create: (_) => PlanningMapProvider(ctx.read<PlanningService>()),
       child: PlanningMapScreen(
         initialCenter: args == null ? null
             : LatLng(args['lat'] as double, args['lng'] as double),
         houseMarker: args != null,
       ));
   },
   ```

10. **AC-04 E2E test:**
    - Seed DB có 10 house, ≥ 3 quận (Q1, Q3, BT).
    - Manual mở mỗi house detail → verify badge hiển thị đúng zone (so với SQL query trực tiếp).
    - Tap badge → mở map zoom 16, marker đúng vị trí.

11. **Smoke test D4:**
    - Mở post house, nhập lat/lng quận risky (zone DGT).
    - Tap check → modal vàng risky show.
    - Submit form → vẫn submit thành công (KHÔNG block).
    - Check console log `host_warned_zone_risky`.

## Todo List
- [ ] `RiskyZoneCodes` constant (sync với backend)
- [ ] `PlanningBadge` widget (async load + fail-silent)
- [ ] Insert badge vào `house_detail_screen.dart`
- [ ] `PlanningCheckButton` widget
- [ ] `PlanningWarningModal` widget (risky → banner vàng)
- [ ] Insert button vào `post_house_screen.dart`
- [ ] Verify submit KHÔNG bị disable (D4)
- [ ] `PlanningAnalytics` stub (FIXME khi user confirm Firebase/Mixpanel)
- [ ] i18n keys VI + EN
- [ ] Route `/tra-quy-hoach` accept args
- [ ] AC-04 E2E test với 10 house seed
- [ ] D4 smoke test (risky → vẫn submit OK)

## Success Criteria
- AC-04: 100% house trong seed (≥10 mẫu, ≥3 quận) hiển thị badge đúng zone (manual verify với SQL).
- Tap badge → mở map zoom 16 đúng vị trí, marker visible.
- US-02 flow: nhập địa chỉ → tap button → modal show → close → submit vẫn được.
- D4: zone risky → banner vàng, button submit vẫn enable, log event xuất hiện.
- AC-09 disclaimer: hiển thị ở 4/4 vị trí (sheet detail P05, footer screen P05, warning modal P06, badge house detail không cần disclaimer riêng — link tới screen có disclaimer).
- KHÔNG regress: house detail render bình thường nếu API fail.

## Risk Assessment
| Risk | Mức | Mitigation |
|------|-----|-----------|
| Badge async chậm → user thấy chớp nháy | Trung | `LinearProgressIndicator` mỏng làm placeholder, KHÔNG layout shift |
| Risky codes drift giữa backend & frontend | Cao | Document shared constant doc; CI check matches; FIXME cho future API `/api/planning/risky-codes` |
| Post house lat/lng undefined → null pointer | Cao | `enabled = lat != null && lng != null` + tooltip; modal KHÔNG fetch nếu null |
| Modal mở rồi user xoay screen → state mất | Thấp | StatefulWidget với `WidgetsBinding.instance.addPostFrameCallback` để re-fetch |
| Analytics chưa setup → log silent | Thấp | Print stub; FIXME comment với issue link |
| House lat/lng = 0,0 (default) → bbox guard fail | Trung | Validate `lat != 0 && lng != 0` trước fetch |
| Submit form trùng tên field `planning_warned` | Thấp | Đặt prefix `planning_*` trong analytics payload |

## Security Considerations
- ✅ JWT token tự động (P04 dio interceptor).
- [ ] Analytics: KHÔNG log lat/lng raw, chỉ zone_code (privacy AC).
- [ ] Risky zone codes hardcode FE — accept risk OK với MVP; doc trong README cần sync với backend.
- [ ] Modal KHÔNG cache response — fresh fetch mỗi tap (per AC-15 freshness).

## Next Steps
- ✅ Phase 07 (admin risky listings + report form) chạy song song được sau khi P05 stable.
- ⚠️ Cần user trả lời Q5 (Firebase/Mixpanel) trước khi remove FIXME analytics.
