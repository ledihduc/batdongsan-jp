# Phase 00 — BA Requirements: Owner–Operator Delegation

**Plan:** `plans/260629-0116-owner-operator-delegation/`
**Author:** BA (Claude main)
**Date:** 2026-06-29
**Status:** REVISED v4 — BA Leader deep-dive (10 expert recs) applied → READY for Phase 3 (Tech Lead planning), pending user confirmation of §13 D1-D9 + Q1 unified decisions log.
**Workflow:** Important Task Workflow (BA → BA Leader → Tech Lead → Developer → Tech Lead Review)
**Changelog:** See §12.

---

## 0. TL;DR (cho người đọc nhanh)

Hệ thống ancu365 hiện tại có 1 vai trò duy nhất cho chủ nhà: **Host = Owner + Operator** (vừa sở hữu, vừa vận hành). Người dùng muốn mở rộng để phục vụ **chủ nhà có tiền nhưng không có thời gian** — giao toàn bộ vận hành cho 1 người đại diện (cá nhân) hoặc 1 doanh nghiệp quản lý bất động sản.

**Đề xuất v1 (gọn, thuận tiện, không lẫn role):**

- **Tách khái niệm** "Owner" (chủ sở hữu) khỏi "Operator" (người vận hành) trên cùng 1 property — nhưng KHÔNG thay đổi schema `host_id` hiện có (giữ stable).
- Thêm 1 bảng **`OperatorDelegation`** + 2 bảng phụ (`delegation_invitations`, `delegation_approvals`). Mọi action của operator vẫn ghi vào DB với `host_id = owner_id`, đồng thời ghi actor identity + delegation reference vào audit log.
- **UX không gây lẫn lộn:** dùng pattern persona-switcher đã có sẵn ở `guest_shell.dart` ("Bạn đang xem: [Mình] / [Đang đại diện cho Anh A]") + header màu cam nhạt + badge rõ ràng + context request-scoped (không session-scoped, tránh stale state khi switch tab).
- **4 preset role** thay vì permission matrix phức tạp: Owner-view / Operator-full / Accountant / Viewer.
- **Owner approval** chỉ cho action vượt ngưỡng — KHÔNG có default cứng (Hanoi/HCMC ≠ Đà Lạt/Phú Quốc): Owner phải chủ động set ngưỡng tại invite (forced engagement).
- **KB04 (khai báo tạm trú) carve-out:** fast-track **6h SLA** (xem §4 Terminology và §13 D1 — quyết định canonical) + default auto-approve trong preset `operator_full`. Lưu ý: 12h là deadline *tenant phải được đăng ký* (Luật Cư Trú §2.1), không phải deadline phê duyệt — xem §10.6 timeline.
- **Chủ tự vận hành hiện tại** không bị ảnh hưởng gì (zero migration impact cho self-managed hosts).

Target ship: **TBD** — Tech Lead xác định ở Phase 3.

Khi market validate có thêm nhu cầu PMC (property management company) đa cấp → migrate sang Org model (v2, Q4 2026).

---

## 1. Problem Statement

### 1.1. Nhu cầu kinh doanh

> **Lưu ý nguồn dữ liệu:** Phân chia thị trường 55/25/20% và ARPU multiplier 2–3× là **BA assumption** dựa trên phỏng vấn định tính với 12 chủ nhà (HCMC/Hà Nội/Đà Nẵng, Q2 2026); chưa có số liệu khảo sát định lượng. Cần validate qua pilot 100-delegation (Q1 metric, §11). Xem §13 D1 và §8 AS-01.

Phân khúc chủ nhà tiềm năng ở Việt Nam (HCMC, Hà Nội, Đà Nẵng, Phú Quốc, Đà Lạt…) có 3 nhóm:

| Nhóm | Mô tả | % Ước tính (BA assumption) | Hiện tại ancu365 phục vụ |
|------|-------|-------------|--------------------------|
| A. Chủ tự vận hành | Chủ trọ truyền thống, ở gần nhà, tự thu tiền/quản lý | ~55% | Tốt |
| B. Chủ + nhân viên thuê tại chỗ | Có 1–2 nhân viên trông trọ nhưng vẫn quyết định lớn | ~25% | Chỉ chủ login được |
| **C. Chủ ủy thác toàn bộ** | **Có tài sản, không có thời gian; thuê đại diện (cá nhân/công ty) lo hết** | **~20% (giá trị đơn hàng cao nhất — BA assumption)** | **Chưa phục vụ** |

Nhóm C có ARPU cao 2–3× nhóm A (BA assumption, chưa validated), là segment chiến lược SaaS, và là cửa ngõ B2B2C với các công ty quản lý BĐS (cityhouse, luxstay, vinhomes service…).

### 1.2. Pain point của người dùng

**Chủ nhà nhóm C (Owner):**
- Hiện không tin ai vì không có công cụ minh bạch dòng tiền/hợp đồng
- Khi giao cho người vận hành: hoặc dùng Excel + Zalo (rủi ro thất thoát), hoặc phải tự check (phản tác dụng vì đã thuê người để khỏi phải làm)
- Muốn thấy ngay: doanh thu tháng, ai đang thuê, hợp đồng nào sắp hết, có ai nợ tiền, người đại diện đang làm gì
- Không muốn nhận thông báo về mọi việc nhỏ → chỉ cần biết việc quan trọng

**Người đại diện / Công ty quản lý (Operator):**
- Quản lý 5–50 căn cho nhiều chủ khác nhau → cần workspace gọn, không lẫn property của owner A với owner B
- Cần chứng minh sự minh bạch cho chủ → audit log đầy đủ
- Cần ranh giới rõ: được làm gì, không được làm gì (tránh tranh chấp pháp lý)

**Người thuê (Tenant):**
- Cần biết ai có thẩm quyền hợp pháp thu tiền và ký hợp đồng đại diện chủ (chống lừa đảo)
- Khi operator đổi giữa thời hạn thuê: cần biết người liên hệ mới

### 1.3. Câu hỏi gốc cần trả lời

> "Làm thế nào để hệ thống ancu365 phục vụ được chủ nhà ủy thác toàn bộ cho người đại diện, **chuẩn chỉnh – thuận tiện – dễ dùng**, mà KHÔNG làm role lẫn lộn?"

---

## 2. Bối cảnh hệ thống hiện tại (BA-level)

### 2.1. Role hiện hữu

| Role hiện tại | Mô tả | Số lượng entity bị "khoá" theo role này |
|---------------|-------|------------------------------------------|
| `guest` | Người tìm thuê, đặt lịch xem | wishlists, viewing_appointments |
| `host` | Chủ nhà = owner + operator gộp 1 | 20+ bảng (`buildings`, `rooms`, `contracts`, `invoices`, `tenants`, `meter_readings`, `khai_bao_tam_tru`, `reservations`, `revenue_sources`, …) |
| `admin` | Vận hành platform | catalog, planning, review approval |

**Insight quan trọng:** mọi bảng nghiệp vụ đều có cột `host_id` → FK đến `users.id`. Khi tách 2 vai trò ra, ta quyết định: `host_id` giữ nghĩa = **"chủ sở hữu"** (Owner). Xem §3.

### 2.2. Hạ tầng audit đã có sẵn

- `ChangeLog`: ghi mọi mutation (`entity_type`, `entity_id`, `actor_id`, `action`, `before_json`, `after_json`)
- `AuditLog` (migration 0019): immutable event log per host
- `CCCDAccessLog`: compliance PDPL

→ Đã sẵn cơ chế ghi "ai làm gì cho ai" → chỉ cần đảm bảo actor identity = operator, host_id = owner, kèm delegation reference khi operator thao tác.

### 2.3. UI persona-switching đã có

`lib/features/guest/guest_shell.dart` đã có pattern Airbnb-style switcher (guest ↔ host). Tái sử dụng cho **owner-context overlay** trong portfolio của operator (KHÔNG tạo persona thứ 3 độc lập — operator dùng UI cùng layout với host, chỉ overlay "acting-as" + cờ scope quyền).

### 2.4. Onboarding KYC đã có

3 bước onboarding (`host/onboarding/step1_info`, `step2_cccd`, `step3_bank`) → operator cá nhân tái sử dụng nguyên xi. Operator doanh nghiệp cần bước bổ sung (GPKD + người đại diện pháp luật + ngành nghề dịch vụ quản lý BĐS đăng ký trong GPKD).

### 2.5. Marketplace integration đã ship (Phase 08)

`marketplace_integration` router đã active. Property của Owner đang delegated mà cũng listing trên marketplace → booking đi đâu, ai handle? AC-51 giải quyết.

---

## 3. Quyết định kiến trúc (BA proposes — Tech Lead detail sau)

### 3.1. Hai mô hình BA cân nhắc

#### Model A — **Delegation Link** (CHỌN cho v1)

- Giữ `host_id` ở mọi bảng nghiệp vụ = **ID của chủ sở hữu** (Owner)
- Thêm bảng mới `operator_delegations`, `delegation_invitations`, `delegation_approvals`
- Mọi mutation của operator: backend kiểm tra `operator_delegations` có cấp quyền không → ghi `host_id = owner_id` vào entity, ghi actor identity + delegation reference vào audit
- Trên UI: operator chọn "đang đại diện cho Anh A" (context) → mọi request xác định acting-as context per-request, không cache vào JWT

**Pro:**
- Thay đổi schema NHỎ (3 bảng mới + 0 ALTER bảng cũ ngoại trừ thêm enum value và 1 cột nullable audit)
- Self-managed hosts không bị ảnh hưởng
- Audit dual-identity tự nhiên
- Revoke tức thời

**Con:**
- Operator quản nhiều owner → mỗi lần làm việc phải switch context (mitigated bằng portfolio dashboard)
- Không phù hợp model PMC đa cấp (operator có nhân viên dưới quyền)

#### Model B — **Organization** (PMC-grade)

- Thêm `organizations`; property thuộc về org (chuyển `host_id` → `org_id`)
- User thuộc nhiều org với role khác nhau
- Operator org có "service contract" với owner org

**Pro:** đúng mô hình PMC, scalable.
**Con:** refactor MỌI bảng có `host_id` (20+ bảng), index, FK, Flutter client cache literal `host_id`. Phải coi là multi-week migration. Hiện chưa validate nhu cầu PMC.

### 3.2. Quyết định BA: **đi Model A cho v1**

Lý do:
1. **YAGNI** — chưa biết PMC có chấp nhận platform không.
2. **Time-to-market** — segment C đã có khách hỏi.
3. **Có exit path** — migration sang Model B tuy non-trivial nhưng contained: chỉ ảnh hưởng DB + repository layer; UI và business logic phần lớn giữ nguyên.
4. **Phù hợp 80% use case** — chủ A ủy thác cho cá nhân/công ty B; B phục vụ nhiều chủ đồng thời.

---

## 4. Định nghĩa khái niệm (terminology)

**Quy ước:** Mọi giá trị số (SLA, retention period, ngưỡng) xuất hiện canonical 1 lần trong bảng này. Các chỗ khác trong doc tham chiếu: "xem §4 Terminology."

| Tên TV | Tên EN trong code | Mô tả |
|--------|-------------------|-------|
| Chủ sở hữu | `owner` | Người sở hữu property, nhận doanh thu cuối cùng, có quyền tối hậu |
| Người đại diện / Người vận hành | `operator` | Người được Owner uỷ thác để thao tác nghiệp vụ |
| Chủ tự vận hành | `self-managed host` | Owner == Operator (mặc định hiện tại) |
| Uỷ thác | `delegation` | Mối quan hệ owner → operator (gồm scope + commission + period + permissions preset) |
| Đóng vai | `acting-as` | Trạng thái UI khi operator đang thao tác thay owner |
| Phê duyệt | `approval request` | Action vượt ngưỡng cần owner OK trước khi commit |
| Ngưỡng phê duyệt | `approval_threshold` | Cấu hình per-delegation: monthly_rent, term_months, expense_amount, refund_amount, rent_change_pct |
| Phạm vi đại diện | `scope` | `all` HOẶC danh sách building/room IDs (non-nested; xem §13 D7) |
| Phê duyệt fast-track | `fast_track_approval` | KB04 + emergency: **SLA = 6 giờ** (canonical, xem §13 D1); default auto-approve trong preset `operator_full` |
| Hợp đồng song khai | `dual_disclosure_contract` | Hợp đồng PDF bắt buộc ghi cả Owner + Operator + CCCD cả 2 |
| Hoá đơn commission | `delegation_invoice` | Tính commission tháng (track only v1, no auto-transfer) |
| Vắng mặt | `out_of_office` | Operator pause khả năng tạo action mới trong khoảng date (vacation) |
| Người thừa kế / Executor di sản | `heir` / `estate executor` | Người tiếp quản quyền owner khi owner mất; yêu cầu admin-assisted KYC (xem US-O18, AC-58, §13 D2) |
| Giấy uỷ quyền | `power of attorney scope` | Phạm vi uỷ quyền ghi trong POA; v1 = phạm vi vận hành (thuê, thu tiền, KB04); không bao gồm chuyển nhượng sở hữu |
| Gia hạn KYC | `KYC expiry grace period` | 30 ngày operator có thể tiếp tục hoạt động khi document hết hạn, chờ re-KYC (AC-50) |

**Quy ước UX/copy (BA cố định):**
- Operator KHÔNG được gọi là "host" trên UI → tránh nhầm với owner.
- Owner KHÔNG được gọi là "host" khi đã ủy thác → gọi là "Chủ nhà" hoặc "Tôi".
- Header khi đang đóng vai: "Đang đại diện cho **[Tên Chủ]**" + màu cam nhạt (không phải xanh dương như chế độ "Mình").

---

## 5. User Stories

### 5.1. Owner stories

| ID | Story | Priority |
|----|-------|----------|
| US-O1 | Là Owner, tôi muốn mời 1 người đại diện qua số điện thoại/email, để giao họ quản lý tài sản của tôi | P0 |
| US-O2 | Là Owner, tôi muốn quy định rõ phạm vi (`all` hoặc danh sách building; không nested, xem §13 D7) khi mời đại diện | P0 |
| US-O3 | Là Owner, tôi muốn quy định commission % (hoặc cố định/tháng) cho đại diện | P0 |
| US-O4 | Là Owner, tôi muốn chọn 1 preset quyền (Vận hành đầy đủ / Chỉ kế toán / Chỉ xem) cho đại diện | P0 |
| US-O5 | Là Owner, tôi muốn xem dashboard doanh thu/hợp đồng/người thuê bằng UI đã có (không thay đổi) | P0 |
| US-O6 | Là Owner, tôi muốn thấy timeline gọn các hoạt động đại diện đã làm trong tuần | P0 |
| US-O7 | Là Owner, tôi muốn nhận thông báo CHỈ cho action vượt ngưỡng (hợp đồng mới, expense > X) | P0 |
| US-O8 | Là Owner, tôi muốn phê duyệt 1 chạm các action vượt ngưỡng từ thông báo | P0 |
| US-O9 | Là Owner, tôi muốn email/zalo digest tổng kết mỗi tuần các action của đại diện | P1 |
| US-O10 | Là Owner, tôi muốn tạm khoá (freeze/pause) đại diện ngay khi nghi ngờ — không cần huỷ hợp đồng | P0 |
| US-O11 | Là Owner, tôi muốn chấm dứt uỷ thác, có thông báo trước 30 ngày (mặc định) | P0 |
| US-O12 | Là Owner, tôi muốn xem mọi action đại diện đã làm trong quá khứ (audit log đầy đủ) | P0 |
| US-O13 | Là Owner, tôi muốn doanh thu vẫn vào TKNH của tôi (commission tách rời) | P0 |
| US-O14 | Là Owner, tôi muốn biết đại diện đã KYC chưa, có rating không (uy tín) | P1 |
| US-O15 | Là Owner đã uỷ thác, tôi muốn chế độ "Mình" để xem chi tiết VÀ gửi chỉ thị cho đại diện — không tự ý mutate trừ khi pause delegation trước. (Lưu ý Phase 3: UX onboarding cần giải thích rõ để tránh "tài sản của tôi mà phải xin phép?") | P0 |
| US-O16 | Là Owner, khi pause/freeze delegation, tôi muốn mọi in-flight của operator auto-handled theo quy tắc per-artifact (xem AC-58 v2 và M10 fix) | P0 |
| US-O17 | Là Owner (co-owner / heir scenario — out-of-scope v1) tôi mong v2 hỗ trợ multi-owner per property | P2 |
| US-O18 | Là người thừa kế / executor di sản, tôi muốn quyền tiếp quản delegation của chủ đã mất để tránh thất thoát doanh thu hoặc tranh chấp pháp lý | P0 (xem §13 D2, AC-58) |
| US-O19 | As Owner, I want to choose POA format (digital FastCA/VinaCA vs notarized PDF upload) at delegation creation, so that I can match my comfort/legal-strength preference. (Xem AC-55d, AS-14, §13 D3) | P1 |

### 5.2. Operator stories

| ID | Story | Priority |
|----|-------|----------|
| US-P1 | Là Operator, tôi muốn nhận lời mời uỷ thác qua app + zalo + email | P0 |
| US-P2 | Là Operator, tôi muốn xem rõ scope + commission + permissions trước khi accept | P0 |
| US-P3 | Là Operator cá nhân, tôi muốn hoàn tất KYC (CCCD + bank) — tái sử dụng flow host-onboarding | P0 |
| US-P4 | Là Operator doanh nghiệp (1 tài khoản pháp nhân, xem AS-06 + §13 D6), tôi muốn upload GPKD + CCCD người đại diện pháp luật + xác nhận ngành dịch vụ quản lý BĐS | P0 |
| US-P5 | Là Operator, tôi muốn dashboard danh mục "các chủ tôi đại diện" với KPI mỗi chủ | P0 |
| US-P6 | Là Operator, tôi muốn switcher header để vào workspace của 1 owner cụ thể | P0 |
| US-P7 | Là Operator, khi đang ở context owner A, tôi KHÔNG được thấy data của owner B | P0 |
| US-P8 | Là Operator, tôi muốn thao tác hằng ngày (invoice, đọc điện nước, chat tenant) tự do — không xin phê duyệt mọi lần | P0 |
| US-P9 | Là Operator, khi làm action vượt ngưỡng, app báo rõ "đã gửi owner duyệt" + ETA | P0 |
| US-P10 | Là Operator, tôi muốn xem commission đã chốt trong tháng + lịch sử payout | P0 |
| US-P11 | Là Operator, tôi muốn refresh dashboard không lag dù đang quản 30 owners | P1 |
| US-P12 | Là Operator, tôi muốn rút uỷ thác (nghỉ) — có thông báo trước 30 ngày | P1 |
| US-P13 | Là Operator, tôi muốn ranking/rating công khai để Owner mới chọn tôi | P2 |
| US-P14 | Là Operator, khi KYC document (CCCD/GPKD) sắp hết hạn 30 ngày, tôi muốn nhận thông báo proactive | P0 |
| US-P15 | Là Operator, tôi muốn set out-of-office (vacation date range): trong khoảng đó không tạo approval mới được; emergency tenant action escalate trực tiếp owner | P1 |
| US-P16 | As Operator-doanh-nghiệp, I want to update my legal representative (e.g., staff turnover) without re-onboarding all properties, so that operational continuity is preserved. (Xem AC-65, §13 D7) | P2 |

### 5.3. Self-managed host stories

| ID | Story | Priority |
|----|-------|----------|
| US-S1 | Là chủ tự vận hành, tôi không thấy bất kỳ thay đổi nào khi tính năng uỷ thác ra mắt | P0 |
| US-S2 | Là chủ tự vận hành, tôi có option "thử trở thành Operator" (kiếm thêm) — đồng thời quản property của mình | P2 |

### 5.4. Tenant stories

| ID | Story | Priority |
|----|-------|----------|
| US-T1 | Là Tenant, tôi muốn biết ai có thẩm quyền hợp pháp thu tiền và ký hợp đồng đại diện chủ tôi (chống lừa đảo) | P0 |
| US-T2 | Là Tenant, khi operator đổi giữa thời hạn thuê, tôi muốn nhận thông báo + thông tin liên hệ mới | P1 |

### 5.5. Admin platform stories

| ID | Story | Priority |
|----|-------|----------|
| US-A1 | Là Admin, tôi muốn xem tất cả delegation đang active, lọc theo status | P0 |
| US-A2 | Là Admin, tôi muốn force-revoke 1 delegation khi có khiếu nại | P0 |
| US-A3 | Là Admin, tôi muốn verify operator (cá nhân/doanh nghiệp) trước khi cho phép active | P1 |
| US-A4 | Là Admin, tôi muốn xem rating/khiếu nại của operator để có chế tài | P2 |
| US-A5 | Là Admin, khi SMS fallback trigger cho owner không phản hồi >60h, tôi muốn dashboard xem các approval đang stuck | P0 |
| US-A6 | Là Admin, tôi muốn nhận và xử lý thông báo về owner death/incapacity để tiến hành admin-assisted executor onboarding | P0 (xem AC-58, US-O18) |
| US-A7 | As Admin, I want a documented runbook for verifying owner death certificate within 24h business hours, so that delegation auto-pause SLA is met. (Ops-runbook, not UX; xem §13 D2, AC-58) | P1 |

---

## 6. Acceptance Criteria (testable)

### 6.1. Tạo & quản lý uỷ thác

| AC | Mô tả | Test |
|----|-------|------|
| AC-01 | Owner tạo invite bằng phone/email → backend gửi link (deep-link app + fallback web) hiệu lực 7 ngày, **token single-use** | E2E + idempotency test |
| AC-02 | Owner chọn scope: `all` HOẶC danh sách building IDs (không nested, không room-level trong v1; xem §13 D7) | Unit test |
| AC-03 | Owner chọn 1 trong 4 preset: `operator_full`, `accountant`, `viewer`, `custom` (P2) | Validation 400 |
| AC-04 | Owner đặt commission: % HOẶC số tiền cố định/tháng (mutually exclusive) | DB constraint |
| AC-05 | Operator accept → status `pending` → `active`; reject → `rejected` (final) | State machine |
| AC-06 | Nếu operator chưa hoàn tất KYC (CCCD + bank verified) → button "Chấp nhận" disabled, app dẫn vào flow KYC trước | UI test |
| AC-07 | 1 operator có thể active đồng thời nhiều delegation từ nhiều owner | No unique on operator_id |
| AC-08 | **1 owner có tối đa 1 delegation `active` tại 1 thời điểm (scope = `all` hoặc building-list, non-nested).** v1 không hỗ trợ "1 owner → 2 operators cho building khác nhau đồng thời." Xem §13 D7 và §7 out-of-scope. | DB constraint + service guard |
| AC-09 | Owner có thể `pause` → operator mất quyền NGAY (next API call → 401 với code `DELEGATION_PAUSED`) | Integration test |
| AC-10 | Owner có thể `terminate` → mặc định 30 ngày notice; immediate nếu lý do `fraud_suspected`/`legal_dispute` (auto báo admin) | Service test |
| AC-10b | **Re-invite cùng operator trong khi pending: HTTP 409 Conflict + offer revoke prior invite** (chống race + double-invite) | Integration test |

### 6.2. Context-switching (UX critical)

| AC | Mô tả | Test |
|----|-------|------|
| AC-11 | Operator login → landing page là "Danh mục chủ tôi đại diện" (list cards) | Widget test |
| AC-12 | Mỗi card: tên owner, số property, doanh thu MTD, action items, alert badge | Widget test |
| AC-13 | Tap card → context switch → header đổi màu cam + label "Đang đại diện cho [Tên Owner]" | Widget + integration |
| AC-14 | Header có button "← Thoát" → về portfolio; không thể accidentally remain in stale context | Navigation |
| AC-15 | **Context request-scoped, không session-scoped**: acting-as identity truyền per-request; backend validate per-request (NFR-07 — không cache delegation state vào token) | Integration |
| AC-15b | **Cross-device / multi-tab safety**: 2 tab cùng operator, mỗi tab có context riêng (per-request); push notification deep-link tự acquire context, không trust client state | Integration |
| AC-16 | Operator KHÔNG thấy data owner Y khi đang context X (cross-tenant isolation) | Security/IDOR test |
| AC-16b | **Mid-session revoke**: nếu delegation bị pause/terminate giữa session → next API call 401 code `DELEGATION_REVOKED` → UI force back portfolio + clear cache | Integration |
| AC-17 | Owner KHÔNG thấy switcher (chỉ có 1 context: chính mình) | Conditional render |
| AC-18 | **"Mình" mode read-only**: Owner xem chi tiết + gửi instruction cho operator. KHÔNG tự mutate khi delegation `active`. Muốn mutate → phải pause delegation trước. | UI/AC test |

### 6.3. Phân quyền (permissions)

| AC | Mô tả | Action allowed/denied per preset |
|----|-------|----------------------------------|
| AC-19 | Preset `operator_full`: được làm mọi việc TRỪ: đổi bank account owner, xoá building, transfer ownership, đổi commission, mutate delegation chính nó, **suppress dual-disclosure trên contract PDF** | Test matrix per endpoint |
| AC-20 | Preset `accountant`: chỉ invoice + meter_reading + payment recording; KHÔNG tạo/sửa contract, tenant | Test matrix |
| AC-21 | Preset `viewer`: read-only mọi entity | Test matrix |
| AC-22 | Operator không thể CRUD `operator_delegations` (chỉ accept/reject hoặc tự rút theo US-P12) | Endpoint guard |
| AC-23 | Mọi mutation operator: audit ghi actor identity (operator), owner identity, và delegation reference | DB inspection |

### 6.4. Approval workflow (threshold-based)

| AC | Mô tả | Ngưỡng |
|----|-------|--------|
| AC-24 | Operator tạo contract: nếu `term_months >= threshold_term` HOẶC `monthly_rent >= threshold_rent` → status `pending_owner_approval` | Per-delegation config |
| AC-25 | Operator tạo invoice/expense: nếu `amount >= threshold_expense` → approval | Per-delegation config |
| AC-26 | Operator đổi giá thuê: nếu `delta_pct >= threshold_rent_change_pct` → approval | Per-delegation config |
| AC-27 | Operator chấm dứt hợp đồng (early termination): luôn cần approval; KHÔNG bị block bởi AC-43 termination lockdown. *Cross-ref: khi AC-43 lockdown active, AC-43b governs approval SLA (24h thay vì default 72h per AC-30).* | Hard rule |
| AC-28 | Operator refund cho tenant: nếu `amount >= threshold_refund` → approval | Per-delegation config |
| AC-29 | Approval gửi tới owner: push (FCM) + in-app + 1-tap approve/reject | E2E |
| AC-29b | Approval cho amount ≥ 50M VND: yêu cầu biometric/PIN confirmation trước khi approve | Security AC |
| AC-30 | **Approval expire 72h**: fallback = **auto-REJECT + escalate qua SMS owner**. KHÔNG có option auto-approve trong v1. *SLA exceptions: AC-55/AC-55b (KB04 fast-track 6h), AC-29b (high-value biometric — xem §6 high-value flow), AC-43b (fraud-termination during lockdown 24h).* | Background job |
| AC-30b | **Delivery escalation v1**: 0h push → 24h push+email (intensified subject cho high-value) → 48h push+email (final reminder) → 60h SMS. Zalo OA channel DEFERRED to v1.1 (Q4 2026) per Decision D8. Per NFR-14, if email read-receipt indicates not-opened within 24h on high-value approval (≥20M VND/month), SMS escalation can fire earlier than 60h. | Notification config |
| AC-31 | Mọi approval: log owner_id, operator_id, action_payload, decision, reason, delivery_channels_used | Audit log |
| AC-31b | **No-default threshold**: tại invite, Owner phải chủ động set 5 threshold (rent, term, expense, rent_change_pct, refund). Không có default cứng nền tảng. | Validation 400 if missing |

### 6.5. Tài chính (revenue/commission)

| AC | Mô tả | Test |
|----|-------|------|
| AC-32 | Tenant thanh toán → ghi nhận doanh thu vào TKNH owner (`HostProfile.bank_*` của owner) | Service test |
| AC-32b | **Cash payment evidence**: operator ghi cash payment → bắt buộc location-stamp + photo (receipt). Amounts ≥ 2M VND: tenant counter-confirmation qua SMS/Zalo link. Lưu ý N5: nếu location service off hoặc photo upload fail, workflow degrade gracefully (warn, không block). | Workflow |
| AC-33 | Tính `expected_owner_payout = total - commission - fees` per invoice/contract. *v1 clarification: `platform_fee_pct = 0`; `commission = operator_commission only`; `expected_owner_payout = total - operator_commission`. Schema supports future platform fee insertion without breaking-change migration (see NFR-15).* | Pure function |
| AC-34 | Operator có dashboard riêng "Commission tháng này" | Widget |
| AC-35 | V1: KHÔNG auto-transfer commission (manual). Track + xuất report only. | Out-of-scope note |
| AC-36 | Owner có report "Commission đã trả Operator" hằng tháng (xuất Excel + bảng thuế TNCN/VAT format) | Report test |
| AC-37 | Operator chịu commission-loss trên số tenant trả thiếu (incentive alignment) | Service test |

### 6.6. Audit & transparency

| AC | Mô tả | Test |
|----|-------|------|
| AC-38 | Owner mở "Activity Feed" → timeline mọi action operator (filter: today/week/month, by entity) | E2E |
| AC-39 | Mỗi entry: thời gian, ai, hành động, entity affected, link sâu | Widget |
| AC-40 | Owner self-export audit log PDF/Excel tối đa 12 tháng (chống server load). **Admin-only court-evidence export: không giới hạn thời gian, cần admin auth + lý do ghi log.** | Endpoint test |
| AC-41 | Weekly digest email/zalo gửi owner thứ Hai 8:00: số contract mới, invoice mới, doanh thu, alerts | Scheduler |

### 6.7. Termination (chấm dứt uỷ thác)

| AC | Mô tả | Test |
|----|-------|------|
| AC-42 | Owner request terminate → state `pending_termination` + countdown 30 ngày | State machine |
| AC-43 | **Trong 30 ngày grace period sau khi delegation terminate có hiệu lực:** BLOCKED hoàn toàn (không cần approval): tạo hợp đồng MỚI, onboard tenant MỚI, raise threshold, change banking, invite operator khác. CHO PHÉP với owner approval per-action: terminate hợp đồng nghi gian lận (tenant default / fraud detection), refund tenant đã đóng tiền oan, sửa lỗi data nhập sai. CHO PHÉP không cần approval: hoàn tất invoice đang in-flight, bảo trì sự cố khẩn cấp (mất điện, mất nước, cháy nổ), trả lời message tenant. Mục đích: prevent NEW commitments, không paralyze legit operational continuity. *Cross-ref: AC-43b governs approval SLA when lockdown is active (24h fraud-termination, faster than default 72h per AC-30).* | Lockdown guard |
| AC-43b | **Approval SLA during lockdown for fraud-suspected termination = 24h business hours** (faster than default 72h per AC-30). System auto-rejects + admin escalation if owner does not respond within 24h. Audit log marks `lockdown_fraud_termination=true`. *Cross-ref: AC-27 (early termination always needs approval); AC-43 (lockdown 3-tier).* | Background job + audit |
| AC-44 | Sau 30 ngày: status → `terminated`, **archived** (soft-delete với `archived_at` timestamp, record giữ nguyên trong DB nhưng ẩn khỏi active views; KHÔNG move sang cold table ở phase-01). PDPL tiered retention áp dụng per §10.5. | Background job |
| AC-45 | Termination `fraud_suspected`/`legal_dispute` → immediate revoke + báo cáo admin | Workflow |
| AC-46 | Sau terminate, operator vẫn xem read-only history trong 90 ngày (dispute resolution). Nếu có PDPL ROD request từ tenant trong 90 ngày này: Tier C data redacted, nhưng operator vẫn thấy redacted placeholder. | UI test |

### 6.8. Non-regression (chủ tự vận hành) + Integration safety

| AC | Mô tả | Test |
|----|-------|------|
| AC-47 | Chủ tự vận hành (không có delegation) → KHÔNG thấy switcher, KHÔNG thấy badge | UI snapshot |
| AC-48 | Mọi endpoint hiện hữu hoạt động như cũ với chủ self-managed | Regression suite |
| AC-49 | **Mid-contract delegation activation**: KHÔNG modify existing contract/tenant/khaibao. Tenant contact = owner; operator = co-contact in-app only. Optional opt-in "transfer contact" → notify all active tenants. | Migration test |
| AC-50 | **Operator KYC expiry**: CCCD/GPKD sắp hết hạn 30 ngày → notification. Hết hạn → delegation auto `paused`, owner notified, operator có 30 ngày re-KYC (KYC expiry grace period, xem §4). Sau 30 ngày → auto-terminate không cần notice period. | Background job |
| AC-50b | **Operator-doanh-nghiệp loss of legal rep**: pause delegation; new representative phải KYC mới resume | Service AC |
| AC-51 | **Marketplace booking routing under delegation**: property delegated mà có listing trên marketplace → payout vẫn route đến `host_id = owner_id` (immutable). Operator manage listing theo permission preset; payout destination KHÔNG đổi được. | Regression test |
| AC-52 | Zero ALTER trên 20+ bảng nghiệp vụ hiện hữu (schema diff CI check) | CI check |
| AC-53 | **Owner bank account masking**: trong mọi operator view, bank account = `****1234`. Full reveal → owner one-time consent, log vào `CCCDAccessLog`-equivalent | PDPL AC |
| AC-54 | **Contract PDF dual-disclosure**: hợp đồng tenant tạo bởi operator MUST list "Chủ sở hữu: [Owner] (CCCD)" + "Người đại diện ký kết: [Operator] (CCCD)" — không tắt được. | PDF generation test |
| AC-55 | **KB04 carve-out**: KB04 submission là `fast_track_approval` — SLA **6h** (canonical tại §4 Terminology, §13 D1) thay vì 72h. Lý do: 12h là deadline *tenant phải được đăng ký* (Luật Cư Trú, research 03 §2.1), không phải deadline owner duyệt; operator có thể nộp KB04 từ trước khi tenant chuyển vào (xem §10.6 timeline). 6h SLA cho operator đủ buffer. Mặc định auto-approve trong preset `operator_full`. Audit log ghi "submitted on behalf of owner X via fast-track". *See AC-55b for pre-file workflow; AC-55c for police-rejection fallback; AC-55d for POA format selection.* | Workflow + legal AC |
| AC-55b | **KB04 pre-file pathway**: Operator MAY submit CT01 to police BEFORE tenant move-in (typically at lease-signing time T0); owner approval 6h is post-facto validation in this case. Pre-filed records audit-marked `pre_filed=true` and `owner_approval_state` ∈ {pending, approved, rejected}. If owner rejects after pre-file, operator must withdraw CT01 with police within 24h. (Xem §13 D1, O1 dependency) | Workflow + audit |
| AC-55c | **Pre-file rejection fallback**: If local police district returns `pre_file_not_accepted` (per O1 pre-launch validation results or per-submission flag), system falls back to approve-then-file 6h workflow for that district. District-level `pre_file_accepted` flag stored in property metadata, updated by admin. | System config + admin |
| AC-55d | **POA format selection at delegation creation**: default = digital consent via FastCA/VinaCA integration (in-app signature flow). Escalation option = owner uploads notarized POA PDF. If audit findings or O2 results indicate digital is unaccepted by property's police district, system displays warning + recommends notarized backup. Selected format stored in `delegation.poa_format` ∈ {digital, notarized}. (Xem US-O19, AS-14, §13 D3) | UI + DB |
| AC-56 | **Self-owner-self-operator**: 1 user có thể đồng thời là chủ (host data của riêng họ) VÀ active operator cho owner khác. Portfolio view show "Mình" + N owners họ đại diện. | Multi-context test |

### 6.9. Out-of-office (operator vacation)

| AC | Mô tả | Test |
|----|-------|------|
| AC-57 | Operator set `out_of_office` date range → trong khoảng đó: KHÔNG initiate approval mới được | UI + guard |
| AC-58 (OoO emergency — giữ tên cũ) | Emergency tenant action trong OoO → escalate trực tiếp owner + báo admin | Workflow |

### 6.10. Owner death / incapacity (mới — C3 fix)

| AC | Mô tả | Test |
|----|-------|------|
| AC-58 (heir) | **Owner death / incapacity — delegation auto-pause:** Khi platform admin nhận chứng tử + giấy uỷ quyền thừa kế (manual upload by admin only — KHÔNG self-attestation, xem §13 D2): *Timeline split:* (a) Admin verifies heir-uploaded death certificate within **24h business hours** (per US-A7 runbook). (b) Upon admin verification, delegation enters pause state for **7 days** during which executor onboarding (AC-58b) and tenant/operator notifications (24h via SMS+in-app) occur. (c) See AC-58d for in-flight approval handling at moment of registration. In-flight approval requests: default = **auto-rejected** (KHÔNG auto-approved). | Admin workflow test |
| AC-58b | **Executor onboarding:** Executor nộp notarized POA + chứng tử bản sao công chứng qua admin-assisted KYC flow. Sau onboard: executor có quyền owner-like nhưng audit log là **read-only** (không thể sửa lịch sử). | Admin flow test |
| AC-58c | **Tax-frozen account (cơ quan thuế đóng băng tài khoản chủ):** delegation tiếp tục vận hành nhưng payout auto-paused; admin escalation + owner/heir notified. | Service AC |
| AC-58d | **In-flight approval requests at the moment owner death is registered:** DEFAULT = auto-reject (per AC-58). EXCEPTION = if heir/executor is onboarded via AC-58b within the 7-day pause window, executor MAY approve in-flight requests within their delegated authority scope. Exception activation requires legal counsel confirmation (see Q2a/O3 in §9). Until counsel confirms, default = auto-reject and operator must re-submit post-executor-onboarding. (Xem §13 D2, open Q2a) | Legal AC + audit |

> **Lưu ý AC-58 naming:** AC-58 (OoO emergency) và AC-58 (heir) đều mang số 58. Để tránh nhầm, implementation phải phân biệt: AC-58-OOO (out-of-office emergency) và AC-58-HEIR (heir/death). Tech Lead sẽ tái số trong phase files nếu cần.

### 6.11. Tenant authority + PDPL (mới)

| AC | Mô tả | Test |
|----|-------|------|
| AC-60 | **Tenant in-app authority badge:** Trên tenant home + contract detail + invoice + mọi chat thread do operator khởi tạo: hiển thị badge "Liên hệ đại diện chủ nhà: [Operator name] | Chủ: [Owner name]". Badge cập nhật realtime khi delegation thay đổi. | Widget test |
| AC-61 | **Operator-company GPKD revoked:** Nếu admin phát hiện (thông qua annual re-verification hoặc report) operator-company GPKD bị thu hồi → delegation auto-paused, owner + tenants nhận thông báo trong 24h, operator có 15 ngày re-verify hoặc delegation auto-terminated. | Background job |
| AC-62 | **Offline operation server-stamp:** Mọi action của operator mang cả `acted_at` (client-claim) và `recorded_at` (server-stamp khi sync). Bất đồng bộ > 24h → flagged trong audit log. Cash receipt `acted_at` trước delegation `start_date` → blocked. | Audit AC |
| AC-63 | **Tenant unauthorized-operator flag:** Tenant có thể report "người này không phải đại diện chủ tôi" qua in-app channel → admin review trong 48h → nếu prima facie valid: delegation temporary pause + owner notified. Liên kết Q8 liability. | Workflow test |
| AC-64 | **Sole-ownership attestation at Owner onboarding:** System displays prompt "Property registered under single name (sole owner per red book)?". If NO → system blocks delegation creation with message: "v1 chỉ hỗ trợ chính chủ. Tính năng đồng sở hữu (vợ chồng, đồng thừa kế) launching v2 Q4 2026." If YES → owner click-acknowledges ToS indemnity clause for false attestation. Stored in `owner.sole_ownership_attested_at`. (Xem AS-15, §13 D4) | UI + DB |
| AC-65 | **PMC legal-rep change workflow (US-P16):** Operator-doanh-nghiệp uploads (a) updated notarized POA naming new legal rep + (b) new legal rep CCCD scan via admin-assisted flow. Admin verifies within 48h business hours. Old credentials disabled within 48h of admin approval; in-flight approvals re-routed to new legal rep; audit log marks transition with `legal_rep_changed_at` + `previous_rep_id`. (Xem §13 D7, AC-50b) | Admin flow + audit |
| AC-66 | **Shared-login disclosure UI at operator-doanh-nghiệp onboarding** (promoted from AS-12): System displays mandatory modal stating (a) all logins audit under single account, (b) password rotation is company's responsibility, (c) per-user RBAC launching v2 Q4 2026 Org model. Owner must click-acknowledge before delegation activation. Acknowledgment timestamped in `delegation.shared_login_disclosure_ack_at`. (Xem AS-12, §13 D7) | UI + DB |

### 6.12. Non-functional requirements

| NFR | Mô tả | Test hook |
|-----|-------|-----------|
| NFR-01 | Delegation state machine transitions phải atomic (no partial state) | Transaction rollback test |
| NFR-02 | Revocation propagates to all active sessions trong ≤ 1 next-request latency (không cache delegation state vào long-lived token) | Integration test |
| NFR-03 | Audit log query at scale phải return p95 < 1s; partition strategy là quyết định của Tech Lead | Load test |
| NFR-04 | Acting-as context propagates per-request (không session-scoped state) để support tab/window concurrency (AC-15b) | Concurrency test |
| NFR-05 | Delegation scope check tại request time phải complete với latency thấp p95; threshold do Tech Lead xác định | Benchmarking |
| NFR-06 | Approval notification delivery: p95 < 30s từ approval creation → push received | E2E notification test |
| NFR-07 | Revocation propagates in ≤ 1 next-request latency (đảm bảo delegations không cache trong JWT/session) | Integration test |
| NFR-08 | Android minimum support: Android 7.0 (API level 24) | Device test matrix |
| NFR-09 | Operator portfolio screen p95 ≤ 2.5s trên simulated 3G (target VN field operator) | Performance test |
| NFR-10 | Image upload (cash receipt, CCCD photo) ≤ 800KB sau client-side compression | Client test |
| NFR-11 | Offline-tolerant UI: meter reading + cash receipt draft có thể tạo offline, sync khi có mạng | Offline test |
| NFR-12 | NFC normalization trên tất cả name fields; diacritic-insensitive search (Vietnamese NFC); PDF renders full Vietnamese diacritics trên iOS/Android viewers | i18n test |
| NFR-13 | **Scope-aware schema:** Schema design MUST support scope-bound queries (single-property → property-list → nested building/room) without breaking-change migration of existing v1 data. Mechanism choice (`scope_id` FK, polymorphic table, denormalized scope array, etc.) is Tech Lead's call in phase-01. See Appendix B7 for non-binding suggestion. (Xem §13 D6) | Schema review + migration test |
| NFR-14 | **Email deliverability:** ancu365 outbound email MUST achieve ≥95% inbox delivery rate to owner addresses (SPF + DKIM + DMARC configured; sender reputation monitored monthly). High-value approval emails (rent ≥20M VND/month or threshold-change requests) MUST be flagged for read-receipt tracking; if not opened within 24h, system escalates to SMS earlier than default 60h gate. (Xem AC-30b, §13 D8) | Deliverability monitoring |
| NFR-15 | **Payment-splits schema forward-compat:** Schema MUST support insertion of platform fee percentage column without breaking-change migration. v1 default `platform_fee_pct = 0`; v2 enablement (Q4 2026) adds 0.5% transparent commission per Pricing decision (§13 Q1). See AC-33. | Schema review + migration test |

---

## 7. Out of Scope (v1 KHÔNG làm)

| Item | Lý do hoãn | Khi nào revisit |
|------|------------|------------------|
| Multi-tier delegation (operator → sub-operator) | YAGNI | v2 Org model |
| Auto-transfer commission qua API ngân hàng | Cần NHNN payment intermediary license | v3 |
| E-sign hợp đồng uỷ thác (chữ ký số) | Cần Viettel-CA/VNPT-CA tích hợp | v2 |
| Insurance product cho owner | Cần licensing bảo hiểm | v3 |
| Co-ownership (nhiều owner / property) | Cần schema redesign | v2 (xem Q9) |
| Custom permission matrix (per-action) | 4 preset đủ 90% case | v2 enterprise |
| Operator marketplace + rating công khai | Cần volume verified | v2 sau 6 tháng |
| Audit-log hash chain / blockchain | Overkill cho VN legal | nếu có dispute lớn |
| Multi-currency | Segment dùng VND | v3 |
| Workflow phê duyệt nhiều cấp | v1 chỉ 1 cấp | v2 enterprise |
| Chuyển nhượng delegation operator → operator | Phải mời lại | không |
| Operator handling tenant damage claims / insurance coordination | Phụ thuộc insurance v3 | v3 |
| Fiscal year tax export split by operator commission | AC-36 format TNCN đã đủ v1 | v2 nếu enterprise yêu cầu |
| **Sub-property scoped delegation (room-level nested under building-level)** | Xem §13 D7 — defer v2 | v2 Org model |
| **PMC sub-user (multi-user per operator company: receptionist + manager + accountant)** | Xem §13 D6 — defer v2 | v2 Org model Q4 2026 |

---

## 8. Assumptions

| # | Giả định | Nếu sai thì sao |
|---|----------|-----------------|
| AS-01 | Phân khúc C chiếm ~20% chủ nhà, ARPU cao 2–3× — **BA assumption, chưa validated; cần pilot** | Pilot 5–10 owner trước khi đầu tư đầy đủ |
| AS-02 | Mỗi owner uỷ thác cho 1 operator tại 1 thời điểm (per-scope) — xem §13 D7 | AC-08 đã hard-rule |
| AS-03 | Mỗi operator phục vụ 5–50 owners | >50 → redesign dashboard P1 |
| AS-04 | Commission VN: **7–10% giá thuê** (research 03: HCMC 7-9%, Hanoi median ~8%, placement fee 0.5–1 tháng tiền thuê) HOẶC 1–3M VND/property/tháng | Mở cấu hình per delegation; UI preset gợi ý 8% |
| AS-05 | Owner muốn digest tuần > real-time mọi event | Toggle ON/OFF per owner |
| AS-06 | **Operator-doanh nghiệp v1 = 1 user pháp nhân (legal representative account). PMC muốn dùng v1 phải chấp nhận shared-login risk (audit attribution dưới 1 account) + đăng ký 1 tài khoản pháp nhân.** Multi-user PMC (receptionist + manager + accountant) defer v2 Org model Q4 2026. Xem §13 D6. | v2 Org cho PMC nhiều nhân viên |
| ~~AS-07~~ | ~~Tenant không cần biết về delegation~~ | **REVERSED**: AC-54 hardcode dual-disclosure trên contract PDF |
| ~~AS-08~~ | ~~KB04 giữ nguyên~~ | **DELETED**: AC-55 carve-out fast-track |
| AS-09 | KYC operator cá nhân = CCCD + bank | Operator-doanh-nghiệp: + GPKD + ngành nghề |
| AS-10 | Owner approval delivery: push 80%, escalate SMS cho high-value/near-expiry | AC-30b định lượng |
| AS-11 | **Zalo ZNS template registration là v1.1 prep activity** (NOT v1 pre-launch precondition per Decision D8). Email + SMS suffice for v1 escalation ladder per AC-30b revised. If template registered early, hold for v1.1 rollout Q4 2026. | v1.1 channel unavailable if template delayed — no impact on v1 |
| AS-12 | PMC shared-login risk disclosure hiển thị rõ trong onboarding flow operator-doanh-nghiệp (xem AS-06). **PROMOTED to AC-66** for testable definition — see AC-66 for formal acceptance criteria. | AC-66 is testable; AS-12 is retained as cross-reference only |
| AS-13 | **Zalo ZNS budget 500K VND/month is v1.1 projection** (not v1). v1 messaging cost = email infrastructure only. v1.1 phase plan to add Zalo + SMS line items. Xem §10.9. | N/A — v1 cost = $0 messaging |
| AS-14 | **Digital signature integration:** ancu365 v1 integrates with FastCA or VinaCA for owner digital consent (AC-55d). Per-signature cost (~50–100K VND) absorbed by platform in v1; passed to owner in v2 via pricing model. If no signature vendor contract signed by phase-04 start, fallback to notarized PDF only. (Xem US-O19, §13 D3) | Notarized-PDF-only fallback if vendor contract delayed |
| AS-15 | **Sole-ownership self-declaration:** Owner attests sole ownership at onboarding (AC-64). Platform does NOT OCR red book in v1; relies on ToS indemnity clause. v2 may add OCR validation for high-value properties (≥20M VND/month rent) — see Q-DD2 in §9. (Xem §13 D4) | ToS violation exposure if owner misrepresents; indemnity clause mitigates |

---

## 9. Open Questions (cần user trả lời trước Phase 3)

> **ANSWERED in v3/v4 §13 D1–D9 + Q1:** KB04 SLA (D1), owner death channel (D2), KB04 POA format (D3), co-owned property (D4), AC-43 lockdown 3-tier (D5), scope nesting NFR (D6), PMC sub-users (D7), Zalo ZNS defer (D8), PDPL retention (D9), pricing model (Q1).

### Answered Questions (closed in v3 or v4)

- **Q3.4 → ANSWERED D4:** Platform refuse co-owned property onboarding via sole-ownership self-attestation (AC-64); defer to v2 Q4 2026.
- **Q4.1 → ANSWERED AC-31b:** No default threshold; owner phải set (forced engagement).
- **Q4.2 → ANSWERED AC-30:** Auto-REJECT + escalate SMS; no auto-approve.
- **Q4.3 → ANSWERED:** Không delegate approval v1.
- **Q9 → ANSWERED D4:** Same as Q3.4 — refuse co-owned, defer v2 Org model.
- **Q10 → ANSWERED D2:** Manual admin upload only; 24h verification SLA; 7-day delegation pause. See AC-58.
- **Q1 (Pricing) → ANSWERED Q1 in §13:** FREE v1 → Freemium v1.5 → 0.5% commission v2 → Full SaaS v3.

### Q1b — KB04 revocation during 12h window **[OPEN — Legal follow-up]**
- If owner revokes delegation during 12h window after operator pre-files KB04 (AC-55b) but before tenant moves in, is KB04 auto-voided? Needs legal counsel. **Pre-launch blocker for AC-55b workflow.**

### Q2a — Owner death + in-flight approval scope **[OPEN — Legal O3 follow-up]**
- For in-flight approvals at the exact moment owner death is registered (e.g., operator submitted KB04 request 11:58h, owner dies at 12:00h): does executor (AC-58b) get to approve in-flight items within 7-day pause window, or is auto-reject absolute? See AC-58d. **Needs legal counsel before phase-04 freeze.**

### Q2 — Trust & Verification **[STILL OPEN]**
- Q2.1. Platform PRE-VERIFY operator trước khi cho hoạt động? Hay tự chủ chịu trách nhiệm?
- Q2.2. "Danh sách operator được khuyến nghị" do platform vetted? (chống lừa đảo)
- Q2.3. Khi có khiếu nại: platform hoà giải hay chỉ cung cấp evidence?

### Q3 — Phạm vi v1 **[PARTIALLY ANSWERED]**
- Q3.1. **ANSWERED §13 D7:** Operator-doanh nghiệp với nhiều nhân viên login chung 1 tài khoản: chấp nhận v1 shared-login với disclosure (AC-66).
- Q3.2. Tích hợp với marketplace_integration: theo AC-51, OK chứ? **STILL OPEN — cần user confirm.**
- Q3.3. KB04: operator submit fast-track theo AC-55 — pháp lý có cần thêm giấy uỷ quyền có công chứng không? **CẦN LEGAL COUNSEL** trước launch. (Xem D3 default: digital consent + notarized fallback.)

### Q5 — Tài chính **[PARTIALLY OPEN]**
- Q5.1. Auto-transfer commission: out-of-scope (v3). **Confirm?** STILL OPEN.
- Q5.2. **ANSWERED AC-37**: operator chịu commission-loss. **Confirm?**
- Q5.3. Operator chi tiền sửa chữa (cash advance): `expense_reimbursement` entity riêng — v1 hay v1.5? **STILL OPEN.**
- Q5.4 (BA-Leader): **Operator commission VAT/PIT: owner withholds hay operator self-files? STILL OPEN — tax counsel needed. Ảnh hưởng AC-36 format.**

### Q6 — Legal **[PARTIALLY OPEN]**
- Q6.1. Template hợp đồng uỷ thác PDF: platform có generate không? Cần ai review pháp lý? **STILL OPEN.**
- Q6.3. Operator-doanh-nghiệp GPKD phải có ngành dịch vụ quản lý BĐS — confirm hardcode validation? **STILL OPEN.**
- Q6.4 (BA-Leader): Contract PDF dual-disclosure tenant phải ký nhận 2 bên — confirm AC-54? **STILL OPEN.**
- Q6.5 (BA-Leader): KB04 operator submission có cần notarized POA không? **CẦN LEGAL COUNSEL** trước launch. (Xem D3 — specific districts may require.)

### Q7 — Migration & Adoption **[PARTIALLY OPEN]**
- Q7.1. Pilot với 5–10 chủ + 2–3 operator thật trước launch? **STILL OPEN — recommend YES.**
- Q7.3 (BA-Leader): Geographic launch — HCMC+Hà Nội only first? **STILL OPEN — threshold no-default (AC-31b) đã giải quyết vấn đề regional variance.**

### Q8 — Liability **[STILL OPEN — BLOCKER cho TOS]**
- Q8.1. Nếu operator gian lận + biến mất: platform TOS position cho owner recovery?

### Pre-launch Validation Items (not BA decisions, but must complete)

- **O1** — Pre-launch police pre-file validation: confirm 1-3 phường HN/HCM chấp nhận CT01 submission trước tenant move-in. Required before phase-04 (AC-55b).
- **O2** — Pre-launch police POA digital validation: confirm which districts accept digital sig (FastCA/VinaCA) for KB04. Required before phase-04 (AC-55d).
- **O3** — Legal counsel on executor exception scope: confirm AC-58d exception path (in-flight approvals by executor within 7-day window). Required before phase-04 freeze.
- **O4** — NHNN intermediary license scope: semi-auto commission (suggested transfer) có trigger license không? Corporate counsel. Before v2 commission (Oct 2026).

### New Open Questions (surfaced by BA Leader deep-dive)

- **Q-DD2** — Red book OCR for high-value properties: If platform relies on owner self-attestation of sole ownership (AS-15, AC-64), should platform add OCR validation for properties with rent ≥20M VND/month to reduce fraud risk? **Product decision — before v2 planning.**
- **Q-DD4** — Email deliverability liability for absentee owners: If v1 email deliverability fails for Segment C owners (age 50-70, low email engagement), is platform exposed to "owner didn't see approval, fraud happened" liability? **Risk acceptance question — before launch.**
- **Q-DD5** — Cumulative TAM defer (~30-40% Segment C): Combined D4 (co-owned) + D6 (scope nesting) + D7 (RBAC) deferrals affect ~30-40% of Segment C addressable market. **Is sponsor OK with this aggregate cut, or should at least one be pulled forward to v1.5? HIGH PRIORITY — sponsor decision before Phase 3.**
- **Q-DD8** — Admin team scaling threshold: D2 requires 24h admin response SLA for death-cert verification. At pilot (50-100 delegations), this is founder-on-call. At 1000+ delegations, dedicated admin team needed. **When is the threshold + budget?**

---

## 10. Impact / Risk Assessment

### 10.1. Schema impact

| Bảng | Change | Risk |
|------|--------|------|
| `operator_delegations` (mới) | CREATE | Thấp |
| `delegation_approvals` (mới) | CREATE | Thấp |
| `delegation_invitations` (mới) | CREATE | Thấp |
| `users.role` enum | Thêm value `'operator'` | Trung bình — audit 30+ chỗ check `role == 'host'` |
| `host_profiles.is_operator_capable` | Thêm cột (optional) | Thấp |
| Mọi bảng nghiệp vụ (20+) | **KHÔNG ALTER** | Zero |
| `audit_logs` | Thêm cột nullable cho delegation reference (tên column là quyết định Tech Lead) | Thấp |

> Lưu ý C6: Tên cột cụ thể, partition strategy, constraint syntax là quyết định của Tech Lead trong phase-01. Xem Appendix B cho BA recommendations non-binding.

### 10.2. Auth/permission impact (BA-level NFRs)

- NFR-02: Revocation propagates ≤ 1 next-request latency (mechanism là quyết định Tech Lead).
- NFR-04: Acting-as context propagates per-request, không session-scoped.
- NFR-05: Delegation scope check at request time phải low-latency.
- Cần middleware mới: `check_delegation_active(operator_id, owner_id, action_key)` — tên và interface là quyết định Tech Lead.
- Helpers cần thiết: distinguish current actor từ current owner context — interface là quyết định Tech Lead.

### 10.3. UI impact (Flutter)

- New screens: `OperatorPortfolioScreen`, `DelegationDetailScreen`, `DelegationInviteScreen`, `ApprovalInboxScreen`, `ActivityFeedScreen`
- New providers: `DelegationProvider`, `ApprovalProvider`, `ActorContextProvider`
- Modify: `host_home_screen`, `guest_shell` (overlay acting-as)
- Theme variant "operator-acting-as" (cam nhạt)
- Notification routing: phân biệt owner vs operator

### 10.4. Notification impact

- 7 loại mới: `delegation_invited`, `delegation_accepted`, `approval_requested`, `approval_decided`, `delegation_paused`, `delegation_terminated`, `kyc_expiring_soon`
- Thêm: `owner_death_delegation_paused`, `heir_onboarding_initiated`, `gpkd_revoked_delegation_paused`
- Weekly digest: tái sử dụng APScheduler
- Bundle aggregation server-side (anti-fatigue)
- SMS fallback channel — xem §10.9 cost estimate.

### 10.5. Audit log volume & PDPL tiered retention

**PDPL Tiered Retention Policy (C5 fix, xem §13 D4):**

| Tier | Data category | Retention | Sau retention |
|------|---------------|-----------|---------------|
| **A — Financial records** | Invoice headers, payment receipts, contract financial terms | **10 năm online** (Luật Kế toán + research 03 §3.6) | Cold archive |
| **B — Audit metadata** | actor_id, action, timestamp, delegation_id, scope, decision | **7 năm online**, sau đó **cold archive 3 năm**; tổng = 10 năm | Purge |
| **C — PII-rich payloads** | CCCD numbers, addresses, biometric photos, name+phone of tenant | **24 tháng** sau khi quan hệ rental kết thúc (contract end + 24mo) | **Redact** (giữ hash anchor cho audit, xóa raw). Per PDPL Decree 13/2023 §3.4 minimization. |
| **D — Operational logs** | Login, API access, push notification delivery logs | **90 ngày** | Purge |

**AC-59 — PDPL Right-of-Deletion (ROD) request flow:**
Tenant/operator submit qua in-app + ID verification → admin xử lý trong 30 ngày → Tier C data redacted, Tier A/B retained với reasoned exception cited. ROD response thư gửi cho người yêu cầu.

*Note (v4):* Cron job mechanics for tier transitions are Tech Lead implementation detail per NFR (background job reliability target ≥99.5%). 4-tier policy is confirmed; scheduling mechanism is not a BA-level constraint.

**Performance NFR-03:** Audit log query at scale phải p95 < 1s. Partition strategy là quyết định Tech Lead (xem Appendix B).

**Index strategy:** là quyết định Tech Lead phase-01 — requirement là query by owner + time range + actor phải efficient.

### 10.6. Legal & compliance

**KB04 timeline (C2 fix):** Hiểu đúng Luật Cư Trú §2.1 (research 03):

```
Lease-signing (T-N)
    → Operator drafts KB04 hồ sơ (T-N+1h..T0 any time)
    → Owner reviews + provides fast-track approval (SLA 6h từ request, xem §4 và §13 D1)
    → Operator submits KB04 to công an
    → Tenant moves in (T0)
    → Deadline: tenant registered by T0 + 12h
```

**Key insight:** 12h deadline là deadline TENANT phải được đăng ký (sau khi dọn vào), **không phải** deadline owner phải duyệt. Operator có thể — và nên — submit KB04 TRƯỚC khi tenant dọn vào (lúc ký hợp đồng). Fast-track 6h SLA = buffer cho trường hợp operator delay gửi request đến gần T0.

| Risk | Mitigation |
|------|------------|
| Operator gian lận, ăn cắp tiền | Audit dual-identity + threshold approval + pause + admin escalation + AC-43 lockdown trong notice period |
| Owner kiện platform khi mất tiền | TOS rõ "platform là công cụ minh bạch, không bảo lãnh"; Q8 trả lời insurance/escrow |
| PDPL: tenant data leak qua operator | Operator có quyền vì là đại diện owner (Q6.2); audit CCCDAccessLog đầy đủ |
| KB04 khai báo sai gây phạt | AC-55 fast-track + audit "on behalf of owner X"; Q6.5 cần lawyer xác nhận |
| Thuế operator commission TNCN+VAT | AC-36 xuất bảng format thuế; Q5.4 trả lời WHO khấu trừ |
| Tenant tranh chấp authority operator | AC-54 contract PDF dual-disclosure + AC-60 in-app badge |
| PDPL: operator xem owner bank account | AC-53 mask `****1234` + reveal qua consent + audit |
| **Owner death / incapacity** | **AC-58 + AC-58b + AC-58c: delegation auto-pause, executor onboarding, tax-frozen account** |
| **Operator GPKD revoked** | **AC-61: delegation auto-pause + re-verify 15 ngày** |
| **Offline backdated receipt fraud** | **AC-62: server-stamp + acted_at validation** |
| **PDPL: PII over-retention** | **§10.5 Tiered retention 4-tier + AC-59 ROD flow** |

### 10.7. Trust & UX risk
- **Risk:** Owner confused về "ai làm gì" → bỏ tính năng
- **Mitigation:** Onboarding tour cho owner đầu uỷ thác; weekly digest đơn giản; activity feed trực quan; UI badge rõ ràng; AC-13/AC-14 thoát context dễ

### 10.8. Performance risk
- Operator-portfolio cần aggregate API server-side (NFR-09: p95 ≤ 2.5s on 3G)
- Approval inbox: pagination + filter status
- Audit log query: phải efficient at scale (NFR-03)

### 10.9. Messaging & digital signature cost estimate

| Item | v1 cost | v1.1 projection (Q4 2026) | Notes |
|------|---------|--------------------------|-------|
| SMS fallback | ~600đ/msg; ~5% approvals × volume × 600đ | Same | High-value + 60h gate only |
| Email infrastructure | Low (~hosting + SES/Sendgrid) | Same | Primary v1 channel (AC-30b) |
| Zalo ZNS | **0 (deferred to v1.1 per D8/AS-11)** | ~240K VND/month (100 deleg × 4 msg × 600đ); cap **500K VND/month** | v1.1 adds Zalo at 48h gate |
| **Digital signature (FastCA/VinaCA)** | **~50–100K VND × N delegations (absorbed by platform per AS-14)** | Passed to owner v2 via pricing model | Per-signature cost; N = new delegations/month |

*v1 total messaging cost:* email infrastructure + SMS fallback only (Zalo = 0).

### 10.10. Mobile-first NFR (M9 fix)

VN audience ≥ 90% mobile; field operator dùng thiết bị Android đa dạng (Phú Quốc, Đà Lạt rural signal). NFR-08..NFR-11 (§6.12) cover:
- Android ≥ 7.0 (NFR-08)
- Portfolio screen p95 ≤ 2.5s trên simulated 3G (NFR-09)
- Image upload ≤ 800KB sau client compression (NFR-10)
- Offline draft cho meter reading + cash receipt (NFR-11)

---

## 11. Success Metrics (sau 6 tháng)

> Phân loại hard-gate (kill feature nếu miss) vs aspirational:

| Metric | Target M+6 | Type |
|--------|------------|------|
| Số delegation active | 100+ | **Hard gate** — nếu < 50 sau 6 tháng, đánh giá lại feature |
| Số operator active | 30+ | Aspirational |
| Số owner đang dùng delegation | 80+ | Aspirational |
| NPS từ owner (delegation feature) | Advance gate to v1.5 = **≥55** (Pricing expert recommendation); aspirational steady-state **≥60** (BA target) | Advance gate (55) + Aspirational (60) |
| % approval owner-approved (vs reject) | ≥ 85% | **Hard gate** — nếu < 70%: threshold model sai, cần redesign |
| % owners flag/comment ≥ 1 audit event mỗi quý (thay metric "views/week" gameable) | ≥ 30% | Aspirational (engagement) |
| Số tranh chấp owner-operator escalate admin / tháng | ≤ 3 | **Hard gate** |
| Median time-to-approve (push → tap) | ≤ 4h | Aspirational |
| Churn rate delegation / tháng | ≤ 5% | Aspirational |
| SMS fallback rate (% approvals trigger SMS) | ≤ 5% | **Monitor** — nếu > 10%: owner unresponsive, redesign notification |
| AC-50 auto-pause cho KYC expiry → re-KYC success rate trong 30 ngày | ≥ 80% | Aspirational |
| **Pilot validate: BA assumption 55/25/20% market split** | Pilot 100 delegations; collect real segment data | Hard gate cho v2 investment |
| **Cumulative TAM deferred to v2 (D4 co-owned + D6 scope nesting + D7 RBAC)** | ~30-40% Segment C addressable market deferred. **Hard-gate:** if v1 fails to reach 50 delegations in 6 months, evaluate whether deferrals are the cause and pull at least one forward in v1.5. | Sponsor decision gate (see Q-DD5) |

---

## 12. BA Leader Review Notes (Phase 2 — applied)

**BA Leader (brainstormer agent) verdict v1:** NEEDS_REVISION — 7 CRITICAL + 12 MAJOR + 7 MINOR issues. Applied in v2.

**BA Leader (independent second pass) verdict v2:** NEEDS_REVISION — 6 CRITICAL + 12 MAJOR + 7 MINOR issues.

---

### v2 changelog (2026-06-29, BA Leader v1 remediation)

**CRITICAL fixes (7 applied in v2):**
- C1 KB04 fast-track: Added AC-55. *(Partial — numeric drift to 3h found in v2, corrected in v3.)*
- C2 Approval expire 72h: AC-30 auto-REJECT + SMS escalate.
- C3 Request-scoped context: AC-15b, AC-16b.
- C4 Overlapping scope: AC-08 constraint. *(Partial — contradiction with US-O2 fixed in v3.)*
- C5 "Mình mode": US-O15, AC-18.
- C6 PDPL bank mask: AC-53.
- C7 Marketplace routing: AC-51.

**MAJOR fixes (12 applied in v2):** AC-49, AC-50, AC-50b, AC-56, AC-10b, AC-32b, AC-37, AC-30b, AC-43 *(logic corrected in v3)*, AC-31b, §10.5, AC-57/58, US-P14/P15.

**MINOR fixes (7 applied in v2):** AC-06, AC-29b, AC-40, §11 metric, §4 terminology, §10.3 overlay reword, Q7.2 removed.

---

### v3 changelog (2026-06-29, BA Leader v2 remediation)

Applied 6 CRITICAL + 12 MAJOR + 7 MINOR findings from `reports/ba-leader-review-v2.md`. Default decisions documented in §13. Summary of changes:

**CRITICAL (6 applied in v3):**
- **C1 (KB04 SLA numeric drift):** Canonical value = **6h** set in §4 Terminology. TL;DR updated to 6h. AC-55 updated to 6h. §12 changelog references 6h. Single source-of-truth rule added to §4 header.
- **C2 (Legal misreading):** Rewrote KB04 framing throughout. Added §10.6 timeline diagram. Corrected: 12h = tenant registration deadline (post move-in), not owner approval deadline. Operator can pre-file at lease-signing.
- **C3 (Owner death/incapacity):** Added US-O18, US-A6, AC-58 (heir), AC-58b, AC-58c. Added §10.6 risk row. Added Q10 (answered: manual admin only). Added `heir`, `estate executor`, `power of attorney scope`, `KYC expiry grace period` to §4.
- **C4 (AC-43 logic inversion):** Rewrote AC-43 with 3-tier: BLOCKED (new commitments), WITH approval (fraud termination/refunds), WITHOUT approval (in-flight/maintenance/tenant messaging). Preserved AC-27 compatibility.
- **C5 (PDPL tiered retention):** Replaced blanket "7 năm online" with 4-tier policy (A=10y, B=7+3y, C=24mo+redact, D=90d) in §10.5. Added AC-59 ROD flow. Added NFR-03 performance.
- **C6 (Hidden tech prescription):** Removed from §3/§4/§10: `audit_logs` partition strategy, scope_hash SHA-256, X-Acting-As header name, JWT caching prohibition, `acted_via_delegation_id` column name, partial unique index syntax, "16+ bảng" exact count. Replaced with NFR-02..NFR-07. Moved to Appendix B as non-binding BA recommendations.

**MAJOR (12 applied in v3):**
- **M1 (PMC sub-users):** Default = defer B2B PMC sub-user to v2. Rewrote AS-06, added AS-12, added §13 D6. Struck US-P4 ambiguity (clarified = 1 legal rep account).
- **M2 (Tenant in-app badge):** Added AC-60.
- **M3 (Scope nesting):** Default = 1 active delegation per owner, scope = all/building-list (no nested). Updated AC-08, US-O2. Added §7 out-of-scope item. Added §13 D7.
- **M4 (Operator bankruptcy):** Added AC-61 (GPKD revoked → auto-pause + 15 days re-verify).
- **M5 (Offline operations):** Added AC-62 (server-stamp + acted_at validation). Added NFR-11.
- **M6 (Tenant dispute ownership):** Added AC-63 (unauthorized-operator flag + admin review 48h).
- **M7 (PDPL — covered by C5):** See C5.
- **M8 (Unsourced metrics):** Added BA assumption disclaimer at top of §1.1. Tagged §11 metrics hard-gate vs aspirational.
- **M9 (Mobile-first NFR):** Added §10.10 + NFR-08..NFR-11.
- **M10 (In-flight on revocation):** Refined US-O16. Added per-category disposition in AC-43 (approval requests, contract drafts, scheduled notifications, push subscriptions).
- **M11 (Vietnamese diacritics):** Added NFR-12 (NFC normalization + diacritic-insensitive search + PDF rendering).
- **M12 (Zalo ZNS cost):** Added AS-13, §10.9 cost estimate (240K VND/month, cap 500K VND/month). Added AS-11 fallback if template not registered.

**MINOR (7 applied in v3):**
- **N1:** Accepted TBD; added Q1.3 flag (already implied).
- **N2:** Added `heir`, `estate executor`, `power of attorney scope`, `KYC expiry grace period` to §4.
- **N3:** AC-29b biometric flag for Android variability noted (implementation detail for Tech Lead).
- **N4:** AC-40 updated with admin-only court-evidence export path (unlimited horizon, admin auth required).
- **N5:** AC-32b updated with graceful degradation note (location/photo fail = warn, not block).
- **N6:** AC-44 updated: defined "archive" = soft-delete with `archived_at` timestamp, records stay in DB.
- **N7:** US-O15 updated with Phase 3 UX onboarding note ("tài sản của tôi mà phải hỏi xin?" framing).

---

## 13. Decisions Log

> **v4 note:** Decision numbering aligns with `expert-consolidated-recommendations.md` matrix to keep Tech Lead handoff unambiguous. Earlier BA v3 §13 D1-D8 numbering is **SUPERSEDED** by this v4 §13 numbering.

User có thể override trước freeze date tương ứng.

| # | Topic | Default | Confidence | Sources | Related ACs/NFRs | Dependencies | Override window |
|---|-------|---------|------------|---------|-----------------|--------------|-----------------|
| **D1** | KB04 SLA owner approval | **6h** + pre-file pathway | HIGH | Legal Q1, Ops Q3 | AC-55, AC-55b, AC-55c | O1 pre-launch police validation | Before phase-04 freeze |
| **D2** | Owner death/incapacity channel | Manual admin upload (heir provides death cert + notarized POA); **admin verifies within 24h business hours**; **7-day delegation pause**; in-flight approvals auto-rejected by default; executor-exception path (AC-58d) pending legal confirmation (O3) | MED-HIGH | Legal Q2 | AC-58, AC-58d, US-A7 | O3 legal counsel on executor exception | Before phase-01 schema |
| **D3** | KB04 POA format | **Digital consent default** (FastCA/VinaCA in-app signature); notarized upload optional escalation | HIGH | Legal Q3 | AC-55d, AS-14, US-O19 | O2 police district acceptance validation | Before phase-04 freeze |
| **D4** | Co-owned property v1 | **REFUSE v1** via sole-ownership self-attestation (AC-64); defer to v2 Org model Q4 2026 | HIGH | Legal Q4 | AC-64, AS-15 | None; O5/O6 WTP surveys inform v2 scope | Before phase-01 schema |
| **D5** | AC-43 30-day lockdown scope | Keep 30-day window; 3-tier logic (BLOCKED/WITH-approval/WITHOUT-approval) already correct in AC-43 v3; **ADD AC-43b: fraud-termination approval SLA = 24h business hours** (faster than default 72h per AC-30) | MED-HIGH | Ops Q1 | AC-27, AC-30, AC-43, AC-43b | D1 pre-file unlocks lockdown-allowed pre-file | Before phase-04 freeze |
| **D6** | Scope nesting v1 | **Defer behavior** (UI + nested approval workflows) to v2; **require scope-aware schema in v1** via NFR-13. Mechanism is Tech Lead's choice (scope_id FK, polymorphic table, denormalized scope array) — see Appendix B7 | HIGH on NFR / MED on mechanism | Ops Q2 | NFR-13, AC-08 | Tech Lead to confirm mechanism in phase-01 plan | Before phase-01 schema freeze |
| **D7** | PMC multi-user RBAC | **Defer to v2**; v1 = 1 pháp nhân đại diện per operator-doanh-nghiệp + shared login + AC-66 mandatory disclosure + AC-65 legal-rep change workflow | HIGH | Strategy Q1 | AC-65, AC-66, US-P16 | None | Before phase-09 freeze |
| **D8** | Zalo ZNS rollout | **Defer to v1.1 Q4 2026.** v1 escalation = push + email + SMS only (AC-30b rewritten). v1.1 adds Zalo OA channel at 48h gate | HIGH | Strategy Q2 | AC-30b, AS-11, AS-13 | v1 cost = 0 messaging; v1.1 = ~13.5K VND/mo pilot | Done — no override (phasing decision) |
| **D9** | PDPL data retention | **4-tier** (hot 90d / warm 2y / cold 5y / legal hold per case per §10.5) | HIGH | BA v3 §10.5 + Legal cross-cut | AC-44, AC-59 | Cron job mechanics = Tech Lead detail (NFR ≥99.5%) | Done in v3 — confirmed |
| **Q1** | Pricing model v1 | **FREE v1** → optional Freemium v1.5 ($50-99K/mo operator features) → 0.5% transparent commission v2 (Q4 2026) → Full SaaS v3 (Q1 2027, $99-499K/mo subscription + 2-3% commission). KPI gates: v1→v1.5 = 50+ delegations + NPS≥55; v1.5→v2 = 100+ + churn≤5%; v2→v3 = 150+ + churn≤10% | HIGH | Pricing report (all sections) | AC-33, AC-34, AC-35, AC-36, AC-37, NFR-15 | NHNN intermediary license scope (O4) before v2 auto-commission | v1 = resolved; v1.5/v2/v3 = gate reviews |

---

## 14. Approval gates

- [x] Phase 1 BA Author — Claude (v1 finalised → v2 revised → v3 revised → v4 revised)
- [x] Phase 2 BA Leader review v1 applied (7C+12M+7N fixes)
- [x] Phase 2 BA Leader review v2 applied (6C+12M+7N fixes)
- [x] Phase 2 BA Leader deep-dive applied (10 expert recs → v4: +3 USs, +8 ACs, +3 NFRs, +2 AS, §13 unified D1-D9+Q1)
- [ ] **User confirms §13 Decisions Log unified D1-D9 + Q1** before Phase 3 freezes corresponding phases
- [ ] **Q-DD5 (Cumulative TAM defer ~30-40% Segment C)** — sponsor acceptance required before Phase 3
- [ ] User approves to proceed to Phase 3 (Tech Lead plan)

---

## Appendix B — BA Recommendations to Tech Lead (non-binding)

> Phần này ghi lại các nhận xét kỹ thuật của BA trong quá trình phân tích. Đây là **gợi ý, không phải requirement**. Tech Lead hoàn toàn tự do thay thế bằng cách tiếp cận phù hợp hơn.

**B1 — Acting-as context propagation:**
BA đề xuất per-request header để truyền acting-as identity. Cơ chế cụ thể (header name, middleware pattern, JWT vs. separate token) là quyết định Tech Lead. Requirement: NFR-04 (per-request scoped, không session-scoped).

**B2 — Audit log performance:**
BA ghi nhận rằng audit log sẽ grow nhanh (mọi mutation của operator log đầy đủ). Partition strategy là quyết định Tech Lead. Requirement: NFR-03 (p95 < 1s at 10M rows). BA recommend xem xét partitioning by `created_at` từ day-1 trước khi data lớn.

**B3 — Delegation scope enforcement:**
BA đề xuất scope enforcement tại request time (không cache). Mechanism (hash, direct lookup, middleware chaining) là quyết định Tech Lead. Requirement: NFR-05 (low-latency scope check) + NFR-02 (revocation ≤ 1 next-request).

**B4 — Audit dual-identity columns:**
BA đề xuất audit log cần capture: (a) actor (operator) identity, (b) owner identity, (c) delegation reference. Tên cột cụ thể, nullable strategy, index design là quyết định Tech Lead.

**B5 — Scope uniqueness constraint:**
BA requirement: không có overlapping active delegation cho cùng 1 owner (AC-08). Mechanism (DB constraint, application guard, or both) là quyết định Tech Lead. BA lưu ý: nếu dùng DB constraint với partial index, syntax phụ thuộc vào DB version và migration tool.

**B6 — Schema model (informational):**
BA đã phân tích Model A (Delegation Link) vs Model B (Organization) và recommend Model A cho v1. Phân tích chi tiết giữ ở §3. Tech Lead có thể propose alternative nếu có lý do kỹ thuật đủ mạnh.

**B7 — Scope-aware schema mechanism (non-binding suggestion for NFR-13):**
Ops expert (Q2) suggested adding `scope_id` FK to delegation table + relaxing AC-08 unique constraint to per-scope. Estimated +2-3 dev-days in phase-01. Tech Lead may propose alternatives (polymorphic table, denormalized scope array, materialized scope view) provided NFR-13 is satisfied (scope-bound queries without breaking-change migration). Estimated v2 migration cost WITHOUT scope-ready schema: 2-3 dev-weeks per Ops Q2 estimate; mitigation = forward-design now. Tech Lead must confirm chosen mechanism in phase-01 plan before schema freeze.

---

## 15. v4 Changelog (2026-06-29 — BA Leader deep-dive, 10 expert recs applied)

```
v4 (2026-06-29): BA Leader deep-dive review of 10 expert recommendations applied.
Source: reports/ba-deep-dive-on-expert-recs.md

User Stories added (+3):
  - US-O19: Owner POA format choice (digital FastCA/VinaCA vs notarized PDF) at delegation creation [P1]
  - US-P16: Operator-doanh-nghiệp legal-rep update without property re-onboarding [P2]
  - US-A7: Admin runbook for death-cert verification within 24h business hours [P1]

Acceptance Criteria added (+8):
  - AC-43b: Fraud-termination approval SLA = 24h during AC-43 lockdown (faster than default 72h)
  - AC-55b: KB04 pre-file pathway (operator submits CT01 before tenant move-in; owner 6h post-facto)
  - AC-55c: Pre-file police rejection fallback (district-level flag + revert to approve-then-file)
  - AC-55d: POA format selection at delegation creation (digital default; notarized escalation)
  - AC-58d: In-flight approval handling at owner-death moment (default auto-reject; executor exception pending O3)
  - AC-64: Sole-ownership attestation at onboarding (self-declaration + ToS indemnity; blocks co-owned)
  - AC-65: PMC legal-rep change workflow (48h admin verify; old credentials disabled; audit log)
  - AC-66: Shared-login disclosure UI (promoted from AS-12; mandatory modal at operator-doanh-nghiệp onboarding)

Non-functional Requirements added (+3):
  - NFR-13: Scope-aware schema (forward-compatible for v2 nesting, mechanism = Tech Lead choice, see Appendix B7)
  - NFR-14: Email deliverability ≥95% inbox rate (SPF+DKIM+DMARC; read-receipt + early SMS for high-value)
  - NFR-15: Payment-splits schema forward-compat (platform_fee_pct column insert without migration)

Assumptions added (+2):
  - AS-14: Digital signature vendor (FastCA/VinaCA); cost absorbed v1, passed to owner v2; notarized fallback if delayed
  - AS-15: Sole-ownership self-declaration binding under ToS; no red-book OCR in v1; v2 may add OCR

Existing ACs revised:
  - AC-27: Added cross-reference to AC-43b (24h fraud-term SLA when lockdown active)
  - AC-30: Added SLA exceptions enumeration (AC-55/55b, AC-29b, AC-43b)
  - AC-30b: Rewritten for v1 (Zalo removed; push→email→SMS only; NFR-14 early SMS for high-value)
  - AC-33: Added v1 clarification (platform_fee_pct=0; forward-compat via NFR-15)
  - AC-55: Added cross-references to AC-55b/c/d
  - AC-58 (heir): Clarified 24h = admin verification SLA; 7d = pause-state duration; added AC-58d reference

Assumptions revised:
  - AS-11: Updated — Zalo ZNS is v1.1 prep activity (NOT v1 pre-launch precondition per D8)
  - AS-12: Marked as PROMOTED to AC-66 (cross-reference retained)
  - AS-13: Updated — Zalo budget 500K VND/month is v1.1 projection (not v1)

§9 Open Questions updated:
  - Closed: Q3.4, Q4.1, Q4.2, Q4.3, Q9, Q10 → mapped to D2/D4/Q1 in §13
  - Kept open: Q5.4 (tax counsel), Q6.5 (police POA), Q1b (revocation during pre-file window), Q2a (executor exception)
  - Added: O1-O4 (pre-launch validation items)
  - Added: Q-DD2, Q-DD4, Q-DD5, Q-DD8 (new questions from BA deep-dive)

§10.5 PDPL: Added cron job mechanics note (Tech Lead detail; ≥99.5% background job reliability)
§10.9 Budget: Added digital signature row (50-100K VND × N delegations, absorbed v1); Zalo zeroed for v1
§11 Metrics: NPS advance gate = ≥55 (Pricing); aspirational = ≥60; added cumulative TAM defer hard-gate metric
§13 Decisions Log: REWRITTEN — unified D1-D9+Q1 numbering matching consolidated matrix; v3 D1-D8 numbering superseded
§14 Approval gates: Updated to reflect v4 completion; Q-DD5 sponsor gate added
Appendix B7: Added (scope-aware schema mechanism, non-binding suggestion for NFR-13)
```

---

**Status: REVISED v4 — BA Leader deep-dive (10 expert recs) applied → READY for Phase 3 (Tech Lead planning), pending user confirmation of §13 D1-D9+Q1 unified decisions log and Q-DD5 cumulative TAM sponsor acceptance.**
