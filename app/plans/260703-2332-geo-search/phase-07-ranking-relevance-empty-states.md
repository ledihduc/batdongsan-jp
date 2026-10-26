# Phase 07 — Ranking / Relevance + xử lý NULL-coord + Empty states

**Mục tiêu:** kết quả đúng kỳ vọng theo từng ngữ cảnh, không giấu inventory tốt.
**Est.:** 1 ngày · **Phụ thuộc:** Phase 03, 06.

---

## 1. Default sort theo mode (D10)
| Mode | Sort mặc định | Lý do |
|---|---|---|
| Nearby | Khoảng cách tăng (`ST_Distance`) | Ý định "gần" |
| Địa danh | Relevance = f(khoảng cách tới điểm geocode) | "gần trường" |
| Tỉnh/Quận (browse-area) | Recency; đổi nhanh "Giá thấp→cao" | Duyệt khu vực, giá nhạy cảm |
| Từ khoá | Text relevance → recency | |
| Home | Recency + boost nổi bật (giữ hành vi cũ) | |

Sort control: `Icons.swap_vert` "Sắp xếp" → sheet *Liên quan · Gần nhất · Giá thấp→cao · Giá cao→thấp · Mới nhất*. Lựa chọn khả dụng đổi theo mode (nearby thêm "Gần nhất").

## 2. Boosting rules (tính server-side, ổn định & phân trang được)
```
score = base(mode)                    // -distance (nearby); text_rank (query); recency (browse)
        + w1 * (available_units > 0)   // còn phòng — boost mạnh nhất
        - p1 * is_full                 // đủ phòng — chìm xuống, KHÔNG ẩn
        + w2 * has_images
        + w3 * has_coords              // nearby/place cần toạ độ
        + w4 * product_type_match      // khớp category đang lọc
        + w5 * is_verified
```
Trọng số tương đối: `available_units>0` > `has_images` > `verified` > `product_type_match` > `has_coords`. **Tie-breakers:** (1) còn phòng > hết, (2) có ảnh > không, (3) mới hơn (`created_at` desc), (4) `id` desc (ổn định phân trang). Nearby: khoảng cách nhỏ hơn thắng trước tiên.

## 3. Xử lý NULL-coord (D5 — điểm quan trọng nhất)
- **Nearby / Place:** 2 truy vấn ghép:
  1. Tin **có toạ độ** trong bán kính — sort khoảng cách (list chính, có badge km, hiện trên map).
  2. Tin **cùng district/tỉnh** của điểm nhưng NULL-coord — nhóm dưới divider **"Cũng ở {khu vực} (chưa có bản đồ)"**, sort recency. Không lên map.
  - Suy district của điểm GPS/geocode bằng **reverse-geocode** (Nominatim) → khoá cho nhóm (2).
- **Browse-area / Query / Home:** NULL-coord **không bị phạt** (`has_coords` chỉ boost, không lọc). Không ẩn.

## 4. Empty states — phải hành động được (E8)
Không dùng chữ trơ "Không tìm thấy" (hiện ở `guest_home_screen.dart:449`). Mỗi mode có CTA:
| Mode | Thông điệp + CTA |
|---|---|
| Nearby ít/không | "Chưa có phòng trong {r}km." → **"Mở rộng lên {r×2} km"** + "Chọn khu vực khác" |
| Có filter | "Không có tin khớp bộ lọc." → **"Bỏ bớt bộ lọc"** (liệt kê chip đang bật để xoá nhanh) |
| Địa danh fail geocode | "Không tìm thấy địa điểm này." → gợi ý tỉnh/quận gần đúng |
| GPS lỗi | Banner + chọn khu vực thủ công (Phase 06) |

## 5. Card presentation
Tách `HouseCard` (hiện là method private trong home) thành widget tái dùng. Thêm:
- Distance badge (nearby/place): dòng địa chỉ → `📍 Quận 7 · 1,2 km`.
- Dòng gọn: **giá (đậm `HD.accent`) · diện tích · phòng ngủ** (thêm `Icons.bed` + `bedrooms`).
- Giữ badge "CÒN N/M"/"ĐÃ ĐỦ" + "XÁC THỰC"; tin hết phòng: overlay mờ + badge xám (đã có `isFull`).

---

## Definition of Done
- Mỗi mode sort đúng mặc định; đổi sort qua sheet hoạt động.
- Tin còn phòng + có ảnh nổi lên trên; tin hết phòng chìm xuống nhưng không biến mất.
- Nearby: tin NULL-coord xuất hiện ở nhóm phụ "Cũng ở khu vực này", không lên map.
- Mỗi empty state có CTA đúng và bấm được.
