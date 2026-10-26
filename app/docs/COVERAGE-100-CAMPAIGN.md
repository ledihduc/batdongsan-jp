# Chiến dịch đưa độ phủ frontend lên 100%

> Bắt đầu 19/07/2026. Mục tiêu bạn đặt: **100% toàn bộ frontend**.
> Đây là việc kéo dài nhiều phiên — tài liệu này để không mất mạch giữa chừng.

---

## 1. QUY MÔ THẬT — đo được, không ước lượng

```
Hiện tại : 19.0%  (4.451 / 23.437 dòng)
Còn thiếu: 18.986 dòng trên 406 tệp Dart
```

Để so sánh: 68 widget test viết trong đợt vừa rồi phủ thêm **~500 dòng** và mất
khoảng nửa ngày. Với nhịp đó, 18.986 dòng là **hàng chục ngày công**.

**Tôi nói thẳng con số này ngay từ đầu** để bạn quyết có muốn đi hết hay dừng ở
một mốc hợp lý. Tôi sẽ làm theo hướng bạn chọn, nhưng không giả vờ rằng đây là
việc vài buổi.

### Nhịp độ ĐO ĐƯỢC (không phải ước lượng)

Hai mẫu thật trong phiên 19/07:

| Mẫu | Test | Dòng phủ thêm | Tỉ lệ |
|---|---|---|---|
| 68 widget test reel | 68 | ~500 | 7,4 dòng/test |
| 19 test `invoice_model` | 19 | 125 | 6,6 dòng/test |
| **Trung bình** | | | **7,2 dòng/test** |

```
Còn thiếu : 18.867 dòng
→ cần thêm khoảng 2.626 test
→ khoảng 30 phiên làm việc tương đương phiên này (87 test/phiên)
```

**Đây là con số tôi tin được**, vì nó suy ra từ hai lần đo thật chứ không phải
cảm tính. Và nó có thể còn LẠC QUAN: phần dễ (model, service) làm trước, phần
màn hình phía sau tốn công hơn nhiều cho mỗi dòng.

### Mốc trung gian đáng cân nhắc

| Mốc | Ước lượng test cần thêm | Giá trị |
|---|---|---|
| **40%** | ~700 | Phủ hết model + service + widget dùng chung |
| **60%** | ~1.400 | Thêm provider + màn chính. Bắt được đa số hồi quy thật |
| **80%** | ~2.000 | Chuẩn của phần lớn dự án nghiêm túc |
| **100%** | ~2.626 | Mọi dòng. 20% cuối tốn công bằng 80% đầu |

**Khuyến nghị của tôi:** nhắm **60–80%** rồi đánh giá lại. Không phải vì 100%
bất khả thi — backend đã 100% — mà vì ở frontend, 20% cuối phần lớn là màn hình
hiếm dùng và nhánh UI phòng thủ, trong khi cùng công sức đó đổ vào tính năng
cho người dùng thật sẽ đáng hơn. **Nhưng bạn quyết, tôi làm theo.**

## 2. NGUYÊN TẮC — rút từ lần suýt sai trước

Khi tôi từng viện cớ "nhánh phòng thủ không đáng phủ", bạn bác bỏ và **bạn
đúng**: mọi nhánh timeout/OSError đều phủ được bằng monkeypatch, và mỗi test
bảo vệ một hành vi thật. Backend giờ 100.00%.

Vậy nên trong chiến dịch này:

1. **Không loại trừ để làm đẹp số.** Chỉ loại trừ thứ không-phải-logic
   (`main()` entry, generated code), và **liệt kê từng dòng** trong báo cáo.
2. **Test phải nêu được nó bảo vệ điều gì.** Test chỉ để tăng số đếm là nợ mới,
   không phải trả nợ.
3. **Đo bằng công cụ, không tự tính.** `lcov --list` + `--summary`.
4. **Không hồi quy.** Mỗi đợt chạy full suite + build web trước khi commit.

---

## 3. THỨ TỰ THỰC HIỆN — dễ và giá trị cao trước

### ✅ Đợt 0 — mở khoá (ĐANG LÀM)
`ApiClient` nhận `http.Client` tuỳ chọn. **Đây là nút thắt lớn nhất**: không có
nó thì toàn bộ tầng service (~40 tệp) không test được, và mọi màn hình gọi API
cũng vậy.

- `const ApiClient({http.Client? client})` — mặc định `null` → tự tạo rồi đóng
  client mỗi lời gọi, **đúng hành vi cũ của `http.get/post/...`**
- `ReelApi({ApiClient? client})` tương tự
- Kiểm chứng bắt buộc: 0 lỗi analyze · full test pass · build web thành công

### Đợt 1 — model & tiện ích thuần (dễ nhất, ~2.000 dòng)
`lib/data/models/**`, `lib/core/utils/**`. Không cần widget, không cần mạng.
Chủ yếu kiểm `fromMap` chịu được payload thiếu/null — **đúng loại lỗi đã gây ra
sự cố đăng nhập trước đây** (`null is not a subtype of int`).

### Đợt 2 — tầng service (~3.000 dòng)
Nhờ Đợt 0 mà làm được. Mẫu có sẵn: `test/data/services/reel_api_test.dart`
dùng `MockClient` — kiểm URL, tham số, ánh xạ, và mã lỗi.

### Đợt 3 — widget dùng chung (~2.500 dòng)
`lib/core/widgets/**` (ds_*). Nhiều tệp đang 0% mà lại được dùng khắp nơi, nên
mỗi test ở đây bảo vệ rất nhiều màn.

### Đợt 4 — provider (~2.000 dòng)
`lib/providers/**`. Kiểm chuyển trạng thái, không cần dựng UI.

### Đợt 5 — màn hình (~9.000 dòng, nặng nhất)
Chia theo vai trò: khách → host → admin → tenant. Cần giả lập kênh nền tảng cho
`image_picker`, `geolocator`, `permission_handler`, `flutter_map`.

---

## 4. HẠ TẦNG TEST ĐÃ CÓ

| Tệp | Dùng để |
|---|---|
| `test/helpers/pump_app.dart` | Bọc provider gốc (Telemetry, Auth) + `SignedInAuthProvider` |
| `test/features/reels/_fake_reel_api.dart` | Mẫu API giả: ghi nhật ký lời gọi, mô phỏng lỗi theo tên phương thức |
| `test/features/reels/_fake_video_player.dart` | Nền tảng `video_player` giả |
| `test/data/services/reel_api_test.dart` | **Mẫu test tầng service** bằng `MockClient` |

### Bẫy đã mắc — đừng mắc lại

- **Giả lập nền tảng**: phát sự kiện `initialized` trong `onListen`, KHÔNG dùng
  `Future.microtask` — broadcast stream vứt sự kiện phát lúc chưa có người
  nghe → `initialize()` treo vĩnh viễn.
- **`pumpAndSettle` treo** ở màn có animation/tick liên tục (trình xem reel).
  Dùng `pump(Duration(...))` nhiều nhịp.
- **`GuestGate`** đọc `AuthProvider` ở mọi hành động cá nhân → thiếu provider
  là `ProviderNotFoundException` ngay khi chạm nút đầu tiên.
- **`flutter pub get` và `flutter test` phải cùng một `docker run`** — pub cache
  nằm trong container.

---

## 5. NHẬT KÝ TIẾN ĐỘ

| Ngày | Việc | Độ phủ toàn app |
|---|---|---|
| 18/07 | Trước chiến dịch | 16.6% |
| 19/07 | 68 widget test reel | 19.0% |
| 19/07 | Đợt 0: mở khoá `ApiClient` + 25 test `reel_api` | 19.0% → 19.2% |
| 19/07 | Đợt 1 (bắt đầu): 19 test `invoice_model` | **19.5%** |
