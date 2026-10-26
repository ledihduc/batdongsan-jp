# Phase 00 — BA Requirements: Tích hợp "Tra cứu Quy hoạch" vào ancu365

> **Revision r2** — đã áp dụng concrete revisions từ BA Leader review (lưu tại `reports/ba-leader-review.md`) + 5 quyết định khoá của user.

---

## Locked Decisions (User confirmed 2026-06-21)

| # | Quyết định | Implication |
|---|------------|-------------|
| D1 | **Share backend.** Merge planning service vào `ancu365-backend` (FastAPI, đã xác nhận cùng stack với faceconst). | Không tách microservice. Route `/api/planning/*` thêm vào FastAPI hiện hữu. |
| D2 | **Flutter dùng `vector_map_tiles` trước.** | POC ở Phase 04 đầu tiên. Có fallback raster Martin. |
| D3 | **Hosting production: VPS self-host Docker.** | ~$41-62/mo theo ADR-002 faceconst. Tự lo backup + monitoring. |
| D4 | **Khi host đăng tin sai quy hoạch: cảnh báo, không block.** | UI hiển thị banner vàng + log analytics; cho phép submit. |
| D5 | **Nominatim self-host cho production.** | Cần ~5GB data Vietnam + ≥ 4GB RAM cho Nominatim container. |

---

## Problem Statement

Người dùng ancu365 (host và guest) cần biết thông tin **quy hoạch sử dụng đất** của một địa chỉ trước khi:
- **Guest:** đặt thuê dài hạn (lo ngại giải toả, hành lang an toàn, ngập lụt).
- **Host:** đăng tin (xác nhận quy hoạch cho phép cho thuê, tránh tranh chấp).
- **Admin:** giám sát listing có địa chỉ thuộc khu quy hoạch giải toả / đất công cộng.
- **Anonymous user:** trải nghiệm thử trước khi đăng ký (Marketing/SEO).

Hiện ancu365 chỉ có bản đồ vị trí nhà (OSM raster + marker giá). Trong khi đó, **faceconst** đã có ETL Python + PostGIS + Martin + Nominatim — toàn bộ portable sang `ancu365-backend` vì cùng stack FastAPI.

---

## User Stories

### US-01 — Guest tra cứu quy hoạch trước khi đặt phòng
**As a** guest đang xem chi tiết một nhà,
**I want** thấy badge "Quy hoạch: <zone_name>" + link "Xem trên bản đồ" ngay trong house detail,
**so that** tôi yên tâm về tính pháp lý trước khi book.

### US-02 — Host kiểm tra quy hoạch khi đăng tin (scope giảm so với r1)
**As a** host đang ở `PostHouseScreen`,
**I want** một button "Kiểm tra quy hoạch" → modal hiển thị zone tại địa chỉ đã nhập,
**so that** tôi biết tin có nằm vùng quy hoạch nhạy cảm; UI **cảnh báo nhưng không block submit** (per D4).

> ✂️ Giảm scope: bỏ "tự động real-time hiện zone khi gõ địa chỉ" — chỉ user-initiated khi tap button.

### US-03 — User tra cứu độc lập trên map
**As any** user (login hoặc không, per US-07),
**I want** mở tab "Tra quy hoạch" riêng, search hoặc tap map,
**so that** tôi tra được quy hoạch bất kỳ điểm nào ở TP.HCM.

### US-04 — Xem chi tiết thửa đất
**As a** user đã tap 1 thửa,
**I want** bottom sheet hiển thị zone_name, zone_code, area_m2, sheet_no/parcel_no, quận, ngày cập nhật, disclaimer,
**so that** tôi nắm thông tin đầy đủ.

### US-05 — Toggle/điều chỉnh lớp quy hoạch
**As a** user trên map,
**I want** bật/tắt lớp "Quy hoạch sử dụng đất 2030" + slider opacity 0–100%,
**so that** tôi vẫn nhìn được nền bản đồ + marker nhà ở dưới.

### US-06 — Admin theo dõi tin vi phạm quy hoạch  *(NEW)*
**As an** admin của ancu365,
**I want** xem báo cáo các listing có zone thuộc nhóm "rủi ro" (đất công cộng / quy hoạch giải toả / cây xanh),
**so that** tôi có thể yêu cầu host gỡ tin hoặc giải trình.

### US-07 — Anonymous user tra cứu công khai  *(NEW)*
**As an** anonymous user (chưa đăng nhập),
**I want** dùng tab "Tra quy hoạch" mà không cần đăng ký,
**so that** tôi trải nghiệm trước khi tạo tài khoản. **Rate-limit:** 30 req/IP/giờ để chống abuse.

### US-08 — Báo cáo dữ liệu sai  *(NEW)*
**As any** user thấy zone không đúng thực tế,
**I want** tap "Báo cáo dữ liệu sai" → form (lý do ngắn + optional ảnh) gửi về admin,
**so that** team điều tra và disclaimer được củng cố.

---

## Acceptance Criteria

### Functional

| ID | Tiêu chí | Cách verify |
|----|----------|-------------|
| AC-01 | Tab/icon "Tra quy hoạch" mở được từ home (hoặc menu); cold start render map < 3s | Stopwatch trên Android Galaxy A series (mid-range) |
| AC-02 | Tap thửa → bottom sheet hiển thị parcel detail: **< 200ms cache hit, p95 < 1.5s cache miss trên 4G**; KHÔNG đo trên emulator | Manual QA 20 taps, log time |
| AC-03 | Search "Trần Phú, Quận 1" → dropdown gợi ý; **p95 < 2.5s cache miss, < 800ms cache hit** | Manual QA với Nominatim warm |
| AC-04 | 100% house detail trong DB seed (≥10 mẫu, ≥3 quận) hiển thị badge đúng zone; tap badge → mở `/tra-quy-hoach` zoom 16, marker nhà visible | E2E test |
| AC-05 | Layer toggle ON/OFF + slider opacity 0–100% mượt (≥30fps) | Manual QA |
| AC-06 | Tap/search ngoài bounding box `[10.35, 106.30, 11.20, 107.05]` → toast: "Tạm thời chỉ hỗ trợ TP.HCM. Bạn có muốn xem map thường không?" + nút "Mở map thường". KHÔNG crash, KHÔNG retry tự động. | Test với toạ độ Hà Nội |
| AC-07 | API 4xx/5xx hoặc timeout > 8s → error card có mã lỗi + nút "Thử lại". Sau 3 retry user-initiated → message cuối "Vui lòng kiểm tra mạng hoặc thử lại sau". KHÔNG retry vô hạn. | Mock API fail |
| AC-08 | Loading skeleton hiển thị < 200ms từ lúc tap; có shimmer animation | Manual QA throttled network |
| AC-09 | Disclaimer pháp lý ("Dữ liệu tham khảo, vui lòng đối chiếu với cơ quan có thẩm quyền") xuất hiện ở **mọi nơi hiển thị zone**: panel parcel, badge house detail, warning post-screen, footer screen `/tra-quy-hoach` | Visual checklist 4 màn |

### Non-Functional  *(NEW section)*

| ID | Tiêu chí | Threshold |
|----|----------|-----------|
| AC-10 | i18n: mọi label UI có entry trong arb/locale file VI + EN; zone_name fallback EN nếu thiếu VI | `flutter intl` check |
| AC-11 | Dark mode: zone overlay opacity tự động giảm 10% trong dark; contrast text panel ≥ 4.5:1 | a11y inspector |
| AC-12 | Accessibility: TalkBack/VoiceOver đọc đủ panel detail; mọi tap target ≥ 48dp | Manual a11y test |
| AC-13 | Location permission denied: app vẫn dùng được qua search; KHÔNG block flow | Test on device |
| AC-14 | Tile cache trên device ≤ 100MB; nút "Xoá cache" trong Settings; auto-evict LRU | Adb shell du, manual test |
| AC-15 | Panel detail hiển thị "Cập nhật: dd/mm/yyyy"; warning vàng nếu fetched_at > 30 ngày | UI check + log |
| AC-16 | Disclaimer ubiquitous (dup với AC-09 nhưng nhấn mạnh: 4 vị trí) | Visual checklist |
| AC-17 | Tap 2 thửa < 500ms → request đầu cancel; KHÔNG race condition UI | Stress test |
| AC-18 | Anonymous user gọi `/api/planning/*` được, nhưng limit **30 req/IP/giờ** (D5: rate limit) | Test trên fresh IP |
| AC-19 | Admin endpoint `/api/planning/admin/risky-listings` chỉ accessible với role `admin` | Auth test |
| AC-20 | App size delta ≤ **+15 MB** sau khi thêm vector_map_tiles (D2) | `flutter build apk --analyze-size` |
| AC-21 | Memory peak khi map mở < **350MB** (mid-range) | Flutter DevTools profiler |
| AC-22 | 5 phút map sử dụng < **5% pin** mid-range | Battery historian |

---

## Out of Scope (Phiên bản 1)

- ❌ Tỉnh/thành ngoài TP.HCM → Phase 2.
- ❌ Quy hoạch giao thông, xây dựng chi tiết → chỉ "quy hoạch sử dụng đất" (landuse).
- ❌ Vẽ polygon đo diện tích → Phase 2.
- ❌ Export PDF báo cáo quy hoạch → Phase 2.
- ❌ Notification khi quy hoạch khu vực thay đổi → Phase 3.
- ❌ Tích hợp tra cứu giấy tờ đất (sổ đỏ) → ngoài scope WFS public.
- ❌ Auto block submit listing nếu zone vi phạm (chỉ warning per D4).
- ❌ Real-time GPS tracking (chỉ snapshot khi user request).
- ❌ AR view zone trên camera.
- ❌ Tích hợp dữ liệu giá đất theo zone.
- ❌ Versioning multi-year zoning (chỉ "2030", không cho chọn năm).
- ❌ Real-time geocoding khi host gõ địa chỉ (chỉ button-initiated per US-02 reduced scope).

---

## Non-Functional Requirements  *(NEW)*

- **Performance:** parcel tap p95 < 1.5s (4G); cold start < 3s; map pan/zoom ≥ 30fps.
- **App size delta:** ≤ +15 MB (debug + release APK).
- **Battery:** 5 phút map < 5% pin.
- **Memory:** peak RAM < 350MB.
- **Privacy:** GPS log retention ≤ 30 ngày; hash userId trước log; không share third-party (Nghị định 13/2023).
- **Offline:** cache 3 zoom levels gần nhất; panel detail readable offline trong 24h.
- **Accessibility:** WCAG 2.1 AA cho text/contrast; tap target ≥ 48dp.
- **i18n:** VI primary, EN fallback.
- **Rate limit:** anonymous 30 req/IP/giờ; logged-in 200 req/user/giờ.

---

## Blocking Decisions — đã chốt

1. ✅ Backend stack: **FastAPI + SQLAlchemy** (đã verify ở `ancu365-backend` repo).
2. ✅ Strategy: **share backend** (D1) — port `planning_etl` + thêm routes vào `ancu365-backend`.
3. ✅ Hosting: **VPS self-host Docker** (D3).
4. ✅ Vector tile lib: **`vector_map_tiles`** trước, fallback Martin raster (D2).
5. ✅ Geocoding: **Nominatim self-host** (D5).
6. ✅ Anonymous policy: **được dùng**, rate-limit 30 req/IP/giờ (AC-18).
7. ✅ Submit policy: **cảnh báo, không block** (D4).

## Blocking Decisions — vẫn cần user trả lời

1. ⚠️ **Legal/IP:** ToU của TNMT TP.HCM có cấm redistribute dữ liệu WFS trong app thương mại không? *(Có thể chặn cả dự án nếu cấm.)*
2. ⚠️ **Sáp nhập đơn vị HC HCMC 2025:** dataset planning đã cập nhật chưa? Mapping quận cũ → mới?
3. ⚠️ **Budget VPS cụ thể:** Hetzner CX32 (~$10/mo) đủ không, hay cần CCX23 (~$30/mo)?
4. ⚠️ **Dark mode ancu365:** hiện đã có chưa? Nếu chưa, AC-11 thành "Phase 2 yêu cầu".
5. ⚠️ **Analytics:** team có dùng Firebase / Mixpanel để track parcel_tap event không?

---

## Assumptions (đã verified)

- ✅ ancu365 backend là **FastAPI 0.115 + SQLAlchemy 2.0 + JWT HS256 + bcrypt** (xem `ancu365-backend/requirements.txt`).
- ✅ SQLite default, hỗ trợ Postgres qua `DATABASE_URL`. → **Cần switch sang PostgreSQL+PostGIS** cho production khi có planning.
- ✅ CORS đã mở `*` ở `main.py:48` — Flutter web/mobile gọi được.
- ✅ JWT shared: route mới dùng cùng `auth.py` của backend ancu365.

## Assumptions (cần verify)

- ⚠️ WFS TNMT TP.HCM endpoint vẫn hoạt động (faceconst đã chạy → 95% probability OK).
- ⚠️ VPS có đủ resource (≥ 8GB RAM, ≥ 60GB SSD) cho PostGIS + Martin + Nominatim.
- ⚠️ ~5GB Nominatim Vietnam data có thể download (không bị block từ VN).

---

## Impact / Risk

| Risk | Mức | Mitigation |
|------|-----|------------|
| **Legal/IP — TNMT cấm redistribute** | **CRITICAL** | Đọc ToU TRƯỚC commit Phase 1; nếu cấm → đàm phán license hoặc dừng. |
| **Privacy Nghị định 13/2023 (DLCN VN)** | Cao | Anonymize GPS log, retention ≤ 30 ngày, không share 3rd-party. |
| **Dữ liệu sai → user kiện civil** | Cao | Disclaimer ubiquitous (AC-09/16); Terms required trước khi dùng; report sai (US-08). |
| **ETL fail âm thầm → data cũ** | Trung | UI hiển thị `fetched_at` + warning > 30 ngày (AC-15); alert ops nếu ETL fail 2 ngày liên tiếp. |
| **vector_map_tiles không tương thích flutter_map 7.0.2** | Cao | POC Phase 04 ngay; fallback Martin raster sẵn (D2). |
| **App size > 60MB** | Trung | Đo trước/sau (AC-20); accept ≤ +15MB. |
| **VPS resource thiếu (8GB RAM)** | Cao | Test trên VPS staging trước prod; có upgrade path. |
| **Sáp nhập đơn vị HC HCMC 2025** | Trung | Mapping cũ→mới; UI handle cả 2 tên. |
| **App Store reject vì hiển thị "official gov data"** | Trung | Disclaimer rõ + đính kèm license/source khi submit. |
| **WFS TNMT thay đổi schema** | Trung | Per-feature guard đã có; alert khi field map thất bại > 10%. |
| **GPS drift 50-100m trong nhà cao tầng** | Trung | Hiển thị accuracy radius; cho user manual adjust pin. |
| **Lệ thuộc 1 nguồn data (TNMT)** | Trung | Mirror dump định kỳ vào S3/Backblaze; document migrate procedure. |
| **Reverse engineering / scraping API** | Thấp | Rate limit (AC-18); không expose raw WFS. |
| **Trùng routing tiles flutter_map + vector overlay** | Thấp | Test render order; opacity slider phải hoạt động. |

---

## Stakeholder

- **Product owner:** Duc
- **Backend dev:** Duc (ancu365-backend + faceconst đều của Duc)
- **Mobile dev:** Duc
- **Người dùng cuối:** guest, host, admin, anonymous visitor (HCMC)

---

## Notes — BA Leader Review

✅ **Đã apply revision r2** — đã add US-06/07/08, sửa AC-02/03/04/06/07, thêm AC-10→AC-22, NFR section, Locked Decisions section, expanded risk matrix.
- Source review: `reports/ba-leader-review.md` (verdict: NEEDS_REVISION).
- Status sau patch: **READY for Tech Lead Phase 3**.
- 5 blocking decision còn lại (legal, sáp nhập HC, VPS budget, dark mode, analytics) **không chặn Phase 3 plan** nhưng phải chốt trước khi merge code.
