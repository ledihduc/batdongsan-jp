# Super App Plan — ancu365 (Bất động sản + Thi công)

Tổng hợp Designer + BA (2026-07) từ mẫu home bTaskee. Quyết định chủ dự án:
- **Giữ design system HD terracotta + gradient hero** (không rebrand cam-neon).
- **Bottom-nav: full super-app 5 tab + FAB mascot giữa** (đổi guest_shell — rủi ro cao, làm sau flag + QA).
- **Thi công: marketplace nhà thầu ĐẦY ĐỦ** (profile/portfolio/RFQ/báo giá/đánh giá).

## Cấu trúc
- **BĐS**: Thuê · Cho thuê · BĐS công nghiệp.
- **Thi công**: Thiết kế · Xây dựng · Nội thất.

## Home layout (mẫu)
Header gradient (chào + map/chat/notif) · thanh tìm kiếm nổi (KHÔNG ví/điểm — ancu365 không có ledger) · **lưới "Dịch vụ" 2 nhóm** · banner peek-carousel · "Tin nổi bật" (list hiện tại) · bottom-nav.

## Ánh xạ tái dùng
Thuê/Cho thuê = dùng lại toàn bộ tin + host suite. Homestay = mode trong Thuê. Bản đồ/quy hoạch = utility. Mua/bán = ẩn (SALE_ENABLED=false). BĐS-CN = mở rộng model house + trường KCN. Thi công = làm mới.

## SLICES (trạng thái)
- **✅ Slice 1 — Home service grid** (LIVE, commit af803e8): `HomeServicesSection` 2 nhóm × 3 tile; wire Thuê/Cho-thuê; Thi công+BĐS-CN tạm "Sắp ra mắt".
- **⬜ Slice 2 — Marketplace nhà thầu (BACKEND)**: migration + bảng `construction_service` (seed 3), `contractor` (profile năng lực, vai trò), `contractor_project` (portfolio), `construction_lead` (RFQ: user nullable/khách vãng lai, service, name, phone, area, description, images, status, assignee), `quote` (báo giá). Endpoints: list services, list/detail contractor + portfolio (theo service), submit RFQ, operator xử lý lead, (P) báo giá. Flag `construction_enabled`. Đánh giá dùng lại `review`. **Cần migration → deploy có gate.**
- **⬜ Slice 3 — Thi công (FRONTEND)**: landing mỗi service (mô tả + portfolio) · danh sách nhà thầu + chi tiết/portfolio · form "Yêu cầu tư vấn/báo giá" (khách vãng lai gửi được) · màn operator/nhà-thầu xử lý lead+báo giá. Wire 3 tile Thi công vào đây (thay "Sắp ra mắt").
- **⬜ Slice 4 — Nav 5-tab + FAB mascot** (RỦI RO CAO): đổi `guest_shell` → 5 mục (Trang chủ · Hoạt động · [FAB Đăng tin/Yêu cầu] · Tin nhắn/Cộng đồng · Tài khoản); cân nhắc gộp shell guest/host qua `persona_mode`. **Sau feature-flag `SUPER_APP_NAV` (default OFF) + QA thiết bị thật.**
- **⬜ Slice 5 — Header gradient + banner carousel** (polish): `DsHomeHeader` gradient bo đáy thay masthead; peek-carousel banner; 6 SVG icon dịch vụ (`assets/services/`) thay Material icon.
- **⬜ Slice 6 — BĐS công nghiệp**: trường KCN (cột nullable trên house) + filter theo khu + tile wiring.

## Phase (MoSCoW)
- P1: Slice 1 (✅) + 3 (Thi công lead/marketplace cơ bản) + 5 (polish home). Must.
- P2: Slice 2 đầy đủ (contractor marketplace + báo giá) + Slice 4 nav + Slice 6 BĐS-CN. Cần Notification/FCM.
- P3: thương mại hoá (hoa hồng/đặt cọc thi công, escrow) — cần Payment + eKYC.

## Vai trò
Khách (thuê + gửi RFQ thi công) · Chủ nhà (cho thuê + quản lý) · **Nhà thầu (mới)** · Operator/Admin (xử lý lead, curate portfolio) · Verifier.

## KPI
#lead thi công/tuần · tỉ lệ điền form · #nhà thầu active · lead→báo giá→chốt · retention BĐS không giảm.
