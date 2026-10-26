# Rental Pivot Plan — ancu365 (họp 2026-07)

> Bổ sung/điều chỉnh [ROADMAP.md](ROADMAP.md) sau cuộc họp chốt mô hình kinh doanh.
> Phân tích 4 chuyên gia (domain/BA/UX/tech) + 2 chuyên gia (BA/Designer cho mảng thuê).

## Định vị mới
**Sàn trung gian THUÊ & CHO THUÊ (dòng tiền)** — bỏ "BĐS chung chung". Giá trị khác biệt = **xếp hạng + review + quản lý nhà/xuất hóa đơn thuế**. Miễn phí trước để hút traffic, thu phí dần.

## Quyết định lớn & tác động
- **Loại bỏ đăng tin BĐS mua/bán** (dễ tạo rác) → **ẩn sau feature-flag `SALE_ENABLED` (default false)**: ẩn segmented "Mua bán" ở trang chủ + nút "Tính khoản vay". GIỮ "So sánh" (hữu ích cho nhà thuê). Code giữ nguyên sau flag (bật lại bằng build-flag).
- **Loan calculator + AVM/định giá bán**: hạ ưu tiên (công cụ người mua).
- **Payment core**: vẫn cần nhưng đổi mục đích → phí xác minh/nâng cấp + (sau) thu tiền thuê.
- ⭐ **"App quản lý nhà" mà họp muốn tích hợp → ĐÃ CÓ SẴN trong ancu365** (toà→phòng→hợp đồng→khách thuê→hóa đơn→điện nước→tạm trú→**xuất TT200 thuế**). KHÔNG cần bên thứ 3 — chỉ **làm nổi bật + đưa lên Tổng quan** như lõi sản phẩm.

## Hai loại "sao" (quyết định UX cốt lõi)
Review hiện dùng **sao vàng ⭐** rồi → **sao chất lượng phải khác hẳn**: **vạch terracotta ▰▰▰▱▱**, không dùng sao.
- **Sao chất lượng** (MỚI): 5 tiêu chí (PCCC, đủ đồ, có bếp, WC khép kín, điều hòa) → tự khai (miễn phí) → **thẩm định viên xác minh** → ảnh hưởng/khoá **khung giá gợi ý** (`giá/m² trung vị khu vực × hệ số sao`).
- **Sao review** (ĐÃ CÓ): trải nghiệm người thuê, tích lũy theo thời gian.
- Hiển thị song song, KHÔNG gộp điểm.

## Data model mới (additive-only + feature flag)
`house_quality_rating` · `verification_request` (phí, khiếu-nại-trigger) · `lead_segment` (target/potential) · vai trò `verifier`.

## Chức năng bổ sung từ note mới
- Phí xác minh gắn **khiếu nại** (người thuê tố → điều thẩm định viên).
- **Blacklist** chủ/khách xấu (giai đoạn sau).
- **Xử lý review 1 sao** (cảnh báo, khiếu nại, chống trả đũa) (giai đoạn sau).
- **Mở rộng KCN & nhà trọ công nhân** (phân khúc, lọc theo khu công nghiệp) (giai đoạn sau).
- **Slogan + SEO** ("vua về thuê và cho thuê") — Marketing.
- Khách mục tiêu = "làm ăn đàng hoàng, đóng phí đều" → ưu tiên giữ chân.

## Todo theo người phụ trách
**DEV — Phase 1 (ngay, 0 blocker):** sao chất lượng tự khai + gợi ý giá; hiển thị+cập nhật nhanh phòng trống; vá review-chỉ-người-đã-ở; **nổi bật quản lý nhà/hóa đơn**; ẩn mua/bán sau flag (✅ đã làm bước flag).
**DEV — Phase 2:** thẩm định viên + verified badge + luồng khiếu nại; target/potential; bản đồ nhà trọ.
**DEV — Phase 3 (cần Payment):** phí xác minh online; Blacklist; xử lý review 1★; KCN/công nhân.
**PRODUCT:** chốt tiêu chí+trọng số sao, hệ số giá, chính sách phí theo giai đoạn, định nghĩa target/potential + blacklist.
**MARKETING:** slogan+SEO+tên miền+app-store; chiến lược miễn-phí→thu-phí.

## Roadmap
- **P1** (0 blocker): sao chất lượng tự khai + phòng trống B2C + tách 2 sao + review-sau-ở + nổi bật quản lý nhà + ẩn mua/bán.
- **P2**: thẩm định viên + verified + khiếu nại + target/potential + map nhà trọ.
- **P3** (cần Payment): phí xác minh online + Blacklist + review 1★ + KCN/công nhân.

## Trạng thái
- ✅ Ẩn mua/bán sau flag `SALE_ENABLED` (Flutter, default off) — CHƯA deploy.
- ⏳ Phase 1 rating/vacancy/review-constraint: chờ bắt tay build.
