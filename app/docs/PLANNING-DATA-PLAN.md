# Dữ liệu quy hoạch cho ancu365 — hiện trạng & lộ trình

> Lập 2026-07-18. Mọi kết luận dưới đây dựa trên đo đạc thực tế
> (`ancu365-backend/scripts/probe_planning_sources.py`), không phải phỏng đoán.

---

## 0. VÌ SAO KHÔNG LẤY DỮ LIỆU TỪ GULAND

Yêu cầu ban đầu là tải bản đồ quy hoạch của Guland rồi xoá logo. Tôi không làm, vì:

- Bản đồ đó là **sản phẩm biên tập của họ** — họ bỏ chi phí thu thập, số hoá, nắn chỉnh. Sao chép để dùng trong sản phẩm cạnh tranh là xâm phạm quyền tác giả với dữ liệu đã được tuyển chọn/sắp xếp.
- **Gỡ watermark là tình tiết tăng nặng**: nó biến việc "dùng nhầm" thành "cố ý che giấu nguồn". Đó là bằng chứng bất lợi rõ ràng nếu có tranh chấp.
- ancu365 **đã chạy công khai** dưới tên miền của bạn. Rủi ro rơi thẳng vào bạn, không phải vào người viết code.
- Về sản phẩm: dữ liệu đi mượn không kiểm chứng được, không cập nhật được, và **không thể trở thành lợi thế cạnh tranh** — bạn mãi mãi chậm hơn nguồn gốc một nhịp.

Phần còn lại của tài liệu này là các đường đi hợp pháp, xếp theo chi phí thực tế.

---

## 1. HIỆN TRẠNG KỸ THUẬT — ĐO ĐƯỢC

Dự án **đã có sẵn** một nửa hạ tầng: `app/services/planning_etl/` (WFS client, PostGIS loader, lệnh `discover-layers`, scheduler) + container `ancu365-martin` phục vụ vector tile + màn hình bản đồ quy hoạch phía Flutter.

Nhưng nó chưa từng chạy được, vì hai lý do:

### 1.1 Endpoint trong config đã CHẾT

```
WFS_BASE_URL = "https://geodata-stnmt.tphcm.gov.vn/geoserver/ows"
```

| Bước | Kết quả |
|---|---|
| DNS | ✅ 210.2.71.235 |
| TCP :443 | ✅ mở |
| TLS | ✅ bắt tay xong (TLSv1.3, chứng thư `*.tphcm.gov.vn` hợp lệ) |
| HTTP | ❌ **máy chủ đóng kết nối, không trả gì** |
| HTTP :80 | 302 → HTTPS, `Server: BigIP` |

Nghĩa là: bộ cân bằng tải F5 còn sống và chuyển hướng, nhưng **geoserver phía sau đã tắt hoặc bị gỡ**. Không phải lỗi mạng phía ta — máy chủ này đặt tại VN (VNPT, IP 14.249.115.0).

### 1.2 Tên layer chưa bao giờ được xác minh

`config.py` ghi thẳng: *"Layer names and district codes are PLACEHOLDERs"*.

```python
LAYER_NAMES = {
    "landuse": "tnmt:quy_hoach_su_dung_dat_2030",  # PLACEHOLDER
    "parcels": "tnmt:ranh_thua_dat",               # PLACEHOLDER
}
```

Tức là dù endpoint còn sống, ETL vẫn sẽ hỏng ngay lần chạy đầu.

### 1.3 Khảo sát các cổng chính thức khác

| Nguồn | Tình trạng đo được |
|---|---|
| HCMC Sở Xây dựng — `gisxaydung.tphcm.gov.vn` | ✅ **200, sống**. Dùng ArcGIS REST qua proxy `/api/arcgis-path/proxy/HCM/...`. Truy vấn trực tiếp trả 404 → proxy chỉ mở cho ứng dụng của họ |
| HCMC Sở Xây dựng — `api-gisxaydung.tphcm.gov.vn` | ✅ 200, không có swagger/openapi công khai |
| Hà Nội — `qhkhsdd.hanoi.gov.vn` | ⚠️ **Sống (HTTP 200)** nhưng máy chủ **thiếu chứng thư trung gian** GlobalSign |
| Bộ Xây dựng — `quyhoach.xaydung.gov.vn` | ⚠️ **Sống (HTTP 200)** — cùng lỗi chuỗi CA |
| `bandodiachinh.gov.vn` | ❌ tên miền không phân giải |

> **Ghi chú trung thực:** ban đầu tôi kết luận 3 cổng bị "chặn theo dấu vân tay TLS". Sai. Khi viết công cụ dò tách bạch từng lớp mới thấy 2 trong 3 chỉ là **lỗi chuỗi chứng thư** — máy chủ hoàn toàn sống. Cách khắc phục là **nạp CA trung gian vào bundle, KHÔNG phải tắt xác thực** (tắt verify thì mất khả năng chứng minh nguồn gốc dữ liệu hiển thị cho người dùng).

### 1.4 Kết luận quan trọng nhất

Tìm kiếm "dữ liệu quy hoạch mở WMS/WFS Việt Nam" trả về **gần như toàn bộ là trang tổng hợp tư nhân** (Guland, tracuuquyhoach, QH Việt), không phải cổng dữ liệu mở nhà nước.

**Việt Nam chưa công bố dữ liệu quy hoạch dạng dịch vụ mở dùng được ở quy mô toàn quốc.** Đó chính là lý do Guland tồn tại được như một doanh nghiệp — họ bỏ công đi gom từ 63 (nay 34) đầu mối. Không có đường tắt kỹ thuật nào thay được việc đó.

---

## 2. BỐN PHƯƠNG ÁN — CHI PHÍ THẬT

### A. Xin cấp dữ liệu chính thức từ Sở TN&MT / Sở Xây dựng ⭐ khuyến nghị nền tảng

Gửi công văn đề nghị cung cấp/khai thác dữ liệu quy hoạch sử dụng đất theo quy định về tiếp cận thông tin.

- **Được:** dữ liệu gốc, có căn cứ pháp lý, được phép hiển thị công khai, có đường cập nhật chính thức. Là **tài sản** của công ty.
- **Mất:** thời gian hành chính (thường vài tuần–vài tháng/tỉnh), có thể có phí, phải làm lại với **từng tỉnh**.
- **Bắt đầu từ đâu:** 2–3 tỉnh trọng điểm nơi có nhiều tin đăng nhất, không làm cả 34 tỉnh cùng lúc.

### B. Mua bản quyền từ đơn vị đã có dữ liệu

Thương lượng license với chính Guland, QH Việt, hoặc tracuuquyhoach.

- **Được:** có ngay, không phải xây pipeline, rủi ro pháp lý bằng 0.
- **Mất:** chi phí định kỳ; phụ thuộc đối thủ; họ có thể từ chối hoặc ra giá cao vì bạn cạnh tranh trực tiếp.
- **Đáng cân nhắc nếu:** cần ra mắt nhanh để kiểm chứng nhu cầu trước khi đầu tư dài hạn.

### C. Tự số hoá từ văn bản công bố công khai

Quyết định phê duyệt QHSDĐ + bản đồ kèm theo được các tỉnh công bố (PDF/ảnh). Tự nắn chỉnh toạ độ và số hoá ranh giới.

- **Được:** hoàn toàn hợp pháp (văn bản nhà nước công bố), **sở hữu 100% kết quả**, khác biệt được với đối thủ nếu làm kỹ.
- **Mất:** nặng công nhất. Ước lượng thô: 1 huyện ≈ vài ngày công cho người có nghề GIS.
- **Hợp lý khi:** làm sâu một khu vực trọng điểm thay vì phủ mỏng toàn quốc.

### D. Nền bản đồ mở + ranh giới hành chính chính thức — **đã có sẵn**

Dự án đang chạy `ancu365-martin` (vector tile) và dữ liệu 34 tỉnh 2 cấp.

- **Được:** miễn phí, hợp pháp, đang chạy rồi.
- **Mất:** **không có lớp quy hoạch** — chỉ là nền bản đồ. Không thay thế được A/B/C.

---

## 3. KHUYẾN NGHỊ — và một con số làm tôi đổi ý

Tôi định khuyến nghị "làm B ngắn hạn + A dài hạn, bắt đầu 1 tỉnh". Rồi tôi truy số liệu thật trong DB:

```
Tổng số tin đăng: 16
  tp-ho-chi-minh  4      da-nang     2      long-an   1
  ha-noi          3      khanh-hoa   1
```

**16 tin trên toàn quốc.** ancu365 vẫn đang ở giai đoạn trước-người-dùng-thật.

### Vì vậy khuyến nghị thẳng: CHƯA đầu tư mua/xin dữ liệu quy hoạch lúc này

Cả ba phương án A, B, C đều tốn **tiền thật hoặc tháng công thật**. Bỏ ra lúc này là đầu tư vào một tính năng mà **chưa có ai để chứng minh là họ cần**. Nếu sau đó sản phẩm xoay hướng — như chính bạn đã kết luận trong nghiên cứu thị trường rằng *Thi công là đại dương xanh* — thì khoản đó mất trắng.

**Thứ tự hợp lý hơn:**

1. **Bây giờ** — giữ nguyên nền bản đồ mở (phương án D, đã chạy). Nếu muốn có gì đó hiển thị, làm **1 quận** theo phương án C: đủ để demo, tự sở hữu, gần như không tốn tiền.
2. **Khi có ~500–1.000 tin và người dùng thật** — đo xem có bao nhiêu người bấm vào tab quy hoạch. Đây mới là dữ liệu để quyết.
3. **Nếu tỷ lệ dùng cao** — lúc đó mới chi cho B (mua nhanh) hoặc A (xin chính thức, bền hơn), bắt đầu từ TP.HCM vì đang dẫn đầu về số tin.

### Nếu bạn vẫn muốn làm ngay

Thì **B trước, A song song**: B cho bạn dữ liệu trong vài tuần để kiểm chứng nhu cầu, A xây đường cấp dữ liệu bền vững phía sau. Đừng chọn C làm đường chính khi chưa biết có người dùng — nó ngốn công nhất.

## 4. VIỆC KỸ THUẬT CẦN LÀM (khi đã có nguồn)

| # | Việc | Trạng thái |
|---|---|---|
| 1 | Công cụ dò nguồn `scripts/probe_planning_sources.py` | ✅ **xong** — phân biệt DNS/TCP/TLS/chuỗi-CA/HTTP, có `--json` cho CI, mã thoát ≠0 khi nguồn chính chết |
| 2 | Gỡ endpoint chết khỏi `config.py`, chuyển sang biến môi trường bắt buộc | chờ chốt nguồn |
| 3 | Nạp CA trung gian GlobalSign để gọi được cổng Hà Nội / Bộ Xây dựng | chờ, chỉ cần nếu chọn 2 nguồn đó |
| 4 | Chạy `discover-layers` thay tên layer PLACEHOLDER bằng tên thật | chờ nguồn sống |
| 5 | Bổ sung adapter **ArcGIS REST** (hiện chỉ có WFS) — cổng TP.HCM dùng ArcGIS | chờ, cần nếu đi đường TP.HCM |
| 6 | Seed PostGIS + phát tile qua `ancu365-martin` | hạ tầng đã sẵn |
| 7 | Ghi rõ **nguồn + thời điểm cập nhật** trên bản đồ trong app | bắt buộc — vừa là nghĩa vụ ghi nhận nguồn, vừa là thứ khiến người dùng tin |
| 8 | Cron chạy `probe` hàng tuần, cảnh báo khi nguồn chết | dễ, làm sau bước 2 |

---

## 5. CHẠY CÔNG CỤ DÒ

```bash
cd ancu365-backend
python3 scripts/probe_planning_sources.py          # báo cáo cho người đọc
python3 scripts/probe_planning_sources.py --json   # cho CI/cron
# mã thoát 1 nếu nguồn đang cấu hình trong config đã chết
```

Kết quả lần chạy 18/07/2026: **2/5 nguồn phản hồi**; nguồn đang cấu hình trong `config.py` **đã chết**.

---

## 6. ĐIỀU CẦN BẠN QUYẾT

1. **Có đầu tư dữ liệu quy hoạch lúc này không?** Khuyến nghị của tôi là **chưa** (mục 3) — 16 tin đăng chưa đủ căn cứ. Nếu bạn có thông tin thị trường mà tôi không thấy (đối tác, cam kết với khách, vòng gọi vốn), thì quyết định có thể khác và tôi làm theo.
2. **Nếu làm ngay**: chọn B (mua, nhanh) hay A (xin chính thức, bền)? Ngân sách cho B là bao nhiêu — con số này quyết định có thương lượng được không.
3. **Nếu chưa làm**: có muốn tôi làm **1 quận mẫu theo phương án C** để có thứ trưng bày, đồng thời kiểm chứng toàn bộ pipeline (ETL → PostGIS → martin → app) chạy thông không?

---

## 7. ĐÃ LÀM TRONG ĐỢT NÀY

- ✅ Chẩn đoán dứt điểm vì sao pipeline quy hoạch chưa từng chạy được (endpoint chết + tên layer là placeholder)
- ✅ Khảo sát 5 cổng chính thức, phân biệt rõ từng kiểu hỏng
- ✅ `scripts/probe_planning_sources.py` — công cụ dò tái sử dụng được, cắm được vào cron/CI
- ✅ Tự sửa một kết luận sai của chính mình (xem ghi chú ở mục 1.3)
- ❌ **Chưa** đụng vào `planning_etl/config.py` — chờ chốt nguồn, sửa bây giờ chỉ là đoán mò
