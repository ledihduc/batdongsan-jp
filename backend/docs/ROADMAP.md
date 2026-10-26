# ancu365 — Roadmap "App BĐS tốt nhất VN"

> Tổng hợp từ buổi lập kế hoạch 4 chuyên gia (BĐS domain, BA, UI/UX, Tech Lead) — 2026-07.
> Nguồn chi tiết kỹ thuật: [PHASE1-BUILD-SPECS.md](PHASE1-BUILD-SPECS.md).

## Định vị chiến lược
App đã có thứ không đối thủ rao vặt nào có: **quản lý cho thuê end-to-end + khai báo tạm trú + TT200 + bản đồ quy hoạch PostGIS**. Con đường "tốt nhất VN" = **ghép lớp GIAO DỊCH (thanh toán/đặt cọc) vào lớp VẬN HÀNH sẵn có** → từ "rao vặt" thành **"sàn giao dịch + vận hành trọn gói"**.

## Nút thắt nền tảng (cả 4 chuyên gia xếp #1)
**Thanh toán & đặt cọc online (VNPay/MoMo/ZaloPay + VietQR).** Hầu hết doanh thu & tính năng khác phụ thuộc nó.

---

## Lộ trình

### PHASE 1 — Mở khoá giao dịch & giữ chân
| Tính năng | Effort | Phụ thuộc | Trạng thái |
|---|---|---|---|
| Bật Geo-search (đã build, đang TẮT) | S | backfill toạ độ | ⏳ chờ deploy + backfill (runbook có) |
| Hoàn thiện Notification thật (eSMS/SES + FCM push) | M | — | ⏳ spec xong, cần credential vendor |
| **Payment core + Đặt cọc online** | L | — | ⏳ spec xong, cần credential + review bảo mật |
| Saved-search + Cảnh báo giá | M | Notification | ⏳ spec xong |
| **Loan calculator** | S | — | ✅ **BUILT (flag, chưa deploy)** |
| **So sánh BĐS (compare)** | S | — | ✅ **BUILT (flag, chưa deploy)** |

### PHASE 2 — Chiều sâu Mua & Homestay
Homestay→OTA (thanh toán + lịch giá động + huỷ/hoàn + tạm trú NA17) · AVM/định giá + bản đồ giá/m² · Thuế/phí sang tên · Trường pháp lý chuẩn + chống tin ảo · Ẩn SĐT + Zalo call-tracking.

### PHASE 3 — Mở rộng
Tìm kiếm nâng cao (Meilisearch) · Marketplace môi giới + hoa hồng · 360/Video tour · Chữ ký số thật (FastCA/VinaCA) + eKYC · Đánh giá 2 chiều · Channel manager iCal · Phòng theo giờ.

## Thứ tự build (nền tảng kỹ thuật trước)
1. Geo-search → 2. Notification+FCM → 3. Payment core → 4. Search infra (Meilisearch) → 5. Saved-search+alert → 6. Homestay OTA → 7. Broker+hoa hồng → 8. (xen kẽ) Loan/Compare/AVM/360.

## Nguyên tắc triển khai an toàn
- Migration **additive-only** (ADD bảng/cột nullable) — canary rollback không đụng DB.
- **Feature flag env + fallback 2 code-path** cho mọi tính năng (như `geo_search_enabled`).
- **Provider qua env, mặc định stub** — bật khi ký hợp đồng vendor.
- Dark-launch Flutter (`--dart-define` OFF) + canary + self-heal.

## Quyết định cần chủ dự án chốt
1. **Thanh toán**: trả thẳng chủ nhà (an toàn pháp lý) vs escrow/giữ hộ (cần giấy phép NHNN)?
2. **Doanh thu**: phí giao dịch % vs gói đẩy tin/VIP vs cả hai?
3. **eKYC/chữ ký số**: đầu tư sớm vs tạm "ảnh + OTP"?
4. **Cổng thanh toán**: tích hợp trực tiếp từng cổng vs aggregator (Payoo/OnePay/9Pay)?

## Đối thủ — họ có, mình thiếu
- Batdongsan: lưu tìm kiếm+cảnh báo, wiki giá/lịch sử giá, gói VIP, định giá.
- Chợ Tốt Nhà: ẩn số+call-tracking, lọc pháp lý/hướng chi tiết.
- Rever/Homedy: môi giới chuyên nghiệp, định giá, 360/VR, hỗ trợ vay.
- Airbnb/Luxstay/Go2Joy: đặt-trả-tiền-ngay, lịch giá động, channel manager, phòng theo giờ.
