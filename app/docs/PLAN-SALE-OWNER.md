# Sale · Chủ phòng · Khách thuê — kế hoạch triển khai

> Nhận spec 05/09/2026. Tệp này chỉ ghi **ĐỘ LỆCH** giữa spec và code hiện có,
> cùng thứ tự làm. Spec đầy đủ nằm trong yêu cầu gốc.

## 1. Phần lớn Giai đoạn 6 ĐÃ TỒN TẠI

Đừng dựng lại. Bảng đã có và đúng nghiệp vụ:

| Spec gọi là | Trong repo |
|---|---|
| `projects` | **`buildings`** (id, host_id, name, address, city, district, ward, note) |
| `rooms` | **`rooms`** (code, area_m2, capacity, base_price, status, images, note) |
| `tenancies` | **`contracts`** + `contract_tenants` + `contract_service_fees` |
| khách thuê | **`tenants`** (CCCD băm một chiều) |
| `invoices` | **`invoices`** + `invoice_line_items` + `credit_notes` |
| `payments` | **`payments`** |
| điện nước | **`meter_readings`**, **`service_fees`** |
| `posts` | **`social_posts`** |
| nhật ký | **`change_logs`**, **`audit_logs`** |

Đo staging 05/09: 2 toà · 9 phòng · **0** hợp đồng · **0** hoá đơn · **0** chỉ số.
Cụm này xây xong nhưng chưa ai dùng — nên đổi nó rẻ hơn nhiều so với vẻ ngoài.

**KHÔNG đổi tên `buildings` → `projects`.** `rooms`, `contracts`, `invoices`,
`delegations`, `meter_readings` đều trỏ vào nó; đổi tên là rủi ro thuần tuý
không đem lại gì cho người dùng. Chữ hiển thị vẫn là "Dự án".

## 2. Bốn độ lệch thật, phải sửa

### 2.1 Mã liên kết theo SALE, không theo dự án ⚠️ ĐẢO NGƯỢC VIỆC VỪA LÀM
Hôm nay đã ship: mỗi **toà nhà** một `claim_code`, chủ nhà nhập mã thì
`buildings.host_id` chuyển sang họ.

Spec khác hẳn: mỗi **sale** một mã CỐ ĐỊNH (`SL-8K4D2Q`), chủ phòng nhập mã để
**liên kết với sale**, rồi sale mới gán từng phòng cho chủ. Quyền sở hữu không
đi kèm việc nhập mã.

→ `buildings.claim_code` (mig 0083) trở thành thừa. Giữ cột, ngừng dùng, gỡ ở
giai đoạn cuối; màn "Nhận bàn giao bằng mã" đổi thành "Liên kết với sale".

### 2.2 Sở hữu nằm ở PHÒNG, không ở toà
Spec: *"Một dự án có thể chứa phòng của nhiều chủ phòng"* → `rooms.owner_id` +
`rooms.managed_by_sale_id`. Hiện quyền sở hữu suy từ `buildings.host_id`, và
`RoomRepository` cách ly bằng join sang `buildings.host_id`.

→ Đây là thay đổi cách ly dữ liệu **sâu nhất** trong cả spec. Phải làm cẩn thận:
thêm cột, backfill `rooms.owner_id = buildings.host_id`, rồi mới đổi repository.

### 2.3 `account_type` tách khỏi `role`
Hiện `users.role ∈ {guest, host, admin}` và **1.054 tài khoản role=host** —
gộp lẫn chủ nhà thật với người chỉ đăng tin bán.

→ Thêm `users.account_type ∈ {customer, sale, owner, admin}`. **Không đụng
`role`** (JWT, `require_host`, 17 test auth đều bám vào đó). Backfill:
`admin→admin`, còn lại `→customer`; `owner` gán cho ai có `buildings` hoặc
`contracts`; `sale` là **tự chọn** — ai tạo `sale_profile` thì thành sale.
Giả định này cần bạn xác nhận: tôi KHÔNG tự phong 1.054 người thành owner.

### 2.4 Hai trạng thái phòng phải tách
Hiện `rooms.status ∈ {vacant, occupied, maintenance}` — một cột gánh hai việc.
Spec tách `availability_status ∈ {vacant, holding, reserved, occupied}` và
`operational_status ∈ {active, maintenance, disabled}`.

→ Thêm hai cột, backfill từ `status`, giữ `status` đồng bộ một thời gian để
`room_state_service` và các test cũ không vỡ.

## 3. Thứ tự làm (bám spec mục 9)

| G | Việc | Ghi chú |
|---|---|---|
| 1 | `account_type`, `sale_profiles`, lớp kiểm quyền dùng chung | giữ `/sale/:id` sống |
| 2 | `sale_owner_links` + mã sale + nhật ký + ngắt/chuyển | thay 2.1 |
| 3 | `rooms.owner_id` + `managed_by_sale_id`, CRUD, ảnh, trạng thái | thay 2.2, 2.4 |
| 4 | Bài viết gắn dự án/phòng, tab trang sale, ghim/ẩn | dùng `social_posts` |
| 5 | `rental_requests` + CRM khách | bảng MỚI, chưa có |
| 6 | Hợp đồng + hoá đơn | nối vào bảng đã có, **khoá sale** |
| 7 | Thông báo + hoàn thiện | `notifications` đã có |

## 4. Luật xuyên suốt (spec mục 4, cuối)

> *"Backend phải kiểm tra quyền từ dữ liệu liên kết. Không nhận sale_id hoặc
> owner_id từ app rồi tin trực tiếp."*

Cụ thể hoá thành **một** hàm dùng chung, mọi route gọi qua đó — không tự viết
điều kiện lọc ở từng router (chỗ nào quên là chỗ đó rò):
- `quyen_phong(actor, room_id)` → `{doc, sua_noi_dung, sua_trang_thai, tai_chinh}`
- Sale: đúng khi `rooms.managed_by_sale_id == actor` **và** link còn `active`.
- Chủ phòng: đúng khi `rooms.owner_id == actor`.
- `tai_chinh` **luôn False** với sale, không có ngoại lệ.

## 5. Bẫy đã biết
- **`AC-51`**: payout bám `effective_owner_id`. Đổi chủ phòng sau khi đã có hoá
  đơn là đẩy tiền sang tài khoản khác → chỉ cho chuyển giao khi không còn hợp
  đồng/hoá đơn hoạt động (spec mục 2 cũng yêu cầu đúng điều này).
- **Giá phải chụp tại thời điểm chốt** (`contracts` đã có `base_price` riêng) —
  sale sửa giá đăng không được làm đổi hợp đồng đang chạy.
- **Tiền lưu số nguyên đồng.** `rooms.base_price` hiện là `Float`. Hoá đơn thì
  đã đúng kiểu; phần giá đăng cần chuyển sang số nguyên ở G3.
- Cụm uỷ quyền cũ (`delegations`) **không** dùng cho quan hệ sale–chủ phòng:
  nó là "chủ nhà uỷ quyền cho người vận hành", ngược chiều với spec này.
