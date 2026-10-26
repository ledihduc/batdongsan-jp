# Kế hoạch trả nợ kỹ thuật & sửa lỗi — ancu365

> Lập 2026-07-19. Mọi mục đều đã **điều tra lại bằng code thật**, không dựa vào tài liệu cũ.
> Trạng thái nền: backend 993 test pass · frontend 665 test pass · 0 fail.

---

## 0. HAI KẾT LUẬN CŨ CỦA TÔI ĐÃ SAI — ĐÍNH CHÍNH TRƯỚC

Khi kiểm tra lại để viết kế hoạch này, hai mục tôi từng báo là "nợ" hoá ra **không phải nợ**:

| Tôi từng nói | Thực tế |
|---|---|
| "Role `operator` không tồn tại → endpoint điều phối lead chỉ admin dùng được. **Khoảng hở phân quyền**" | **SAI.** `require_operator`/`require_contractor` đã được gỡ có chủ đích ngày 14/07 (`app/auth.py:98`). Đây là **quyết định thiết kế đã chốt** (role-model "Option A"): điều phối lead dùng `require_admin`, quyền nhà thầu kiểm bằng **ownership** (`_own_contractor_or_admin`), operator BĐS dùng `resolve_actor_context`. Không có lỗ hổng nào. |
| "`contracts/batch-renew`, `meter-readings/batch` có API nhưng thiếu màn" | **SAI.** Cả hai đều đã được frontend gọi. |

**Nguyên nhân:** `BUSINESS-FLOWS.md` viết ngày 18/07 nhưng mô tả trạng thái trước 14/07, và tôi đọc lại tài liệu đó thay vì đọc code. Đúng cùng loại lỗi đã khiến tôi làm mất bước kiểm magic bytes ở P1 — **tài liệu nói tính năng từng tồn tại, không đảm bảo nó còn/chưa tồn tại**.

→ **Việc #0: sửa `BUSINESS-FLOWS.md`** cho khớp thực tế. 30 phút. Nếu không, lần sau lại có người (kể cả tôi) lập kế hoạch dựa trên nó.

---

## 1. DANH SÁCH NỢ THẬT — đã xác minh

| # | Mục | Mức độ | Công | Rủi ro nếu để |
|---|---|---|---|---|
| A | Test chập chờn `test_message_is_redacted_before_log` | 🔴 Cao | **15 phút** | CI không bao giờ xanh ổn định → mất tác dụng cổng chặn |
| B | Tài liệu BUSINESS-FLOWS sai thực tế | 🔴 Cao | 30 phút | Lập kế hoạch sai (đã xảy ra 1 lần) |
| C | Test FE cho Reels: 6/7 file ~0% (741/773 dòng chưa phủ) | 🟠 TB | 1–3 ngày tuỳ phương án | Sửa UI reel không có gì canh |
| D | Chưa nối CI (bộ PostgreSQL chạy tay) | 🟠 TB | 0.5–1 ngày | Test có mà không ai chạy = không có test |
| E | Chính tả `hủy`/`huỷ` lẫn lộn | 🟢 Thấp | 15 phút | Thiếu chỉn chu, không ảnh hưởng chức năng |
| F | Tenant portal (U2) chưa xây | 🟢 Thấp | — | Hoãn có chủ đích, không phải nợ |

---

## 2. TỪNG MỤC: NGUYÊN NHÂN & PHƯƠNG ÁN

### A. Test chập chờn — đã tìm ra nguyên nhân gốc

**Không phải "test xấu" chung chung.** `/api/client-logs` có `@limiter.limit("120/hour")` tính theo IP, mà slowapi lưu bộ đếm **trong bộ nhớ dùng chung cả tiến trình pytest**. Mọi TestClient đều mang cùng một IP (`testclient`), nên khi chạy full suite, hạn ngạch cạn trước lúc test này chạy → POST trả **429** → không có log để bắt → `assert capture_client_logs` fail.

Chạy riêng thì pass vì bộ đếm còn mới. Đúng kiểu lỗi "xanh khi chạy lẻ, đỏ khi chạy chung".

| Phương án | Được | Mất |
|---|---|---|
| **A1. Tắt limiter trong fixture của test đó** ⭐ | 15 phút, đúng bản chất (test này kiểm *redaction*, không kiểm rate limit), đã dùng đúng cách này ở test reel | Không kiểm rate limit ở đây — nhưng vốn dĩ nó không nhằm kiểm điều đó |
| A2. Reset bộ đếm limiter giữa các test (fixture autouse toàn cục) | Sạch cho mọi test tương lai | Đụng conftest gốc, ảnh hưởng ~1000 test đang xanh |
| A3. Đánh dấu `xfail` | 1 phút | Che lỗi, không sửa. **Không nên** |

→ **Khuyến nghị A1.** Nếu sau này còn test khác dính, mới nâng lên A2.

### C. Test FE cho Reels — điểm nghẽn thật nằm ở đâu

`ApiClient` là `const ApiClient()` và gọi thẳng hàm cấp cao `http.get/post/...` (`api_client.dart:83,94,106,130`). **Không có chỗ tiêm `http.Client` giả** → không mock được mạng.

| Phương án | Được | Mất |
|---|---|---|
| **C1. Bỏ `reel_api.dart` (83 dòng), test 4 file WIDGET bằng API giả** ⭐ | Phủ được **585/773 dòng** phần có logic UI thật. **Không đụng** `ApiClient` — lớp mạng lõi của toàn app | `reel_api.dart` vẫn 1.2%. Nhưng nó là lớp ánh xạ mỏng, hỏng sẽ lộ ngay ở integration test backend |
| C2. Thêm tham số `http.Client` tuỳ chọn vào `ApiClient` | Test được cả tầng API, đúng chuẩn | **Đụng lớp mạng của TOÀN BỘ app** — mọi màn hình đều đi qua đây. Rủi ro hồi quy cao nhất trong danh sách này, đổi lấy 83 dòng |
| C3. Làm cả hai | Phủ cao nhất | Gộp một thay đổi rủi ro cao vào một đợt lẽ ra an toàn |

→ **Khuyến nghị C1.** Lý do: 83 dòng ánh xạ JSON không đáng để mạo hiểm lớp mạng của cả ứng dụng. Nếu sau này cần C2, làm thành **một đợt riêng, có test hồi quy riêng**, không trộn vào việc khác.

**Thứ tự trong C1** (dễ → khó, dừng được ở bất kỳ đâu):
1. `reel_comments_sheet.dart` (135 dòng) — chỉ cần API giả
2. `reel_moderation_screen.dart` (131 dòng) — chỉ cần API giả
3. `reel_bar.dart` (76 dòng) — cần giả `video_player`
4. `reel_viewer_screen.dart` (230 dòng) — khó nhất: `video_player` + đo thời lượng xem + cử chỉ
5. `reel_composer_screen.dart` (89 dòng) — cần giả `image_picker`

Làm hết 1–2 đã đưa tổng từ 4.1% lên **~39%** trong ~nửa ngày.

### D. Nối CI

| Phương án | Được | Mất |
|---|---|---|
| **D1. GitHub Actions: backend + FE, PostgreSQL bằng service container** ⭐ | Chuẩn ngành, có sẵn Postgres | Dự án **chưa phải git repo** (`Is a git repository: false`) → phải khởi tạo git + đẩy remote trước |
| D2. Cron trên chính máy chủ, chạy test rồi báo kết quả | Không cần git/remote, hợp với cách deploy thủ công hiện tại | Không chặn được commit hỏng (vì không có commit); chỉ là "báo động sau khi đã hỏng" |
| D3. Hook thủ công: script `./check.sh` chạy trước khi deploy | 30 phút, phù hợp quy mô hiện tại | Phụ thuộc người nhớ chạy |

→ **Khuyến nghị: D3 trước, D1 khi lên git.** Dự án đang deploy thủ công bằng `docker run`, chưa có git — dựng CI đầy đủ lúc này là làm hạ tầng cho một quy trình chưa tồn tại. Một script `check.sh` (analyze + test BE + test FE + probe nguồn) chạy trước mỗi lần deploy giải quyết 80% giá trị với 5% công.

### E. Chính tả `hủy` / `huỷ`

App dùng `hủy` 16 chỗ, `huỷ` 3 chỗ. Cùng một luồng đặt lịch mà `house_detail_screen.dart:564` viết *"Bạn đã huỷ lịch xem"* còn màn Lịch sử viết *"Đã hủy lịch hẹn"*.

Cả hai đều đúng tiếng Việt — đây là chọn quy ước, không phải sửa lỗi. **Cần bạn chốt.** Theo số đông trong code thì nên thống nhất về `hủy`.

---

## 3. LỘ TRÌNH ĐỀ XUẤT

### Đợt 1 — "dọn nền" (≈1 ngày) ⭐ nên làm ngay
- **A1** sửa test chập chờn (15 phút)
- **B** sửa `BUSINESS-FLOWS.md` (30 phút)
- **E** thống nhất chính tả — *nếu bạn chốt* (15 phút)
- **D3** script `check.sh` (30 phút)
- **C1 bước 1–2**: test `reel_comments_sheet` + `reel_moderation_screen` (~nửa ngày)

**Kết quả:** test suite xanh ổn định, có cổng kiểm trước deploy, tài liệu tin được, độ phủ reel FE 4.1% → ~39%.

### Đợt 2 — "phủ nốt phần khó" (≈1–2 ngày)
- **C1 bước 3–5**: `reel_bar`, `reel_viewer_screen`, `reel_composer_screen` (cần giả lập kênh nền tảng)

**Kết quả:** độ phủ reel FE ~90%.

### Đợt 3 — chỉ khi thực sự cần
- **C2** tiêm phụ thuộc vào `ApiClient` — làm riêng, có test hồi quy riêng
- **D1** CI đầy đủ — sau khi dự án lên git

---

## 4. ĐIỀU TÔI KHUYÊN KHÔNG LÀM LÚC NÀY

| Việc | Vì sao chưa nên |
|---|---|
| Reels P3 (HLS+CDN, object storage) | Tốn tiền định kỳ cho vấn đề chưa xảy ra. MP4+faststart đang đủ, đĩa còn 406GB |
| Dữ liệu quy hoạch | 16 tin đăng — xem `PLANNING-DATA-PLAN.md` |
| Tenant portal U2 | Hoãn có chủ đích, không phải nợ |
| Đưa độ phủ FE toàn app từ 16.6% lên cao | Phần lớn code chưa phủ là màn hình cũ đang chạy ổn. Phủ theo **code mới viết** (diff-cover) có giá trị hơn phủ đều |

---

## 5. CẦN BẠN QUYẾT

1. **Chạy Đợt 1 luôn không?** Đây là phần tôi tự tin nhất về tỉ lệ giá trị/công.
2. **Chính tả**: thống nhất `hủy` (theo số đông) hay `huỷ`?
3. **C1 hay C2** cho test FE? Tôi khuyến nghị C1 — không đụng lớp mạng của toàn app chỉ vì 83 dòng.
4. **Dự án có kế hoạch lên git không?** Câu trả lời quyết định D1 hay D3.
