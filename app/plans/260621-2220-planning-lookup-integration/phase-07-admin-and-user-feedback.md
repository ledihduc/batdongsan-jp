# Phase 07 — Admin Risky Listings Screen + User Report Form (US-06 + US-08)

## Context Links
- BA: `phase-00-ba-requirements.md` § US-06 (admin theo dõi listing risky), US-08 (báo cáo dữ liệu sai); AC-19 (admin role check)
- Reports: Phase 03 endpoint contract `/api/planning/admin/risky-listings`, `/api/planning/report-error`
- Reference code:
  - `ancu365-app/lib/features/admin/admin_home_screen.dart`
  - `ancu365-app/lib/data/services/admin_api_service.dart`
  - `ancu365-app/lib/features/planning/widgets/parcel_detail_sheet.dart` (P05 — button trigger US-08)

## Overview
- Priority: **P1**
- Status: Pending
- Estimate: 1 ngày
- Description: 2 màn nhỏ — admin xem list listing rơi vào zone risky + form user report data sai. Reuse pattern admin hiện hữu.

## Key Insights
- US-06: admin endpoint đã có ở P03 → chỉ cần screen consume.
- US-08: trigger từ sheet (P05) + warning modal (P06); form đơn giản (parcel_id, reason, optional image).
- Image upload reuse `image_picker` (đã có sẵn) + `/api/upload` (existing ancu365 endpoint).
- Admin screen access qua existing role check (admin user trong seed).
- KHÔNG cần screen riêng phức tạp — list cơ bản với pull-to-refresh.

## Requirements
### Functional
- **US-06 admin screen:** Tab/menu "Listing risky" trong admin home → list houses với title, address, district, zone_name, zone_code (chip màu cam). Tap row → mở house detail. Pull to refresh.
- **US-08 report form:** Modal/screen từ parcel detail sheet button "Báo cáo dữ liệu sai":
  - Field: reason (textarea, 10-500 chars, required).
  - Field: optional image (image_picker → upload via `/api/upload` → URL trả về).
  - Submit → POST `/api/planning/report-error` → toast success + close.

### Non-functional
- Admin endpoint chỉ accessible với role=admin (AC-19) — backend đã check ở P03; FE chỉ verify token role để show/hide menu.
- Form submit response < 2s.

## Architecture
```
AdminHomeScreen (existing)
 └─ NEW: Tile "Listing rủi ro quy hoạch" → push RiskyListingsScreen

RiskyListingsScreen (NEW)
 ├─ FutureBuilder<List<RiskyHouse>>
 ├─ Pull-to-refresh
 └─ ListTile per house → push existing HouseDetailScreen

ParcelDetailSheet (P05, modify)
 └─ TextButton "Báo cáo dữ liệu sai" → push ReportErrorScreen(parcelId)

ReportErrorScreen (NEW)
 ├─ Form: reason (TextField multiline) + ImagePicker
 ├─ Upload flow: pick → POST /api/upload → get URL
 └─ Submit: POST /api/planning/report-error → pop with success
```

## Related Code Files

### To create
- `ancu365-app/lib/features/admin/planning/risky_listings_screen.dart`
- `ancu365-app/lib/data/models/risky_house_model.dart`
- `ancu365-app/lib/features/planning/report/report_error_screen.dart`

### To modify
- `ancu365-app/lib/features/admin/admin_home_screen.dart` (add tile)
- `ancu365-app/lib/data/services/planning_service.dart` (add 2 methods: `getRiskyHouses`, `reportError` — already P04)
- `ancu365-app/lib/data/services/admin_api_service.dart` (or extend `PlanningService` admin section)
- `ancu365-app/lib/features/planning/widgets/parcel_detail_sheet.dart` (wire button → navigation)
- `ancu365-app/lib/l10n/app_vi.arb` + `app_en.arb` → 6 keys

### To delete
- (none)

## Implementation Steps

1. **Model** `risky_house_model.dart`:
   ```dart
   class RiskyHouse {
     final int id;
     final String title;
     final double latitude, longitude;
     final String? zoneCode;
     final String? zoneName;
     const RiskyHouse({required this.id, required this.title,
         required this.latitude, required this.longitude,
         this.zoneCode, this.zoneName});
     factory RiskyHouse.fromJson(Map<String, dynamic> j) => RiskyHouse(
         id: j['id'] as int, title: j['title'] as String,
         latitude: (j['latitude'] as num).toDouble(),
         longitude: (j['longitude'] as num).toDouble(),
         zoneCode: j['zone_code'] as String?,
         zoneName: j['zone_name'] as String?);
   }
   ```

2. **PlanningService methods** (extend từ P04):
   ```dart
   Future<List<RiskyHouse>> getRiskyHouses() async {
     final res = await _dio.get('/api/planning/admin/risky-listings');
     return ((res.data as Map)['items'] as List)
         .map((e) => RiskyHouse.fromJson(e)).toList();
   }

   Future<void> reportError({required String parcelId,
                              required String reason,
                              String? imageUrl}) async {
     await _dio.post('/api/planning/report-error', data: {
       'parcel_id': parcelId,
       'reason': reason,
       'image_url': imageUrl,
     });
   }
   ```

3. **Admin home tile** `admin_home_screen.dart`:
   ```dart
   ListTile(
     leading: const Icon(Icons.warning_amber, color: Colors.amber),
     title: const Text('Listing rủi ro quy hoạch'),
     subtitle: const Text('Tin đăng nằm zone đất công cộng/giải toả'),
     onTap: () => Navigator.push(context,
         MaterialPageRoute(builder: (_) => const RiskyListingsScreen())),
   ),
   ```

4. **Risky listings screen** `risky_listings_screen.dart`:
   ```dart
   class RiskyListingsScreen extends StatefulWidget {
     const RiskyListingsScreen({super.key});
     @override State<RiskyListingsScreen> createState() =>
         _RiskyListingsScreenState();
   }
   class _RiskyListingsScreenState extends State<RiskyListingsScreen> {
     late Future<List<RiskyHouse>> _future;
     @override
     void initState() {
       super.initState();
       _future = context.read<PlanningService>().getRiskyHouses();
     }
     Future<void> _refresh() async {
       setState(() {
         _future = context.read<PlanningService>().getRiskyHouses();
       });
     }
     @override
     Widget build(BuildContext ctx) => Scaffold(
       appBar: AppBar(title: const Text('Listing rủi ro')),
       body: RefreshIndicator(onRefresh: _refresh,
         child: FutureBuilder<List<RiskyHouse>>(
           future: _future,
           builder: (ctx, snap) {
             if (snap.connectionState != ConnectionState.done)
               return const Center(child: CircularProgressIndicator());
             if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
             final items = snap.data ?? [];
             if (items.isEmpty) return const Center(
                 child: Text('Không có listing rủi ro'));
             return ListView.separated(
               itemCount: items.length,
               separatorBuilder: (_, __) => const Divider(height: 1),
               itemBuilder: (_, i) {
                 final h = items[i];
                 return ListTile(
                   title: Text(h.title),
                   subtitle: Row(children: [
                     Chip(label: Text(h.zoneCode ?? '?',
                                       style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.amber.shade100,
                          visualDensity: VisualDensity.compact),
                     const SizedBox(width: 8),
                     Expanded(child: Text(h.zoneName ?? '—',
                         overflow: TextOverflow.ellipsis)),
                   ]),
                   trailing: const Icon(Icons.chevron_right),
                   onTap: () => Navigator.pushNamed(
                       ctx, '/house-detail', arguments: h.id),
                 );
               },
             );
           },
         ),
       ),
     );
   }
   ```

5. **Report error screen** `report_error_screen.dart`:
   ```dart
   class ReportErrorScreen extends StatefulWidget {
     final String parcelId;
     const ReportErrorScreen({required this.parcelId, super.key});
     @override State<ReportErrorScreen> createState() =>
         _ReportErrorScreenState();
   }
   class _ReportErrorScreenState extends State<ReportErrorScreen> {
     final _reasonCtrl = TextEditingController();
     String? _imageUrl;
     bool _submitting = false;

     Future<void> _pickImage() async {
       final picker = ImagePicker();
       final file = await picker.pickImage(source: ImageSource.camera,
                                            maxWidth: 1280);
       if (file == null) return;
       // POST to existing /api/upload
       final url = await context.read<ApiClient>().upload(file.path);
       setState(() => _imageUrl = url);
     }

     Future<void> _submit() async {
       final reason = _reasonCtrl.text.trim();
       if (reason.length < 10) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text('Lý do tối thiểu 10 ký tự')));
         return;
       }
       setState(() => _submitting = true);
       try {
         await context.read<PlanningService>().reportError(
             parcelId: widget.parcelId, reason: reason, imageUrl: _imageUrl);
         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text('Đã gửi báo cáo. Cảm ơn bạn!')));
         Navigator.pop(context);
       } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('Gửi thất bại: $e')));
       } finally {
         if (mounted) setState(() => _submitting = false);
       }
     }

     @override
     Widget build(BuildContext ctx) => Scaffold(
       appBar: AppBar(title: const Text('Báo cáo dữ liệu sai')),
       body: Padding(padding: const EdgeInsets.all(16),
         child: Column(crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Parcel ID: ${widget.parcelId}',
                    style: const TextStyle(fontFamily: 'monospace')),
               const SizedBox(height: 16),
               TextField(controller: _reasonCtrl, maxLines: 5, maxLength: 500,
                   decoration: const InputDecoration(
                       labelText: 'Lý do (≥10 ký tự)',
                       hintText: 'VD: Thực tế zone đây là dân cư, không phải cây xanh',
                       border: OutlineInputBorder())),
               const SizedBox(height: 16),
               Row(children: [
                 OutlinedButton.icon(
                     icon: const Icon(Icons.camera_alt),
                     label: Text(_imageUrl == null
                         ? 'Đính kèm ảnh (tuỳ chọn)' : 'Đã đính kèm'),
                     onPressed: _pickImage),
                 if (_imageUrl != null)
                   IconButton(icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _imageUrl = null)),
               ]),
               const Spacer(),
               SizedBox(width: double.infinity,
                   child: FilledButton(
                       onPressed: _submitting ? null : _submit,
                       child: _submitting
                           ? const SizedBox(height: 18, width: 18,
                               child: CircularProgressIndicator(strokeWidth: 2))
                           : const Text('Gửi báo cáo'))),
             ])),
     );
   }
   ```

6. **Wire trigger từ `parcel_detail_sheet.dart`** (P05):
   ```dart
   TextButton.icon(
     icon: const Icon(Icons.flag_outlined, size: 16),
     label: const Text('Báo cáo dữ liệu sai'),
     onPressed: () => Navigator.push(context, MaterialPageRoute(
         builder: (_) => ReportErrorScreen(parcelId: parcel.parcelId))),
   ),
   ```

7. **Wire trigger từ warning modal `planning_warning_modal.dart`** (P06):
   - Add link "Báo cáo nếu thông tin sai" ở footer modal.

8. **i18n keys** thêm:
   ```json
   {
     "adminRiskyListingsTitle": "Listing rủi ro quy hoạch",
     "adminRiskyEmpty": "Không có listing rủi ro",
     "reportErrorTitle": "Báo cáo dữ liệu sai",
     "reportErrorReasonLabel": "Lý do (≥10 ký tự)",
     "reportErrorAttachImage": "Đính kèm ảnh (tuỳ chọn)",
     "reportErrorSubmit": "Gửi báo cáo"
   }
   ```

9. **Smoke tests:**
   - Login admin → mở admin home → tile "Listing rủi ro" → list show.
   - Login non-admin → menu admin KHÔNG hiển thị (existing behaviour).
   - Mở planning map → tap parcel → sheet → button "Báo cáo" → fill form → submit → toast success.
   - Verify backend: `SELECT * FROM planning.reports ORDER BY id DESC LIMIT 1` show row mới.

## Todo List
- [ ] Model `RiskyHouse`
- [ ] Service methods `getRiskyHouses`, `reportError`
- [ ] Tile vào `admin_home_screen.dart`
- [ ] `RiskyListingsScreen` với pull-to-refresh
- [ ] `ReportErrorScreen` (form + image picker)
- [ ] Wire button từ `parcel_detail_sheet.dart` (P05)
- [ ] Wire link từ `planning_warning_modal.dart` (P06)
- [ ] i18n keys VI + EN
- [ ] Smoke test admin role
- [ ] Smoke test non-admin → 403 (verify backend rejects)
- [ ] Smoke test report form → DB insert

## Success Criteria
- AC-19: non-admin gọi `/api/planning/admin/risky-listings` → 403 (verify với curl).
- Admin login → screen show ≥ 1 row (cần seed 1 house ở zone risky để test).
- Form report: reason < 10 ký tự → error; ≥ 10 ký tự → submit OK + DB row.
- Image upload optional, upload thành công → URL lưu vào field.
- Link "Báo cáo" hiện ở 2 vị trí (sheet detail + warning modal).

## Risk Assessment
| Risk | Mức | Mitigation |
|------|-----|-----------|
| Image upload chậm → user frustrated | Trung | `maxWidth: 1280` resize trước upload; show progress |
| Spam report (abuse) | Trung | Rate limit 10/h ở P03 đã có; admin có thể mark `status='spam'` thủ công |
| Admin endpoint return empty (chưa có house risky) | Thấp | Seed 1 house gần zone risky để smoke test; empty state UI rõ ràng |
| Image URL leak qua public upload endpoint | Trung | Existing `/api/upload` đã có auth; verify URL format |
| User report mà không login → 401 | Thấp | Backend `require_user` đã enforce; FE check token trước khi mở form |
| Risky zone codes đổi backend nhưng FE không sync | Trung | Trùng risk với P06 — document shared constant |

## Security Considerations
- ✅ AC-19: admin role check enforce ở backend P03 (`require_admin`).
- ✅ Report: `require_user` enforce ở backend.
- [ ] Image upload: max size 5MB (configure `image_picker` + backend reject lớn hơn).
- [ ] Reason field: sanitize trước insert (XSS nếu sau này hiển thị raw cho admin) — Pydantic max_length=500 đã có.
- [ ] Admin screen: KHÔNG hiển thị PII khác (host name, phone) — chỉ house title + zone info.
- [ ] Privacy: report log retention 90 ngày (cao hơn 30 ngày GPS log vì cần investigate).

## Next Steps
- ✅ Phase 08 (tests + docs) start sau khi P07 stable.
- ⚠️ Future: build admin moderate workflow (mark report resolved/spam) — defer Phase 2.
