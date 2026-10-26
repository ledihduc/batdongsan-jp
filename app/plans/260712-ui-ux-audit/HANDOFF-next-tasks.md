# HANDOFF — ancu365 UI/UX audit (đọc file này trước khi làm tiếp)

> Cập nhật: 2026-07-12. Người bàn giao: phiên AI trước. Trạng thái: P0 + P1(rental-first) ĐÃ xong, deploy, verify, push. Còn 1 task lớn + vài việc nhỏ.

## 0. Bối cảnh nhanh (đọc để khỏi dò lại)

- App: Flutter web `ancu365` (package `house_booking`) + FastAPI + Postgres.
- **Sửa code ở đâu:** local `/tmp/ancu365-work/app-lib/` (chỉ thư mục `lib/`) và `/tmp/ancu365-work/backend-full/`.
- **Deploy:** rsync lên server `~/deploy/ancu365/ancu365-app/lib/` rồi build tại chỗ. Web bind-mount từ `~/deploy/ancu365/ancu365-app/build/web` vào container nginx `ancu365-web` → build xong là live.
- **SSH:** `sysadmin@digilab.ddns.net -p 5002` (mật khẩu qua env `SSHPASS`, KHÔNG in ra/commit).
- **Flutter SDK trên server:** `~/flutter/bin` → shell non-login phải `export PATH="$HOME/flutter/bin:$PATH"`.
- **Build:** `flutter build web --dart-define=SUPER_APP_NAV=true --release`.
- **Container:** web `ancu365-web`, backend `ancu365-backend`, DB `faceconst-db` (db/user `ancu365`).
- **Repo git trên server:** `~/deploy/ancu365/ancu365-app/` → `github.com:ledihduc/ancu365-app.git` (branch `main`).
- **Commit rule:** conventional commits, KHÔNG có AI reference / Co-Authored trailer (theo CLAUDE.md user).

## 1. Đã làm xong (đừng làm lại)

- Audit UI/UX bằng screenshot thật + code (báo cáo trong `reports/`: `synthesis.md`, `designer-review.md`, `ba-review.md`).
- **P0** (commit `9c9663c`): giảm đỏ→nền trung tính; tiêu đề sans thay serif; empty/error state danh sách + không nuốt lỗi; ẩn 6 nút demo-login khỏi release; xoá ảnh rác feed cộng đồng (post id=2); avatar hỏng→icon; FAB hết đè banner.
- **P1 rental-first** (commit `810b1fb`): gộp "Thuê nhà/Cho thuê"→1 tile "Nhà cho thuê" + thêm tile "Bản đồ"; login value-prop thay metaphor "nhật báo"; ngưỡng tin cậy xếp hạng nhà thầu (<3 đánh giá đánh dấu "mới").
- Docs audit synced + commit `66b7334`.
- Đã verify: `flutter analyze` sạch, build EXIT 0, site 200, screenshot xác nhận.

## 2. CÒN LẠI — việc phải làm tiếp (ưu tiên từ trên xuống)

### D1 — Nhóm việc nhỏ, rủi ro thấp (làm luôn được, gộp 1 commit)
File: `app-lib/features/guest/home/home_services_section.dart`, `app-lib/providers/house_provider.dart`
1. **Sửa doc comment lỗi thời** ở `home_services_section.dart` dòng ~11–16: vẫn tả "Thuê nhà/Cho thuê → onOpenListing (cuộn tới lưới)" nhưng code đó đã xoá. Viết lại đúng hành vi hiện tại (tile → `PropertyListingScreen`).
2. **`print()` trong `house_provider.fetchHouses()` catch** đang chạy ở prod → bọc `if (kDebugMode)` (import `package:flutter/foundation.dart`).
3. **Nhất quán điều hướng (#3):** 3 tile nhóm THI CÔNG (Thiết kế/Xây dựng/Nội thất) hiện mở `CommunityBlockScreen` (tìm địa danh + post), KHÁC nhóm BĐS (mở danh sách tin). Đây là mầm "không trực quan". Quyết định 1 mô hình nhất quán — gợi ý: cho 3 tile này mở landing/danh sách dịch vụ thay vì CommunityBlock, hoặc tách rõ nhãn. CẦN xác nhận hướng trước khi sửa.

→ Sau sửa: `flutter analyze` 4 file, build, verify screenshot, commit `refactor(ux): ...`, push.

### D2 — TASK LỚN: bỏ tường đăng nhập (browse-first) — HIGH IMPACT, cần quyết P2 hay P3
**Đây là gốc của lời chê "không trực quan".** Người mới hiện bị `LoginScreen` chặn ngay tại `/` — chưa thấy căn nhà nào đã phải đăng nhập.

Bối cảnh code (đã verify):
- `app-lib/core/router/app_router.dart` `_RootGate` tại `/`: render `LoginScreen` khi `!authProvider.isAuthenticated` (line ~574).
- `GuestShell` + hydrate (`fetchInitialData`, `fetchMyHouses(user.id!)`, notifications, chat, appointment) đều **giả định có `user.id`** → null sẽ crash nếu mở cho khách.
- **API `/api/houses` CÔNG KHAI** (không cần token, đã verify trả 16 tin) → dữ liệu để browse sẵn sàng.

**Phương án 2 (khuyến nghị nếu chấp nhận test kỹ):** `/` render GuestShell chế độ khách; xem được danh sách + chi tiết + bản đồ + xếp hạng; mọi hành động cá nhân (lưu/liên hệ/đăng/cộng đồng/chat) → bottom-sheet "Đăng nhập để tiếp tục". Phải guard MỌI điểm hydrate dùng `user.id` (null→skip, không crash). Rủi ro trung bình-cao (~1.5–2.5 ngày). Làm nhánh riêng + feature-flag `GUEST_BROWSE` + e2e cả 2 path (khách & đã login) trước khi bật.

**Phương án 3 (an toàn, nhanh, đổi lại trùng UI):** thêm route công khai `/preview` read-only (chỉ danh sách + chi tiết), nút "Đăng nhập" nổi; KHÔNG đụng GuestShell/hydrate. Rủi ro thấp (~0.5–1 ngày). Nợ: trùng UI danh sách 2 nơi.

→ **Chưa làm** vì đụng vùng auth nhạy cảm — chờ user chọn P2/P3.

### D3 — Quyết định sản phẩm (không cần code ngay, hỏi user)
- **C1. User chính là người thuê hay chủ nhà?** Rental-first (đã duyệt) nghiêng người thuê → đẩy tìm/lọc/bản đồ lên đầu, "Đăng tin" giấu trong menu chủ nhà. Nếu chủ nhà là chính → cần tile "Đăng tin" nổi ngoài home (đánh đổi: loãng trải nghiệm người thuê).
- **C2. Giữ 6 khối hay thu gọn về lõi thuê nhà?** Giữ = tham vọng siêu-app nhưng rối (2 mô hình điều hướng). Thu gọn = nhất quán, khớp lời chê, đẩy Thi công/Cộng đồng vào tab phụ.

## 3. Mẹo môi trường (đã vấp ở phiên trước)

- **Screenshot site self-signed cert:** dùng Playwright `chromium.launch({channel:'chrome', args:['--ignore-certificate-errors']})` + `newContext({ignoreHTTPSErrors:true})`. KHÔNG dùng `--headless=new` (bỏ qua flag cert) hay legacy `--headless` (forward sang Chrome GUI đang chạy).
- **Vượt tường login để screenshot:** mint JWT qua `POST /api/auth/login {"email":"guest@housebooking.com","password":"guest123"}` rồi inject `localStorage['auth_token']` (web secure_storage = plain localStorage), reload.
- Screenshot lưu `/tmp/ancu365-work/shots/`.

## 4. Câu hỏi mở còn treo cho user
1. D1#3: chọn mô hình điều hướng nhất quán cho nhóm THI CÔNG?
2. D2: browse-first theo P2 (đầy đủ, rủi ro cao hơn) hay P3 (route preview, an toàn)?
3. D3: C1 (user chính) + C2 (giữ/thu gọn khối)?
