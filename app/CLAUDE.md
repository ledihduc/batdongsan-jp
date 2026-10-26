# CLAUDE.md — ancu365-app (Flutter web, package `house_booking`)

> Chỉ ghi NGUYÊN TẮC ỔN ĐỊNH. Phương án tái cấu trúc: **`../AI-REFACTOR-PLAN.md`** (có bản đồ cụm→file đầy đủ).

## Định vị nhanh (cho AI)
- Cấu trúc **feature-first**: `lib/features/<feature>/` (guest, host/*, construction, admin, planning…).
- **Data/domain sạch (khuôn đích)**: `lib/data/{models,repositories,services}` + `lib/domain/repositories` (interface `i_*`).
- **Design System**: `lib/core/widgets/ds.dart` (barrel export `Ds*` + tokens). Import 1 dòng là đủ. **Màu CHỈ ở `lib/core/theme/design_tokens.dart`.**
- **Router**: `lib/core/router/app_router.dart` (khai báo `GoRoute`, dùng `deferred as` cho lazy-load).
- God-file có MỤC LỤC ở đầu (grep `MỤC LỤC`): `construction_screens.dart`, `service_extra_screens.dart`.

## Quy ước (viết code mới theo đây)
- **1 file = 1 màn, tên khớp nội dung** (`*_screen.dart`, `*_sheet.dart`). KHÔNG gom nhiều màn public 1 file; KHÔNG tên mơ hồ (`*_screens`, `*_extra`, `*_body`). Tiêu chí là COHESION, không phải số dòng.
- Màn dài → tách **section widget** (mẫu tốt: `features/guest/booking/booking_detail_screen.dart`).
- **Form**: dùng `DsFormSection` + `DsTextField` + `ImageGridUploader` (`core/widgets/`). Submit sticky.
- Docstring đầu màn: `/// <mục đích>. Route: <path>. Provider: <x>. API: <y>.`

## Điều hướng — luật (nguồn bug `/host/billing` trước đây)
- Màn cần **URL / deep-link / back trình duyệt** → khai báo `GoRoute` + `context.go/push`.
- Sub-flow **không cần URL** (form nhiều bước, sheet, push trong tab) → `Navigator.push`.
- **`context.go('/route-không-tồn-tại')` KHÔNG throw** — nó render trang lỗi. Muốn mở màn push-based thì DÙNG `Navigator.push`, đừng `go()`.

## `web/` = NỘI DUNG CÔNG KHAI (đã có sự cố)
- `flutter build web` copy MỌI thứ trong `web/` ra `build/web/` — nơi đang phục vụ thẳng ra Internet.
  Tài liệu nội bộ để ở đây sẽ tự public (đã xảy ra 26/07/2026 với `web/design/`).
- Tài liệu/ghi chú/báo cáo → **`docs/`** (bản HTML để đọc: `docs/html/`). KHÔNG bao giờ đặt trong `web/`.
- `check.sh` có cổng CHẶN deploy khi `web/` có tệp ngoài danh sách `WEB_ALLOW`; thêm asset thật thì khai báo vào đó.

## Verify & deploy
- Verify: `flutter analyze` (repo còn ~300 info có sẵn — chỉ chặn khi có `error`/`warning`) → `flutter test` (1049 pass) → `flutter build web --release` → **`python3 tools/nen_gz.py build/web`**.
- **`flutter` phải chạy TRONG container, và `pub get` phải CÙNG lệnh với việc dùng nó** — pub cache nằm trong container, không mount ra:
  `docker run --rm -v "$PWD":/app -w /app ghcr.io/cirruslabs/flutter:stable bash -lc 'flutter pub get >/dev/null && flutter test'`.
  Chạy `flutter` bằng SDK trên host sẽ ghi đè `.dart_tool/package_config.json` bằng đường dẫn host và làm hỏng resolve của container.
- **`tools/nen_gz.py` KHÔNG được quên.** nginx bật `gzip_static`, nên mọi trình duyệt thật (gửi `Accept-Encoding: gzip`) nhận tệp `.gz`. `flutter build web` KHÔNG sinh lại `.gz` → bỏ bước này là deploy xong mà người dùng vẫn thấy **bản build cũ**, còn `curl` (mặc định không gzip) lại thấy bản mới nên nhìn qua tưởng đã live. Kiểm bằng `curl -sk --compressed <url>`.
- **Nếu tách file trong vùng `deferred as`** (`app_router.dart`): đo lại kích thước chunk JS (build không báo lỗi phình chunk).
- Web phục vụ trực tiếp từ `build/web` (bind-mount) → build + nén gz xong là live. `check.sh` ở `../ancu365-backend/`.
- SĐT masked; giữ role='guest' whitelist.
</content>
</invoke>
