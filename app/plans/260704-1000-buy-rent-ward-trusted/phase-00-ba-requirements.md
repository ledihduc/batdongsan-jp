# Phase 00 — BA Requirements

**Feature bundle:** Mua–Bán / Cho thuê tabs + Chọn phường xã (trước/sau sáp nhập 01/07/2025) + Auto-publish + Cờ "Uy tín" do admin phê duyệt.
**Ngày:** 2026-07-04
**Trạng thái:** BA analysis — chờ review.

---

## 1. Vấn đề & bối cảnh

App ancu365 hiện tại chỉ phục vụ **cho thuê phòng/nhà** (rental). Người dùng có 3 khó khăn:

1. **Không tìm được nhà bán trên app** — mọi tin đều là cho thuê; nếu muốn bán/mua thì phải dùng app khác.
2. **Không tìm được theo phường/xã cụ thể** — chỉ có tỉnh + huyện (đã có plan `260703-2332-geo-search`), trong khi VN vừa sáp nhập hành chính 01/07/2025:
   - Bỏ cấp huyện; còn 34 tỉnh + ~3.321 phường/xã (từ 63 tỉnh + ~10.600 xã).
   - Người dân, đặc biệt chủ đất/nhà, **vẫn quen tên cũ**; nhưng giấy tờ mới ghi tên mới.
3. **Đăng tin phải chờ admin duyệt** → chậm, người mua/thuê không thấy tin mới ngay; nhưng bù lại tin có mức độ tin cậy.

Yêu cầu người dùng đưa ra:
- Thêm 2 mục **Mua bán** & **Cho thuê** ở màn hình chính (guest home).
- Khi đăng tin, người đăng chọn **đăng bán** hoặc **đăng cho thuê**.
- Ở tìm kiếm phường/xã, cho chọn danh sách **trước sáp nhập** (10.600 xã) hoặc **sau sáp nhập** (3.321 xã) để phù hợp với cả người dùng cũ và mới.
- Đăng tin **không cần duyệt** — publish ngay lập tức; tin vẫn được gửi tới admin; admin **chỉ đánh cờ "Uy tín"** cho tin đã kiểm chứng → cờ hiển thị trên khung ảnh của bài đăng.

---

## 2. User Stories

### US-1 — Tìm mua/thuê ở màn hình chính
> **Là** người dùng đang tìm nhà, **tôi muốn** thấy ngay 2 tab "Mua bán" / "Cho thuê" ở đầu trang chủ, **để** không mất công lọc lại mỗi lần vào app.

### US-2 — Tìm theo phường/xã có toggle "Trước sáp nhập" / "Sau sáp nhập"
> **Là** người dùng đã quen tên phường/xã cũ (trước 01/07/2025), **tôi muốn** chọn "phường/xã trước sáp nhập" để tìm bằng tên cũ; **hoặc** chọn "sau sáp nhập" nếu tôi đọc trên giấy tờ hành chính mới, **để** không bị lạc bởi tên đã thay đổi.

### US-3 — Chủ nhà đăng tin: chọn Bán hoặc Cho thuê
> **Là** chủ nhà, **tôi muốn** khi đăng tin có thể chọn "đăng bán" hoặc "đăng cho thuê", nhập giá phù hợp (giá bán một lần vs giá thuê/tháng), **để** một tài khoản có thể vừa bán vừa cho thuê nhiều tài sản.

### US-4 — Đăng tin publish ngay
> **Là** chủ nhà, **tôi muốn** tin đăng xuất hiện ngay trên trang tìm kiếm sau khi bấm "Đăng", **để** không bỏ lỡ khách hàng đang tìm.

### US-5 — Admin đánh dấu tin uy tín
> **Là** admin, **tôi muốn** duyệt danh sách tin đăng và bấm 1 nút để đánh dấu tin đó là "uy tín", **để** người mua/thuê có thể phân biệt tin đã được kiểm chứng.

### US-6 — Người tìm nhìn thấy cờ "Uy tín"
> **Là** người dùng tìm nhà, **tôi muốn** thấy cờ "Uy tín" nổi bật trên khung ảnh của tin đăng đã được admin phê duyệt, **để** ưu tiên xem tin đó trước.

---

## 3. Acceptance Criteria (Gherkin)

### AC-1 (Home tabs)
```gherkin
Given tôi mở app và ở guest home
When màn hình load xong
Then tôi thấy 2 tab lớn "Mua bán" và "Cho thuê" ở đầu (dưới AppBar)
And tab "Cho thuê" được chọn mặc định (giữ hành vi cũ để không đảo lộn user hiện tại)
And khi tap "Mua bán" → chỉ thấy tin transaction_type='sale'
And khi tap "Cho thuê" → chỉ thấy tin transaction_type='rent'
And filter/search bar áp dụng riêng cho từng tab (không nhiễu chéo)
```

### AC-2 (Ward picker — toggle)
```gherkin
Given tôi mở search overlay và chọn "Chọn phường/xã"
When màn hình picker mở
Then tôi thấy segmented control ở đầu: "Sau sáp nhập" (mặc định) | "Trước sáp nhập"
And danh sách phường/xã dưới thay đổi theo lựa chọn
And khi chọn 1 phường "trước sáp nhập" → hiển thị chip "(nay thuộc: <phường mới>)" ở dưới ô search
And backend nhận cả 2 dạng slug (old_slug hoặc new_slug), luôn map về new_slug để query
```

### AC-3 (Post — chọn Bán/Cho thuê)
```gherkin
Given tôi mở màn hình "Đăng tin"
When tôi vào bước cơ bản
Then tôi thấy chip chọn "Đăng bán" | "Đăng cho thuê" ngay đầu form
And label field giá đổi theo:
  - Đăng bán → "Giá bán (triệu VND)"
  - Đăng cho thuê → "Giá thuê / tháng (VND)"
And validator giá đổi theo (bán: ≥100tr; thuê: ≥500k/tháng — không cứng, chỉ warn)
And không chọn được cả 2, không để trống
```

### AC-4 (Auto-publish)
```gherkin
Given tôi là chủ nhà đã đăng tin thành công
When request POST /api/houses trả 201
Then house.status = 'published' (không phải 'pending')
And tin xuất hiện ngay trên guest search (không cần refresh)
And tin gửi notification tới admin (queue background, không chặn UI)
And tin mặc định is_trusted = false
```

### AC-5 (Admin trusted toggle)
```gherkin
Given tôi là admin và đang ở màn admin listings review
When tôi bấm nút "Đánh dấu uy tín" trên 1 tin
Then house.is_trusted = true
And card của tin có cờ "Uy tín" hiển thị ngay ở góc trên bên trái khung ảnh
And chủ tin nhận notification "Tin của bạn đã được đánh dấu uy tín"
And admin có thể bỏ đánh dấu (toggle off)
```

### AC-6 (Trusted badge hiển thị)
```gherkin
Given tin có is_trusted = true
When tin xuất hiện trên guest home / search results / house_detail
Then cờ "Uy tín" hiển thị trên khung ảnh (top-left, chip vàng-đỏ Editorial tone)
And cờ có tooltip "Đã được ancu365 kiểm chứng" khi hover/long-press
And không đè lên nút wishlist (top-right) hay nút back (top-left AppBar)
```

---

## 4. Edge cases

| # | Edge case | Behavior mong muốn |
|---|-----------|---------------------|
| E1 | User dùng app trên máy cũ, cache list là 'approved' status | Backend vẫn accept `status=approved` OR `status=published` khi filter; ưu tiên trả 'published'. Migration đổi 'approved' → 'published'. |
| E2 | Tin cũ đã 'approved' | Migration: `status='approved'` → `status='published'`; `is_trusted=false` (không tự set uy tín cho tin cũ để tránh spam admin). |
| E3 | Tin cũ 'pending' | Migration: `status='pending'` → `status='published'`. Admin đọc log 1 lần để duyệt catch-up nếu muốn. |
| E4 | Người dùng chọn phường trước sáp nhập nhưng phường đó không có mapping mới (dữ liệu thiếu) | UI show fallback: "Phường/xã này đã đổi tên, thử tìm bằng danh sách sau sáp nhập". Không crash. |
| E5 | Tin có toạ độ nhưng không map được về phường/xã | Vẫn hiển thị bình thường, không loại; sort theo distance nếu applicable. |
| E6 | Admin đánh dấu uy tín rồi bỏ | `is_trusted_updated_at` lưu lịch sử; badge biến mất; notification "Cờ uy tín đã được gỡ" (optional). |
| E7 | Cùng 1 chủ nhà đăng cả tin bán và tin thuê | Cho phép; mỗi tin là 1 record với transaction_type khác nhau. Không giới hạn. |
| E8 | Chủ nhà đổi transaction_type sau khi đăng | Cho phép trong 24h đầu; sau 24h phải đăng tin mới (tránh gian lận đổi giá bán → giá thuê). |
| E9 | Đăng tin có nội dung xấu/spam | Admin có nút "Ẩn tin" (soft-delete) song song với "Đánh dấu uy tín". Không phải phần "cờ uy tín" mà là moderate. |
| E10 | User chưa login mà bấm "Đăng bán/cho thuê" | Redirect login, giữ state đã chọn để tránh phải chọn lại. |

---

## 5. Non-Functional Requirements

- **Backward-compat:** API `/api/houses` phải chấp nhận cả `status=approved` (legacy) và `status=published` (mới) → alias.
- **Performance:** thêm index `(transaction_type, status, is_trusted)` để list query nhanh; response p95 < 400 ms.
- **A11y:** cờ "Uy tín" phải có `Semantics(label: 'Tin đã được ancu365 kiểm chứng')`.
- **i18n:** Tất cả copy tiếng Việt, tuân `docs/vietnamese-glossary.md` (Xóa, hủy, mua bán, cho thuê).
- **Dữ liệu phường/xã:** dataset offline, không phụ thuộc mạng khi mở picker.

---

## 6. Out of Scope (v1)

- Không làm bản đồ heatmap giá bán / giá thuê theo phường/xã.
- Không tự phát hiện "tin trùng lặp" (spam detection).
- Không làm hệ thống chấm điểm uy tín theo lịch sử (chỉ có on/off flag do admin thao tác).
- Không thêm gói VIP / boost tin.
- Không làm auto-verify qua giấy tờ (KYC listing).
- Không migrate toàn bộ tin cũ về "trước sáp nhập" — chỉ áp dụng cho tin mới có `ward_slug` chuẩn.

---

## 7. Open Questions (cần user chốt trước khi lock plan)

| # | Câu hỏi | Đề xuất mặc định |
|---|---------|-------------------|
| Q1 | Tab "Cho thuê" hay "Mua bán" là mặc định? | **Cho thuê** — giữ hành vi cũ, không đảo lộn 100% user hiện tại. |
| Q2 | Tin cũ đã `approved` sau migration nên đặt `is_trusted = ?` | **false** — admin sẽ đánh dấu lại theo tiêu chí mới. Tránh spam badge lịch sử. |
| Q3 | Admin có cần "lý do" khi bỏ cờ uy tín (audit trail) không? | **Không bắt buộc** ở v1; log thời điểm + admin id là đủ. |
| Q4 | Ai được xem cờ uy tín? Guest anon hay chỉ user login? | **Cả 2** — cờ là điểm khác biệt về niềm tin, luôn public. |
| Q5 | Cờ uy tín có ảnh hưởng ranking không? | **v1: không** — chỉ hiển thị. Boost ranking sẽ tính ở v2 sau khi có metric. |
| Q6 | Nguồn dữ liệu phường/xã trước sáp nhập | **Dùng vietnam-provinces v1 (đã có JSON) + dataset communes 2024 public từ chính phủ (danh mục HC 2020)**. Sau sáp nhập: **Nghị quyết 202/2025/QH15 + Nghị định cấp phường/xã 2025**. |
| Q7 | Mapping old→new commune | **Bảng cứng trong JSON**, không tra cứu online. |
| Q8 | Có cần multi-select ward (chọn nhiều phường 1 lúc) không? | **v1: không** — chỉ 1 ward tại 1 thời điểm. Multi-select đưa v2. |
| Q9 | Post publish auto có cần rate-limit anti-spam? | **Có** — giới hạn 5 tin / 24 h / user (soft-cap; admin có thể bỏ giới hạn). |
| Q10 | Người dùng thấy tin của mình trong lúc chờ admin trusted-review không? | **Có, ngay** — status = published sẵn; badge trusted là add-on. |

---

## 8. Impact / Risk

| # | Rủi ro | Mitigation |
|---|--------|-------------|
| R1 | Đảo ngược approval flow → tin xấu/spam tràn màn hình chính | Rate-limit 5 tin/24h + admin có "Ẩn tin" 1-click + report abuse từ guest. |
| R2 | Dataset phường/xã (~13 nghìn record cả trước+sau) làm bundle Flutter phình | Tách JSON assets, lazy-load theo tỉnh; nén gzip ~200KB. |
| R3 | Mapping old→new commune sai/thiếu | v1 chỉ hỗ trợ ~90% commune có mapping chuẩn; 10% còn lại show fallback message. |
| R4 | Tin cũ 'approved' → 'published' phá analytics dashboard | Alias 'approved' trong API filter + note trong changelog + migration reversible. |
| R5 | Cờ trusted bị lạm dụng (admin đánh dấu tin của bạn bè) | Audit log all trusted toggle → super-admin review; ra roadmap v2 quy trình double-check. |
| R6 | Home tabs làm CTR trang chính giảm nếu user Rent quen scroll thấy nhà thuê ngay | Rent tab mặc định + tab bar bám phần trên → chỉ 1 tap để đổi. Đo lường CTR sau 2 tuần. |

---

## 9. Success Metrics

- **Adoption Sale tab:** ≥15% guest active users mở tab "Mua bán" trong 4 tuần đầu.
- **Post breakdown:** ≥10% tin đăng mới là transaction_type='sale' trong 4 tuần.
- **Publish speed:** thời gian từ POST /api/houses tới visible ở search: p95 < 5s (trước đây phải chờ admin, có thể vài giờ).
- **Trusted badge coverage:** ≥30% tin có > 100 views được admin đánh cờ trong 2 tuần.
- **Ward search:** ≥40% search có sử dụng chọn phường/xã (đo qua param `ward_slug`).
- **User retention:** không giảm >5% so với baseline sau khi đổi flow.

---

## 10. Dependencies

- **Blocker:** Plan `260703-2332-geo-search` đang chờ implement. Ward picker (feature 1) nên chờ Phase 04 của geo-search xong (SearchProvider + location picker) → tránh conflict merge.
- **Data:** Cần dataset commune 2024 (trước) và 2025 (sau); ước tính ~200KB gzipped.
- **Backend:** không cần package mới; chỉ migration + endpoint mới.
- **Flutter:** không cần package mới (dùng flutter/material sẵn có).

---

## 11. Waypoints trước khi lock

Trước khi chuyển sang plan chi tiết, cần confirm với user:
1. Q1–Q10 ở phần Open Questions (đề xuất mặc định trong bảng).
2. Có OK với việc **giữ song song** cả `status='approved'` (legacy) và `status='published'` (mới) qua alias, thay vì migrate hết?
3. Có OK với việc **defer feature 2 (ward picker)** đến khi geo-search Phase 04 landed, để chạy song song feature 3 (Sale/Rent) + feature 4 (Trusted) trước?
