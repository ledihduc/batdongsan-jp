# Construction Marketplace + BĐS-CN — Plan (Tech Lead + BA + Designer)

Hoàn thiện mảng "sắp ra mắt" của siêu app: **Thi công** (thiết kế/xây dựng/nội thất — marketplace nhà thầu ĐẦY ĐỦ) + **BĐS công nghiệp**. Xem [SUPER-APP-PLAN.md](SUPER-APP-PLAN.md).
Định vị pháp lý: ancu365 là **sàn TRUNG GIAN, no-escrow, KHÔNG là bên hợp đồng** — chi phối toàn bộ quy tắc tranh chấp.

## Data model (Tech Lead) — additive-only
Bảng mới: `construction_services` (seed design/build/interior) · `contractors` (user_id nullable, company_name, service_slugs JSONList, province/district_code, phone, verified, rating_avg/count, status pending/active/suspended) · `contractor_projects` (portfolio: images JSONList) · `construction_leads` (RFQ: user_id nullable=vãng lai, service_slug, name, phone, area, budget, description, images, status new/assigned/quoted/won/lost/spam, assigned_operator_id, contractor_id) · `quotes` (lead_id, contractor_id, amount VND, note, valid_until, status sent/accepted/rejected/expired).
Mở rộng: `reviews` += `contractor_id` nullable + `target_type` default 'house'. `houses` += cột industrial nullable (industrial_type, floor_area, industrial_zone(_slug), ceiling_height, power_capacity, industrial_meta JSON) + `product_type='industrial'`.
Migrations 0044→0050 (hoặc gộp), seed service bằng bulk_insert trong migration.

## RBAC (Tech Lead)
Thêm `require_operator` (operator/admin) + `require_contractor` (contractor/admin + ownership check). Mở whitelist role ở `users.py` → thêm operator/contractor. Đăng ký public vẫn chỉ guest.
**Lộ SĐT**: SĐT khách chỉ lộ cho nhà thầu SAU khi lead gán cho thầu đó; SĐT thầu lộ cho khách SAU khi accept báo giá.

## Vòng đời (BA)
- Lead: new→assigned→quoted→won|lost|spam (chỉ operator set spam).
- Contractor: pending→active|rejected→suspended.
- Quote: sent→accepted(→lead won, quote khác auto reject)|rejected|expired.
- Review: chỉ khách có lead `won` với thầu mới review được (gate cứng).

## API (Tech Lead) — router có `_guard(construction_enabled)`
services list · contractors list/detail/portfolio + verify(admin) · leads: POST public RFQ + operator list/manage + contractor xem lead-của-mình + user xem lead-của-mình · quotes: contractor tạo + user accept/reject · review (tái dùng reviews.py, target_type=contractor).

## Flags (default OFF, bật tăng dần)
`construction_enabled` · `construction_public_rfq_enabled=True` (kill-switch spam) · `contractor_marketplace_enabled` · `industrial_re_enabled`.

## UI (Designer) — 8 màn + luồng RFQ 3-điểm-vào
Landing dịch vụ · Danh sách nhà thầu (DsContractorCard + filter) · Chi tiết + DsPortfolioGrid (lightbox) · **DsRfqForm** (vãng lai, 2 field bắt buộc, đính ảnh, OTP nhẹ) · Yêu cầu của tôi + DsQuoteCard (so sánh/accept) · Đánh giá · Pro (nhà thầu: leads/quote/portfolio) · Operator (hàng đợi + gán).
**`DsInterestSheet`** thay `_comingSoon`: giữ đủ 6 tile nhưng biến "sắp ra mắt" thành thu-lead (cờ `isLive` per-service). BĐS-CN: `DsIndustrialCard` (nhấn diện tích sàn/KCN/điện dạng bảng) + filter theo KCN/loại/diện tích.
Component mới: DsVerifiedBadge(positive, tách khỏi DsTrustedBadge amber) · DsContractorCard · DsPortfolioGrid · DsRfqForm · DsQuoteCard · DsInterestSheet · DsIndustrialCard · DsSpecTable.

## Thứ tự build (khớp cả 3): RFQ trước
1. Migrations+models+flags+RBAC (M). 2. **RFQ/lead** (submit public + operator) (M) → KPI #lead/tuần sớm. 3. BĐS-CN cột+filter (xen kẽ, S-M). 4. Contractor onboarding+portfolio+verify (M). 5. Quote (M). 6. Review contractor (S). FE: DsInterestSheet trước (thu lead ngay cả khi backend chưa sẵn).

## Quyết định cần chủ dự án chốt (BA)
(a) auto-route lead hay 100% operator gán ở P1; (b) OTP SĐT vãng lai trước khi lộ báo giá?; (c) chính sách hoa hồng P3 (%/lead vs phí đăng ký thầu); (d) định nghĩa "hoàn thành" để mở gate review.

## Phụ thuộc & KPI
Notification/FCM chặn P2 (báo lead/quote). Payment chặn P3 (đặt cọc/hoa hồng). KPI: #lead/tuần, tỉ lệ điền form/tile, %lead trong SLA 24h, %spam; (P2) #thầu active, lead→quoted→won, #review hợp lệ.
