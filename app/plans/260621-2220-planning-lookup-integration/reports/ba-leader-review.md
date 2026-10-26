# BA Leader Review — Phase 00 BA Requirements

**File reviewed:** `phase-00-ba-requirements.md`  
**Reviewer role:** BA Leader (Senior BA)  
**Date:** 2026-06-21

---

## Tóm tắt (TL;DR)

Tài liệu BA chất lượng khá: problem statement rõ, 5 US bao quát 3 flow chính (browse listing / post listing / standalone lookup), AC hầu hết đo lường được, đã ý thức disclaimer pháp lý. **Điểm yếu lớn:** thiếu persona **admin** (đã có trong DB schema ancu365), thiếu **non-functional requirements** (i18n, accessibility, dark mode, location permission), AC-02/AC-03 có ngưỡng performance không khả thi cho mobile + self-host stack, và risk legal/IP dữ liệu WFS TNMT chưa được đánh giá đầy đủ. Một số Open Questions thực sự là **blocking decisions** cần chốt trước khi Tech Lead plan, không phải "ngoài scope".

**Verdict:** **NEEDS_REVISION** (mức độ vừa — không phải làm lại, chỉ patch thêm 5–7 chỗ).

---

## Findings

### 1) Completeness of User Stories

| Issue | Mức | Mô tả |
|------|-----|------|
| Thiếu persona **Admin** | Cao | DB schema (`database_helper.dart`) đã có role `admin` + `host` + `guest`. BA bỏ sót use case admin xem báo cáo zoning vi phạm, force-unlist tin vi phạm quy hoạch. |
| Thiếu persona **Anonymous/chưa login** | Trung | US-03 nói "user bất kỳ role nào" nhưng không xác định user chưa login có dùng được không. Tra quy hoạch nên public để SEO/marketing — cần làm rõ. |
| Thiếu US cho **error reporting** | Thấp | Khi data sai (zone hiển thị nhầm), user có cách nào báo cáo? Liên quan trực tiếp tới Risk "kiện do dữ liệu sai". |
| Thiếu US cho **performance trên 3G/4G yếu** | Trung | Người dùng VN dùng mạng kém phổ biến. Cần US về caching offline hoặc thấp-bandwidth mode. |

### 2) Testability của Acceptance Criteria

| AC | Vấn đề | Đề xuất |
|----|--------|--------|
| AC-02 | "< 500ms" sau tap thửa — không tính time-to-first-tile-load, không nêu network condition, không nêu thiết bị. Mobile 4G real-world realistic ~1–2s nếu cache miss. | Tách: "< 200ms nếu cache hit; < 1.5s p95 nếu cache miss trên 4G" |
| AC-03 | "Độ trễ < 1s với cache" — không có baseline cache miss. Nominatim self-host có thể chậm cold start. | Thêm: "< 2.5s p95 cache miss" |
| AC-01 | "Tap icon → render" — không nêu cold start vs warm. | Thêm benchmark cold start < 3s |
| AC-04 | "Mở 3 nhà khác nhau Q1/Q3/Thủ Đức" — không phải tiêu chí đo lường, chỉ là test script. | Đổi thành: "100% house detail trong DB test (≥10 mẫu) hiển thị badge đúng zone" |
| AC-06 | "Hiển thị thông báo" — không định nghĩa wording cụ thể, không định nghĩa "ngoài 24 quận" (toạ độ vs reverse geocode). | Định nghĩa bounding box HCMC + wording exact |
| AC-07 | "Fallback message rõ ràng" — vague | Thêm: retry button, error code, không retry tự động vô hạn |
| AC-09 | Disclaimer chỉ footer panel — không xuất hiện ở House detail badge (US-01) và Post screen warning (US-02). | Thêm AC-09b: disclaimer xuất hiện ở MỌI nơi hiển thị zone info |

**AC còn thiếu:**
- AC về **i18n**: app có `flutter_localizations` — zone_name cần tiếng Việt, không hardcode English.
- AC về **dark mode**: ancu365 chưa rõ có dark mode chưa, nhưng cần check màu zone (TNMT dùng màu sáng) có readable trên dark theme.
- AC về **accessibility**: TalkBack/VoiceOver đọc được zone info, contrast ratio màu vùng ≥ 3:1.
- AC về **location permission**: nếu user từ chối GPS, app vẫn dùng được (search + tap manual).
- AC về **deeplink**: house detail → planning map có giữ context (zoom level, marker nhà).
- AC về **memory**: vector tile cache không vượt N MB, có cơ chế evict.

### 3) Hidden Scope Creep

| Item | Mức | Phân tích |
|------|-----|----------|
| US-02 "tự động hiện zone khi nhập địa chỉ" | Cao | Cần debounced geocoding khi user gõ + reverse polygon lookup + zone display TRƯỚC khi submit. Đây là feature riêng biệt, ngầm yêu cầu integrate sâu vào PostHouseScreen — có thể x2 effort. **Đề xuất:** tách US-02 thành Phase 1.5 hoặc giảm scope (chỉ button "Kiểm tra quy hoạch" mở modal thay vì auto-realtime). |
| US-05 "slider opacity 0–100%" | Thấp | Slider UI thực ra dễ, nhưng test trên Android/iOS với vector tile có thể phức tạp. OK. |
| AC-03 dropdown gợi ý địa chỉ | Trung | Autocomplete dropdown = thêm component UI + cache layer + abort controller. Không phức tạp nhưng đáng note. |

### 4) Contradictions

| ID | Vấn đề |
|----|--------|
| US-03 vs Out-of-Scope #7 | US-03 nói "tra quy hoạch của bất kỳ điểm nào ở TP.HCM" — nhưng Out-of-Scope ghi "Authentication riêng cho planning API — dùng chung JWT của ancu365". Nếu user chưa login (anonymous), liệu có gọi được API không? Cần làm rõ: API planning có require auth không? |
| Open Q #1 (a) "chạy 2 backend song song" vs Assumption "dùng chung JWT" | Nếu faceconst FastAPI chạy riêng, phải có middleware verify JWT của ancu365. Hiện FastAPI chưa có route nào — assumption JWT shared là chưa được verify. |
| AC-02 < 500ms vs Open Q #2 vector_map_tiles "hơi nặng" | Mâu thuẫn rõ ràng. Không thể đảm bảo 500ms nếu chính BA admit lib nặng. |

### 5) Missing Edge Cases

- **Multi-language**: app có thể có user nói English (expat thuê dài hạn ở HCMC). Zone name "Đất ở đô thị" cần có English fallback hoặc i18n.
- **Dark mode / Theme**: zone color overlay có thể conflict với dark map base.
- **Location permission denied**: app fallback ra sao?
- **Network khi đang fly-to**: nếu mạng cắt giữa lúc fetch tile, có cancel kịp không?
- **Tap nhanh nhiều thửa liên tiếp**: race condition khi 2 request parcel detail concurrent.
- **Thửa quá nhỏ / quá to**: thửa < 1m² (lỗi data) hoặc thửa > 1km² (đất công cộng lớn) — UI có vỡ không?
- **Toạ độ trên biên giới quận**: 1 điểm có thể thuộc 2 polygon do data conflict. Chọn polygon nào?
- **GPS drift trong nhà cao tầng**: định vị sai 50–100m → zone hiển thị sai → user kiện. Có hiển thị accuracy radius không?
- **Map base tile fail** nhưng vector tile OK (hoặc ngược lại) — UI partial.
- **Background → foreground**: state map có persist không?
- **Phiên bản dữ liệu**: zone là "Quy hoạch 2030" — khi TNMT release 2050, làm sao versioning, có UI cho user chọn năm không?
- **Vùng giáp ranh tỉnh khác** (giáp Long An, Bình Dương): user tap gần biên giới hành chính.

### 6) Unclear / Risky Assumptions

| Assumption | Risk | Đề xuất |
|-----------|------|--------|
| "ancu365 backend là Node.js/Express (suy ra từ localhost:3000)" | Cao — chưa verified, ảnh hưởng decision shared vs separate backend | Cần Tech Lead xác nhận STACK trước khi plan. Đề xuất task discovery 1 ngày. |
| "Người dùng đa số ở TP.HCM" | Trung — nhưng app cũng có guest từ tỉnh khác về HCMC thuê | OK cho MVP, nhưng cần plan cho non-HCMC location showing "tính năng chưa hỗ trợ khu vực này". |
| "Dữ liệu WFS TNMT TP.HCM vẫn hoạt động" | Cao — TNMT đổi endpoint, đổi auth, đổi schema → ETL chết | Cần SLA monitoring, alert khi WFS fail, fallback dataset cached. |
| "Server ≥ 8GB RAM" | Trung — chưa được provision | Cần xác nhận hosting plan trước khi commit deadline. |
| Implicit: "JWT của ancu365 dùng được cho FastAPI" | Cao — FastAPI chưa có auth middleware, format JWT có thể khác | Bắt buộc verify trong Tech Lead phase, không assume. |
| Implicit: "Dữ liệu WFS TNMT public, OK redistribute qua app" | **Rất cao — Legal** | Phải check ToU của TNMT TP.HCM. Có rất nhiều bộ dữ liệu Nhà nước VN cấm redistribute commercial. |

### 7) Open Questions — đủ ưu tiên?

Open Questions hiện list 5 câu, NHƯNG:

- **Q#1 (backend chia sẻ hay tách) là BLOCKING** — không thể plan Phase 1 nếu chưa quyết. BA đã có khuyến nghị (a) nhưng cần user confirm.
- **Q#3 (hosting) BA tự đẩy "ngoài scope plan này"** — sai. Hosting quyết định deployment timeline + cost + có deploy được không. **Phải có quyết định trước khi merge code.**

**Còn thiếu (phải bổ sung):**
- Legal: ToU của TNMT TP.HCM cho phép app thương mại dùng dữ liệu không?
- Privacy: app có log GPS / search query của user không? Lưu bao lâu?
- Branding: zone color theo TNMT chính thức hay tự design? (Nếu đổi màu, có thể bị accuse "không phản ánh chính thức".)
- Phạm vi quận/huyện: 24 hay 22 đơn vị hành chính HCMC sau sáp nhập 2025? Cần update.
- Internationalization timeline: VN-only mãi mãi, hay Phase 2 cho HN/ĐN?
- Performance budget cụ thể: app size delta tối đa khi thêm feature là bao nhiêu MB?
- KPI thành công: bao nhiêu % user dùng feature/tháng được coi là thành công?
- Analytics: track event nào? (parcel_tap, zone_lookup, etc.)

### 8) Risk Matrix — còn thiếu

Risk hiện có 6 mục, mostly tech. **Thiếu các risk quan trọng:**

| Risk thiếu | Mức | Mitigation gợi ý |
|-----------|-----|-----------------|
| **Legal/IP — TNMT cấm redistribute commercial** | **Rất cao** | Đọc ToU trước commit code; nếu cấm, dừng dự án hoặc đàm phán license. |
| **Privacy — log GPS user vi phạm Nghị định 13/2023 (luật bảo vệ DLCN VN)** | Cao | Anonymize log, retention policy ≤ 30 ngày, không share third party. |
| **Dữ liệu sai → user kiện civil/criminal** | Cao | Disclaimer mạnh hơn; thêm Terms phải accept trước khi dùng tính năng; bảo hiểm trách nhiệm? |
| **ETL fail âm thầm → user thấy data cũ không biết** | Trung | UI hiển thị "Dữ liệu cập nhật: dd/mm/yyyy"; alert ops nếu > 7 ngày. |
| **Lệ thuộc 1 nguồn data (TNMT)** | Trung | Có backup mirror; document quy trình migrate nếu source đổi. |
| **Reverse engineering / data scraping** | Trung | Rate limit API, không expose raw WFS public. |
| **Đơn vị hành chính HCMC đã/đang sáp nhập (theo NQ 2025)** | Trung | Mapping cũ → mới phải có; UI cần handle tên quận cũ vs mới. |
| **flutter_map breaking change** (lib version 7.x đang phát triển nhanh) | Thấp | Lock version + test trước khi upgrade. |
| **App Store review reject** vì hiển thị thông tin "official government" mà không có authorization | Trung | Disclaimer + có thể cần submit kèm tài liệu nguồn data khi review. |

---

## Concrete Revisions (đề xuất sửa cụ thể)

### A) Thêm User Stories

```
### US-06 — Admin theo dõi tin vi phạm quy hoạch
**As an** admin của ancu365,
**I want** xem danh sách các listing có zone "đất công cộng / quy hoạch giải toả",
**so that** tôi có thể yêu cầu host gỡ tin hoặc bổ sung giải trình.

### US-07 — Anonymous user tra cứu công khai (Marketing/SEO)
**As an** anonymous user (chưa đăng nhập),
**I want** dùng tính năng tra quy hoạch không cần tạo tài khoản,
**so that** tôi trải nghiệm trước khi quyết định đăng ký.
(Lưu ý: limit số lượt/ngày để chống abuse.)

### US-08 — Báo cáo dữ liệu sai
**As any** user nhìn thấy zone hiển thị không đúng thực tế,
**I want** tap "Báo cáo dữ liệu sai" → form đơn giản (ảnh + ghi chú),
**so that** đội ngũ có thể điều tra và disclaimer được củng cố.
```

### B) Sửa Acceptance Criteria

- **AC-02 cũ → mới:** "Bottom sheet hiển thị parcel detail < 200ms nếu cache hit; p95 < 1.5s khi cache miss trên 4G (mid-range Android Galaxy A series); KHÔNG đo trên emulator."
- **AC-03 mới:** "p95 < 2.5s cache miss (Nominatim self-host warm), p95 < 800ms cache hit."
- **AC-04 mới:** "100% house detail trong DB seed (≥ 10 mẫu phân bố 3+ quận) hiển thị badge đúng zone; tap badge → mở `/tra-quy-hoach` với map zoom 16, marker nhà visible."
- **AC-06 mới:** "Tap/search vị trí ngoài bounding box [10.35, 106.30, 11.20, 107.05] → toast tiếng Việt: 'Tạm thời chỉ hỗ trợ TP.HCM. Bạn có muốn xem map vị trí thường không?' + nút 'Mở map thường'. Không crash, không retry tự động."
- **AC-07 mới:** "Khi planning API trả 4xx/5xx hoặc timeout > 8s → error card với mã lỗi + nút 'Thử lại'. Sau 3 lần retry user-initiated, hiển thị 'Vui lòng kiểm tra mạng hoặc thử lại sau'. KHÔNG retry vô hạn."

### C) Thêm AC mới

- **AC-10 — i18n:** Tất cả label UI có entry trong arb/locale file; zone_name fallback EN nếu thiếu.
- **AC-11 — Dark mode:** Zone overlay opacity tự động giảm 10% trong dark mode; contrast ratio text trong panel ≥ 4.5:1.
- **AC-12 — Accessibility:** TalkBack đọc đầy đủ panel detail; tất cả tap target ≥ 48dp.
- **AC-13 — Location permission denied:** App vẫn dùng được qua search; không bắt buộc GPS.
- **AC-14 — Tile cache:** Vector tile cache trên device ≤ 100MB; có nút "Xoá cache" trong Settings.
- **AC-15 — Data freshness:** Panel detail hiển thị "Cập nhật: dd/mm/yyyy"; cảnh báo vàng nếu > 30 ngày.
- **AC-16 — Disclaimer ubiquitous:** Disclaimer xuất hiện ở: panel parcel, badge house detail, warning post-screen, footer screen `/tra-quy-hoach`.
- **AC-17 — Concurrent tap:** Tap 2 thửa liên tiếp < 500ms → request 1 bị cancel, không race condition UI.

### D) Update Out-of-Scope

Thêm rõ ràng:
- ❌ Auto block submit listing nếu zone vi phạm (chỉ warning — đã rõ trong Open Q #4)
- ❌ Real-time GPS tracking (chỉ snapshot khi user request)
- ❌ AR view zone trên camera
- ❌ Tích hợp dữ liệu giá đất theo zone
- ❌ Multi-province (HCMC only Phase 1)
- ❌ Versioning multi-year zoning (chỉ "2030", không cho chọn năm)

### E) Promote Open Questions thành blocking decisions

Thêm phần **"Blocking Decisions — phải chốt trước Phase 3"**:
1. ancu365 backend stack (Node/Express? NestJS? Express + Prisma?) — cần verify.
2. Backend strategy: 2 backend song song (recommend) vs port API.
3. Hosting & budget cap cho production (Supabase vs VPS).
4. **Legal:** Đã đọc & confirm ToU của TNMT TP.HCM chưa? Nếu chưa — chặn trước khi viết code.
5. Anonymous user policy: tra quy hoạch có cần login không?

### F) Mở rộng Risk Matrix

Add các risk ở mục 8 ở trên (legal/IP, privacy Nghị định 13, GPS drift, ETL fail âm thầm, lệ thuộc 1 nguồn, sáp nhập đơn vị HC, app store review reject).

### G) Bổ sung Non-Functional Requirements section (mới)

```
## Non-Functional Requirements
- Performance: parcel tap p95 < 1.5s 4G; cold start < 3s.
- App size delta: ≤ +15 MB sau khi tích hợp vector_map_tiles.
- Battery: 5 phút sử dụng map < 5% pin (mid-range device).
- Memory: peak RAM < 350MB khi map mở.
- Privacy: GPS log retention ≤ 30 ngày, hash userId.
- Offline: cache 3 tile levels gần đây, panel detail readable offline (24h).
- A11y: WCAG 2.1 AA cho text/contrast.
- i18n: VI primary, EN fallback.
```

---

## Verdict

**NEEDS_REVISION**

**Lý do (ngắn gọn):**
1. Thiếu persona admin & anonymous user (CRITICAL — đã có trong stack ancu365).
2. AC performance không khả thi / không có baseline (CRITICAL).
3. Thiếu hoàn toàn Non-Functional Requirements (i18n, a11y, dark mode, location perm).
4. Risk legal/IP TNMT data + privacy Nghị định 13 chưa cover (HIGH — có thể chặn cả dự án).
5. 2 Open Questions là blocking nhưng bị treat như "nice to know".
6. US-02 ngầm scope creep — cần tách hoặc giảm.

**Ước lượng effort sửa:** 1–2h (không phải làm lại, chỉ patch như mục Concrete Revisions ở trên).

**Sau khi sửa xong + user approve → Tech Lead có thể bắt đầu Phase 3 (Tech Lead Planning).**

---

## Unresolved Questions (cho user)

1. ancu365 backend hiện tại CHÍNH XÁC là stack gì? (Node/Express/NestJS/Fastify?) — cần verify trước.
2. ToU của TNMT TP.HCM về việc redistribute dữ liệu WFS trong app thương mại đã được kiểm tra chưa?
3. Có bắt buộc anonymous user dùng feature được không, hay phải login?
4. Sáp nhập đơn vị hành chính HCMC 2025 đã ảnh hưởng tới dataset planning chưa?
5. Có budget cụ thể cho hosting production chưa?
6. App ancu365 hiện có dark mode chưa? Có cam kết WCAG AA không?
