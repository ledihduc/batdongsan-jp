# Điều tra: vì sao 0 lượt đăng ký từ Internet

> Ngày 27/07/2026 · Nguồn dữ liệu: log truy cập NPM (`proxy-host-3_access.log`, 19–27/07) + DB production
> Trạng thái: **đã đo được phễu thật, tìm ra 3 nguyên nhân, đã vá 3 thứ trong tầm tay**

## TL;DR

App **có người vào thật** — 52 khách lạ từ Việt Nam trong 8 ngày. Nhưng:

1. **Một nửa rơi rụng ở khâu TẢI app**, chưa kịp thấy gì.
2. **Không công cụ tìm kiếm nào từng ghé** — Googlebot: 0 lượt. Kênh vào duy nhất là **link chia sẻ trên Zalo**.
3. **0 lượt bấm đăng ký** trong toàn bộ log.

Nguyên nhân số 1 không phải "app dở" mà là **gần như không có ai biết app tồn tại**, cộng thêm việc app tự làm khó mình ở 3 giây đầu.

---

## 1. Phễu đo được (8 ngày, đã loại LAN và bot)

| Bước | Số IP | Còn lại |
|---|---:|---:|
| Tải trang chủ | 52 | 100% |
| Tải `flutter_bootstrap.js` | 34 | 65% |
| Tải xong gói app `main.dart.js` | 26 | 50% |
| Gọi `/api/houses` (thật sự **thấy tin đăng**) | 16 | 31% |
| Gọi `/api/auth/register` | **0** | **0%** |

Đối chiếu DB: 11 tài khoản, 8 cái tạo ngày 02/07 (seed), 3 cái ngày 11/07. **16 ngày liên tiếp không ai đăng ký.**

`/api/auth/login` có 6 lượt — đều từ IP của chính chủ dự án.

## 2. Ba nguyên nhân

### 🔴 #1 — Không ai tìm thấy app (nghiêm trọng nhất)

```
Googlebot     0 lượt      bingbot   0 lượt
coccocbot     0 lượt      Yandex    0 lượt
```

**Chưa công cụ tìm kiếm nào từng thu thập trang này.** Trang `/tin` và `sitemap.xml` dựng sẵn cho SEO vì thế **chưa phục vụ ai** (`/tin` chỉ có 2 lượt xem trong 8 ngày).

Lý do: tên miền DDNS, chưa khai báo Google Search Console, **không có backlink nào** — Google tìm ra site qua liên kết hoặc qua khai báo, không có cả hai thì không bao giờ ghé.

Kênh vào thật sự, thấy rõ trong referrer:
```
http://digilab.ddns.net/?zarsrc=31&utm_source=zalo&utm_medium=zalo...   (750+ lượt)
```
→ **Toàn bộ traffic đến từ link dán trên Zalo.**

### 🟠 #2 — Mất một nửa người vào ở khâu tải app

52 → 26 IP giữa "mở trang" và "tải xong gói app". Ba thứ cộng dồn:

- Gói `main.dart.js` **1,5MB sau nén** (5,5MB gốc) — nặng với mạng di động VN.
- **Trang trắng im lặng** suốt thời gian đó: không chữ, không vòng quay, không dấu hiệu app đang mở.
- **Hai script Firebase chặn hiển thị** tải từ gstatic trên MỌI lượt truy cập — trong khi `firebaseConfig` vẫn còn nguyên placeholder `__FIREBASE_API_KEY__` nên `initializeApp` **chưa từng chạy**. Tức là mọi khách phải chờ tải hai tệp không dùng vào việc gì.

### 🟡 #3 — Link chia sẻ Zalo hiện ra trơ trụi

Kênh vào duy nhất là Zalo, nhưng `index.html` **không có một thẻ Open Graph nào** → link dán lên Zalo/Facebook không có ảnh, không tiêu đề, không mô tả. (Trang `/tin` thì có đủ thẻ — nhưng đó không phải trang người ta chia sẻ.)

---

## 3. Đã vá (27/07)

| # | Việc | Vì sao |
|---|---|---|
| 1 | Thêm thẻ Open Graph + Twitter Card vào `index.html` | Tối ưu đúng kênh ĐANG có người (Zalo), không phải kênh chưa tồn tại |
| 2 | Màn chờ HTML/CSS thuần (tên app + vòng quay + "Đang tải…") | Thay trang trắng im lặng; hiện ngay, không đợi JS. Có van an toàn 20 giây phòng khi `flutter-first-frame` không kích hoạt |
| 3 | Firebase SDK chuyển sang **tải theo nhu cầu** | Bỏ 2 request chặn hiển thị mà chưa từng dùng; khi ops điền khoá thật thì tự tải |

Trước đó cùng ngày đã xong **HTTPS thật** (xem `../ancu365-backend` + memory) — gỡ cảnh báo "Not Secure" vốn là thứ khách nhìn thấy đầu tiên.

---

## 4. Việc CHỦ DỰ ÁN phải tự làm (tôi không làm thay được)

1. **Khai báo Google Search Console** cho `https://digilab.ddns.net` rồi nộp `sitemap.xml`. Không có bước này thì Google sẽ tiếp tục không bao giờ ghé, và mọi công sức SEO là vô nghĩa.
2. **Cân nhắc tên miền thật** thay cho DDNS — tên miền `.ddns.net` vừa khó tin với người dùng vừa bất lợi khi xếp hạng.
3. Có backlink đầu tiên: đăng vào hội nhóm BĐS, diễn đàn, trang cá nhân — Google cần đường để tìm tới.

## 5. Điều KHÔNG nên kết luận vội

**"0 đăng ký" chưa chứng minh được luồng đăng ký hỏng** — vì chưa có ai bấm vào nó lần nào. App đang theo hướng *browse-first* (xem không cần tài khoản), nên khách chỉ đăng ký khi muốn **làm gì đó** (lưu tin, đặt lịch xem, nhắn chủ nhà). Với 16 người xem tin và ~20 tin đăng, đơn giản là **chưa đủ nội dung để ai đó muốn hành động**.

Thứ tự đúng vẫn là: **có người vào** → có nội dung đáng xem → mới đến chuyện tối ưu tỉ lệ đăng ký. Đầu tư tiếp vào tinh chỉnh form/luồng lúc này là tối ưu cho nhóm người chưa tồn tại.

## 6. Cách đo lại sau này

```bash
# Phễu (đổi ngày theo nhu cầu)
docker exec proxy-proxymanager-1 sh -lc '
L=/data/logs/proxy-host-3_access.log
for s in "\"/\" " flutter_bootstrap.js main.dart.js /api/houses /api/auth/register; do
  printf "%-24s %s\n" "$s" "$(grep -v "\[Client 192.168" $L | grep -viE "bot|crawl|Headless" \
    | grep -- "$s" | grep -o "\[Client [0-9.]*\]" | sort -u | wc -l)"
done'

# Công cụ tìm kiếm đã ghé chưa
docker exec proxy-proxymanager-1 grep -c Googlebot /data/logs/proxy-host-3_access.log
```
