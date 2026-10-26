# Phase 06 — Flutter: "Tìm quanh đây" + Map/List

**Mục tiêu:** flow nearby hoàn chỉnh với permission priming, radius, distance badge, list/map.
**Est.:** 2 ngày · **Phụ thuộc:** Phase 04, 05.

---

## 1. Điểm vào
- Chip **"Quanh đây"** (`Icons.near_me`) đầu hàng FilterChip categories trên home (cạnh "Tất cả").
- Mục "Quanh đây" đỉnh `GuestSearchScreen` khi query rỗng.

## 2. Permission priming (tái dùng pattern hiện có)
Codebase có `PrimingPresenter` + `PrimingOutcome{accept, defer}` cho camera/notification nhưng **chưa có location**. Thêm song song:
1. `enum LocationContext { nearbySearch }` vào `permission_types.dart`.
2. `LocationPrimingSheet` (mô phỏng `CameraPrimingSheet`, tái dùng `_priming_sheet_parts.dart` + `_priming_button_pair.dart`). Copy: *"Bật vị trí để xem phòng gần bạn nhất, kèm khoảng cách chính xác. ancu365 chỉ dùng vị trí khi bạn tìm quanh đây."* Nút **"Bật vị trí"** / **"Để sau"**.
3. `PrimingPresenter.presentLocation(context, LocationContext)` → `PrimingOutcome`. Chỉ khi `accept` mới gọi OS dialog (qua `GeoLocationService`).

Luồng: tap "Quanh đây" → priming → accept → OS request → GPS → nearby.

## 3. Radius selector
`RadiusChips`: **1 · 3 · 5 · 10 km** (default **3km**), luôn hiện dưới header `NearbyResultsScreen`. Đổi bán kính = re-query tức thì (`fetchNearby`), không cần "Áp dụng". Nếu <5 kết quả → gợi ý (không tự đổi) CTA "Mở rộng lên {next}km".

## 4. Xử lý từ chối / GPS off (E6, E7 — không bao giờ ngõ cụt)
| Tình huống | Xử lý |
|---|---|
| "Để sau" ở priming | Không request OS. Fallback `LocationPicker` + toast "Bạn có thể chọn khu vực thủ công". |
| OS denied (1 lần) | `SoftReAskBanner` (đã có) đầu list: "Bật vị trí để sắp xếp theo khoảng cách". Vẫn cho tìm thủ công. |
| `permanentlyDenied` | Banner + nút "Mở Cài đặt" (`openAppSettings()`). Không lặp OS dialog. |
| GPS/service OFF | Dialog "Bật định vị trên thiết bị" + nút mở location settings. |
| Timeout | Dùng last-known-location; nếu không → fallback picker + retry. |
| Ngoài bbox VN | "Vị trí ngoài phạm vi phục vụ" + fallback picker. |

## 5. `NearbyResultsScreen` — List ⇄ Map
- Toggle **Danh sách / Bản đồ** (SegmentedButton header). **List mặc định** (rẻ, mobile, chứa được tin NULL-coord).
- Map: `flutter_map` (deferred như route `/map` — giữ bundle nhẹ). Marker cluster; tâm = vị trí user (chấm xanh) + vòng tròn bán kính. Tap marker → mini-card peek → tap → `/house/:id`.
- **Tin NULL-coord không hiện trên map** nhưng **vẫn ở list** dưới divider "Các tin khác trong khu vực" (xem Phase 07).

## 6. Distance badge trên card
`DistanceBadge`: `Icons.near_me` + khoảng cách. Format VN: `<1km → "300 m"`, `≥1km → "1,2 km"` (dấu phẩy thập phân). Chỉ hiện ở mode nearby/place, khi có toạ độ.

---

## Widgets tạo mới
`NearbyResultsScreen`, `RadiusChips`, `DistanceBadge`, `NearbyMapView` (flutter_map + cluster + radius circle, deferred), `LocationPrimingSheet` + `LocationContext`.

## Nice-to-have (Phase sau)
Map view + cluster có thể hoãn — list-first đủ giá trị v1. Peek-map dải nhỏ trên list.

---

## Definition of Done
- Tap "Quanh đây" → priming → cấp quyền → thấy nhà trong 3km sắp gần→xa + distance badge.
- Đổi radius 1/3/5/10 → re-query đúng.
- Từ chối quyền → banner + fallback picker (không crash, không treo loading).
- Toggle list/map hoạt động; map chỉ vẽ tin có toạ độ; tap marker → house detail.
