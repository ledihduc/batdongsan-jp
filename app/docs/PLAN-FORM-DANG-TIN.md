# Kế hoạch: 4 hình thức đăng tin + trường thông tin theo loại hình

> Trạng thái: ĐỀ XUẤT, chưa code. Viết 25/08/2026.
> Liên quan: `lib/features/host/post/post_house_screen.dart` (god-file ~1250 dòng),
> `ancu365-backend/alembic/versions/0074_category_groups.py` (12 loại hình / 3 nhóm).

## 0. Điều quan trọng nhất: 4 hình thức KHÔNG cùng một loại dữ liệu

| Hình thức | Bản chất | Lưu ở đâu |
|---|---|---|
| **Cho thuê** | CUNG — tôi có một bất động sản có thật | `houses` (transaction_type='rent') |
| **Cần bán** | CUNG — tôi có một bất động sản có thật | `houses` (transaction_type='sale') |
| **Cần thuê** | CẦU — tôi chưa có gì, tôi đang tìm | **bảng mới** `demand_posts` |
| **Cần mua** | CẦU — tôi chưa có gì, tôi đang tìm | **bảng mới** `demand_posts` |

Nhồi tin CẦU vào bảng `houses` là sai và sẽ hỏng ngay: `houses` bắt buộc
`address`, `area`, `price`, `category_id` — người **cần thuê** không có địa chỉ,
không có diện tích, không có ảnh. Nhồi vào thì hoặc phải nới lỏng ràng buộc của
tin thật (mở đường cho tin rác), hoặc bắt người dùng bịa số. Ngoài ra tin CẦU
còn lọt vào bản đồ, sitemap, SEO, bộ đếm "tin đang đăng" của hồ sơ — sai hết.

→ **Hai luồng, một cửa vào.** Màn chọn 2×2 ở đầu, rồi rẽ nhánh.

## 1. Cửa vào chung (bước 0)

```
        TÔI CÓ                       TÔI CẦN
┌────────────────────┐      ┌────────────────────┐
│  Cho thuê          │      │  Cần thuê          │
├────────────────────┤      ├────────────────────┤
│  Cần bán           │      │  Cần mua           │
└────────────────────┘      └────────────────────┘
```
Nhãn cột "TÔI CÓ / TÔI CẦN" là thứ giúp người dùng không bấm nhầm — bốn ô trần
như hiện nay dễ nhầm "Cần bán" (tôi có nhà) với "Cần mua" (tôi không có gì).

## 2. Luồng CUNG — Cho thuê / Cần bán

Giữ `post_house_screen` nhưng chia **3 bước có thanh tiến độ** thay vì một trang
cuộn dài (đây là lý do form hiện tại "tệ": mọi trường của mọi loại hình hiện
cùng lúc, người đăng phòng trọ vẫn phải nhìn ô "tải trọng sàn").

**Bước 1 — Ở đâu, cái gì** (3 câu hỏi, không hơn)
- Bản đồ ghim vị trí → tự điền tỉnh/phường/địa chỉ (đã có).
- Nhóm loại hình: Lưu trú dài hạn · Lưu trú ngắn hạn · Kinh doanh.
- Loại hình cụ thể (12 loại — khớp ĐÚNG bảng `categories` hiện có).

**Bước 2 — Thông tin theo loại hình** (chỉ hiện trường thuộc nhóm đã chọn)

*Lưu trú dài hạn — Phòng trọ · Chung cư mini · Căn hộ · Nhà nguyên căn*
| Trường | Vì sao cần |
|---|---|
| Giá / tháng · Tiền cọc (mấy tháng) | Cọc là thứ khách hỏi đầu tiên, hiện phải đọc trong mô tả |
| Điện · nước · phí dịch vụ (đ/kWh, đ/m³, đ/tháng) | Ở VN đây là khoản gây tranh cãi nhiều nhất; hiện tin nào cũng giấu |
| Số phòng ngủ · WC (đã có) | |
| Nội thất: trống / cơ bản / đầy đủ | Quyết định giá, hiện chỉ nằm trong mô tả |
| Giờ giấc: tự do / có giờ · chung chủ hay không | Bộ lọc người thuê trẻ dùng nhiều nhất |
| Chỗ để xe: có / không / mất phí | |
| Ở ghép + giới tính (đã có `gender_pref`) | |
| Thời hạn thuê tối thiểu (tháng) | |
| Số phòng còn trống (đã có `total_units`/`available_units`) | |

*Lưu trú ngắn hạn — Villa · Hotel · Motel · Home stay*
| Trường | Vì sao cần |
|---|---|
| Giá / đêm + giá cuối tuần / lễ | Ngắn hạn không có giá tháng; một giá duy nhất là sai mô hình |
| Sức chứa (số khách) · số giường | Đơn vị bán của lưu trú ngắn hạn là ĐẦU NGƯỜI, không phải m² |
| Giờ nhận / trả phòng | |
| Số đêm tối thiểu · phụ thu khách thêm | |
| Chính sách huỷ (linh hoạt / vừa / nghiêm) | |
| Tiện nghi: hồ bơi · bếp · BBQ · máy giặt… | |

*Kinh doanh — Mặt bằng cửa hàng · Shop house · Văn phòng · Kho xưởng*
| Trường | Vì sao cần |
|---|---|
| Giá / tháng **hoặc** giá / m²/tháng (chọn cách tính) | Văn phòng & kho luôn báo giá theo m² |
| Mặt tiền (m) · đường trước mặt (m) | Với mặt bằng bán lẻ đây là yếu tố số 1 |
| Tầng · tổng số tầng · thang máy | |
| Kho xưởng: chiều cao thông thuỷ · tải trọng sàn · xe container vào được không · PCCC | Đã có `industrial_attrs` JSON để chứa |
| Được đăng ký kinh doanh tại địa chỉ? | Thiếu cái này là hợp đồng đổ vỡ sau khi ký |
| Ngành nghề phù hợp / bị cấm (chủ nhà cấm bếp, karaoke…) | |
| Thời hạn thuê tối thiểu · chu kỳ tăng giá | |

*Riêng “Cần bán” (mọi nhóm), thêm:*
- Pháp lý: sổ đỏ / sổ hồng / hợp đồng mua bán / đang chờ sổ (đã có `legal_status`)
- Hướng nhà (đã có `direction`), diện tích đất & diện tích sàn, số tầng, năm xây
- Tình trạng: đang ở · đang cho thuê · để trống
- Sở hữu: chính chủ · đồng sở hữu · uỷ quyền bán — **tự khai, hiển thị kèm “(tự khai)”**
- Giá có thương lượng hay không

**Bước 3 — Ảnh, tiêu đề, mô tả** (giữ như hiện tại; tiêu đề gợi ý tự sinh đã có).

## 3. Luồng CẦU — Cần thuê / Cần mua (form MỚI, ngắn)

Nguyên tắc: **≤ 8 trường, không ảnh, không địa chỉ chính xác**, xong trong 30
giây. Người đang tìm nhà không có gì để mô tả; bắt họ làm form dài là mất họ.

*Cần thuê*
- Khu vực mong muốn (chọn NHIỀU quận/phường)
- Loại hình mong muốn (chọn nhiều trong 12 loại)
- Ngân sách từ – đến (đ/tháng)
- Thời điểm dọn vào · thời hạn thuê dự kiến
- Số người ở · có thú cưng không
- Yêu cầu bắt buộc (chip): chỗ để xe · giờ tự do · máy lạnh · ban công · gác…
- Ghi chú tự do

*Cần mua* — như trên, đổi 3 trường cuối:
- Ngân sách từ – đến + hình thức: tiền mặt / cần vay
- Diện tích tối thiểu · số phòng ngủ tối thiểu
- Pháp lý chấp nhận được · hướng ưu tiên · mục đích (để ở / đầu tư)
- Thời hạn cần chốt

**Tin CẦU tự hết hạn sau 30 ngày** (`expires_at`), có nút gia hạn. Không có cơ
chế này thì sau 6 tháng danh sách toàn nhu cầu chết — đúng thứ đã giết các trang
“cần mua cần bán” đời cũ.

**SĐT**: tin CẦU chỉ liên hệ qua chat trong app hoặc SĐT masked. Đăng nhu cầu
kèm số điện thoại công khai = mồi cho môi giới gọi rác, người dùng sẽ không đăng
lần thứ hai.

## 4. Thay đổi dữ liệu (additive, đúng luật migration của repo)

1. **Bảng mới `demand_posts`**: `id · user_id · kind('rent'|'buy') · province_code ·
   ward_slugs(JSON) · category_ids(JSON) · budget_min · budget_max · area_min ·
   bedrooms_min · move_in_date · duration_months · needs(JSON) · note · status ·
   expires_at · created_at`.
2. **`houses.extra_attrs JSON`** — chứa các trường theo loại hình ở Bước 2
   (điện/nước, giờ giấc, mặt tiền, tải trọng sàn…). Một cột JSON thay vì ~25 cột
   mới: các trường này chỉ để HIỂN THỊ và lọc thô, không join, không ràng buộc.
   Trường nào chứng minh được là dùng để LỌC nhiều thì tách cột riêng + index sau.
3. Không đụng `categories` — 12 loại hình trong yêu cầu **khớp đúng** bảng hiện có.

## 5. Vì sao form hiện tại "tệ" — 6 điểm sửa được ngay

1. Một trang cuộn rất dài, không biết còn bao nhiêu bước → chia 3 bước + thanh tiến độ.
2. Mọi trường hiện cùng lúc cho mọi loại hình → chỉ hiện trường của nhóm đã chọn.
3. Dropdown cho thứ chỉ có 2–4 lựa chọn → dùng chip bấm một chạm.
4. Ô số nhập tay (số phòng, số tầng) → stepper +/−.
5. Lỗi chỉ hiện khi bấm Đăng, ở tận cuối trang → kiểm tra ngay từng bước.
6. Thoát giữa chừng mất trắng → nháp tự lưu + hỏi lại khi thoát
   (mẫu `PopScope` đã dùng ở `provider_profile_edit_screen.dart`).

## 6. Thứ tự làm đề xuất

1. Màn chọn 2×2 + tách luồng (nhỏ, thấy ngay kết quả).
2. Form CẦU + bảng `demand_posts` + màn danh sách nhu cầu (giá trị mới, độc lập).
3. Chia 3 bước cho form CUNG (không đổi dữ liệu, chỉ đổi bố cục).
4. `extra_attrs` theo loại hình, làm dần từng nhóm — bắt đầu bằng lưu trú dài
   hạn vì chiếm phần lớn tin.
