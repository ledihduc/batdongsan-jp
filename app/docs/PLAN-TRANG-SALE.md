# Kế hoạch — Trang cá nhân cho SALE (landing page)

> Chốt 05/09/2026. Trạng thái: **chưa triển khai**.

## Vì sao làm

Sale (môi giới) cần một chỗ **trưng bày** để gửi cho khách: mở ra là thấy người
này là ai, đang có nhà gì, khách cũ nói gì. Hiện app có sẵn màn hồ sơ công khai
tương đối đầy đủ nhưng **không chia sẻ được** — nó không có URL, và nút "Chia sẻ"
đang copy một link đã chết.

### Quyết định nền
- **KHÔNG thêm vai `broker`.** Người dùng thường CHÍNH LÀ sale — ai cũng đăng tin
  được như bình thường. Bỏ được cả migration role, whitelist và guard.
- **Trang tự có khi đăng tin đầu tiên.** Không bắt bật thủ công; không có tin thì
  trang rỗng, chẳng ai chia sẻ làm gì.
- **SĐT mặc định TẮT, sale tự bật.** Số của chính họ, họ chủ động khoe — khác hẳn
  việc lộ số người khác. Bất biến "SĐT masked" giữ nguyên ở mọi nơi khác.

## Đã có sẵn (đừng dựng lại)

| Thành phần | Đường dẫn |
|---|---|
| Màn hồ sơ công khai | `lib/features/guest/broker/broker_profile_screen.dart` |
| Bản đồ điểm chốt | `lib/features/guest/broker/broker_deal_map.dart` |
| API hồ sơ + đánh giá | `GET /api/hosts/{id}`, `/api/hosts/{id}/reviews` |
| 4 thẻ số liệu THẬT | `app/routers/hosts_public.py:123` (`_host_public`) |

---

## P1 — Đường dẫn chia sẻ được (bắt buộc)

**Lỗi phải sửa trước:** `broker_profile_screen.dart:152` copy
`Env.brokerPublicUrl` → `https://ancu.digi-lab.vn/moi-gioi/...`. Domain đó đã gỡ
ngày 03/09 → sale gửi link, khách nhận trang lỗi.

1. Thêm `GoRoute` **`/sale/:id`** trong `lib/core/router/app_router.dart`
   (deferred như các route nặng khác). Chấp nhận cả `/sale/12-nguyen-van-a` —
   phần slug chỉ để link đọc được, khi phân giải thì chỉ lấy số đầu.
2. `Env.brokerPublicUrl` trỏ về `$apiBaseUrl/sale/{id}-{slug}`.
   **Đánh đổi có ý thức:** link mở được nhưng KHÔNG có thẻ preview khi dán vào
   Zalo/Facebook, và Google không index — vì site SSR đã bị gỡ. Muốn hai thứ đó
   phải dựng lại một trang SSR, việc riêng.
3. Nút chia sẻ dùng `share_plus` (mở khay chia sẻ hệ thống) thay vì chỉ copy
   clipboard, + nút **QR code** để sale cho khách quét tại chỗ.

## P2 — Phần sale tự soạn

Trang hiện chỉ có số liệu hệ thống tính. Landing page cần chỗ sale tự nói về
mình. **Một migration additive** thêm vào `host_profiles`:

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `tagline` | String(120) | một câu định vị: *"Chuyên căn hộ Q7, 6 năm bám địa bàn"* |
| `areas` | JSON | khu vực hoạt động (nhiều chip) |
| `specialties` | JSON | chung cư / đất nền / nhà phố / cho thuê |
| `year_started` | Integer | năm vào nghề — **TỰ KHAI** |
| `zalo` / `facebook` | String(200) | kênh liên hệ |
| `show_phone` | Boolean=false | công tắc P3 |

**`year_started` phải hiển thị khác `years_active`.** Backend đã tính
`years_active` = số năm tham gia nền tảng (`hosts_public.py:112`) và docstring
ghi rõ nó KHÔNG phải năm kinh nghiệm nghề. Trộn hai cái là biến một con số kiểm
chứng được thành con số tự khai.

Kèm: màn **"Sửa trang cá nhân"** + nút **Xem thử** (thấy đúng như khách thấy).

## P3 — Nút liên hệ

`_host_public()` cố ý không trả email/SĐT. Nay trả thêm `phone` **chỉ khi**
`show_phone = true`, kèm `zalo`. Trang hiện hai nút chính: **Gọi** và **Zalo**;
`show_phone=false` thì chỉ còn **Nhắn tin** (chat trong app).

## P4 — Lối vào

- Tab Cá nhân: thêm "Trang cá nhân của tôi" (chỉ hiện khi đã có ≥1 tin đăng).
- Thẻ tin đăng: chạm tên người bán → mở `/sale/:id`.

---

## KHÔNG làm trong đợt này

- **Hoa hồng.** Cần bảng `deal` + cách chứng minh giao dịch đã chốt — vấn đề
  nghiệp vụ, không phải kỹ thuật. Dự án riêng.
- **Thẻ "giao dịch thành công" / "khách đã tư vấn"** trong bản thiết kế gốc. Hệ
  thống không đo được hai chỉ số đó; docstring hiện tại đã ghi rõ lý do không
  dựng thẻ bịa số — giữ nguyên nguyên tắc.
- **Vai `broker` và trang SSR.** Xem phần quyết định nền.

## Verify

```
flutter analyze && flutter test          # mốc 978 pass
flutter build web --release && python3 tools/nen_gz.py
```

Kiểm tay trên `https://ancu365.ddns.net`:
1. Mở thẳng `/sale/190` ở **cửa sổ ẩn danh** → trang hiện đủ, không đòi đăng nhập.
2. Bấm Chia sẻ → link copy ra phải mở được (không còn `ancu.digi-lab.vn`).
3. `show_phone=false` → API **không** trả `phone`; bật lên mới có. Kiểm bằng
   `curl` chứ đừng chỉ nhìn giao diện.
4. Tài khoản chưa có tin nào → không thấy lối vào "Trang cá nhân của tôi".
