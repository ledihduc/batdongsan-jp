# Review UI/UX — màn "Cá nhân" (Profile), ancu365 mobile web

> Ngày 26/07/2026 · Phạm vi: 1 màn trong ảnh chụp (tài khoản `interior.pro@housebooking.com` — "Nội Thất Mộc Décor")
> File nguồn: `lib/features/guest/profile/profile_screen.dart`, `lib/features/guest/guest_shell.dart`, token `lib/core/theme/design_tokens.dart`

---

## 0. Mục tiêu màn hình — lỗi gốc

Người dùng vào Profile để **(a)** vào nhanh việc của mình (tin đã đăng, lịch hẹn, yêu cầu dịch vụ) và **(b)** đổi vai/cài đặt.

**Màn hiện tại không có hành động chính nào nổi bật.** Thứ nổi nhất về thị giác lại là *"Chỉnh sửa hồ sơ"* — một việc người dùng làm 1–2 lần trong đời. Việc dùng hằng ngày (danh sách "Của tôi") bị đẩy xuống dưới nếp gấp: **chỉ ~1,5 dòng danh sách hiện ra** trên màn 6.1".

Nguyên nhân: 8 tầng nội dung xếp chồng trước khi tới danh sách — eyebrow → title → cover → avatar → tên → email → 2 nút → segmented → 3 thẻ số → nhãn "Của tôi".

---

## 1. Vấn đề theo mức tác động

### 🔴 P0-1. Segmented "Khách thuê / Chủ nhà" màu ĐEN — lệch hệ màu
**Vị trí:** `profile_screen.dart:457` → `color: selected ? HD.ink : Colors.transparent` (`HD.ink = #050505`).
**Vì sao sai:** toàn app đã chuyển sang hệ xanh Facebook (`HD.accent = #1877F2`). Mảng đen đặc này là **di sản của theme "editorial" đen-trắng cũ**, giờ đứng cạnh avatar xanh + nút xanh trông như widget chưa style / lỗi render. Nó cũng **hút mắt mạnh hơn cả nút hành động chính**, phá thứ bậc.
**Sửa:** đổi nền chọn sang `HD.accent` (chữ trắng), hoặc nhẹ hơn: nền `HD.paperRaised` + chữ `HD.accent` + viền `HD.accent` (kiểu iOS segmented). Bo góc `HD.r8` cho khớp các thành phần khác — hiện đang vuông góc 0px trong khi nút bên trên bo tròn.

### 🔴 P0-2. Sai danh tính vai trò — tài khoản ĐƠN VỊ mà hiện "Thành viên / Khách thuê / Chủ nhà"
**Vị trí:** badge cạnh tên + segmented + danh sách "Của tôi".
**Vì sao sai:** đây là tài khoản **đơn vị nội thất**. Nhưng:
- Badge ghi *"Thành viên"* — không phản ánh vai trò;
- Bộ chuyển vai chỉ có *Khách thuê / Chủ nhà* — không có **Đơn vị**;
- Danh sách thiếu lối vào **"Kênh đơn vị"** (provider hub: hồ sơ năng lực, nhu cầu phù hợp, báo giá của tôi). Đối chiếu code: `profile_screen.dart` **không hề** trỏ tới `ProviderHubScreen` — lối vào duy nhất nằm trong drawer (`drawerContractorChannel`).
**Hệ quả:** đơn vị đăng nhập vào không thấy đường tới nơi kiếm tiền của họ. Đây là lỗi **chức năng**, không chỉ thẩm mỹ.
**Sửa:** badge hiển thị đúng vai (`Đơn vị nội thất`); nếu tài khoản có `contractor profile` → thêm mục **"Kênh đơn vị"** lên ĐẦU danh sách "Của tôi" kèm badge trạng thái duyệt; cân nhắc segmented 3 trạng thái hoặc ẩn segmented với tài khoản đơn vị.

### 🟠 P1-3. Ba lối vào trùng nhau cho "đã lưu / yêu thích"
Nút **"Tin đã lưu"** + thẻ số **"Yêu thích 1"** + tab đáy **"Yêu thích"** → cùng một đích.
**Sửa:** bỏ nút *"Tin đã lưu"* (đã có tab đáy). Ô trống dùng cho nút phụ có giá trị hơn: *"Chia sẻ hồ sơ"* hoặc *"Xem hồ sơ công khai"* — thứ đơn vị thực sự cần.

### 🟠 P1-4. Ba thẻ số: màu vô nghĩa, số 0 gây nản, không bấm được
**Vì sao sai:** xanh–**lục**–xanh: màu lục ở "Đặt lịch" không mang nghĩa gì (không phải trạng thái tốt/xấu) → nhiễu. Hai số 0 to đùng là thông điệp tiêu cực đầu màn. Thẻ trông như nút nhưng (theo ảnh) không có affordance bấm.
**Sửa:**
- Thống nhất 1 tông: nền `HD.accentTint`, số `HD.accent`, nhãn `HD.inkMuted`.
- Khi giá trị = 0 → **không in số 0 đậm**; hiện gạch `–` mờ, hoặc gộp cả cụm thành 1 dòng CTA: *"Chưa có tin đăng — Đăng tin đầu tiên →"*.
- Cho bấm được (mỗi thẻ nhảy tới đúng danh sách), thêm ripple + vùng chạm ≥44px.

### 🟠 P1-5. Mật độ quá thấp — nếp gấp nuốt hết nội dung hữu ích
**Sửa (thứ tự ưu tiên, thu ~180–220px):**
1. **Gộp header trang vào cover**: bỏ khối `TÀI KHOẢN / Cá nhân` (tab đáy đã cho biết đang ở đâu) → tiết kiệm ~96px.
2. **Ẩn email** hoặc rút gọn (`inte•••@housebooking.com`): với đơn vị, email đầy đủ là thông tin nhạy cảm hiển thị vô ích ~40px.
3. Nhãn **"Của tôi"** đang canh giữa, xám nhạt, chiếm ~60px → chuyển canh trái, `HD.eyebrow()`, padding trên 16 dưới 8 (khớp nhãn "Dịch vụ thi công" phía dưới).
4. Giảm khoảng cách cover→tên→nút từ 24 xuống 16.

### 🟡 P2-6. Avatar trong tab đáy — không nhất quán & khó đọc
3 tab kia là icon nét, tab "Cá nhân" là **ảnh avatar** trong pill. Ở 24px, ảnh nhân vật thành đốm màu, lại **trùng lặp** avatar đã to ở đầu màn.
**Sửa:** dùng icon `person` nét/đặc như 3 tab còn lại (giữ pill nền `HD.accentSoft` khi active). Nếu muốn giữ avatar → bỏ viền xanh, thêm mask tròn 20px và fallback chữ cái.

### 🟡 P2-7. Cover xanh trơn, chưa dùng được
Dải xanh phẳng chỉ để làm nền cho avatar. Với **đơn vị**, đây là chỗ đắt giá nhất để tạo uy tín.
**Sửa:** cho phép tải **ảnh bìa** (đã có `editProfChangeCover` trong i18n!) — hiện màn này chưa lộ nút đó; khi chưa có ảnh thì dùng gradient `accent → accentDeep` thay vì màu phẳng.

### 🟡 P2-8. Thiếu safe-area đáy trên trình duyệt mobile
Thanh tab đáy nằm sát thanh công cụ Safari → 2 thanh dính nhau, dễ bấm nhầm.
**Sửa:** `SafeArea(bottom: true)` + `padding.bottom` cho nav bar; hoặc `viewport-fit=cover` + `env(safe-area-inset-bottom)`.

### ⚪ Ghi chú ngoài UI (nhưng ảnh hưởng niềm tin)
Safari hiện **"Không bảo mật"** → đang mở bằng **HTTP** (IP:port). Domain thật `https://ancu365.vn` đã có SSL — nên test/demo bằng domain HTTPS, tránh khách nhìn thấy cảnh báo.

---

## 2. Bố cục đề xuất (sau khi sửa)

```
┌──────────────────────────────────────┐
│ [cover gradient / ảnh bìa]      ⚙ ⏻ │  ← gộp header vào cover, action nổi lên
│   (avatar)                           │
│ Nội Thất Mộc Décor  ⟨Đơn vị nội thất⟩│  ← badge đúng vai
│                                      │
│ [ Chỉnh sửa hồ sơ ] [ Xem hồ sơ ↗ ]  │  ← bỏ "Tin đã lưu" (trùng tab đáy)
│ ┌ Khách thuê │ Chủ nhà ┐ (xanh, bo)  │  ← bỏ nền đen
│                                      │
│  ▸ Kênh đơn vị            ⟨Chờ duyệt⟩│  ← MỚI: lối vào chính của đơn vị
│  CỦA TÔI                             │  ← canh trái
│  ▸ Tin đã đăng            Quản lý…  →│
│  ▸ Lịch hẹn xem nhà       Các lịch…→ │
│  DỊCH VỤ THI CÔNG                    │
│  ▸ Yêu cầu dịch vụ của tôi          →│
└──────────────────────────────────────┘
   🏢 Bất động sản │ 🔧 Thi công │ ♡ Yêu thích │ 👤 Cá nhân
```
Thẻ số: chuyển xuống **dưới** danh sách hoặc thu thành 1 dòng ngang mảnh — chúng là thông tin tham khảo, không phải hành động.

---

## 3. Thứ tự thi công đề xuất

| Đợt | Việc | Ước lượng | Rủi ro |
|---|---|---|---|
| **1** | P0-1 đổi màu segmented (1 dòng token) | 5 phút | Rất thấp |
| **1** | P1-3 bỏ nút "Tin đã lưu" | 10 phút | Thấp |
| **1** | P1-5 gộp header + ẩn email + nhãn canh trái | 30 phút | Thấp |
| **2** | P0-2 badge đúng vai + mục "Kênh đơn vị" | 1–2 giờ | Trung bình (cần biết tài khoản có hồ sơ đơn vị hay không) |
| **2** | P1-4 thẻ số: 1 tông + trạng thái rỗng + bấm được | 1 giờ | Thấp |
| **3** | P2-6/7/8 icon nav, ảnh bìa, safe-area | 2 giờ | Thấp |

**Nguyên tắc bắt buộc khi sửa màu:** chỉ đổi trong `lib/core/theme/design_tokens.dart` hoặc dùng token có sẵn — **không hard-code màu** trong widget (luật repo).

---

## 4. Tóm tắt 1 câu

Màn đang **đẹp phần trang trí, yếu phần việc**: một mảng đen lạc hệ hút hết sự chú ý, ba lối vào trùng nhau, và tài khoản đơn vị không tìm thấy đường vào kênh của mình — sửa 3 điểm đó trước, phần còn lại chỉ là tinh chỉnh nhịp và mật độ.
