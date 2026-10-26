# Thiết kế: Marketplace Dịch vụ (Thiết kế/Xây dựng/Nội thất) + BĐS Công nghiệp

Ngày chốt: 2026-07-05. Quyết định nghiệp vụ đã chốt với chủ sản phẩm:
1. **Cơ chế lead = Hybrid** — đơn vị tự phục vụ (thấy nhu cầu + gửi báo giá) + operator điều phối/QA.
2. **BĐS công nghiệp = mở rộng tin đăng BĐS** (không phải directory dịch vụ).
3. Triển khai P1 → P3.

## Nguyên tắc chống chồng chéo (2 loại "chợ", chung hạ tầng)
| | Chợ Nhà ở (có sẵn) | Chợ Dịch vụ (mới) | BĐS Công nghiệp |
|---|---|---|---|
| Cung | `HostProfile` → tin `House` | `Contractor` → hồ sơ + portfolio | tin `House` (loại CN) |
| Cầu | tìm tin, đặt lịch xem | đăng `Lead` / duyệt danh bạ | tìm tin, đặt lịch xem |
| Bản chất | listing tài sản | directory năng lực | listing tài sản |
Chung: User, Chat (thêm `context_type/id`), Notification (type mới), Upload, Province master.
Tách: bảng listing, review (nhà=`reviews`, đơn vị=`contractor_reviews`), luồng chốt.

## Vai trò
- User (khách): đăng yêu cầu, duyệt danh bạ, nhận báo giá, đánh giá.
- Provider = `Contractor` gắn `user_id` (1 user có thể vừa khách vừa đơn vị; KHÔNG đè role host).
- Operator (có sẵn): điều phối/QA lead. Admin: duyệt đơn vị + kiểm duyệt.

## Thực thể (nền migration 0044 + bổ sung 0045+)
- `ConstructionService` (danh mục: design/build/interior). Industrial KHÔNG ở đây.
- `Contractor` +: `slug` unique, `cover_images`, `website`, `year_established`, `team_size`,
  `plan`(free/pro), `is_promoted`, máy trạng thái `pending→approved→suspended`.
- `ContractorProject` (portfolio) — giữ.
- `ConstructionLead` +: `province_code/district_code`, `visibility`(public/private), `target_contractor_id`, `expires_at`, `max_quotes`.
- `Quote` (báo giá) — giữ; máy trạng thái `sent→accepted/declined/expired`.
- MỚI `ContractorReview`(contractor_id, user_id, lead_id, rating, comment) — chỉ sau lead `won`.
- MỚI `LeadContractor`(lead_id, contractor_id, viewed_at, quoted_at) — routing + feed + giới hạn N/lead.

## Luồng (state machine)
- Onboard đơn vị: tạo hồ sơ → `pending` → admin duyệt → `approved` (hiện danh bạ).
- RFQ mở: user đăng `Lead`(public) → match & báo đơn vị phù hợp → đơn vị gửi `Quote` → user so sánh → chọn → chat → `won/lost`. ĐT user che tới khi accept.
- Liên hệ thẳng: duyệt danh bạ → chi tiết đơn vị → "Yêu cầu báo giá" (Lead có `target_contractor_id`).
- Operator (tùy chọn): lọc/gán/QA. Lead: `new→routed→quoted→won/lost/expired/spam`.

## Lộ trình
- **P1 — Directory + Onboard + My Requests**: bật cờ, danh bạ đơn vị (lọc dịch vụ/khu vực),
  chi tiết đơn vị + portfolio, đăng ký làm đơn vị (pending→admin duyệt), "Yêu cầu của tôi".
- **P2 — Self-serve báo giá**: feed nhu cầu cho đơn vị, gửi `Quote`, user so sánh & chốt,
  `contractor_reviews`, thông báo lead/quote.
- **P3 — BĐS công nghiệp + Promote**: mở rộng `House` (loại hình industrial + thuộc tính:
  diện tích ha, tải điện, PCCC, pháp lý KCN) tái dùng search/detail/booking; gói pro/promote + xếp hạng.

Cổng tính năng: `construction_enabled` (env). Cờ RFQ vãng lai: `construction_public_rfq_enabled`.
