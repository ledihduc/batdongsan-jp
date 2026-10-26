# Phase 00 — BA Requirements (Geo-Search)

**Phạm vi:** 3 chế độ tìm kiếm — (1) theo địa danh, (2) theo tỉnh/thành & quận/huyện, (3) tìm quanh đây (GPS).
**Chỉ nhà `status='approved'` mới hiển thị công khai.**

---

## 1. User Stories & Acceptance Criteria (Gherkin)

### US-01 — Tìm theo địa danh (place/landmark)
Người thuê nhập landmark → thấy nhà gần đó, sắp theo khoảng cách.

```gherkin
Scenario: Địa danh có kết quả geocode
  Given tôi ở màn hình tìm kiếm
  When tôi nhập "Đại học Bách Khoa Hà Nội" và bấm Tìm
  Then hệ thống geocode (Nominatim) lấy toạ độ tâm địa danh
  And hiển thị nhà 'approved' trong bán kính mặc định (3km) quanh điểm đó
  And danh sách sắp xếp tăng dần theo khoảng cách
  And mỗi kết quả hiển thị khoảng cách ("cách 1,2 km")

Scenario: Địa danh mơ hồ (nhiều gợi ý)
  Given tôi gõ "chợ Bến Thành"
  When Nominatim trả nhiều địa điểm
  Then hiển thị danh sách gợi ý (display_name) để tôi chọn 1
  And chỉ sau khi chọn mới tìm nhà quanh địa danh đó

Scenario: Không geocode được
  When Nominatim không trả kết quả
  Then hiển thị "Không tìm thấy địa danh này"
  And gợi ý thử tìm theo tỉnh/thành hoặc từ khoá khác
```

### US-02 — Tìm theo tỉnh/thành & quận/huyện
```gherkin
Scenario: Chọn tỉnh/thành
  When tôi chọn "TP. Hồ Chí Minh" từ picker
  Then danh sách lọc theo tin khớp tỉnh này (đối chiếu qua province_code)
  And có thể tinh chỉnh thêm theo quận/huyện

Scenario: Dữ liệu free-text lệch chuẩn
  Given một số tin có city = "Sài Gòn"/"HCM"
  When tôi lọc "TP. Hồ Chí Minh"
  Then backfill province_code (so khớp không dấu) đã gom các biến thể về đúng tỉnh
  And tin chưa có code vẫn tìm được qua fallback ILIKE
```

### US-03 — Tìm quanh đây (GPS)
```gherkin
Scenario: Cấp quyền & có kết quả
  Given tôi bấm "Tìm quanh đây" và cấp quyền vị trí
  When app lấy được GPS
  Then hiển thị nhà 'approved' có toạ độ trong bán kính mặc định (3km)
  And sắp xếp tăng dần theo khoảng cách (ST_DWithin + ST_Distance)
  And tôi có thể đổi bán kính (1/3/5/10 km)

Scenario: Từ chối quyền vị trí
  When tôi từ chối cấp quyền
  Then hiển thị thông báo cần quyền + nút mở Cài đặt
  And đề xuất fallback: nhập địa danh hoặc chọn tỉnh/thành

Scenario: Không có nhà trong bán kính
  When kết quả rỗng
  Then hiển thị empty state + nút "Mở rộng bán kính" (mức kế tiếp)
```

### US-04 — Kết hợp filter + tìm kiếm
```gherkin
Scenario: Nearby + giá + loại hình
  Given tôi ở "Tìm quanh đây" bán kính 3km
  When tôi thêm giá <= 3 triệu và product_type = 'boarding_house'
  Then kết quả thoả đồng thời điều kiện không gian VÀ bộ lọc thuộc tính
  And vẫn sắp theo khoảng cách
```

---

## 2. Edge cases & xử lý chất lượng dữ liệu

| # | Tình huống | Xử lý |
|---|---|---|
| E1 | Tin `lat/lng = NULL` | Loại khỏi nearby/địa danh (không tính được khoảng cách); không vẽ pin. **Vẫn** hiển thị ở lọc tỉnh/thành + text search. |
| E2 | Chuyển list → map | Map chỉ vẽ tin có toạ độ. Banner "X phòng chưa có vị trí bản đồ" + link xem list — không "mất" listing. |
| E3 | Chuẩn hoá tỉnh | Bảng alias ("Sài Gòn"/"HCM"→TP.HCM) + so khớp không dấu (đã có ở `/provinces/search`). Lọc qua `province_code` chuẩn hoá. |
| E4 | `district` không thuộc `city` đã chọn | Ưu tiên lọc tỉnh; quận/huyện là thu hẹp best-effort trên free text, không chặn cứng. |
| E5 | Địa danh trả nhiều kết quả | Bắt buộc chọn 1 (disambiguation) trước khi tìm nhà. |
| E6 | GPS bị từ chối / tắt | Trạng thái rõ + CTA Cài đặt + fallback picker. Không crash/treo loading. |
| E7 | GPS ngoài bbox VN | "Vị trí ngoài phạm vi phục vụ" + fallback chọn tỉnh. |
| E8 | Kết quả rỗng (mọi mode) | Empty state riêng + CTA (mở rộng bán kính / nới bộ lọc / đổi từ khoá). |
| E9 | Toạ độ rác ngoài lãnh thổ | Bỏ qua khi vượt bbox VN. |
| E10 | Địa danh gần ranh giới tỉnh | Nearby/địa danh theo khoảng cách, chấp nhận kết quả xuyên tỉnh. |

---

## 3. Non-functional requirements (NFR)

- **Độ trễ:** nearby/tỉnh (PostGIS) p95 < 400ms trang đầu; geocode (Nominatim nội bộ) p95 < 800ms; round-trip UI có kết quả đầu < 1.5s trên 4G.
- **Rate limit:** tái dùng `slowapi`. Geocode/`search-nearby` ~120/h (đụng service chung planning); `/api/houses` giữ nguyên.
- **Phân trang:** nhất quán limit/offset; nearby sort khoảng cách ổn định (tie-break `id`).
- **Chỉ mục:** GIST trên `geom` (partial `status='approved' AND geom IS NOT NULL`).
- **Offline/permission:** mất mạng → lỗi mạng + retry; thiếu quyền vị trí → chỉ vô hiệu nearby, không chặn app.
- **Degrade:** Nominatim lỗi/timeout → fallback tỉnh + từ khoá, không để 5xx lan ra UI.

---

## 4. Success metrics
Xem `plan.md §10`. Trọng tâm: tỉ lệ dùng geo ≥30%, tỉ lệ non-empty ≥80%, độ phủ toạ độ ≥70% sau backfill, <5% phiên nearby lỗi quyền.

## 5. Ngoài phạm vi (v1)
Xem `plan.md §9`.
