# KẾ HOẠCH — Trang "Đã đặt" v2: kiểm soát trạng thái, lịch sử, sửa đổi (16/09/2026)

## Vì sao làm lại

Trang "Đã đặt" hiện là 4 tab danh sách tĩnh: Phòng đã đặt · Lịch đã hẹn · Đang thuê · Lịch sử.
Đo trên code và dữ liệu staging:

| Vấn đề | Hậu quả |
|---|---|
| Đơn phòng và lịch hẹn nằm 2 tab riêng, mỗi tab xếp một kiểu | Khách không thấy "hôm nay mình phải đi đâu, mấy giờ" |
| Không có chỗ nói **việc cần làm** (bên bán bận chờ chọn giờ, sắp tới giờ nhận phòng) | Lịch `doi_gio` nằm lẫn trong danh sách, dễ trễ |
| **Không có lịch sử thay đổi**: đơn phòng có ghi `change_logs` nhưng không ai đọc; lịch hẹn xem **không ghi gì** | Cãi nhau "tôi đã đổi giờ / sale đã xác nhận chưa" không có bằng chứng |
| Khách **không sửa được gì** sau khi đặt: không đổi giờ, không sửa số khách/SĐT | Muốn đổi là phải huỷ rồi đặt lại → mất giờ đã giữ, sale nhận 2 thông báo rối |
| Tab "Lịch sử" chỉ là danh sách đơn đã đóng, không lọc, không nhóm | Không tra lại được |

## Mục tiêu

1. **Trạng thái** — mỗi mục có thanh tiến trình, nhãn nói thật, và *việc tiếp theo*.
2. **Lịch sử** — mỗi đơn/lịch có dòng thời gian: ai (Bạn / Sale X / Chủ nhà / Hệ thống) làm gì, lúc nào, đổi từ gì sang gì.
3. **Sửa đổi** — khách tự đổi giờ, sửa thông tin, huỷ; mọi lần sửa đều vào lịch sử và báo sale + chủ nhà.

## Luồng

```
Tab Đã đặt
├── [Cần bạn xử lý]  ← chỉ hiện khi có: chọn giờ mới · sắp nhận phòng/sắp đi xem (≤24h)
├── Sắp tới (n)      ← đơn phòng + lịch xem + hẹn chốt còn mở, lọc: Tất cả · Đặt phòng · Xem nhà
│     nhóm: Hôm nay · Ngày mai · Tuần này · Sau đó · Chưa có giờ
│     thẻ: khối ngày giờ | loại · tên · phụ đề | trạng thái + tiến trình 4 bước | nút việc chính
├── Đang thuê (n)    ← hợp đồng dài hạn (giữ nguyên + gửi chỉ số điện nước)
└── Lịch sử (n)      ← đã trả phòng / đã xem / đã huỷ / bị từ chối, lọc theo loại + trạng thái, nhóm theo tháng

Chạm thẻ → PHIẾU (đã có) được bổ sung:
├── Tiến trình (stepper)
├── Nút sửa: [Đổi giờ] [Sửa thông tin] [Huỷ]   ← chỉ hiện khi server nói còn sửa được
└── Lịch sử thay đổi (timeline)
```

### Luật sửa đổi

| | Đơn phòng ngắn hạn | Lịch xem nhà |
|---|---|---|
| Đổi giờ | `pending`/`approved`, **còn hạn huỷ miễn phí**. Báo giá lại (bỏ qua chính đơn mình khi xét trùng lịch). Sau khi đổi → `pending` chờ sale xác nhận lại | `pending`/`approved`. Chọn khung còn trống → `pending` chờ duyệt lại |
| Sửa thông tin | tên, SĐT, số khách (≤ sức chứa), ghi chú — khi `pending`/`approved` | tên, SĐT, số người, hình thức, lời nhắn — khi `pending`/`approved`/`doi_gio` |
| Huỷ | còn hạn huỷ miễn phí (đã có) | `pending`/`approved`/`doi_gio` (đã có) |
| Ghi lịch sử + báo sale/chủ nhà | mọi thao tác | mọi thao tác |

## Backend

- **Một nguồn lịch sử**: bảng `change_logs` sẵn có (`entity_type` = `reservation` | `viewing_appointment`). Không thêm bảng.
- `services/lich_su_dat.py` — `ghi()` + `doc()` dịch hành động thành câu tiếng Việt, gắn vai người làm.
- `services/sua_dat_cho.py` — sửa thông tin / đổi giờ cho cả hai loại.
- `services/da_dat_tong_hop.py` — gom mục cho trang Đã đặt, tính tiến trình + việc tiếp theo + "cần xử lý" ở **server** (một chỗ duy nhất quyết định).
- `short_stay_service.quote/busy` nhận `bo_qua` (id đơn của chính mình) để đổi giờ không tự đụng lịch mình.
- Lịch hẹn xem **bắt đầu ghi lịch sử** ở mọi endpoint: đặt, duyệt/từ chối/chốt, bên bán đổi giờ, khách chọn giờ, khách đổi lịch, sửa, huỷ, hẹn chốt.

| Endpoint | |
|---|---|
| `GET /api/guest/da-dat` | tổng hợp: `can_xu_ly`, `sap_toi`, `lich_su`, số đếm |
| `GET /api/guest/reservations/{id}/lich-su` | timeline đơn phòng |
| `PATCH /api/guest/reservations/{id}` | sửa thông tin đơn |
| `POST /api/guest/reservations/{id}/doi-gio/bao-gia` | báo giá giờ mới (bỏ qua chính đơn) |
| `POST /api/guest/reservations/{id}/doi-gio` | xác nhận đổi giờ (kèm mã báo giá) |
| `GET /api/viewing-appointments/{id}/lich-su` | timeline lịch hẹn |
| `PATCH /api/viewing-appointments/{id}/khach` | khách sửa thông tin lịch |
| `POST /api/viewing-appointments/{id}/khach-doi-lich` | khách tự đổi khung giờ |

Người ngoài: 404 (không để dò id) — cùng luật với phiếu.

## App

- `data/services/da_dat_api.dart` — tổng hợp + model mục.
- `features/guest/da_dat/da_dat_screen.dart` — viết lại theo luồng trên.
- `features/guest/da_dat/the_lich_su.dart` — timeline + stepper dùng chung hai phiếu.
- `features/guest/da_dat/sua_thong_tin_sheet.dart` — sheet sửa thông tin dùng chung.
- Đổi giờ đơn phòng: `RoomBookingScreen` chế độ đổi giờ (dùng lại lưới giờ, bỏ qua khoảng của chính đơn).
- Đổi lịch xem: `doi_gio_sheet.dart` chế độ khách tự đổi.

## Kiểm thử

- BE: lịch sử đủ sự kiện + đúng vai; đổi giờ không tự đụng lịch mình, đụng người khác → 409, quá hạn → 409, trạng thái về `pending`, lịch bận cập nhật; sửa số khách vượt sức chứa → 422; người ngoài 404; tổng hợp đúng nhóm + việc cần làm.
- FE: nhóm theo ngày, lọc loại, thẻ cần xử lý, timeline hiện đúng câu, sheet sửa gửi đúng trường, đổi giờ gửi mã báo giá.
- E2E Playwright trên staging: đặt → đổi giờ → sửa số khách → huỷ → xem lịch sử.
