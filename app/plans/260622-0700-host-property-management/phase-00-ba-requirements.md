# Phase 00 — BA Requirements: Quản lý Nhà trọ & Homestay cho Host

**Ngày:** 2026-06-22
**Trạng thái:** ✅ APPROVED v2 (BA Leader reviewed, 10 decisions sealed, 9 user stories added)
**Revision:** v2 — applied BA Leader feedback (reports/ba-leader-review.md)
**Nguồn research:**
- `plans/research/nha-tro-vn-systems.md` (7 app QL nhà trọ VN: LOZIDO, Resident, Simple House, DigiStay, Smartos, MONA, Ami)
- `plans/research/homestay-vn-systems.md` (Cloudbeds/Hostaway/AirHost + Zalo-first VN ecosystem)
- `plans/research/codebase-audit-host-feature.md` (audit ancu365 hiện có)
- `plans/260622-0700-host-property-management/reports/ba-leader-review.md` (BA Leader review v1)

---

## 1. Problem Statement

Host của ancu365 hiện **chỉ có một dashboard mỏng**: My Listings + duyệt booking xem nhà (`HostHomeScreen`). Thiếu mọi công cụ vận hành thực tế mà chủ trọ / chủ homestay VN đang dùng hằng ngày — buộc họ phải dùng SONG SONG ancu365 + Excel + Zalo + app khác (LOZIDO/Phongtro123).

**Hệ quả:**
- Marketplace ancu365 chỉ là kênh quảng cáo, không giữ chân host về mặt operations
- Host nhập liệu trùng (đăng tin 1 lần, đăng lại lên Zalo/Phongtro123, ghi Excel, tính tiền tay)
- Không có dữ liệu vận hành → marketplace không thể signal "host uy tín", "tỷ lệ lấp đầy cao"
- Bỏ lỡ moat lớn nhất ở VN: **không app QL nhà trọ nào tích hợp khai báo tạm trú VNeID** (gov mandate 2024+, phạt 3–20M VND nếu thiếu sót, Decree 282/2025 hiệu lực 2025-12-15)

---

## 2. Target Users (Host Segmentation)

Theo research, host VN chia làm 3 tier với nhu cầu **rất khác nhau**:

| Tier | Quy mô | % thị trường | Hành vi hiện tại | Pain chính |
|---|---|---|---|---|
| **T1 — Single host** | 1–3 căn / dãy nhỏ | 80% homestay, đa số chủ trọ nhỏ | Zalo + Excel + sổ ghi tay | Đôi khi double-book, quên thu tiền, ngại app phức tạp |
| **T2 — Small chain** | 4–10 căn / 20–50 phòng | 15% | Excel nâng cao + Zalo + đôi khi LOZIDO/Phongtro123 | Tính tiền điện nước hàng tháng cho 20+ phòng, theo dõi nợ |
| **T3 — Professional** | >10 căn / >50 phòng | 5% | Dùng SaaS chuyên (LOZIDO Pro, Cloudbeds) | Báo cáo P&L, multi-property rollup, multi-channel sync |

**Quyết định scope MVP:** Ưu tiên **T1 + T2**, T3 sẽ phục vụ ở phase sau (nếu họ chấp nhận thiếu channel manager).

---

## 3. Hai dòng sản phẩm — KHÔNG được trộn lẫn

Đây là phân biệt quan trọng nhất: chủ trọ và chủ homestay vận hành **hoàn toàn khác nhau**.

### 3a. Nhà trọ (Boarding house / dài hạn)
- **Đơn vị thuê:** phòng (room), không phải nguyên căn
- **Thời hạn:** 1 tháng → 1 năm, hợp đồng cố định
- **Doanh thu:** tiền phòng + điện + nước + dịch vụ — chốt **hàng tháng**
- **Workflow:** chốt số điện/nước cuối tháng → tạo hóa đơn → thu tiền → cập nhật công nợ
- **Pháp lý:** **bắt buộc đăng ký tạm trú** cho khách thuê trong 12h (24h vùng xa) — chủ trọ chịu trách nhiệm

### 3b. Homestay (Vacation rental / ngắn ngày)
- **Đơn vị thuê:** nguyên căn / phòng — cả ngày
- **Thời hạn:** 1 → 14 đêm
- **Doanh thu:** giá/đêm (base + cuối tuần + lễ) — chốt **theo booking**
- **Workflow:** quản lý lịch trống → nhận booking → check-in → check-out → cleaning → review
- **Pháp lý:** **khai báo lưu trú** với người nước ngoài (cùng quy định, cùng API VNeID/Bộ CA)
- **Kênh:** 88% qua Zalo + Facebook trực tiếp (research), 12% qua Airbnb/Booking → **Zalo deep-link là must-have, channel manager là nice-to-have**

> **Implication:** Hệ thống cần 2 entity flows tách biệt nhưng dùng chung một số phần (HostProfile, KhaiBaoTamTru, Notifications, Reports).

---

## 4. User Stories (segmented)

### A. Onboarding & Host Profile
- **A1** [T1,T2,T3] Là host, tôi muốn đăng ký role host + xác thực CCCD + tài khoản ngân hàng, để khách tin tưởng và có thể nhận tiền.
- **A2** [T1,T2,T3] Là host, tôi muốn cập nhật avg response time + uy tín được hiển thị trên marketplace listing.

### B. Nhà trọ — Quản lý tòa nhà & phòng
- **B1** [T2,T3] Là chủ trọ, tôi muốn tạo "dãy trọ / tòa nhà" với địa chỉ + ghi chú, để quản lý nhiều phòng cùng một địa điểm.
- **B2** [T1,T2,T3] Là chủ trọ, tôi muốn tạo từng phòng riêng (mã, diện tích, sức chứa, giá base, trạng thái: trống/đang ở/đang sửa), không chỉ đếm số `total_units`.
- **B3** [T2,T3] Là chủ trọ, tôi muốn **duplicate** 1 phòng đã có sẵn (1-click clone) để khỏi nhập trùng → MVP scope, defer full template builder.
- **B4** [T1,T2,T3] **(MUST)** Là chủ trọ, tôi muốn set phòng status = `maintenance` với ngày start/end, auto-skip invoice tháng đó, dashboard hiện "X phòng đang sửa, ETA done". State machine: `vacant ↔ occupied`, `vacant → maintenance → vacant`.

### C. Nhà trọ — Hợp đồng & khách thuê
- **C1** [T1,T2,T3] Là chủ trọ, tôi muốn tạo hợp đồng cho 1 phòng: chọn phòng + nhập thông tin khách (tên, CCCD, số ĐT, ngày bắt đầu, hạn HĐ, tiền cọc, tiền phòng), để có record chính thức.
- **C2** [T1,T2,T3] Là chủ trọ, tôi muốn upload ảnh CCCD + ảnh khách + ảnh phòng lúc bàn giao, để có bằng chứng nếu tranh chấp cọc.
- **C3** [T1,T2,T3] Là chủ trọ, tôi muốn xem trạng thái hợp đồng (draft / active / sắp hết hạn / đã chấm dứt) + cảnh báo trước 30 ngày hết hạn (dashboard widget, không cần cron).
- **C4** [T2,T3] Là chủ trọ, tôi muốn gia hạn HĐ hàng loạt cho nhiều khách (batch renewal).
- **C5** [T1,T2,T3] **(MUST — ~30% case)** Là chủ trọ, khi tenant báo move-out giữa kỳ, tôi muốn ghi nhận ngày trả phòng thực tế + tạo final invoice (prorate tiền nhà ngày + chốt điện nước cuối) + ghi nhận deposit refund (trừ hư hại nếu có).
- **C6** [T1,T2,T3] **(MUST — dispute prevention)** Là chủ trọ, khi terminate contract, tôi muốn upload ảnh phòng lúc trả + ghi note hư hại để justify deposit deduction.
- **C7** [T2,T3] **(SHOULD)** Là chủ trọ, khi tenant đổi phòng trong dãy (transfer), tôi muốn link HĐ cũ với phòng mới, prorate tiền tháng đó, không phải tạo HĐ mới hoàn toàn.
- **C8** [T1,T2] **(MUST — VN context)** Là chủ trọ, tôi muốn 1 hợp đồng có nhiều tenant (roommates 2-4 người ở chung phòng), trong đó **1 người là primary contact** chịu trách nhiệm tiền nhà, others là co-tenant phải khai báo tạm trú riêng. Schema: `Contract M:N Tenant` qua bảng pivot `contract_tenants(contract_id, tenant_id, is_primary)`.

### D. Nhà trọ — Hóa đơn & thu tiền
- **D1** [T1,T2,T3] Là chủ trọ, mỗi tháng tôi muốn nhập số điện/nước cho từng phòng (auto tính tiền dựa theo đơn giá đã cài), **bấm 1 button "Tạo hoá đơn tháng X" cho cả dãy** (manual trigger, không cron) để generate invoice.
- **D2** [T1,T2,T3] Là chủ trọ, tôi muốn xem hóa đơn của tháng: tiền phòng + điện + nước + dịch vụ + tổng, gửi cho khách qua **Zalo deep-link mở sẵn nội dung + public-link với UUID token** dẫn đến HTML invoice view (không cần PDF MVP).
- **D3** [T1,T2,T3] Là chủ trọ, tôi muốn đánh dấu hóa đơn đã thu (tiền mặt / chuyển khoản), tự cập nhật công nợ phòng đó. **Invoice đã `paid` immutable** — chỉ tạo Credit Note / Adjustment record riêng nếu cần sửa.
- **D4** [T1,T2,T3] Là chủ trọ, tôi muốn thấy danh sách phòng còn nợ + tuổi nợ (0–30d, 30–60d, >60d) để chủ động đòi.
- **D5** [T2,T3] Là chủ trọ, mỗi tháng tôi muốn **xem danh sách "cần nhắn" trên dashboard** (phòng nào sắp đến hạn / quá hạn) → tap row → mở Zalo deep-link với template pre-filled (manual send MVP, defer Zalo Business API auto-send).

### E. Homestay — Lịch & booking ngắn ngày
- **E1** [T1,T2,T3] Là chủ homestay, tôi muốn xem lịch tháng / năm của 1 căn — biết ngày nào trống / đã đặt / chặn (cleaning, bảo trì).
- **E2** [T1,T2,T3] Là chủ homestay, tôi muốn chặn / mở khoá lịch 1 hoặc nhiều ngày liền (block range).
- **E3** [T1,T2,T3] Là chủ homestay, tôi muốn set giá theo cuối tuần / lễ tết khác giá thường (pricing rules với priority resolution: base < weekend < holiday < manual override) — không phải sửa từng ngày.
- **E4** [T1,T2,T3] Là chủ homestay, khi có guest gửi yêu cầu đặt phòng qua marketplace, tôi muốn duyệt nhanh (approve/reject + lý do).
- **E5** [T1,T2,T3] Là chủ homestay, tôi muốn check-in (nhận khách) + check-out (trả phòng) bằng tap-button, để workflow rõ ràng.
- **E6** [T2,T3] Là chủ homestay nhiều căn, tôi muốn xem unified calendar tất cả căn, dễ phát hiện trùng lịch.
- **E7** [T1,T2,T3] **(MUST — anti over-booking)** Là chủ homestay, khi guest cancel reservation trước check-in, tôi muốn apply cancel policy **rigid 24h: full refund nếu >24h, 50% nếu 0-24h, 0% nếu sau check-in**. Auto-release calendar slot. Gửi noti nếu có waitlist.
- **E8** [T1,T2] **(SHOULD)** Là chủ homestay, khi có nhiều booking request cho cùng ngày, tôi muốn xem chúng cùng lúc và pick 1 → auto-reject các request khác.

### F. Khai báo tạm trú (VN-specific, áp dụng cả nhà trọ & homestay)
- **F1** [T1,T2,T3] Là host, sau khi có khách mới (tạo HĐ trọ / booking homestay), hệ thống PRINT cho tôi form khai báo tạm trú đã pre-fill thông tin, để tôi nộp online tại http://tbltkbtt.bocongan.gov.vn/ hoặc qua VNeID app.
- **F2** [T1,T2,T3] Là host, tôi muốn checklist "đã khai báo / chưa" + nhắc 12h sau check-in nếu chưa khai → tránh phạt 3–20M VND.
- **F3** [T2,T3] Là host nhiều căn, tôi muốn báo cáo "số khách chưa khai báo" để xử lý batch.
- **F4** [Future] Là host, tôi muốn submit khai báo trực tiếp qua API gov (sau khi gov mở API) → bỏ bước copy thủ công.

### G. Báo cáo (Reports)
- **G1** [T1,T2,T3] Là host, tôi muốn xem doanh thu tháng + năm (rent + utilities + booking homestay) — **table view MVP**, chart sau.
- **G2** [T2,T3] Là host, tôi muốn xem tỷ lệ lấp đầy (occupancy) theo phòng / căn.
- **G3** [T2,T3] Là chủ homestay, tôi muốn xem ADR (giá trung bình / đêm) và RevPAR.
- **G4** [T2,T3] **(SHOULD)** Là chủ trọ, tôi muốn export báo cáo tháng ra CSV/Excel để gửi kế toán / lưu sổ sách. PDF defer.

### H. Marketplace integration
- **H1** [T1,T2,T3] Là host, listing trên marketplace của tôi tự động đồng bộ với phòng / căn trong hệ thống ops — đăng 1 lần dùng 2 chỗ.
- **H2** [T1,T2,T3] Là host, khi có guest book từ marketplace, hệ thống tự tạo bản nháp hợp đồng (nhà trọ) hoặc reservation (homestay) — chỉ cần confirm.

---

## 5. Acceptance Criteria (tổng quan, sẽ chi tiết hơn ở từng phase)

**AC sản phẩm (user-facing, testable):**
- Host T1 với 1 căn nhà trọ 5 phòng có thể: tạo phòng, thêm khách + HĐ, tạo hóa đơn tháng (rent + điện + nước) → hoàn tất trong < 10 phút (đo từ tap "Tạo dãy" đến tap "Hoàn tất" + thời gian nhập liệu user).
- Host T1 với 1 căn homestay có thể: chặn lịch 1 tuần, set giá cuối tuần khác giá thường → < 3 phút.
- Khi tạo HĐ mới có khách thuê → form khai báo tạm trú được generate sẵn (HTML public-link với UUID token + PDF download tuỳ chọn) trong < 5 giây.
- Toàn bộ ops data của host **không lộ** cho user khác (RBAC). Integration test: Host A login + GET `/api/host/rooms?host_id=<B>` → KHÔNG thấy room của Host B.
- **State machine validity:** Contract chỉ chuyển: `draft → active → (expired | terminated)`. Active → draft return 400. Test mỗi transition invalid.
- **Invoice immutability sau paid:** Invoice đã mark `paid` không cho phép edit line items. Phải tạo Credit Note record riêng.
- **Khai báo deadline visibility:** Sau check-in 12h chưa mark đã khai báo → badge đỏ trên dashboard + notification. Test simulate 12h sau.
- **Soft delete contract:** Contract `terminated` KHÔNG xoá DB, giữ history. Query active list mặc định filter `status != terminated`.
- **Concurrent booking conflict (homestay):** 2 guest book cùng slot trong 1 giây → chỉ 1 thành công, người kia 409 Conflict. Test với race condition.
- **Cancel policy enforcement:** Guest cancel reservation → server tính refund theo D10 (24h rigid), không trust client input.

**AC kỹ thuật:**
- API host-only được bảo vệ bằng `require_host()` middleware (đang thiếu).
- Schema nhà trọ và homestay tách bạch nhưng share `HostProfile` + `KhaiBaoTamTru`.
- Multi-tenant isolation: **Repository pattern auto-inject `host_id` filter** vào mọi ops query (D6). Plus integration test cross-host access bị 403/404.
- Migration safe (Alembic versioned cho **TẤT CẢ** tables, không chỉ planning module; không dùng `metadata.create_all` cho core tables mới).
- CCCD storage: **local filesystem + folder permissions 0700 + access log audit table** (D7). Encryption-at-rest defer cloud.

**Engineering DoD (không phải product AC):**
- Hot reload không vỡ Provider tree.
- TS analyze 0 errors trước merge.
- `dart analyze` 0 errors trước merge.
- Per-phase acceptance demo bằng seed script + manual click-through.

---

## 6. Out of Scope (giai đoạn này)

❌ **Channel manager** (sync Airbnb/Booking/Agoda) — phức tạp, T3 only, để phase sau
❌ **Dynamic pricing AI** — chưa đủ data
❌ **IoT smart meter** — cần thiết bị phần cứng
❌ **Đóng/khoá smart lock + cleaning workforce marketplace** — out of scope
❌ **Direct VNeID API submission** — chỉ làm form generator + reminder; integration gov API chờ partner
❌ **Multi-currency, multi-language UI** — chỉ tiếng Việt MVP (EN cho form khai báo foreigner guest → defer)
❌ **Chữ ký số / e-contract hợp pháp** — chỉ lưu HĐ PDF upload, không công chứng số
❌ **Payment escrow** (giữ cọc cho khách) — chỉ ghi nhận, không giữ tiền
❌ **Auto-cron job scheduler** (APScheduler/Celery beat) — MVP dùng manual button + dashboard "cần action" list, không có background job
❌ **Excel import từ host T1** — defer post-MVP, theo dõi nếu T1 churn cao thì add Phase 09
❌ **PDF generation server-side** (reportlab/weasyprint) — MVP dùng HTML public-link với UUID token, defer PDF
❌ **Zalo Business API auto-send** — MVP chỉ deep-link `zalo.me/{phone}?text=`, host tap để mở Zalo manual
❌ **Cloud storage encrypted CCCD** (S3/R2) — MVP local filesystem + permissions + audit log, cloud sau launch
❌ **Bulk template builder rooms** (template + variation) — MVP chỉ "Duplicate this room" 1-click
❌ **Chart UI cho reports** — MVP table view, chart sau khi data đủ
❌ **Host-configurable cancel policy** — MVP rigid 24h fixed, configurable defer

---

## 7. Đề xuất Phase Breakdown (HIGH-LEVEL) — ⚠️ DEPRECATED

> **DEPRECATED:** Section này là outline ban đầu. Phase order chính thức xem **§9b Revised Phase Order** bên dưới (đã re-order theo decision "nhà trọ trước homestay"). Giữ section này để tham chiếu lịch sử.

### Phase 01 — Foundation & Host Profile (1 tuần)
**Goal:** Đặt nền móng bảo mật + thông tin host trước khi build features.
- Backend: `require_host()` dependency, validate `host_id == current_user.id`
- Model: `HostProfile` (verified, bank_account, tax_id, response_time, rating, payout_schedule)
- API: GET/PATCH `/api/host/profile`, POST `/api/host/verify` (upload CCCD)
- Flutter: Host onboarding flow (3 step: thông tin → CCCD → bank), Host settings screen
- Alembic: migration 0002 cho host_profiles

**Sized:** ~3–4 ngày dev + 1 ngày test.

### Phase 02 — Nhà trọ Core: Building / Room / Tenant (1.5 tuần)
**Goal:** Tạo được cấu trúc dãy trọ với từng phòng + khách thuê cụ thể.
- Models: `Building`, `Room`, `Tenant`, `Contract` (chưa có Invoice/Payment)
- Quan hệ: Host 1—N Building, Building 1—N Room, Room 1—N Contract (history), Contract N—1 Tenant
- API: CRUD cho từng entity + endpoints như `/api/host/buildings/{id}/rooms`
- Flutter: 
  - Màn hình "Quản lý nhà trọ" → list Building → drill vào Room → drill vào Contract
  - Form tạo phòng (mã, diện tích, giá, status, ảnh)
  - Form tạo hợp đồng (chọn phòng + tenant info + ngày + cọc)
  - Bulk create rooms (template)

**Sized:** ~5–7 ngày.

### Phase 03 — Nhà trọ Ops: Invoice + Payment + Meter (1.5 tuần)
**Goal:** Đóng vòng tròn ops cho chủ trọ — chốt tiền hàng tháng.
- Models: `Invoice`, `InvoiceLineItem`, `Payment`, `MeterReading`, `ServiceFee`
- Engine: Job tự generate invoice ngày 1 hàng tháng cho mọi Contract active
- API: nhập meter reading, generate invoice draft, mark paid, debt aging report
- Flutter:
  - Màn hình "Hóa đơn tháng" với inline editor: nhập số điện/nước từng phòng → preview tiền
  - List hóa đơn (filter chưa thu / đã thu / quá hạn)
  - Share invoice qua Zalo deep-link / copy link
  - Debt dashboard (phòng nào nợ bao nhiêu, bao lâu)

**Sized:** ~7 ngày.

### Phase 04 — Homestay Core: Calendar + Pricing + Booking (1.5 tuần)
**Goal:** Vận hành 1 căn homestay được trên app.
- Models: `Stay` (đổi tên / mở rộng Booking hiện tại), `Availability` (per-day per-property), `PricingRule` (base / weekend / holiday / range), `Reservation` (short-term booking)
- Lưu ý: NHA TRỌ booking khác hẳn — không dùng cùng table với Booking xem nhà hiện tại
- API: availability calendar, pricing rule CRUD, reservation lifecycle
- Flutter:
  - Calendar view (tháng) với màu trạng thái: trống / đã đặt / chặn
  - Tap range để block / unblock
  - Form pricing rule (cuối tuần x1.5, lễ x2, etc.)
  - Reservation list + check-in/check-out actions

**Sized:** ~7 ngày.

### Phase 05 — Khai báo tạm trú workflow (3–4 ngày)
**Goal:** Differentiation feature, giúp host tránh phạt.
- Model: `KhaiBaoTamTru` (host_id, tenant/guest_id, contract_id/reservation_id, status: pending/declared/skipped, declared_at, deadline_at)
- Logic: trigger khi tạo Contract / Reservation → tạo record pending, deadline = check-in + 12h
- API: GET checklist outstanding, PATCH mark declared
- Flutter: 
  - Banner / badge trên dashboard "X khách chưa khai báo" 
  - Form generator → PDF / shareable text pre-filled
  - Tap "Đã khai báo" để clear

### Phase 06 — Reports + Zalo deep-link + Notifications polish (3–4 ngày)
**Goal:** Giữ chân host bằng analytics + tự động hoá nhắc nhở.
- Reports: doanh thu tháng/năm, occupancy, ADR (homestay), debt aging (nhà trọ)
- Zalo deep-link generator (`https://zalo.me/{phone}?text=...`) cho: gửi hoá đơn, nhắc tiền nhà, gửi check-in instruction
- Scheduled notifications: invoice due reminder, contract expiring 30d, khai báo overdue
- Push (FCM) — optional, nếu time

### Phase 07 — Marketplace ↔ Ops integration (3–4 ngày)
**Goal:** Một lần đăng, dùng 2 chỗ.
- Khi host tạo room mới → auto-suggest publish lên marketplace listing
- Khi guest book trên marketplace → tạo draft Reservation (homestay) hoặc Contract (nhà trọ)
- Sync trạng thái: listing tự động "đã đủ phòng" khi tất cả room occupied

---

## 8. Risks & Mitigation

| Risk | Mức độ | Mitigation | Phase address |
|---|---|---|---|
| Scope creep — 8 phase x ~1.5w = 10-13 tuần | HIGH | Mỗi phase phải ship được standalone; user có thể stop sau Phase 04 vẫn dùng được nhà trọ end-to-end. Cắt feature defer (§6) | All |
| Khai báo tạm trú: gov chưa có API public | MED | MVP chỉ làm form generator + reminder. Không phụ thuộc API gov. Document rõ "công đoạn nộp vẫn manual" | 05 |
| Migration SQLite ↔ Postgres mismatch | MED | Dùng Alembic versioned migrations từ Phase 01. Test cả 2 DB trước khi merge. Reset data OK (D1: chưa launch) | 01 |
| Schema clash: Booking (xem nhà) vs Reservation (homestay) vs Contract (nhà trọ) | HIGH | Phase 01b rename `Booking → ViewingAppointment` standalone (D9). Document trong Phase 03/07 tech plan | 01b, 03, 07 |
| RBAC: host A thấy data của host B | CRITICAL | Repository pattern auto-inject `host_id` (D6). Integration test cross-host bắt buộc. Security review trước merge mọi PR ops | 02-all |
| Zalo deep-link policy thay đổi | LOW | Dùng chuẩn `zalo.me/{phone}?text=` đã public lâu năm. Nếu chết, fall back về SMS link `sms:+84...` | 06 |
| **PDPL (NĐ 13/2023) — CCCD storage compliance** | HIGH | Local filesystem + folder permissions 0700 + access log audit table (D7). Cloud encrypted defer. PDPL audit checklist documented | 02 |
| **Concurrent booking conflict (homestay race)** | HIGH | DB-level constraint `EXCLUDE USING gist (room_id WITH =, daterange WITH &&)` Postgres exclusion, hoặc serializable transaction. Integration test với race condition | 07 |
| **Booking rename regression** | MED | Grep toàn dự án trước rename. Backward-compat layer trong notification types nếu cần. Smoke test toàn bộ ViewingAppointment flow sau rename | 01b |
| **Roommates schema lock-in early** | MED | Quyết D2 (Contract M:N Tenant) chốt schema từ Phase 03. Test với 1-tenant + multi-tenant data đồng thời | 03 |

---

## 9. Decisions Sealed (2026-06-22)

**Round 1 — User-sealed (5 decisions):**

| # | Quyết định | Giá trị |
|---|---|---|
| 1 | Thứ tự sản phẩm | ✅ **Nhà trọ TRƯỚC**, homestay sau (phase homestay chuyển xuống cuối) |
| 2 | Khai báo tạm trú | ✅ Form generator + reminder only — **KHÔNG auto-submit gov** |
| 3 | Payment | ✅ Chỉ ghi nhận thủ công MVP (cash / bank transfer note) — **không tích hợp** Momo/ZaloPay/VNPay |
| 4 | Database | ✅ **Migrate SQLite → Postgres TRƯỚC** khi build Phase 02 |
| 5 | Booking rename | ✅ Rename `Booking` → `ViewingAppointment` để tránh nhầm với Reservation (homestay) / Contract (nhà trọ) |

**Round 2 — BA Leader recommendations applied (D1-D10, defaulted safe per BA Leader review):**

| # | Topic | Sealed value | Rationale |
|---|---|---|---|
| D1 | SQLite data preservation | ✅ **Reset toàn bộ** (chưa launch production) | App đang phase test, chưa có user thật. Tiết kiệm 2-3d migration script |
| D2 | Roommates model | ✅ **Contract M:N Tenant** qua bảng `contract_tenants(contract_id, tenant_id, is_primary)` | Match thực tế VN: 1 HĐ cho cả nhóm thuê, 1 primary contact trả tiền, others là co-tenant phải khai báo tạm trú riêng |
| D3 | Invoice rendering | ✅ **HTML public-link với UUID token** (UUIDv4 secret slug) | Đơn giản, gửi Zalo deep-link, guest click view web. PDF generation defer |
| D4 | Auto-cron infra | ✅ **Manual button + dashboard "cần action" list** | MVP tránh setup APScheduler/Celery. Phase 06 chỉ làm UI hiển thị "cần action", không trigger ngầm |
| D5 | Bulk create rooms (B3) | ✅ **"Duplicate this room" 1-click** | 80% giá trị với 20% effort. Full template builder defer |
| D6 | Multi-tenant isolation strategy | ✅ **Repository pattern auto-inject `host_id`** + integration test cross-host | 1-dev, không cần Postgres RLS complexity. Defense-in-depth: repo layer + manual filter |
| D7 | CCCD storage | ✅ **Local filesystem + folder permissions 0700 + access log audit table** | MVP compliance NĐ 13/2023. Cloud encrypted defer sau launch |
| D8 | T1 entry barrier (Excel import) | ✅ **Skip MVP** | Theo dõi nếu T1 churn cao sau launch → add Phase 09 |
| D9 | Booking rename scope | ✅ **Standalone Phase 01b** (1d), giữa Phase 01 (DB migration) và Phase 02 (Foundation) | Clean separation, dễ revert nếu fail |
| D10 | Cancel policy homestay | ✅ **Rigid 24h: >24h full / 0-24h 50% / sau check-in 0%** | MVP simple fixed. Host-configurable defer |

**Context answers (5 câu hỏi BA Leader đặt — defaulted theo BA Leader recommendation):**

| # | Câu hỏi | Giá trị mặc định |
|---|---|---|
| Q1 | SQLite có data user thật chưa? | ❌ Chưa launch production → reset OK (D1) |
| Q2 | Đã có Zalo Official Account chưa? | ❌ Chưa → chỉ dùng deep-link `zalo.me/{phone}` manual, không auto-send |
| Q3 | Target launch date | 🟡 Soft 3 tháng (~2026-09-22) — không hard deadline, có buffer |
| Q4 | App đã có production user chưa? | ❌ Chưa → free to reset DB, no migration script needed |
| Q5 | Audit trail cho contract/invoice? | ✅ Có — dispute prevention. Lưu `created_by`, `updated_at`, `change_log` table cho Contract + Invoice từ Phase 03 |

> **Lưu ý:** Nếu user phản đối bất kỳ default nào → revise lại trước khi vào Phase 4 (dev).

## 9b. Revised Phase Order — Sizing recalibrated (BA Leader v2)

Phase order final theo seal "nhà trọ trước homestay" + sizing realistic (BA Leader review).

| # | Phase | Realistic | Key deliverables |
|---|---|---|---|
| **01** | **DB migration SQLite → Postgres** | **2–3d** | Docker-compose Postgres, Alembic baseline TẤT CẢ tables (users/houses/bookings/planning), data seed script, reset existing SQLite |
| **01b** | **Booking → ViewingAppointment rename** | **1d** | Grep toàn dự án, rename model+router+helper+notification types+Flutter provider+screens, smoke test no regression |
| **02** | Foundation & Host Profile | **4–5d** | `require_host()` middleware, audit existing endpoints add auth, `HostProfile` model + onboarding 3-step UX (info → CCCD upload → bank), audit log table |
| **03** | Nhà trọ Core (Building/Room/Tenant/Contract) | **7–9d** | Models + repo layer auto-inject `host_id`, M:N Contract-Tenant (D2), Room state machine (B4 maintenance), transfer room (C7), soft delete, state validation tests |
| **04** | Nhà trọ Ops (Invoice/Payment/Meter) | **8–10d** | Invoice immutable after paid, manual "Tạo hoá đơn tháng X" button (D4), move-out prorate (C5), final settle utility, deposit refund (C6), debt aging |
| **05** | Khai báo tạm trú (form gen + reminder) | **4–5d** | HTML public-link UUID token + PDF download tuỳ chọn (D3), 12h deadline reminder UI, roommate khai báo (mỗi tenant 1 record), EN version foreigner defer |
| **06** | Reports + Zalo deep-link + Notifications | **5–6d** | Table-view reports (G1-G4, chart defer), Zalo deep-link URL builder, "cần action" dashboard list (D4, không cron), CSV export |
| **07** | **Homestay Core** (Calendar/Pricing/Reservation) | **9–11d** | Availability + pricing rules priority resolution, concurrent booking conflict prevention (Postgres exclusion), cancel policy enforcement (D10 24h rigid), check-in/check-out workflow |
| **08** | Marketplace ↔ Ops integration | **5–7d** | Sync 1 chiều ops → marketplace (House sync ảnh link), auto-create Contract/Reservation draft from marketplace booking, collision resolution |
| | **TOTAL dev** | **45–57d (~9-11.5w)** | |
| | **+ buffer 15%** | **+7–9d** | Demo prep, bug fix per phase, integration regression |
| | **GRAND TOTAL** | **52–66d (~10.5-13 tuần)** | |

**Nhà trọ usable end-to-end:** sau Phase 06 (~6 tuần)
**Homestay usable end-to-end:** sau Phase 07 (~9 tuần)
**Full marketplace integration:** sau Phase 08 (~10.5-13 tuần)

> **Buffer reasoning:** Per phase cần demo (0.5d) + bug fix iteration (0.5d) + integration regression test. Total buffer ~15% là conservative ổn.

## 9c. Constraints chốt từ decisions

- **Booking rename = Phase 01b standalone (D9):**
  - Sized 1d riêng, không gộp vào Phase 02
  - File scope: `app/models.py` (model), `app/routers/bookings.py`, helper `app/services/notifications.py` (event types `booking_new/approved/...` → `viewing_appointment_*`), Flutter `lib/providers/bookings_provider.dart`, `lib/features/host/host_home_screen.dart` (line 57), chat `house_id` ref nếu liên quan
  - Smoke test: end-to-end flow xem nhà (request → approve → schedule) không vỡ sau rename

- **Migration Postgres = Phase 01 (D1 reset):**
  - Docker-compose service `postgres:15` + healthcheck
  - Alembic baseline migration `0001_initial.py` cho TẤT CẢ tables hiện có (users, houses, bookings, planning_provinces, …) — không chỉ planning module
  - Reset SQLite data (chưa launch) → KHÔNG cần migration script preserve
  - Seed script `scripts/seed_dev.py` chạy được trên Postgres
  - CI test: run pytest với Postgres container, không SQLite

- **Form khai báo tạm trú format (D3):** HTML public-link với UUID token là primary, PDF download là secondary
  - `KhaiBaoTamTru` table có `public_token` (UUIDv4 column) + `expires_at`
  - Endpoint public `GET /public/khaibao/{token}` render HTML view (không cần auth)
  - Endpoint `GET /api/host/khaibao/{id}/pdf` generate PDF on-the-fly (defer phase 05 nếu time tight)
  - Sẽ chốt template chi tiết ở Phase 05 tech plan

- **Roommates M:N (D2):**
  - Bảng pivot `contract_tenants(contract_id, tenant_id, is_primary BOOLEAN, joined_at)`
  - Primary tenant: chịu trách nhiệm tiền (invoice gửi cho primary)
  - Co-tenant: vẫn phải tạo `KhaiBaoTamTru` record riêng
  - Khi 1 co-tenant move out giữa kỳ: update `contract_tenants.left_at`, không terminate cả contract

- **Multi-tenant isolation = Repository pattern (D6):**
  - Tạo `app/repositories/base.py` với class `HostScopedRepository` auto-add `WHERE host_id = current_user.id` vào mọi query
  - Mọi router gọi qua repo, KHÔNG query trực tiếp `db.query(Model)`
  - Integration test `tests/security/test_cross_host_isolation.py` chạy từ Phase 02

- **CCCD storage = Local + audit (D7):**
  - Folder `storage/cccd/` với chmod 0700
  - Filename UUIDv4, không lưu tên gốc
  - Table `cccd_access_log(user_id, file_id, accessed_at, action)` log mọi read/write
  - Không expose direct URL; chỉ qua endpoint `GET /api/host/cccd/{id}` với auth

- **Audit trail Contract + Invoice (Q5):**
  - Table `change_logs(entity_type, entity_id, actor_id, action, before_json, after_json, created_at)`
  - Triggered từ Phase 03 (Contract) + Phase 04 (Invoice)
  - Không cần UI hiển thị log MVP, chỉ store DB cho future dispute

---

## 10. Execute order (final after BA Leader v2)

Phases chạy tuần tự theo §9b:

1. **Phase 01** (DB migration) — chặn tất cả
2. **Phase 01b** (Booking rename) — chặn Phase 03+07
3. **Phase 02** (Foundation + HostProfile + audit log) — chặn tất cả ops phases
4. **Phase 03** (Nhà trọ Core: Building/Room/Tenant/Contract) — chặn Phase 04, 05
5. **Phase 04** (Nhà trọ Ops: Invoice/Payment/Meter) — high-value, nhà trọ usable end-to-end
6. **Phase 05** (Khai báo tạm trú) — differentiation moat
7. **Phase 06** (Reports + Zalo + Noti) — polish, cải thiện DX
8. **Phase 07** (Homestay Core) — second product line
9. **Phase 08** (Marketplace ↔ Ops integration) — cuối

**Tổng thời gian:** ~10.5–13 tuần dev cho 1 dev full-time (sized với buffer 15%).
**Cắt scope nếu deadline pressure:** Defer Phase 07 (homestay) + Phase 08 (marketplace integration) → giảm còn ~6-7 tuần, ship nhà trọ-only MVP trước.

---

## 11. BA v2 Sign-off

**Critical issues C1-C6:** ✅ Resolved (xem §4 stories C5-C8, B4, E7; §5 testable AC; §9c constraints)
**Important issues I1-I8:** ✅ Resolved (xem §4 stories C7, C8, E7; §6 defer list; §9b sizing)
**Missing user stories 9 items:** ✅ Added (C5, C6, C7, C8, B4, E7, E8, A3 deferred, G4)
**Missing AC 6 items:** ✅ Added §5 (state machine, immutability, deadline, soft delete, race, cancel policy)
**Hidden scope creep:** ✅ Resolved (bulk → duplicate D5; auto-cron → manual D4; PDF → HTML link D3; Zalo Business → deep-link only; chart → table; marketplace → 1 chiều)
**Decisions D1-D10:** ✅ Defaulted safe per BA Leader recommendation (xem §9 round 2)

**STATUS:** ✅ **READY for Phase 3 (Tech Lead Planning)** — BA doc v2 approved, all blockers resolved.

> **User override window:** Nếu user phản đối bất kỳ default nào trong D1-D10 hoặc Q1-Q5, hãy báo TRƯỚC khi spawn researcher/planner agents.
