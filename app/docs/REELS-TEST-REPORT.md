# Báo cáo kiểm thử & độ phủ — Video Reel (P0 → P3)

> Lập 2026-07-18 · cập nhật sau khi dựng hạ tầng đo độ phủ đầy đủ.
> **Mọi con số dưới đây là kết quả xuất ra từ công cụ đo, không phải tôi tự tính.**

---

## 1. CÔNG CỤ ĐO ĐÃ CÀI

| Công cụ | Phiên bản | Dùng để |
|---|---|---|
| `coverage[toml]` | 7.15.2 | Đo độ phủ **dòng + nhánh** cho Python |
| `pytest-cov` | 5.0.0 | Gắn coverage vào pytest |
| `diff-cover` | 9.2.0 | Đo độ phủ **riêng phần code vừa đổi** (chỉ số hữu ích hơn tổng thể) |
| `lcov` / `genhtml` | 2.x | Đọc & tổng hợp báo cáo Flutter (chạy trong container, không cài lên host) |
| `flutter test --coverage` | Flutter stable | Sinh `coverage/lcov.info` cho Dart |

Cấu hình đo nằm ở `ancu365-backend/pyproject.toml` — bật `branch = true`, vì **chỉ đo dòng sẽ báo "xanh" cho một `if` chưa bao giờ đi vào nhánh `else`**.

Đầu ra: `htmlcov/index.html` (xem trực quan), `coverage.xml` (cho CI), `coverage.json` (để đối chiếu máy đọc).

---

## 2. KẾT QUẢ BACKEND — 100.00%

Xuất trực tiếp từ `coverage report`:

```
Name                                    Stmts   Miss Branch BrPart    Cover
---------------------------------------------------------------------------
app/routers/reels.py                      357      0    112      0  100.00%
app/services/media/video_processor.py      73      0     12      0  100.00%
app/workers/media_worker.py               173      0     38      0  100.00%
---------------------------------------------------------------------------
TOTAL                                     603      0    162      0  100.00%
```

Đối chiếu từ `coverage.json` (số máy đọc, không qua định dạng bảng):

```
num_statements   = 603      covered_lines    = 603     missing_lines    = 0
num_branches     = 162      covered_branches = 162     missing_branches = 0
percent_covered  = 100.0    excluded_lines   = 2
```

### 2 dòng bị loại trừ — giải trình đầy đủ

```
app/workers/media_worker.py:296   if __name__ == "__main__":
app/workers/media_worker.py:297       main()
```

Đây là **điểm vào khi chạy trực tiếp**, không phải logic nghiệp vụ — bản thân `main()` đã được test riêng (7 test trong `TestMainLoop`). Cấu hình loại trừ trong `pyproject.toml` chỉ chứa các mẫu không-phải-logic (`__main__`, `TYPE_CHECKING`, `abstractmethod`, `...`). **Không có nhánh xử lý lỗi nào được đưa vào danh sách loại trừ để làm đẹp con số.**

### Những nhánh trước đây tôi nói "không đáng phủ" — nay đã phủ hết

Ở bản báo cáo trước tôi để lại 13 dòng và biện hộ rằng ép phủ sẽ tạo test giả tạo. **Điều đó sai** — tất cả đều phủ được bằng monkeypatch chuẩn, và mỗi test đều kiểm chứng một hành vi thật:

| Nhánh | Test đã viết | Bảo vệ điều gì |
|---|---|---|
| `ffprobe` timeout | `test_ffprobe_TREO_la_loi_TAM_THOI` | Máy tải nặng → treo. Phải là lỗi **tạm thời** (cho retry), đánh dấu vĩnh viễn sẽ **vứt oan video của user** |
| `ffmpeg` timeout trong `_run` | `TestTimeoutFfmpeg` (3 test) | Job treo vô hạn bị chặn; vẫn là lỗi tạm thời |
| `duration` không đọc được | `test_duration_KHONG_doc_duoc_thi_ve_0_chu_khong_no` (4 ca) | ffprobe trả `"N/A"` → `float()` ném ValueError. Không bắt thì **worker sập giữa chừng** |
| `OSError` khi dọn file (2 chỗ) | `test_khong_xoa_duoc_file_do_dang...` | Đĩa chỉ-đọc → lỗi thứ cấp **không được che mất lỗi gốc 413** mà user cần biết |
| `OSError` ở `getmtime` | `test_file_BIEN_MAT_giua_luc_quet` | Tranh chấp thật: worker xoá file đúng lúc janitor đọc mtime |
| Nhánh vòng lặp đọc nhiều khối | `test_file_NHIEU_KHOI_ghi_du...` | File >1MB: chữ ký chỉ kiểm khối đầu, kiểm lại sẽ **chặn nhầm file thật** |
| Xoá bình luận khi reel đã mất | `test_xoa_binh_luan_khi_reel_da_bien_mat` | Bình luận mồ côi không làm nổ thao tác xoá |

---

## 3. KẾT QUẢ FRONTEND — 4.1% → 73.5%

Xuất từ `lcov --list` (19/07, sau khi viết 68 widget test):

```
reel_comments_sheet.dart      91.9%   135 dòng
admin/reel_moderation_screen  90.3%   134
reel_bar.dart                 84.2%    76
reel_viewer_screen.dart       78.6%   234
reel_composer_screen.dart     52.7%    91
reel_model.dart              100.0%    29
reel_api.dart                  6.0%    83   ← cố ý bỏ, xem dưới
                    Tổng:     73.5%   782
```

Toàn app Flutter: **19.0%** (4.451 / 23.437). Bộ test FE: **733 pass / 0 fail**.

### Hai thứ chặn đường, và cách xử lý

**`ReelApi` không tiêm được** — widget dùng `static const _api = ReelApi()`.
Đã đổi thành tham số `api` tuỳ chọn ở 4 widget (`this.api = const ReelApi()`),
nên mã sản phẩm giữ nguyên hành vi, chỉ mở một khe cho test. **Không đụng
`ApiClient`** — lớp mạng của toàn app — đúng như phương án C1 đã chốt.

**`video_player` cần kênh nền tảng** — đã viết `_fake_video_player.dart` cài
`VideoPlayerPlatform.instance` giả. Nhờ đó test được cả nhánh video hỏng
("Không phát được video này") lẫn tắt/bật tiếng.

> **Bẫy đã mắc khi viết giả lập:** bắn sự kiện `initialized` bằng
> `Future.microtask` thì controller chưa kịp lắng nghe, mà broadcast stream vứt
> luôn sự kiện không người nghe → `initialize()` treo vĩnh viễn. Phải phát
> trong `onListen`.

### `reel_api.dart` 6% — cố ý

83 dòng ánh xạ JSON. Để test được phải thêm chỗ tiêm `http.Client` vào
`ApiClient`, tức đụng lớp mạng mà **mọi màn hình** đi qua — rủi ro hồi quy cao
nhất trong cả danh sách, đổi lấy 83 dòng. Sai sót ở lớp này lộ ngay tại 39 test
tích hợp backend. Nếu làm, nên là một đợt riêng có test hồi quy riêng.

### `reel_composer_screen.dart` 52.7%

Phần chưa phủ là luồng **chọn video từ thư viện** — cần giả `image_picker`
(kênh nền tảng khác). Phần đã phủ là các chốt chặn quan trọng: không cho đăng
khi chưa có video, chọn sẵn khối theo feed, giới hạn ký tự.

---

## 4. ✅ 19 TEST FRONTEND FAIL — ĐÃ SỬA XONG

**Trước: 642 pass / 19 fail → Sau: 665 pass / 0 fail.**

Không test nào được "sửa cho qua". Mỗi ca đều truy nguyên nhân rồi mới viết lại:

| Nhóm | Số | Nguyên nhân THẬT | Cách xử lý |
|---|---|---|---|
| `planning_map_provider` | 3 | Code **cố ý** đổi từ `state=error` sang tick tạm thời. Doc comment ghi rõ: *"Tách khỏi state.error để tránh ErrorCard modal kẹt overlay"*. Test mã hoá hành vi LỖI cũ | Viết lại theo hành vi đúng + **thêm 3 test canh hồi quy** |
| `widget_test.dart` | 1 | Test **mẫu mặc định của Flutter** ("Counter increments") — app chưa bao giờ có counter, fail từ ngày khởi tạo dự án | Thay bằng **smoke test thật**: app dựng được, không nuốt lỗi, chạy được cả nhánh có/không Firebase |
| `AnalyticsHomeScreen` | 7 | Widget thêm phụ thuộc `Provider<TelemetryService>`, test dựng trần → `ProviderNotFoundException` | Thêm helper `test/helpers/pump_app.dart` |
| `PeriodSwiper` | 4 | Cùng nguyên nhân trên | Dùng `pumpApp()` |
| `FilterBottomSheet` | 2 | Cùng nguyên nhân — bấm Áp dụng ném exception nên sheet **không bao giờ đóng** | Thêm provider vào 3 chỗ pump |
| `DrillRoomScreen` | 1 | Màn đã đổi từ `CircularProgressIndicator` sang **skeleton** (`DsRowSkeleton`) — cải tiến UX | Sửa kỳ vọng + khẳng định KHÔNG còn spinner |
| `AppointmentStatusChip` | 1 | **Sai chính tả dấu thanh**: test đòi `"Đã huỷ"`, widget ghi `"Đã hủy"` — hai chuỗi Unicode khác nhau | Sửa test theo widget (app dùng `hủy` 16 chỗ vs `huỷ` 3 chỗ) |

**Điểm chung:** 18/19 là **test cũ so với code**, 1 là test rác chưa bao giờ đúng. **Không có lỗi sản phẩm nào** trong nhóm này — nhưng phải điều tra từng cái mới kết luận được, vì "sửa test cho xanh" mà code hỏng thật thì tệ hơn để nguyên đỏ.

**Phát sinh thêm — chưa sửa vì là quyết định sản phẩm:** app dùng lẫn `hủy` (16 chỗ) và `huỷ` (3 chỗ), trong đó `house_detail_screen.dart:564` hiện *"Bạn đã huỷ lịch xem"* còn màn Lịch sử đặt lịch hiện *"Đã hủy lịch hẹn"* — **cùng một luồng, hai cách viết**. Cần bạn chốt dùng kiểu nào rồi thống nhất.

---

## 5. PHÂN BỐ 185 TEST BACKEND

| Tệp | Test | Loại | Trọng tâm |
|---|---|---|---|
| `tests/services/media/test_video_processor.py` | 37 | Unit — ffmpeg **thật** | probe/validate/transcode/thumbnail, timeout, phân loại lỗi |
| `tests/services/media/test_media_worker.py` | 42 | Unit — SQLite | claim nguyên tử, tranh chấp, retry, dọn rác, `main()` |
| `tests/api/test_reels_routes.py` | 91 | Integration — SQLite | 20 endpoint, phân quyền, biên |
| `tests/api/test_reels_ranking_pg.py` | 10 | Integration — **PostgreSQL thật** | `sort=hot` + cá nhân hoá |
| `tests/e2e/test_reel_full_lifecycle.py` | 5 | **E2E** — ffmpeg thật | Trọn vòng đời |
| **Tổng** | **185** | | **185 pass / 0 fail**, ~38 giây |

### Vì sao phải có bộ PostgreSQL riêng

Công thức xếp hạng dùng `extract(epoch ...)` và `power()` — **SQLite không có**. Nếu chỉ test trên SQLite, nhánh `sort=hot` không bao giờ được chạy mà báo cáo vẫn "xanh": đúng kiểu lỗi nguy hiểm nhất vì nó tạo cảm giác an toàn giả.

Chạy trên container PostgreSQL **dựng riêng cho test**, không đụng `faceconst-db`. Không set `REELS_TEST_PG_URL` thì tự skip.

---

## 6. LỖI THẬT PHÁT HIỆN ĐƯỢC KHI VIẾT TEST

### 6.1 LỖ HỔNG BẢO MẬT — mất kiểm tra magic bytes (do tôi gây ra ở P1)

**Mức độ: Cao.** Test `test_file_khong_phai_video_bi_chan` fail ngay lần chạy đầu.

P0 có kiểm **chữ ký nhị phân** để chặn file giả mạo đuôi. Khi tôi thay upload base64 bằng **streaming** ở P1, tôi viết lại endpoint và **làm mất bước này** — chỉ còn kiểm đuôi file, thứ client hoàn toàn tự đặt.

Hệ quả: file bất kỳ đặt tên `.mp4` được ghi xuống đĩa, tối đa 120MB/lần, 20 lần/giờ/IP; chỉ bị phát hiện khi worker chạy ffprobe, hoặc nằm tới 24h nếu không tạo reel. **Đây là đường làm đầy đĩa** — đúng thứ P0 đặt ra để chặn.

Đã vá bằng `_ensure_video_magic()` kiểm ngay ở khối 1MB **đầu tiên**, trước khi ghi tiếp. Kiểm chứng trên môi trường thật sau deploy:

```
file rác 300KB → HTTP 400 "File không phải video hợp lệ", KHÔNG ghi gì
video thật     → HTTP 201 (đường dùng bình thường không ảnh hưởng)
```

> **Bài học:** kế hoạch ghi P0 "✅ validate magic bytes" và tôi đã tin vào dòng đó khi làm P1. Tài liệu nói tính năng *từng* tồn tại, không đảm bảo nó *còn* tồn tại. Chỉ có test mới giữ được.

### 6.2 Kỳ vọng của TÔI sai, không phải sản phẩm sai

Test giả định báo cáo trùng trả **409**. Đọc code thì API cố ý **idempotent**: trả 201 nhưng không cộng đếm — đúng hơn, vì client mạng chập chờn gửi lại không bị báo lỗi vô cớ. Tôi sửa test theo sản phẩm và đổi tên thành `test_bao_cao_TRUNG_khong_tang_dem`.

---

## 7. NHỮNG BẤT BIẾN ĐƯỢC BẢO VỆ

**Bảo mật & chống lạm dụng**
- `upload_id` giả mạo (`../../etc/passwd`, `/etc/passwd`, `raw_x.mov; rm -rf /`, mã hoá URL) → 400
- File giả mạo đuôi → chặn **ngay ở cửa upload**, không nằm lại đĩa
- Video vượt giới hạn → 413, file dở dang bị dọn (kể cả khi `os.remove` lỗi)
- Quá 5 reel/ngày → 429; reel cũ hơn 24h không tính vào quota
- `interests` rác từ client (kể cả chuỗi SQL injection) bị lọc trước khi vào truy vấn
- Analytics: khách 401, host 403, admin 200

**Tính đúng đắn của số liệu**
- Xem 1s không tính; xem 3s tính 1; **tua lại 5 lần vẫn là 1**
- Cùng user trên 2 thiết bị = 1 lượt xem
- Báo cáo trùng không cộng dồn (1 người **không** thể tự ẩn reel người khác)

**Cách ly dữ liệu** (rủi ro của việc dùng chung bảng bình luận)
- Reel id=777 và bài viết id=777 **không thấy bình luận của nhau**
- Không trả lời chéo, không xoá chéo được

**Độ bền của worker**
- Lỗi vĩnh viễn → **không retry**, báo user ngay · lỗi tạm thời → quay lại hàng đợi, **không xoá file gốc**
- Thất bại → dọn cả bản gốc lẫn file dở dang
- Janitor xoá file mồ côi >24h nhưng **không đụng** file mới / file còn reel trỏ tới / reel đang hiển thị dù rất cũ
- 1 job hỏng **không làm chết** worker; session luôn được đóng
- Job treo >30 phút được nhả lại; hai worker không cùng giành 1 job

**Xếp hạng** (chỉ PostgreSQL)
- Bình luận×5 > thích×3 > xem×1 · reel cũ bị giảm điểm theo tuổi
- **Reel mới chưa tương tác vẫn có điểm** ← canh đúng lỗi đã gặp (thiếu số hạng nền → `0 × 2 = 0`)
- Hợp gu được đẩy lên nhưng **không đè bẹp** reel có tương tác thật

---

## 8. GHI CHÚ KỸ THUẬT

**Vì sao dùng ffmpeg thật thay vì mock.** Giá trị của `video_processor` nằm ở chỗ nó gọi ffmpeg *đúng cách*. Mock đi thì test chỉ kiểm tra chính cái mock. Test dựng video HEVC 1080×1920 thật rồi kiểm đầu ra đúng là H.264 720×1280 có faststart.

**Vì sao mỗi test có DB riêng.** Cách phổ biến là chia sẻ 1 connection rồi rollback. Nhưng endpoint gọi `commit()`/`rollback()` thật — đường xử lý `IntegrityError` của lượt xem *phụ thuộc vào đúng hành vi đó*. Tôi thử `join_transaction_mode="create_savepoint"` và nó làm hỏng việc cô lập giữa các test. Giải pháp: dựng schema **một lần** vào file mẫu, mỗi test copy ra dùng riêng — cũng là lý do bộ test nhanh (**226s → 12s**).

**Hai cái bẫy đã mắc và cách tránh.**
1. `dependency_overrides[get_db]` **phải** là generator function. `lambda: iter([db])` khiến FastAPI truyền thẳng iterator vào endpoint → `AttributeError: 'list_iterator' object has no attribute 'get'`.
2. `flutter pub get` và `flutter test` phải chạy **cùng một `docker run`** — pub cache nằm trong container, tách ra sẽ lỗi `No such file or directory` cho `vector_math`.

---

## 9. CÔNG VIỆC CÒN LẠI

1. **Frontend** — 6/7 file reel gần 0% (mục 3). Cần cho phép tiêm phụ thuộc vào `ApiClient` trước khi test được `reel_api.dart`.
2. **19 test FE fail sẵn** (mục 4) — phải dọn trước khi dùng làm cổng chặn CI.
3. **Chưa nối CI** — bộ PostgreSQL cần `REELS_TEST_PG_URL`; hiện chạy thủ công.
4. **Một test backend chập chờn** (`test_message_is_redacted_before_log`) — fail trong full suite, pass khi chạy riêng và pass cả thư mục `observability`. Không liên quan reel, có từ trước.

---

## 10. CÁCH CHẠY LẠI

```bash
cd ancu365-backend

# Toàn bộ test reel + độ phủ (không cần PostgreSQL)
docker run --rm --network faceconst_default -e PYTHONPATH=/app --env-file .env \
  -v "$PWD:/app" -w /app ancu365-backend:local \
  python -m pytest tests/api/test_reels_routes.py tests/services/media/ \
    tests/e2e/test_reel_full_lifecycle.py \
    --cov=app.routers.reels --cov=app.services.media.video_processor \
    --cov=app.workers.media_worker --cov-report=term-missing --cov-report=html

# Kèm phần xếp hạng — PostgreSQL DÙNG RIÊNG cho test (không đụng faceconst-db)
docker run -d --name ancu365-test-pg --network faceconst_default \
  -e POSTGRES_PASSWORD=testpw -e POSTGRES_USER=testuser -e POSTGRES_DB=reeltest \
  postgres:16-alpine
docker run --rm --network faceconst_default -e PYTHONPATH=/app \
  -e REELS_TEST_PG_URL="postgresql://testuser:testpw@ancu365-test-pg:5432/reeltest" \
  -e DATABASE_URL="sqlite:///:memory:" -e JWT_SECRET="test-secret-xyz-never-use-in-prod" \
  -v "$PWD:/app" -w /app ancu365-backend:local \
  python -m pytest tests/api/test_reels_ranking_pg.py
docker rm -f ancu365-test-pg

# Frontend
cd ../ancu365-app
docker run --rm -v "$PWD":/app -w /app ghcr.io/cirruslabs/flutter:stable \
  bash -lc "flutter pub get && flutter test --coverage"   # pub get PHẢI cùng container
docker run --rm -v "$PWD":/w -w /w debian:13-slim bash -lc \
  'apt-get update -qq && apt-get install -y -qq lcov && lcov --list coverage/lcov.info'
```
