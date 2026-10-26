# Build ancu365 — lệnh và những chỗ đã trả giá

> Cập nhật 03/09/2026, sau khi **gỡ bỏ môi trường production cũ**.
> Từ nay chỉ còn MỘT môi trường: `https://ancu365.ddns.net`.

## TL;DR

```bash
# iOS — App Store archive (chạy trên máy macOS)
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://ancu365.ddns.net \
  --dart-define=PUBLIC_SITE_URL=https://ancu365.ddns.net \
  --dart-define=LEGAL_BASE_URL=https://ancu365.ddns.net

# Android
flutter build apk --release \
  --dart-define=API_BASE_URL=https://ancu365.ddns.net \
  --dart-define=PUBLIC_SITE_URL=https://ancu365.ddns.net \
  --dart-define=LEGAL_BASE_URL=https://ancu365.ddns.net

# Web (deploy: phục vụ thẳng từ build/web qua bind-mount)
flutter build web --release && python3 tools/nen_gz.py
```

Chạy thử trên iPhone cắm cáp: đổi `build ipa` → `run -d ios`, giữ nguyên ba `--dart-define`.

---

## Ba `--dart-define` bắt buộc

`String.fromEnvironment` đọc lúc **biên dịch**, không đổi được lúc chạy. Thiếu cái
nào thì nó rơi về giá trị mặc định — và cả ba mặc định hiện đều **sai**.

| Tham số | Mặc định trong code | Vì sao PHẢI truyền |
|---|---|---|
| `API_BASE_URL` | `http://localhost:3003` (iOS) | Trên iPhone thật, `localhost` là chính cái điện thoại đó → mọi lời gọi treo 10 giây rồi `connectTimeout`. `http://` còn bị iOS ATS chặn thêm một tầng. |
| `PUBLIC_SITE_URL` | `https://ancu.digi-lab.vn` | Domain này **đã tắt** (03/09). Link chia sẻ tin/môi giới dán vào Zalo, Facebook sẽ ra trang lỗi. |
| `LEGAL_BASE_URL` | `https://ancu.digi-lab.vn` | Cũng đã tắt. Đây là link **Chính sách riêng tư** + **Điều khoản** — Apple soi mục 5.1.1. |

**Không cần** truyền `BASEMAP_TILE_URL` và `MARTIN_TILE_URL`: cả hai tự suy ra từ
`API_BASE_URL` (`lib/core/config/env.dart`).

---

## Chọn domain — cái bẫy đã tốn nhiều giờ

App gọi **ba nhóm đường dẫn**, và chúng KHÔNG cùng nằm dưới `/api/`:

| Đường dẫn | Dùng cho |
|---|---|
| `/api/...` | mọi dữ liệu |
| `/api/basemap/{z}/{x}/{y}.png` | nền bản đồ (proxy OSM) |
| **`/planning-tiles/...`** | **ảnh lớp quy hoạch** |
| **`/martin/...`** | lớp thửa đất (vector) |

`https://ancu.digi-lab.vn` (site Next.js SEO, nay đã gỡ) **chỉ proxy `/api/`**.
Trỏ app vào đó thì đăng nhập và danh sách tin vẫn chạy bình thường —
**nhưng lớp quy hoạch trống trơn**, vì hai đường dẫn kia trả về trang HTML 404.
Đây đúng là lỗi đã gặp trên bản iOS.

Domain đúng phải phục vụ đủ cả bốn. Kiểm nhanh trước khi build:

```bash
for u in "/api/houses?limit=1" "/api/basemap/13/6504/3606.png" \
         "/planning-tiles/v2/hanoi-pk/13/6504/3606.png" \
         "/martin/planning.parcels/12/3242/1929"; do
  printf "%-48s " "$u"
  curl -s -o /dev/null -w "%{http_code}\n" "https://ancu365.ddns.net$u"
done
# Cả bốn phải là 200.
```

---

## Web: PHẢI nén lại `.gz` sau mỗi lần build

nginx bật `gzip_static`, tức là **có `X.js.gz` thì nó phục vụ file đó**, không
thèm đọc `X.js`. Build xong mà quên nén lại thì trình duyệt nhận JS của bản
build TRƯỚC.

```bash
flutter build web --release
python3 tools/nen_gz.py          # xoá .gz cũ + nén lại toàn bộ
```

Hai cái bẫy đã trả giá bằng việc `/map` và `/planning` **chết trắng** trên staging:

1. **Bỏ qua tệp nhỏ.** Script đầu chỉ nén tệp ≥ 1KB. Một chunk deferred co lại
   dưới 1KB ở lần build sau thì `.gz` CŨ vẫn nằm đó và vẫn được phục vụ →
   `loadLibrary()` ném `DeferredLoadException` → hiện "Không tải được trang".
   Mọi request đều **200** nên nhìn log mạng không thấy gì bất thường.
2. **`.gz` mồ côi.** Tệp nguồn biến mất giữa hai lần build (chunk bị đánh số
   lại) nhưng `.gz` ở lại.

`tools/nen_gz.py` xử lý cả hai: xoá sạch `.gz` rồi nén mọi tệp, không ngưỡng.

**Đừng `rm -rf build/web`** để dọn — thư mục đó đang được container web
bind-mount, xoá là đứt mount và site trả 403/404 cho tới khi
`docker restart ancu365-web-staging`. Muốn dọn thì xoá *nội dung* bên trong.

---

## Verify trước khi phát hành

```bash
flutter analyze     # chỉ chặn khi có error/warning; repo còn ~250 info có sẵn
flutter test        # mốc hiện tại: 978 pass
flutter build web --release && python3 tools/nen_gz.py
```

Bẫy service worker: sau khi deploy web, đối chiếu hash để chắc chắn máy chủ đang
phục vụ đúng bản vừa build, đừng tin mắt nhìn:

```bash
md5sum build/web/main.dart.js
curl -s https://ancu365.ddns.net/main.dart.js | md5sum
```

---

## Còn nợ trước khi nộp App Store

- **Hai trang pháp lý chưa có nội dung thật.** `/chinh-sach-quyen-rieng-tu` và
  `/dieu-khoan` hiện trả 200 nhưng nội dung là `index.html` của app (do nginx
  `try_files ... /index.html`), không phải văn bản chính sách. Site Next.js phục
  vụ hai trang này đã bị gỡ ngày 03/09. Apple 5.1.1 đòi chính sách **đọc được**.
- **Chưa từng build được iOS trên máy chủ này** — máy chủ chạy Linux, build iOS
  bắt buộc macOS + Xcode.
