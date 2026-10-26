# Chuẩn bị nộp App Store / Google Play — ancu365

Cập nhật: 03/08/2026. Đây là checklist các việc CẤU HÌNH TRÊN CONSOLE (không phải
code) + trạng thái các rủi ro duyệt đã xử lý trong code.

## Đã xử lý trong CODE (đã deploy)

| Mã | Việc | Trạng thái |
|----|------|-----------|
| B1 | Xoá tài khoản trong app (Settings → Xoá tài khoản) + `POST /api/auth/delete-account` | ✅ |
| B2 | `NSLocationWhenInUseUsageDescription` (iOS) | ✅ |
| B3 | Ẩn nút social login "bảo trì" | ✅ |
| R1 | Chặn người dùng (nút Chặn ở bài/bình luận, màn "Người đã chặn", lọc feed/reel/comment) | ✅ |
| R2 | Báo cáo bình luận (long-press) + reel (đã có sẵn) | ✅ |
| R3 | Chính sách quyền riêng tư + Điều khoản (link trong Register + Settings → mở ancu.digi-lab.vn) | ✅ |
| R4 | `ITSAppUsesNonExemptEncryption = false` | ✅ |
| L1 | Đổi tên iOS "House Booking" → "ancu365" | ✅ |
| L2 | Ẩn switch Dark mode + Thông báo (placeholder) | ✅ |
| I1 | `PrivacyInfo.xcprivacy` cho iOS required-reason API `UserDefaults` | ✅ |
| I2 | Tắt `remote-notification` background mode khi chưa cấu hình Firebase/APNs iOS | ✅ |

URL pháp lý (dùng cho metadata store + link trong app):
- Chính sách quyền riêng tư: https://ancu.digi-lab.vn/chinh-sach-quyen-rieng-tu
- Điều khoản sử dụng: https://ancu.digi-lab.vn/dieu-khoan

## L3 — KHAI BÁO DỮ LIỆU (làm trên Console, chưa làm)

App thu thập ảnh **giấy tờ tuỳ thân (CCCD/CMND)** khi chủ nhà xác minh
(`host_profile_provider.uploadCccd`) + vị trí + ảnh + thông tin liên hệ. Phải khai
đúng, nếu không sẽ bị từ chối vì "khai báo sai".

### Google Play — Data safety (Play Console → App content → Data safety)
Khai các nhóm dữ liệu **có thu thập**:
- **Personal info**: Name, Email, Phone, **Government ID** (ảnh CCCD — chọn mục này).
- **Location**: Approximate + Precise (tính "Tìm quanh đây", chỉ khi user cho phép).
- **Photos**: ảnh nhà/phòng/avatar/CCCD.
- **App activity / User content**: bài đăng, reel, bình luận.
- **Device ID / Messages**: push token (Firebase).
Với mỗi mục: mục đích = App functionality (+ Account management). Nêu **được mã hoá
khi truyền** (HTTPS) và **người dùng xoá được** (đã có xoá tài khoản).
Điền URL chính sách quyền riêng tư ở trên.

### Apple — App Privacy (App Store Connect → App Privacy)
Khai "Data Used to Track You" = **None** (app không tracking/ads). "Data Linked to
You": Contact Info (name/email/phone), Sensitive Info / Government ID (CCCD),
Location, User Content, Identifiers (push token). Mục đích: App Functionality.

## Việc metadata khác khi nộp
- **Privacy Policy URL** (bắt buộc cả 2 store): dùng link phía trên.
- **App icon** thật (kiểm không còn icon Flutter mặc định).
- **Screenshots** đúng kích thước từng thiết bị.
- **Age rating / Content rating**: app có UGC → khai có nội dung do người dùng tạo +
  đã có báo cáo/chặn/kiểm duyệt.
- iOS: cấp tài khoản test cho reviewer trong "App Review Information". Không để nút
  đăng nhập demo public trong app production.
- **Account deletion**: Play Console → App content → khai có xoá trong app + URL web
  (có thể trỏ tới trang hướng dẫn hoặc chính sách).

## iOS preflight trước khi bấm Submit

- Chạy `flutter analyze --no-fatal-infos` và sửa hết `error`/`warning` trước khi archive.
- Bundle ID iOS chính thức: `vn.ancu365.app`.
- Chọn Apple Developer Team trong Xcode → Runner → Signing & Capabilities.
- Nếu muốn bật push notification:
  - tạo iOS app trong Firebase đúng Bundle ID;
  - thêm `ios/Runner/GoogleService-Info.plist`;
  - bật Push Notifications + Background Modes/Remote notifications trong Xcode;
  - đảm bảo APNs key/certificate đã nối vào Firebase.
- Nếu chưa bật push thật, cứ để notification/push ở trạng thái tắt như hiện tại để
  tránh bị hỏi tính năng chưa hoàn chỉnh.

## Còn nên làm (không chặn duyệt nhưng nên)
- Nối switch "Thông báo" vào cấu hình push thật rồi hiện lại (hiện đang ẩn).
- Bọc mọi `debugPrint`/`print` bằng `kDebugMode` để không log PII/token ở bản release.
