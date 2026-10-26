# Redesign quản trị host — Rủi ro & phương án xử lý (2026-07)

## Đã ship & live
- Đợt 1: KPI 3 ô + Quick-Action bar + "Việc cần làm hôm nay".
- Đợt 3: gom 8 nút phẳng → menu nhóm THU CHI / VẬN HÀNH KHÁC.
- Đợt 4: màn Nhắc nợ hàng loạt (Zalo 1 chạm); KPI nâng cấp "Đã thu / Còn nợ / Tỉ lệ lấp đầy" (revenue.gross + totalUnpaid + occupancy.buildingAvgPct).
- Đợt 2-lite: mặc định vào tab vận hành (initialIndex:1); **Đợt 2 đầy đủ sau flag `HOST_SINGLE_DASHBOARD` (default OFF, dark-launch)**.
- Dọn nợ kỹ thuật: xoá widget mồ côi HDNhaTroKpiBar.

## Bảng rủi ro
| # | Rủi ro | Mức | Xử lý |
|---|---|---|---|
| R1 | Đợt 2 đầy đủ (bỏ tab lồng) đụng điều hướng lõi | Cao | Sau flag `hostSingleDashboard` (default OFF); QA thiết bị thật (deep-link /host/*, luồng hẹn xem, truy cập Tin đăng) trước rollout; rollback = tắt flag |
| R2 | KPI "Đã thu/Lấp đầy" thêm 2 fetch (revenue+occupancy) khi mở tab → chậm nhẹ | TB | Fetch sau các fetch khác; null-safe (hiện 0/— khi chưa tải); cân nhắc cache |
| R3 | "Nhắc tất cả qua Zalo" web chặn popup nhiều link | Thấp | Đường chính per-row 1-chạm vẫn chạy; nâng cấp = gửi server (ZNS/Zalo OA) sau |
| R4 | Dashboard 1 kiểu chưa hợp homestay (Còn nợ/HĐ) | TB | Phát hiện loại chủ → KPI riêng (đêm trống/check-in); TODO |
| R5 | Nợ kỹ thuật: param maintenanceCount truyền nhưng ít dùng; loop fetchRooms N lần | Thấp | Dọn dần; cân nhắc bỏ máy tính maintenance nếu không hiển thị |
| R6 | Thứ tự deploy migration (cột House) | TB | Quy trình: migration→verify→backend→web; additive-only + downgrade |
| R7 | Deploy/migration prod bị gate | TB | Giữ (an toàn); health-check + auto-rollback; cân nhắc permission-rule nếu deploy thường xuyên |
| R8 | Giới hạn usage cắt ngang build lớn | TB | Chia lát nhỏ, commit + analyze sạch trước deploy |
| R9 | Cờ an toàn OFF (self-heal autofix/deploy, review_requires_stay, phí xác minh DEFERRED, Payment chưa build) | Thấp | Safe-by-default; bật khi xác thực + chốt kinh doanh |

## Nguyên tắc giảm rủi ro
Chia lát nhỏ · commit+analyze sạch+deploy auto-rollback · 80/20 (an toàn tác động cao trước) · migration additive-only · feature-flag cho phần rủi ro · safe-by-default.
