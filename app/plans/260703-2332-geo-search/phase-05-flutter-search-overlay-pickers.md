# Phase 05 — Flutter: Search overlay hợp nhất + Location picker

**Mục tiêu:** một ô tìm — ba ý định. Người thuê VN gõ "gần Bách Khoa", "Quận 7", "chung cư Vinhomes" trong cùng chỗ; hệ thống phân loại giúp.
**Est.:** 2 ngày · **Phụ thuộc:** Phase 04.

---

## 1. `GuestSearchScreen` — overlay typeahead full-screen
Nâng search bar ở `guest_home_screen.dart` (dòng ~230–299) từ TextField-submit thành **nút mở `GuestSearchScreen`** (push route). Giữ hình tròn `HD.accentSoft` + nút `Icons.tune`.

Mỗi phím gõ (debounce **300ms**, tái dùng `Debouncer`) fan-out song song 3 nguồn → sections có nhãn:

| Section | Nguồn | Icon | Chọn → |
|---|---|---|---|
| **Quanh đây** (top khi query rỗng) | GPS | `near_me` | Nearby flow (Phase 06) |
| **Tỉnh/Thành · Quận/Huyện** | 63-province fuzzy (local + backend), từ **1 ký tự** | `location_city` | Set bộ lọc địa giới |
| **Địa danh / Địa chỉ** | Nominatim, từ **≥3 ký tự** (D9) | `place_outlined` | Geocode → nearby quanh điểm |
| **Tin đăng khớp** | full-text `query` | `search` | `setSearchQuery` như cũ |
| **Tìm gần đây** (query rỗng) | `RecentSearchStore` | `history` | Phát lại `SearchIntent` |

Thứ tự khi có query: **Tỉnh/Quận → Địa danh → Tin khớp** (rẻ→đắt). Hủy request cũ khi có query mới (sequence token, tránh race kết quả trễ ghi đè).

Mỗi hàng: dòng chính (tên) + dòng phụ ngữ cảnh ("Quận 7, TP.HCM" / "Trường · TP.HCM"). **Không** hiện lat/lng thô. Loading: `LinearProgressIndicator` mảnh dưới ô nhập (không che list — cho province hiện ngay khi Nominatim còn chạy).

## 2. `LocationPicker` — cascading tỉnh → quận/huyện
Tổng quát hoá `ProvincePicker` (đang gắn chặt `PlanningMapProvider`) → widget dùng chung, bottom sheet 2 cấp:
- **Cấp 1:** 63 tỉnh (fuzzy, backend đã có). Chọn → trượt cấp 2.
- **Cấp 2:** quận/huyện của tỉnh (backend cần trả list quận theo tỉnh — hoặc v1 chỉ chọn tỉnh + để user gõ quận). Có mục **"Toàn {tỉnh}"**.
- Breadcrumb `TP.HCM › Quận 7` + nút X lùi cấp.
- Client chỉ gửi `provinceCode`(slug) + `districtCode` — không gửi chuỗi hiển thị.

## 3. Kết hợp với filter khác
Địa giới là **facet độc lập** cộng dồn với giá/diện tích/loại/từ khoá. Hiển thị vùng đã chọn thành **chip xoá được** ("TP.HCM › Quận 7 ✕") dưới search bar, cạnh FilterChip category. Xoá chip = bỏ ràng buộc địa giới, giữ phần còn lại.

## 4. Recent & Saved searches
- **Recent:** 8–10 `SearchIntent` cuối (SharedPreferences). Tap = tái lập nguyên trạng bộ lọc. Nút "Xóa lịch sử".
- **Saved (nice-to-have, có thể để Phase sau):** lưu bộ (địa điểm+giá+loại) với nhãn ("Trọ Q.7 dưới 3tr"). v1 local; sync server + push "tin mới khớp" là retention lever mạnh cho thị trường VN.

---

## Widgets tạo mới
`GuestSearchScreen`, `SearchSuggestionTile` (icon phân loại), `LocationChip` (chip khu vực xoá được), `LocationPicker`.

## Mở rộng
`guest_home_screen.dart` (search bar → mở overlay; thêm chip "Quanh đây" + `LocationChip`), `advanced_filter_screen.dart` (thêm mục địa giới mở `LocationPicker` + chọn sort mặc định).

---

## Definition of Done
- Gõ "quan 7" (không dấu) → section Tỉnh/Quận hiện Quận 7 từ 1 ký tự đầu vùng.
- Gõ landmark ≥3 ký tự → section Địa danh hiện gợi ý; chọn → chuyển nearby.
- Chọn tỉnh/quận → `LocationChip` hiện dưới search bar; kết quả lọc đúng; xoá chip khôi phục.
- Recent search tap → tái lập đúng mode + filter.
- Không có race: gõ nhanh không để kết quả cũ ghi đè kết quả mới.
