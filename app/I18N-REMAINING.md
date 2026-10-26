# i18n — phần còn lại (bàn giao cho Gemini CLI / hoặc Claude sau khi hết giới hạn)

**Trạng thái (24/07/2026):** Guest + Host + Admin CHÍNH đã đa ngôn ngữ vi/en/zh (Đợt 1–9, ~1834 key, đã deploy live). Còn **~89 file đuôi dài** (analytics internals, homestay/property widgets, planning widgets, permissions, operator, market_research…) chưa i18n. Các agent Đợt 10–12 chết giữa chừng do **hết giới hạn tuần Anthropic (reset 28/07)**; 19 file sửa dở đã được `git checkout` về gốc nên cây nguồn **build được**.

## Cơ chế (đã hoạt động ổn 9 đợt)
- gen-l10n: `l10n.yaml` (arb-dir `lib/l10n`, template `app_vi.arb`, class `AppLocalizations`, synthetic-package:false). 3 file `app_{vi,en,zh}.arb` phải **cùng bộ key**.
- Truy cập: `AppLocalizations.of(context)` → `l.<key>`. Placeholder ICU: value `"{name}"`, gọi `l.key(name)`; template (vi) cần `@key: {"placeholders":{"name":{}}}` (script tự thêm).

## Quy tắc dịch
Chỉ dịch text người-dùng-thấy (Text/label/hint/nút/snackbar/validator/empty). BỎ QUA: comment, log, asset path, route, tên analytics, **hằng CODE dùng trong logic** (status/category/tx_type gửi API), chuỗi so sánh `==`, ký hiệu tiền `đ`/`₫`, ghép dữ liệu động (địa chỉ/tên/số). Mỗi file 1 prefix key (camelCase). vi = giữ nguyên tiếng Việt gốc; en tự nhiên; zh giản thể.

## GOTCHA test (bắt buộc)
Widget test mặc định chạy locale **en-US** → nếu màn có i18n mà test pump bare MaterialApp thì `AppLocalizations.of` null → crash, hoặc render tiếng Anh trong khi assertion tiếng Việt. FIX: ở `test/helpers/pump_app.dart` và mọi `_pump` cục bộ, thêm:
```dart
localizationsDelegates: AppLocalizations.localizationsDelegates,
supportedLocales: AppLocalizations.supportedLocales,
locale: const Locale('vi'),
```

## Quy trình 1 đợt
1. Với mỗi file: thay literal → `l.<prefixKey>`, thêm import `package:house_booking/l10n/app_localizations.dart`, lấy `final l = AppLocalizations.of(context);` trong build/method có context. Helper không context → truyền `l` từ call site hoặc thêm param `BuildContext`.
2. Thêm 3 bản dịch cho mỗi key mới vào **cả 3** `app_{vi,en,zh}.arb` (giữ cùng bộ key).
3. Verify bằng Docker (KHÔNG cài Flutter máy chủ):
   ```bash
   IMG=ghcr.io/cirruslabs/flutter:stable
   docker run --rm -v "$PWD":/app -w /app $IMG bash -lc \
     'flutter pub get >/dev/null && flutter gen-l10n && flutter analyze 2>&1 | grep " error •" | grep -v integration_test/'
   docker run --rm -v "$PWD":/app -w /app $IMG bash -lc 'flutter test'   # phải 804 pass
   docker run --rm -v "$PWD":/app -w /app $IMG bash -lc 'flutter build web --release'
   ```
   3 lỗi `integration_test/*` là CÓ SẴN (bỏ qua). Web phục vụ trực tiếp từ `build/web` (bind-mount) → build xong là live tại 127.0.0.1:3030.

## Danh sách file còn lại
Chạy để lấy danh sách + số literal:
```bash
for f in $(grep -rlP "['\"][^'\"]*[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệ][^'\"]*['\"]" lib/features --include='*.dart'); do
  n=$(grep -P "['\"][^'\"]*[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ][^'\"]*['\"]" "$f" | grep -vcE ':\s*//|///'); [ "$n" -ge 3 ] && echo "$n ${f}"; done | sort -rn
```
Cụm lớn: `host/analytics/**` (subsystem thống kê), `host/homestay/**` + `host/property/**` (widgets), `planning/**`, `permissions/**` (chú ý `permissions/copy/priming_copy.dart` là const-data — cần refactor thành getter nhận context), `admin/market_research_screen.dart` (~130, báo cáo admin-only), `operator/**`, `host/dashboard/widgets/hd_status_pill.dart` (factory tĩnh gọi từ hd_listing_row.dart:63 & hd_appointment_row.dart:53 — sửa cùng lúc).

## LƯU Ý QUAN TRỌNG
- **git commit đang treo cả session** (lỗi permission stream) — toàn bộ i18n Đợt 1–9 đang UNCOMMITTED trên đĩa. **Commit tay trước** khi Gemini sửa tiếp, để có mốc revert an toàn.
- Đừng `git checkout .` toàn bộ (sẽ mất hết Đợt 1–9). Chỉ revert từng file khi cần.
</content>
