# Plan v2: Khảo sát phân loại + Tách BĐS/Thi công + Feed thi công kiểu Facebook

Ngày: 2026-07-12. v2 = v1 + **điều chỉnh sau phản biện** (gỡ các điểm sót). Trigger: chủ SP
muốn (1) khảo sát sở thích phân loại người dùng (đa mục đích), (2) màn top phân định rõ
**Bất động sản** vs **Thi công**, (3) Thi công = **news feed kiểu Facebook mobile**.

## Quyết định đã chốt
1. Phân loại = **nhiều sở thích (multi-select)** → suy ra `default_world`.
2. Top split = **segmented ở đỉnh trang chủ** (`Bất động sản | Thi công`).
3. Cộng đồng ngành xây dựng nằm trong thế giới Thi công (nhưng **tách theo world**, xem §2b).
4. Lưu prefs = **client + backend** (đồng bộ).
5. Feed: showcase + thảo luận trước, RFQ-in-feed sau.

## Điều chỉnh cốt lõi sau phản biện (điểm sót → cách xử lý)
- **[Chiến lược] Feed cho hệ rỗng = thị trấn ma.** → Đảo ưu tiên: **P1 khảo sát + P2 top split**
  làm trước (giá trị cao, rủi ro thấp). **Feed FB (P3/P4) gate sau flag**, chỉ bật khi có nội
  dung thật; song song chạy **chiến dịch onboard đơn vị + tạo nội dung gốc** (không seed giả
  trên feed social). Có ngưỡng liquidity tối thiểu trước khi lộ Feed ra người dùng cuối.
- **[IA] Tránh 2 hệ điều hướng.** → **1 mô hình:** world-switcher (BĐS/Thi công) là trục
  chính ở đỉnh; **bottom-nav đổi nội dung theo world** (không phải cả 2 chạy song song):
  - World **Bất động sản** → tab: Khám phá · Yêu thích · Đặt lịch · Cá nhân.
  - World **Thi công** → tab: Bảng tin (feed) · Danh bạ · Yêu cầu của tôi · Cá nhân.
  (Cá nhân dùng chung.) Bỏ tab "Cộng đồng" độc lập.
- **[IA] Cộng đồng trải cả 2 world.** → **Tách cộng đồng theo world**: post `rent/lease/
  industrial` thuộc world BĐS (mục Cộng đồng-BĐS bên trong world BĐS, tuỳ chọn P4); post
  `design/build/interior` thuộc world Thi công (là chính Feed). KHÔNG gộp cả cục.
- **[Kỹ thuật] Feed không phải "reuse sẵn".** → Coi **Feed đồng nhất là hạng mục LỚN** (§3),
  không phải ráp nhẹ. Bổ sung schema + adapter, có ước lượng riêng.
- **[BA] "Tôi là đơn vị" là danh tính.** → Tách khỏi survey; là **CTA "Trở thành đơn vị"**
  riêng (kích hoạt luồng đăng ký Contractor đã có).
- **[Rủi ro] Redesign lớn + phiên song song.** → **Feature-flag toàn redesign**
  (`REDESIGN_V2`) dark-launch; migration **target revision cụ thể** (chuỗi multi-head có
  baseline `bef9a3d80bf2`), không `alembic upgrade head` mù.

---

## 1. BA — Nghiệp vụ

### 1a. Persona & interests
Đa mục đích → lưu **interests[]** (không ép vai trò). Từ interests suy `default_world`.
- interests: `rent, buy, sell_or_list, find_service, follow_construction`.
- **"đơn vị/nhà thầu" KHÔNG nằm trong interests** → CTA riêng "Trở thành đơn vị".
- **Tie-break default_world:** nếu có bất kỳ interest BĐS (`rent/buy/sell_or_list`) → mặc định
  BĐS; nếu CHỈ có `find_service/follow_construction` → Thi công; rỗng/bỏ qua → BĐS.

### 1b. Survey (≤3 câu, bỏ qua được, 1 lần, chỉnh lại trong Hồ sơ)
- Q1 (bắt buộc, multi): mục đích (5 lựa chọn trên). Q2 (tuỳ): tỉnh quan tâm. Q3 (điều kiện,
  nếu có interest thi công): mảng `design/build/interior/industrial`.

### 1c. Lưu prefs + vòng đời
- Khách: SharedPreferences. Đăng nhập: **merge client→account** (union interests; nếu account
  đã có prefs thì hợp nhất, không ghi đè) rồi `PUT /api/me/preferences`.
- **User cũ đã onboard (không có prefs):** lần vào đầu sau khi bật flag → hiện survey 1 lần
  (backfill), có "Bỏ qua". Cờ `prefs_prompted` để không nhắc lại.

### 1d. Ngưỡng liquidity cho Feed (điều kiện lộ P3)
Feed Thi công chỉ **hiển thị công khai** khi đạt tối thiểu (ví dụ) ≥N đơn vị approved + ≥M
bài đăng thật/tuần. Trước ngưỡng: mục Thi công hiển thị **Danh bạ + Đăng yêu cầu** (marketplace,
đã có), CHƯA mở feed social. Cấu hình qua flag + số liệu, không seed giả.

## 2. Designer — UI/UX

### 2a. Onboarding survey
1 trang: chip đa chọn (Q1) + dropdown tỉnh (Q2) + chip mảng (Q3, hiện có điều kiện). "Bỏ qua"
+ "Bắt đầu". HD tokens (đỏ accent, gradient). Xong → route theo `default_world`.

### 2b. Top split + 1 mô hình điều hướng
- Segmented `Bất động sản | Thi công` ngay dưới app bar (pill lớn, active = đỏ/trắng, có icon).
- **Bottom-nav đổi theo world** (§ điều chỉnh IA) — chỉ 1 hệ điều hướng, không chồng.
- Nhớ world gần nhất; mặc định = `default_world`.

### 2c. Feed Thi công kiểu Facebook — LÀM RÕ LAYOUT (tránh lệch FB)
Header **KHÔNG để thẻ hồ sơ to** như v1 (FB thật không vậy). Chuẩn FB mobile:
- **Hàng 1 (mảnh):** thanh chức năng xây dựng cuộn ngang (Thiết kế/Xây dựng/Nội thất/Công
  nghiệp/Danh bạ/Xếp hạng/Đăng yêu cầu) — kiểu shortcut bar.
- **Composer bar:** avatar nhỏ user + ô "Chia sẻ dự án / Bạn cần thi công gì?" + nút Ảnh /
  Yêu cầu báo giá. (Đây là nơi user "xuất hiện", thay cho thẻ hồ sơ to.)
- (Tuỳ chọn) story row đơn vị nổi bật.
- **Feed:** `PostCard` — tác giả + badge (đơn vị ✔), nội dung, ảnh, **Thích · Bình luận ·
  Chia sẻ**. Loại post: showcase / thảo luận / (sau) RFQ.
- Khách chưa login: composer đổi thành dải "Đăng nhập để đăng bài / cá nhân hoá"; vẫn xem/lướt.
- **Ngân sách chiều cao:** app bar + segmented + shortcut bar + composer phải gọn (≤ ~30% màn).
- **Trước khi code P3: chốt wireframe** (ảnh) với chủ SP để xác nhận đúng "kiểu Facebook".
- **Responsive web:** contentMaxWidth, cột theo breakpoint (audit đã chê thiếu).

## 3. Kiến trúc Feed đồng nhất (HẠNG MỤC LỚN — không phải reuse nhẹ)
Hiện trạng (đã kiểm): `SocialFeedProvider` chỉ nạp `SocialPost` (userId/content/images/category/
like/comment; KHÔNG có post-type, author-type, verified, share). Showcase = `ContractorProject`,
RFQ = `ConstructionLead` là **model KHÁC**.
Phương án: **Feed item polymorphic**
- Backend: `GET /api/construction/feed` trả list item chuẩn hoá `{type: post|showcase|rfq,
  author{name,avatar,is_contractor,verified}, content, images, meta, like/comment_count,
  liked_by_me, created_at, ref_id}` — hợp nhất 3 nguồn, phân trang cursor.
- SocialPost schema +: `post_type`, `author_is_contractor`, (share_count nếu làm share).
- Client: `FeedItem` + adapter render bằng `PostCard` mở rộng (badge + nút Chia sẻ + CTA
  "Báo giá" cho item RFQ). Reuse composer/comments đã có.
- Ước lượng: đây là phần nặng nhất của P3, cần task riêng.

## 4. Lộ trình (đảo ưu tiên + flag)
- **P1 — Khảo sát & prefs** (giá trị cao, rủi ro thấp): survey + PreferencesService + backend
  `user_preferences` (`GET/PUT /api/me/preferences`, migration target-rev) + merge/backfill +
  route landing. CTA "Trở thành đơn vị" tách riêng.
- **P2 — Top split + 1 hệ điều hướng:** WorldSwitcher; bottom-nav theo world; gỡ tile thi công
  khỏi world BĐS; bỏ tab Cộng đồng độc lập. Behind `REDESIGN_V2`.
- **P3 — Feed Thi công (gate liquidity + flag):** kiến trúc feed đồng nhất (§3) + shortcut bar +
  composer + PostCard mở rộng (badge/share) + loại showcase/thảo luận. **Chốt wireframe trước.**
- **P3.5 — RFQ-in-feed.** **P4 — cá nhân hoá** theo interests/khu vực + cộng đồng-BĐS trong
  world BĐS + story đơn vị + moderation bài đăng.

Mỗi phase: analyze sạch → build web → screenshot verify → commit → push. Tất cả sau `REDESIGN_V2`.

## 5. Rủi ro xuyên suốt & giảm thiểu
- **Migration multi-head:** dùng `alembic upgrade <revision>` cụ thể + test DB throwaway trước.
- **Phiên song song cùng repo:** làm sau flag, commit nhỏ, kéo main trước mỗi phiên; tránh sửa
  cùng file nav với phiên khác.
- **Mode-concept trùng:** GuestShell đã có host/guest mode. World-switcher là trục MỚI ở trên;
  phải hoà 2 khái niệm (world = BĐS/Thi công; mode chủ-nhà = chỉ trong world BĐS). Làm rõ ở P2.
- **Instrument KPI:** thêm event (survey_completed, world_switch, feed_view, post_created,
  rfq_from_feed) để đo thật, không đoán.
- **Guest merge/backfill** test kỹ (khách→login; user cũ→backfill).

## 6. Cần chốt trước khi code
- Wireframe header Feed "kiểu Facebook" (ảnh) — xác nhận đúng ý.
- Ngưỡng liquidity tối thiểu để mở Feed (số N đơn vị / M bài).
- Chủ trương nội dung gốc (ai/đội nào tạo bài thật ban đầu).
