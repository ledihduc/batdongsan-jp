# Kế hoạch — Album tin đăng cho sale

> Chốt 05/09/2026. Trạng thái: **chưa triển khai**.

## Vấn đề

Một sale ôm 20 căn trong cùng một toà thì trang cá nhân hiện ra 20 bài rời rạc,
cuộn mỏi tay mà khách vẫn không thấy được "anh này có nguyên toà". Bản thân sale
cũng không có chỗ nào để quản lý theo toà: *toà S1 còn căn nào, căn 1201 đã bán
chưa*.

Cần một lớp **gom nhóm** đặt trên tin đăng — gọi là **album**, đúng như album ảnh
Facebook: một cái tên, một ảnh bìa, và danh sách tin bên trong.

## Không tái dùng bảng `buildings`

`buildings` (`app/models/rental.py:6`) thuộc mảng **vận hành cho thuê**: toà →
phòng → hợp đồng → hoá đơn, gắn với `host_id` và dùng cho nhà trọ của chính chủ.
Album là lớp **trưng bày** cho tin đăng, gắn với người đăng và có thể gồm cả tin
bán lẫn cho thuê, cả nhà mình lẫn nhà bán hộ. Ép chung một bảng là trộn hai
nghiệp vụ khác nhau, và mọi truy vấn của cả hai bên sẽ phải mang thêm điều kiện
"loại nào" mãi mãi.

---

## Mô hình dữ liệu

### Một tin thuộc TỐI ĐA MỘT album

Dùng khoá ngoại trên `houses`, **không** làm bảng nối nhiều-nhiều.

Lý do: nhu cầu thật là "căn này thuộc toà nào" — mà một căn hộ chỉ nằm trong đúng
một toà. Bảng nối kéo theo thứ tự trong album, trùng lặp, và câu hỏi "xoá album
thì tin đi đâu" — trả giá cho một khả năng chưa ai cần. Sau này muốn nhóm cắt
ngang ("dưới 3 tỷ", "view biển") thì đó là **nhãn**, một cơ chế khác, thêm sau.

```
-- Migration additive
CREATE TABLE listing_albums (
  id            SERIAL PRIMARY KEY,
  owner_id      INTEGER NOT NULL,          -- users.id, index
  name          VARCHAR(200) NOT NULL,     -- "Vinhomes Grand Park — toà S1"
  description   TEXT DEFAULT '',
  cover_house_id INTEGER,                  -- ảnh bìa lấy từ 1 tin trong album
  address       VARCHAR(300) DEFAULT '',
  city          VARCHAR(100) DEFAULT '',
  district      VARCHAR(100) DEFAULT '',
  is_public     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMP NOT NULL DEFAULT now()
);

ALTER TABLE houses ADD COLUMN album_id INTEGER;   -- nullable, index
ALTER TABLE houses ADD COLUMN unit_label VARCHAR(50) DEFAULT '';  -- "Căn 1201"
```

`unit_label` nằm trên `houses` chứ không trên bảng nối: nó là thuộc tính của
CHÍNH căn đó, tồn tại kể cả khi tin bị gỡ khỏi album.

**Xoá album KHÔNG xoá tin** — chỉ set `album_id = NULL`. Album là cái kệ, không
phải cái hộp; đập kệ thì đồ vẫn còn.

---

## Backend

| Endpoint | Việc |
|---|---|
| `GET /api/albums?owner_id=` | danh sách album công khai của một người (cho trang sale) |
| `GET /api/albums/{id}` | chi tiết + tin bên trong, sắp theo `unit_label` rồi `id` |
| `POST /api/albums` | tạo (require_user) |
| `PATCH /api/albums/{id}` | sửa tên/mô tả/bìa/công khai — **chỉ chủ album** |
| `DELETE /api/albums/{id}` | xoá kệ, gỡ `album_id` của tin về NULL |
| `PATCH /api/houses/{id}` | thêm `album_id` + `unit_label` vào phần cho sửa |

**Luật quyền phải viết ngay từ đầu, không để sau:** chỉ gán được tin của CHÍNH
mình vào album của CHÍNH mình. Thiếu kiểm tra này thì bất kỳ ai cũng nhét tin
người khác vào album mình rồi trưng như hàng của mình — đúng kiểu lỗi IDOR mà
`_ensure_owner_or_admin` (`app/auth.py:249`) đang chặn ở chỗ khác.

Số tin trong album tính bằng `COUNT` có lọc `status='published'` — album 12 căn
mà 9 căn đã gỡ thì phải hiện 3, không phải 12.

---

## Giao diện

### 1. Trên trang cá nhân sale (`/sale/:id`)
Chèn dải **"Album"** ngay trên feed bài đăng: lưới 2 cột, mỗi ô là ảnh bìa + tên
+ "N căn". Đúng kiểu album ảnh Facebook. Không có album nào thì ẩn hẳn dải.

### 2. Màn chi tiết album
Đầu trang: bìa lớn, tên, địa chỉ, "N căn đang bán". Bên dưới là **feed bài đăng**
dùng lại `FbPostCard` như trang sale — thêm chip `unit_label` ("Căn 1201") ở góc
ảnh. Không dựng kiểu thẻ thứ ba cho cùng một thứ.

### 3. Màn quản lý (chỉ chủ album)
Vào từ tab Cá nhân → "Album của tôi". Tạo/sửa/xoá; trong một album có nút **"Thêm
tin vào album"** mở danh sách tin của mình để tích chọn nhiều cùng lúc.

**Gợi ý gom nhóm tự động:** khi mở màn tạo album, nếu người này có ≥3 tin cùng
`address` hoặc cùng `district` + tiêu đề trùng tiền tố, gợi ý sẵn tên album và
tích sẵn các tin đó. Đây là chỗ tính năng đáng dùng hay không được quyết định —
bắt sale tự tích 20 căn bằng tay thì họ làm một lần rồi thôi.

---

## Thứ tự làm

1. **P1** — migration + 5 endpoint + luật quyền. Có test cho: người khác không
   gán được tin vào album của tôi; xoá album không xoá tin.
2. **P2** — dải album + màn chi tiết trên trang sale (phần khách nhìn thấy).
3. **P3** — màn quản lý + gán tin hàng loạt.
4. **P4** — gợi ý gom nhóm tự động.

P2 làm được ngay sau P1; P3 mới là phần sale dùng hằng ngày.

## KHÔNG làm trong đợt này

- **Nhãn cắt ngang** ("dưới 3 tỷ", "view biển") — cơ chế khác, thêm sau nếu có ai
  thật sự hỏi.
- **Album ảnh rời** (ảnh không gắn tin nào). Album ở đây là album TIN ĐĂNG; thêm
  ảnh rời là mở ra một kho media riêng cần kiểm duyệt.
- **Sắp xếp kéo-thả** trong album. Sắp theo `unit_label` đã đủ đúng với nhu cầu
  "căn 1201, 1202, 1505".

## Verify

```
flutter analyze && flutter test
flutter build web --release && python3 tools/nen_gz.py
cd ../ancu365-backend && ./check.sh          # đọc kỹ output
```

Kiểm tay trên `https://ancu365.ddns.net`:
1. Tạo album, gán 3 tin → trang `/sale/:id` hiện ô album ghi "3 căn".
2. Gỡ 1 tin (đổi status) → ô album phải ghi "2 căn", không phải 3.
3. Xoá album → 3 tin vẫn còn nguyên trong feed.
4. Bằng `curl` với token của tài khoản B, thử `PATCH` tin của A vào album của B
   → phải bị từ chối. Đừng chỉ kiểm bằng giao diện.
