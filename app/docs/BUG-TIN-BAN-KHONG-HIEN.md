# Điều tra: đăng tin BÁN nhà xong không hiển thị

> Ngày 26/07/2026 · Trạng thái: **đã tìm ra nguyên nhân, xác nhận bằng dữ liệu production + gọi API thật**

## TL;DR

Tin bán **không mất** — nó bị đẩy vào **hàng chờ admin duyệt** vì có một "chốt an toàn": tin bán giá **≥ 2 tỷ** thì không tự lên. Nhà bán ở VN gần như luôn ≥ 2 tỷ ⇒ **hầu hết mọi tin bán đều bị chặn**. Tệ hơn, app vẫn báo *"Đã đăng tin thành công!"* nên người dùng tưởng hỏng.

---

## 1. Bằng chứng

### a) Dữ liệu thật trong DB
```
  tx  |     status     | n  |    giá min    |    giá max
------+----------------+----+---------------+----------------
 rent | published      | 17 | 2,000,000     | 25,000,000,000
 sale | pending_review |  1 | 2,000,000,000 | 2,000,000,000   ← TIN BỊ KẸT
 sale | published      |  1 | 25,000,000    | 25,000,000      ← 25 triệu (dưới ngưỡng) nên lên được
```

### b) Gọi API thật
```
GET /api/admin/houses?status=pending_review  → admin thấy 1 tin: id=30 "bán nhà" 2.000.000.000
GET /api/houses?transaction_type=sale        → khách thấy 1 tin: id=23 "bán nhà" 25.000.000
```
⇒ Tin id=30 **có trong DB**, **admin thấy**, nhưng **feed công khai không có**. Cơ chế duyệt hoạt động đúng — vấn đề là **ngưỡng giá quá thấp** và **không nói cho người dùng biết**.

---

## 2. Nguyên nhân gốc

### 🔴 Nguyên nhân #1 — Ngưỡng chặn quá thấp
`ancu365-backend/app/routers/houses.py:23`
```python
SALE_REVIEW_THRESHOLD = 2_000_000_000  # 2 tỷ VND
```
`houses.py:331`
```python
if tx_type == "sale" and price_val >= SALE_REVIEW_THRESHOLD and not _is_admin_poster:
    post_status = HouseStatus.PENDING_REVIEW      # ⇒ KHÔNG hiển thị công khai
```
Giá nhà bán trung bình tại VN: **2–10 tỷ**. Ngưỡng 2 tỷ + toán tử `>=` ⇒ **~100% tin bán thật đều rơi vào hàng chờ**. Chốt an toàn này (chống tin giá ảo/lừa đảo) đúng về ý định nhưng **sai về con số**.

### 🔴 Nguyên nhân #2 — App báo "thành công" dù tin chưa lên
`ancu365-app/lib/features/host/post/post_house_screen.dart:426`
```dart
ok ? l.postHousePostSuccess : l.postHousePostFailed   // "Đã đăng tin thành công!"
```
Không hề đọc `status` trả về từ server. Người dùng nhận thông báo xanh "thành công", quay ra feed → **không thấy gì** → kết luận "app lỗi". Đây là lý do bạn báo bug.

### 🟠 Nguyên nhân #3 — Badge trạng thái ở "Tin đã đăng" dùng mã CŨ
`ancu365-app/lib/features/host/profile/my_listings_screen.dart:253`
```dart
switch (status) {
  case 'approved': …   // backend giờ trả 'published'
  case 'pending':  …   // backend giờ trả 'pending_review'
  case 'rejected': …
  default: label = status;   // ⇒ in thẳng chuỗi thô
}
```
Backend đã đổi sang `published` / `pending_review` (xem `app/house_status.py`) nhưng FE chưa cập nhật ⇒ chủ nhà thấy badge xám ghi **"pending_review"** / **"published"** (chữ Anh, thô), thay vì "Chờ duyệt" (cam) / "Đang đăng" (xanh). Mất luôn manh mối duy nhất để tự hiểu chuyện gì đang xảy ra.

---

## 3. Phương án xử lý

### Bước 0 — Mở khoá ngay tin đang kẹt (1 phút)
Duyệt tin id=30 để nó lên feed ngay:
```bash
curl -X POST http://127.0.0.1:3010/api/admin/houses/30/moderate \
  -H "Authorization: Bearer <admin_token>" \
  -H 'Content-Type: application/json' -d '{"action":"approve"}'
```
Hoặc vào **Admin → Chờ duyệt → Duyệt**. *(Cần bạn xác nhận vì đây là hành động công khai nội dung.)*

### Bước 1 — Sửa ngưỡng (quyết định nghiệp vụ, cần bạn chọn)

| Phương án | Nội dung | Ưu | Nhược |
|---|---|---|---|
| **A. Bỏ tiền kiểm, chuyển hậu kiểm** ⭐ *khuyến nghị* | Tin bán **lên ngay**; admin có quyền ẩn/xoá sau; giữ nút "Báo cáo tin sai" | Không chặn nguồn cung — app đang có **19 tin**, chặn tin là tự sát | Tin xấu có thể lên vài giờ trước khi bị ẩn |
| **B. Nâng ngưỡng** | `2 tỷ → 50 tỷ` (chỉ chặn tin dị thường) | Giữ chốt chống giá ảo, 1 dòng code | Vẫn chặn biệt thự/đất lớn hợp lệ |
| **C. Giữ nguyên, chỉ sửa UX** | Chỉ làm Bước 2+3 | An toàn nhất về nội dung | Mọi tin bán vẫn phải chờ người duyệt → chậm, cần admin trực |

**Khuyến nghị: A + phần chống lạm dụng của B** — cho lên ngay, chỉ tiền kiểm khi giá **> 50 tỷ** *hoặc* tài khoản mới < 24h *hoặc* đã có tin bị từ chối. Lý do: theo đo lường 19/07 app **chưa có người dùng từ Internet**; ưu tiên số 1 là **có tin đăng**, không phải kiểm duyệt.

```python
# houses.py — bản đề xuất
SALE_REVIEW_THRESHOLD = 50_000_000_000  # 50 tỷ: chỉ chặn tin dị thường
```

### Bước 2 — Nói thật với người dùng (bắt buộc, làm dù chọn phương án nào)
`post_house_screen.dart` — đọc `status` từ response:
- `published` → "Đã đăng tin thành công! Tin đã hiển thị công khai."
- `pending_review` → **dialog** (không phải snackbar): *"Tin đã gửi — đang chờ duyệt. Tin bán giá trị lớn cần quản trị viên xác minh (thường trong 24h). Bạn theo dõi trạng thái tại Cá nhân → Tin đã đăng."*

### Bước 3 — Sửa badge trạng thái (bug #3)
`my_listings_screen.dart:253` — thêm mã mới, giữ mã cũ để tương thích:
```dart
case 'published':
case 'approved':        → "Đang đăng"  (xanh)
case 'pending_review':
case 'pending':         → "Chờ duyệt"  (cam)
case 'rejected':        → "Bị từ chối" (đỏ)
case 'hidden':          → "Đã ẩn"      (xám)
```
Nên gom thành **1 hàm dùng chung** (`core/` hoặc extension trên `House`) vì `admin_home_screen`, `host_home_tin_dang_tab`, `my_listings` đang mỗi nơi tự map một kiểu.

### Bước 4 — Chống tái diễn
- **Test hồi quy**: tin bán dưới ngưỡng → `published`; trên ngưỡng → `pending_review`; đảm bảo có test cho **cả 2 nhánh** (hiện chỉ có nhánh trên ngưỡng).
- **Thông báo cho admin** khi có tin vào hàng chờ (hiện tin nằm im, không ai biết).
- Cân nhắc **badge "Chờ duyệt"** ngay trên feed của chính chủ (chỉ chủ thấy) để không bao giờ có cảm giác "tin bốc hơi".

---

## 4. Ước lượng

| Việc | File | Thời gian | Rủi ro |
|---|---|---|---|
| B0 duyệt tin kẹt | (API/UI admin) | 1 phút | — |
| B1 sửa ngưỡng | `houses.py:23` | 5 phút + rebuild BE | Thấp |
| B2 thông báo theo status | `post_house_screen.dart` + 3 khoá i18n | 30 phút | Thấp |
| B3 badge dùng chung | `my_listings` + 2 màn khác | 45 phút | Thấp |
| B4 test + thông báo admin | `tests/` + notification | 1–2 giờ | Trung bình |

**Deploy:** B1 cần rebuild image backend + chạy lại container (thủ công, `--env-file`); B2/B3 chỉ cần `flutter build web` (bind-mount ⇒ build xong là live).
