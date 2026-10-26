# Kế hoạch: tách bạch hai thế giới Bất động sản / Thi công

> Ngày 27/07/2026 · Nối tiếp commit `898964a` + `1662000`
> Nguồn: phàn nàn của chủ dự án ("giao diện hai bên y hệt nhau") + 2 vòng phản biện

## Bối cảnh — đã làm gì rồi

| Đã xong | Commit |
|---|---|
| Ẩn nút "Bộ lọc nâng cao" (bộ lọc BĐS) ở tab Thi công | `898964a` |
| Sửa lỗi FAB: nhãn suy từ `_currentIndex` còn hành động suy từ `_isConstructionTab` → lệch nhau khi slot đảo | `898964a` |
| Màu nhận diện riêng cho Thi công (`HD.construction`) + nhãn thế giới ở AppBar + huy hiệu ở drawer | `898964a` |
| Trả lại màu logo bất biến · dùng `kWorldConstruction` xuyên suốt · `toolbarHeight: 64` | `1662000` |

**Chưa giải quyết:** ba việc dưới đây, xếp theo TÁC ĐỘNG THẬT lên đúng điều chủ dự án phàn nàn.

---

## A. Card feed Thi công đang dùng chung khung với card nhà ⭐ tác động cao nhất

**Vấn đề.** `construction_world_body.dart:366` dựng mọi card (showcase · yêu cầu báo giá · bài cộng đồng) bằng `FbPostCard` — đúng widget mà feed BĐS dùng. Cùng khung, cùng avatar tròn, cùng hàng nút. Badge phân loại có (`_tag`, dòng 386) nhưng **nhỏ, nằm cạnh tên tác giả, màu nhạt 12% alpha** → mắt lướt qua không bắt được.

Đây nhiều khả năng là nguyên nhân CHÍNH của cảm giác "y hệt", hơn cả AppBar và drawer — vì nó chiếm ~90% diện tích màn hình.

**Việc cần làm**
1. Cho `FbPostCard` một tham số `accent` (mặc định `HD.accent`) → card Thi công truyền `HD.construction`. Áp lên viền trái mảnh hoặc nền badge.
2. Badge loại nổi hơn: đặt **trên cùng card** (không nằm cạnh tên), nền đặc thay vì alpha 12%, kèm icon riêng cho từng loại (showcase / RFQ / bài viết).
3. Card "Yêu cầu báo giá" (RFQ) nên khác hình dạng rõ rệt so với card khoe công trình — đây là hai loại nội dung có mục đích trái ngược (một bên tìm thợ, một bên khoe năng lực).

**Ước lượng:** ~3h · **Rủi ro:** thấp (thêm tham số có giá trị mặc định, không phá chỗ đang dùng)

---

## B. Thi công mất khả năng lọc theo giá / khu vực

**Vấn đề.** Commit `898964a` ẩn nút "Bộ lọc nâng cao" ở tab Thi công vì nó mở `AdvancedFilterScreen` — bộ lọc BĐS (giá theo triệu, số phòng ngủ). Đúng là tránh được việc hỏi nhầm "mấy phòng ngủ", **nhưng chưa bù lại phần đã mất**: Thi công giờ chỉ còn chip chọn ngành trong thân màn (`construction_world_body.dart:547`), không lọc được **khoảng giá · khu vực · sắp xếp**.

Phản biện gọi đúng tên: đây là **nợ**, không phải "đã xong".

**Hai hướng**

| | Nội dung | Công | Ghi chú |
|---|---|---|---|
| B1 | `AdvancedFilterScreen` nhận tham số `world`, ẩn/hiện nhóm tiêu chí theo thế giới | ~2h | Rẻ, nhưng nhét hai nghiệp vụ vào một màn — đúng cái sai đang phải gỡ |
| B2 ⭐ | Màn lọc RIÊNG cho Thi công: ngành · khu vực · khoảng ngân sách · sắp xếp | ~4h | Sạch hơn, hợp hướng tách bạch |

**Khuyến nghị B2.**

### ĐÃ KIỂM BACKEND (27/07) — phạm vi thu hẹp lại

| Tiêu chí | Backend hỗ trợ? | Bằng chứng |
|---|---|---|
| **Khu vực (tỉnh)** | ✅ CÓ | `construction.py:268,277` — `GET /contractors?province_code=` |
| **Ngành/dịch vụ** | ✅ CÓ | cùng endpoint, tham số `service` |
| **Sắp xếp** | ⚠️ CỐ ĐỊNH | `construction.py:279+` xếp cứng: promote → gói pro → đã thẩm định → điểm. Không cho client chọn |
| **Khoảng ngân sách** | ❌ KHÔNG | `construction.py:86` — `budget` là **chuỗi tự do** `String(100)`, không lọc theo khoảng được |

**Hệ quả:** làm được NGAY phần lọc **ngành + khu vực** (~2h, chỉ FE). Phần **ngân sách** cần đổi mô hình dữ liệu phía server (tách thành số min/max + migration + sửa form nhập) — việc riêng, ~4h backend, và phải quyết định có ép người dùng nhập số thay vì chữ hay không.

**Đề nghị:** làm B2 giới hạn ở ngành + khu vực trước; ngân sách để thành hạng mục riêng khi có nhu cầu thật.

### ĐÃ LÀM (27/07) — B2 thu hẹp

Bộ lọc áp lên **DANH BẠ ĐƠN VỊ**, không lên feed. Lý do: `GET /construction/feed`
không có tham số khu vực và **dữ liệu cũng không cho** — bài cộng đồng và showcase
chỉ có địa danh dạng CHỮ, chỉ RFQ mới có `province_code`. Lọc feed theo tỉnh sẽ âm
thầm nuốt hai loại kia, tức bộ lọc nói dối.

| Tệp | Việc |
|---|---|
| `contractor_filter_screen.dart` (mới) | `ContractorFilter` + màn lọc ngành · khu vực · sắp xếp |
| `contractor_list_screen.dart` | nhận `ContractorFilter`, thanh tóm tắt bộ lọc + đếm kết quả, nút nới lọc ở trạng thái rỗng |
| `construction_api.dart` | `contractors()` gửi thêm `province_code` (trước đây bỏ hẳn) |
| `guest_home_screen.dart` | icon `tune` trả lại tab Thi công, mở bộ lọc Thi công thay vì bộ lọc BĐS |
| `app_system_drawer.dart` | danh bạ mở ở MỌI ngành (bỏ ghim cứng `'build'` + chuỗi Việt hoá cứng) |

Sắp xếp làm phía client (backend xếp cứng, không nhận `sort`; endpoint trả tối đa
200 dòng nên an toàn). **Ngân sách vẫn KHÔNG có** — cố ý, có test khoá.

Kiểm chứng: `flutter analyze` 0 error · `flutter test` 849 pass · `flutter build web` xanh.

---

## C. Cấu trúc drawer hai bên vẫn quá giống

**Vấn đề.** Danh sách mục ĐÃ khác nhau (`_constructionItems` vs `_realestateItems`), nhưng **cách trình bày giống hệt**: cùng số nhóm, cùng kiểu `_label` + `_item`, cùng footer, cùng đầu trang avatar + khẩu hiệu. Huy hiệu thế giới vừa thêm chỉ cao ~20px ở đầu — mắt quét theo hình chữ F thường bỏ qua, tập trung vào thân danh sách, mà thân thì vẫn y như nhau.

**Việc cần làm**
1. Đổi **thứ tự/nhóm** theo nghiệp vụ chứ không chỉ đổi nội dung: bên Thi công đưa "Kênh đơn vị" + "Yêu cầu của tôi" lên NHÓM ĐẦU (đây là việc chính của họ), danh bạ/thư viện xuống dưới.
2. Đầu drawer đổi nền theo màu thế giới (hiện dùng chung `HD.appGradient`).
3. Cân nhắc bỏ khẩu hiệu chung, thay bằng một dòng mô tả riêng từng thế giới.

**Ước lượng:** ~2h · **Rủi ro:** thấp

---

## D. Chưa kiểm chứng bằng mắt

AppBar nay 2 dòng. Tôi đã nới `toolbarHeight: 64` nhưng **chưa xác minh trên màn hẹp thật** (iPhone SE 320px) — nhất là ca chưa đăng nhập, khi `actions` có thêm nút "Đăng nhập" dạng chữ.

**Việc cần làm:** thêm golden test / widget test dựng AppBar ở bề rộng 320px cho cả hai thế giới, hoặc bạn chụp màn hình gửi lại. ~1h

---

## Trạng thái

| | Hạng mục | Trạng thái |
|---|---|---|
| A | Card feed Thi công khác khung card nhà | ✅ XONG — commit `a424c3a` |
| C | Đảo nhóm menu theo nghiệp vụ + nền đầu menu theo thế giới | ✅ XONG — commit `a424c3a` |
| D | Test khoá phần nhận diện (7 test) | ✅ XONG — commit `a424c3a` |
| B | Bộ lọc riêng cho Thi công (ngành · khu vực · sắp xếp) trên danh bạ đơn vị | ✅ XONG 27/07 — 6 test khoá |

**Nợ còn lại của B:** lọc theo **khoảng ngân sách** — cần đổi `Contractor.budget`
từ chuỗi tự do sang số min/max (migration + sửa form nhập, ~4h backend), và phải
quyết định có ép người dùng nhập số thay vì chữ hay không.

## Điều cần cân nhắc thẳng thắn

Toàn bộ kế hoạch này là **polish giao diện cho một app đang có ~0 người dùng thật từ Internet** (xem `DIEU-TRA-0-DANG-KY.md`: 52 khách/8 ngày, 0 lượt đăng ký, Googlebot chưa từng ghé). Hai vòng phản biện đều nêu điểm này.

Mục **A và C là đáng làm** vì chúng sửa một khiếm khuyết sản phẩm thật (người dùng không phân biệt được hai mảng nghiệp vụ). Nhưng nếu phải chọn giữa việc này và việc **đưa người dùng vào app** (khai báo Google Search Console, tên miền thật, backlink đầu tiên), thì việc sau có đòn bẩy lớn hơn nhiều.
