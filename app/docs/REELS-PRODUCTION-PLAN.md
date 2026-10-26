# Reels — Kế hoạch đưa lên chuẩn SẢN PHẨM

> Lập 2026-07-18. Bản đang live là **MVP/demo**, tài liệu này là lộ trình đưa nó thành sản phẩm hoàn chỉnh.
> Mọi con số hạ tầng bên dưới đã đo thực tế trên máy chủ, không phải ước đoán.

---

## 0. HIỆN TRẠNG & KHOẢNG CÁCH (thẳng thắn)

Bản đang chạy đủ để **demo/nghiệm thu ý tưởng**, KHÔNG đủ để mở cho người dùng thật đăng video.

| Hạng mục | MVP hiện tại | Chuẩn sản phẩm | Rủi ro nếu giữ nguyên |
|---|---|---|---|
| **Upload** | base64 → nạp hết vào RAM, cap 30MB, không resume | Presigned PUT thẳng lên object storage, resumable | Tốn RAM, fail với mạng yếu, không upload được video dài |
| **Lưu trữ** | Ổ đĩa local (`/uploads`) | Object storage (MinIO) + lifecycle | Không backup, không scale, đầy đĩa là sập cả app |
| **Chuẩn hoá video** | ❌ Không transcode | ffmpeg: H.264/AAC, ≤720×1280, faststart | **Video iPhone (HEVC/MOV) không phát được trên web/nhiều Android** |
| **Ảnh bìa** | ❌ Không có | Trích khung hình tự động (ffmpeg) | Feed xấu, user tự đăng ra thẻ đen |
| **Kiểm chứng file** | Chỉ theo đuôi file | ffprobe: codec, thời lượng, kích thước thật | Upload file giả mạo đuôi, video 10 phút |
| **Kiểm duyệt** | ❌ Không | Hàng đợi duyệt + report + auto-hide | **Nội dung bẩn/bản quyền công khai ngay** |
| **Chống lạm dụng** | ❌ Không rate limit | Giới hạn N reel/ngày/user | 1 user có thể làm đầy 409GB |
| **Lượt xem** | `+1` mỗi lần lướt qua | Unique + chỉ tính khi xem ≥3s | Số liệu ảo, thao túng được |
| **Feed reel** | Mới nhất, 20 cái, không phân trang | Cursor pagination + xếp hạng + ưu tiên chưa xem | Cạn nội dung, không giữ chân |
| **Trình phát** | Autoplay muted, cơ bản | Preload, double-tap like, bình luận, chia sẻ, tiết kiệm data | Trải nghiệm thua FB rõ rệt |
| **Đo lường** | ❌ Không | Watch time, completion, lỗi phát | Không biết reel có hiệu quả không |
| **Xoá/vòng đời** | Soft delete | Xoá file thật, archive reel cũ | Rác tích tụ vĩnh viễn |

---

## 1. KIẾN TRÚC MỤC TIÊU (tận dụng hạ tầng SẴN CÓ)

**Đã có sẵn:** 36 vCPU · 62GB RAM · 409GB trống · ffmpeg/ffprobe trên host · **MinIO đang chạy**.
→ Không cần mua thêm dịch vụ ngoài; làm chuẩn được ngay trên máy hiện tại.

```
[App] --(1) xin presigned URL--> [API]
[App] --(2) PUT video trực tiếp--> [MinIO: bucket reels-raw]
[App] --(3) báo "đã upload"------> [API] → tạo Reel(status=processing) + đẩy job
                                            │
                                   [Worker ffmpeg]
                                   ├─ ffprobe: validate codec/thời lượng/kích thước
                                   ├─ transcode → H.264/AAC, ≤720×1280, +faststart
                                   ├─ trích thumbnail (khung hình ~1s)
                                   └─ upload bản chuẩn → [MinIO: reels-pub] → Reel.status=ready
                                            │
[App] <--(4) feed chỉ lấy status=ready--- [API]
[App] <--(5) phát video qua /media/* ----- [NPM → MinIO] (cache dài, hỗ trợ range)
```

**Vì sao presigned + object storage:** bỏ hẳn base64 (hết vấn đề RAM), video không đi qua API, upload nặng không làm nghẽn backend, và tách được storage khỏi vòng đời container.

---

## 2. LỘ TRÌNH 4 GIAI ĐOẠN

### ✅ P0 — CHẶN RỦI RO — **ĐÃ XONG 2026-07-18** (đã deploy live)
**Quyết định đã chốt:** mọi user được đăng reel · **duyệt TRƯỚC khi hiển thị**.
Đã làm (migration `0051_reel_moderation`):
- Reel user đăng → `status='pending'`, **không hiện công khai** cho tới khi admin duyệt.
- Quota **5 reel/ngày/user** (429) + slowapi `10/hour` theo IP.
- **Validate magic bytes** (`ftyp`/EBML) — chặn file giả đuôi .mp4.
- `POST /reels/{id}/report` + chống báo trùng; **đủ 3 báo cáo → tự ẩn**.
- `GET /reels/mine` — user thấy trạng thái reel của mình (chờ duyệt / bị từ chối + lý do).
- Admin: `GET /reels/moderation/queue` + `POST /reels/{id}/moderate` (approve/reject/hide) + **màn "Kiểm duyệt Video Reel"** trong Admin dashboard (3 tab).
- Composer báo rõ **"Đã gửi, chờ duyệt"**; nút **Báo cáo** trong trình xem reel.

*(Nội dung P0 gốc — giữ để tham chiếu)*
| Việc | Chi tiết |
|---|---|
| Giới hạn quyền đăng | Composer reel chỉ mở cho **admin** (hoặc tắt cờ) đến khi P1 xong |
| Rate limit | Tối đa N reel/ngày/user (tái dùng cơ chế rate-limit sẵn có) |
| Validate server-side | Chặn theo dung lượng + đuôi file thật (magic bytes), từ chối sớm |
| Nút "Báo cáo reel" | Người dùng report → vào hàng đợi admin |
| Cảnh báo dung lượng | Alert khi `/uploads` vượt ngưỡng |

**Done khi:** không ai ngoài admin đăng được reel; không có kịch bản làm đầy đĩa; có đường báo cáo nội dung.

---

### 🟠 P1 — PIPELINE MEDIA CHUẨN — ✅ **XONG** (18/07/2026)
| Việc | Trạng thái |
|---|---|
| ~~MinIO bucket + presigned upload~~ | ❌ **BỎ** — `faceconst-minio` thuộc dự án khác, không expose công khai; dùng sẽ phải đụng hạ tầng dùng chung. Thay bằng **multipart streaming lên đĩa cục bộ** (409GB ≈ 30k reel). Object storage dời sang P3. |
| Upload không base64 | ✅ `POST /api/reels/upload` ghi theo khối 1MB → không phình RAM; FE dùng `http.MultipartRequest` |
| ffmpeg vào image | ✅ `ffmpeg 7.1.5` trong image backend |
| Hàng đợi job | ✅ Bảng `media_jobs` + container `ancu365-media-worker`; claim nguyên tử, job `running` treo >30' được nhả lại |
| Transcode + thumbnail | ✅ H.264/AAC ≤720×1280 giữ tỉ lệ, `+faststart`; ảnh bìa khung ~1s (dự phòng khung 0) |
| Validate ffprobe | ✅ ≤90s, chặn file giả (đọc metadata thật, không tin đuôi file) |
| Mở rộng schema | ✅ mig `0052`: `processing_status/error, original_path, duration_ms, width, height, size_bytes` |
| Trạng thái trên UI | ✅ Composer báo "đang xử lý + chờ duyệt"; `/api/reels/mine` trả trạng thái + lý do lỗi |
| Dọn bản gốc | ✅ Xoá sau khi transcode **và cả khi thất bại**; janitor quét file mồ côi >24h mỗi giờ |

**Đã đo trên môi trường thật** (video mô phỏng iPhone: HEVC 1080×1920, 3.0MB):

| | Vào | Ra |
|---|---|---|
| Codec | HEVC/H.265 *(web không phát được)* | **H.264** ✓ |
| Kích thước | 1080×1920 | 720×1280 |
| Dung lượng | 3.0 MB | **552 KB** (−82%) |
| faststart | — | có ✓ |
| Ảnh bìa | không | tự động ✓ |

Đường lỗi cũng đã kiểm chứng: file rác đội lốt `.mp4` → *"File không phải video hợp lệ"*; video 100s → *"Video dài 100s, tối đa 90s"*; `upload_id` giả mạo (`../../etc/passwd`) → HTTP 400. Reel hỏng **không lọt vào feed công khai** (feed lọc `ready` + `published`).

> **Hai lỗi tự tìm ra khi test và đã vá:**
> 1. *Thử lại vô ích* — lỗi do chính file (không phải video, quá dài) vẫn retry đủ 3 lượt, user phải chờ ~40s mới biết. Tách `PermanentVideoError` → báo lỗi ngay (**đo lại: 7s**).
> 2. *Rò rỉ đĩa* — file gốc chỉ được xoá ở nhánh thành công, nên mỗi reel hỏng để lại 1 file vĩnh viễn; ngoài ra upload xong mà không tạo reel (user bỏ ngang / bị rate limit chặn) cũng để lại file mồ côi. Thêm `_fail()` dọn sạch + `_sweep_orphans()` quét mỗi giờ (đã test: file >24h bị dọn, file mới **không** bị dọn nhầm).

**Done khi:** ~~user quay bằng iPhone (MOV/HEVC) đăng lên → phát được trên mọi trình duyệt/thiết bị, có ảnh bìa tự động, backend không phình RAM.~~ ✅ Đạt.

---

### 🟡 P2 — TRẢI NGHIỆM & AN TOÀN — ✅ **XONG** (18/07/2026)
| Nhóm | Trạng thái |
|---|---|
| **Trình phát** | ✅ Nạp trước 1 trang kề · double-tap thích (kèm tim bay, KHÔNG bỏ thích để tránh lỡ tay) · bottom-sheet bình luận · chia sẻ (chép link) · tạm dừng khi app xuống nền · **tiết kiệm dữ liệu** (nút bật/tắt, lưu bền — tắt tự phát + tắt nạp trước) · thanh tiến trình |
| **Kiểm duyệt** | ✅ Đã xong từ P0 (hàng đợi admin, tự ẩn khi đủ 3 báo cáo, duyệt/từ chối kèm lý do) |
| **Số liệu đúng** | ✅ Bảng `reel_views` + ràng buộc unique `(reel_id, viewer_key)`; chỉ tính khi xem **≥3s**; khách dùng khoá phiên lưu bền nên cũng được khử trùng |
| **Feed** | ✅ Cursor `"<created_at>|<id>"` (không lặp/nhảy như offset) · ưu tiên reel **chưa xem**, thiếu mới bù bằng reel đã xem |
| **Bình luận reel** | ✅ **Tái dùng** `social_comments` + cột `target_type` — thừa hưởng nguyên cây reply, tombstone, `reply_count` thay vì dựng bảng gần giống hệt |

**Đã đo:** xem 1s → không tính · xem 5s → +1 · gọi lại 5 lần → **vẫn +1** (tua lại không ăn gian) · người xem khác → +1 · cursor lật 3 trang không trùng · cursor rác → 400.

> **Rủi ro lường trước và đã chặn:** dùng chung bảng bình luận nghĩa là reel id=6 và bài viết id=6 có thể **thấy bình luận của nhau**. Đã thêm `target_type` vào **cả 4** truy vấn social cũ và kiểm chứng: bài viết id=6 không thấy bình luận của reel id=6; 100% bình luận cũ giữ nguyên `target='post'`.

**Done khi:** ~~trải nghiệm ngang FB Reels ở mức cơ bản và có công cụ xử lý nội dung xấu.~~ ✅ Đạt.

---

### 🟢 P3 — TĂNG TRƯỞNG & VẬN HÀNH — ✅ phần làm được đã xong (18/07/2026)
- ✅ **Xếp hạng** `?sort=hot`: `(1 + like×3 + bình luận×5 + view) / (giờ_tuổi + 2)^1.5`, **nhân đôi** cho khối user chọn trong khảo sát (`user_preferences`). Nhân chứ không cộng → hợp gu là điểm cộng, không đè lên chất lượng. *Đã đo: khối được quan tâm nhảy từ vị trí 5 → 2, nhưng reel có tương tác thật vẫn giữ đầu bảng.*
  - `sort=hot` **không** dùng được cursor (điểm đổi liên tục) → trả **400** thay vì phân trang sai ngầm.
- ✅ **Analytics** `GET /api/reels/analytics/summary` (chỉ admin): phân bố trạng thái, **tỉ lệ transcode hỏng**, dung lượng đĩa, tổng view/like/bình luận, top 10 reel. Hiện thành dải số liệu ngay trên màn kiểm duyệt.
- ✅ **Lifecycle** (worker chạy mỗi giờ): reel xoá mềm >30 ngày → xoá hẳn file, **giữ bản ghi làm tombstone**; `media_jobs` xong >30 ngày → xoá. *Cố ý KHÔNG xoá `reel_views`* — mất dữ liệu đó thì người cũ xem lại sẽ bị đếm thêm lần nữa.

**⏸ Hoãn có chủ đích (cần bạn quyết định, không phải quên):**
- **HLS + CDN** — cần dịch vụ ngoài và **chi phí định kỳ**. MP4 + faststart đang đủ ở quy mô hiện tại; chỉ đáng làm khi băng thông thành nút thắt thật.
- **Object storage** — `faceconst-minio` thuộc dự án khác. Muốn dùng phải đụng hạ tầng dùng chung; đĩa cục bộ còn ~409GB (≈30k reel) nên chưa cấp thiết.
- **Chi phí băng thông** — chưa có công cụ đo ở tầng ancu365; gắn vào NPM/hạ tầng chung nên để bạn quyết.

---

## 3. BỐN QUYẾT ĐỊNH CẦN CHỐT (ảnh hưởng thiết kế)

1. **Ai được đăng reel?**
   (a) Chỉ admin (giai đoạn đầu) · (b) Chủ nhà + đơn vị thi công · (c) Mọi user.
   → *Khuyến nghị: (b)* — đúng mục tiêu kinh doanh (khoe nhà/công trình), giảm rác so với (c).

2. **Kiểm duyệt trước hay sau?**
   (a) Duyệt trước khi hiện · (b) Hiện ngay + report/auto-hide.
   → *Khuyến nghị: (a) khi ít user (kiểm soát chất lượng), chuyển (b) khi lượng đăng tăng.*

3. **Định dạng phát:** MP4 faststart trước hay làm HLS ngay?
   → *Khuyến nghị: MP4 trước* (đơn giản, đủ tốt), HLS ở P3 khi traffic tăng.

4. **Thời lượng & chất lượng tối đa:** 60s hay 90s? 720p hay 1080p?
   → *Khuyến nghị: 60s / 720×1280* — cân bằng chi phí băng thông và chất lượng.

---

## 4. RỦI RO & CHI PHÍ

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| **Băng thông** (chi phí lớn nhất của video) | Cao | 720p, thumbnail ở feed (không autoplay ở thanh reel), cache CDN, đo sớm |
| Nội dung bẩn / bản quyền | Cao | Kiểm duyệt + report + nhật ký + điều khoản UGC |
| Đầy đĩa | Trung bình | Object storage + quota/user + xoá bản gốc + alert |
| Video không phát được | Trung bình | **Transcode chuẩn hoá (P1) là cách duy nhất xử lý triệt để** |
| Transcode nghẽn | Thấp | 36 vCPU dư sức; giới hạn job song song |

**Ước lượng dung lượng:** 720p ~60s ≈ 8–15MB → 409GB ≈ **~30.000 reel**. Không phải nút thắt trước mắt; băng thông mới là.

---

## 5. KHUYẾN NGHỊ NGAY VỚI BẢN ĐANG LIVE

Tính năng đã deploy và **bất kỳ user đăng nhập nào cũng đăng được video** → nên xử lý trong hôm nay:

> **Làm P0 ngay**: khoá composer về admin-only + rate limit + nút báo cáo. **Giữ nguyên phần hiển thị** reel demo (đẹp, không rủi ro) để anh em vẫn xem/nghiệm thu được.
> Phương án thay thế nếu muốn tuyệt đối an toàn: tắt cờ `REELS_ENABLED=false` (ẩn toàn bộ) cho tới khi P1 xong.

**Tổng effort P0→P2: ~2–3 tuần** cho một sản phẩm reel hoàn chỉnh, chạy trọn trên hạ tầng hiện có.

---

## 6. TIÊU CHÍ "HOÀN CHỈNH" (Definition of Done cho cả tính năng)
- [ ] Người dùng quay bằng điện thoại bất kỳ → đăng → phát mượt trên web + mobile
- [ ] Có ảnh bìa tự động, trạng thái xử lý rõ ràng, lỗi có thể thử lại
- [ ] Không thể lạm dụng: rate limit, quota, validate thật, kiểm duyệt + report
- [ ] Số liệu xem/like trung thực; admin có dashboard xử lý nội dung
- [ ] Feed reel có phân trang, không lặp, ưu tiên nội dung chưa xem
- [ ] Có cờ tắt khẩn cấp + alert dung lượng/băng thông
- [ ] Có test (upload, transcode fail, playback) + rollout theo cờ
