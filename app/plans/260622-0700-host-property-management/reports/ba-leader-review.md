# BA Leader Review — Host Property Management

**Reviewer:** Senior BA Leader (brainstormer mode)
**Date:** 2026-06-22
**Document reviewed:** `phase-00-ba-requirements.md` (status: APPROVED, scope sealed)
**Research input:** `nha-tro-vn-systems.md`, `homestay-vn-systems.md`, `codebase-audit-host-feature.md`

---

## Overall Assessment

Document structure tốt — segmentation T1/T2/T3 rõ ràng, phân biệt nhà trọ vs homestay đúng (đây là điểm sống còn, nhiều startup VN trộn lẫn), 5 decisions đã seal hợp lý cho 1-founder context. **Nhưng scope đang underestimate operational complexity ~30-40%**: thiếu nhiều flow đời sống thực (move-out mid-term, room maintenance, roommates, refund cọc), một số AC không testable, "bulk create rooms" và "auto-generate invoice tháng" đều là hidden scope creep. Sizing 7-8 tuần là optimistic mode, realistic 9-11 tuần nếu giữ nguyên scope. Khuyến nghị **NEEDS_REVISION** trước khi sang Phase 3 — cần fix 6 critical issues + thêm ~8 user stories thiếu + clarify 4 assumptions.

---

## Strengths

- Segmentation T1/T2/T3 với % thị trường + hành vi hiện tại → có actionable decision (skip T3 channel manager)
- Phân biệt rõ Section 3a (nhà trọ) vs 3b (homestay) — không trộn entity flows
- 5 sealed decisions đều correct cho 1-dev constraint (defer payment gateway, defer gov API submission)
- Section 9c (New constraints) bắt được dependency Booking rename → đã flag pre-work
- Risk table có cover RBAC + schema clash, không quá lạc quan
- Out of scope (Section 6) liệt kê rõ — chống được scope creep từ stakeholder sau

---

## Critical Issues (BLOCK — phải fix trước Phase 3)

| # | Issue | Section | Suggested fix |
|---|---|---|---|
| C1 | **Thiếu flow tenant move-out mid-term** (refund cọc, settle utility cuối, ngày trả phòng < ngày hết HĐ). Đây là ~30% case thật ở nhà trọ T1/T2 (sinh viên đổi trường, công nhân nghỉ việc). Không có user story → schema Contract sẽ thiếu `terminated_at`, `deposit_refund_amount`, `final_invoice_id`. | §4C, §4D | Thêm story C5 + C6 (xem "Missing User Stories" bên dưới) + AC cụ thể |
| C2 | **Thiếu Room maintenance status flow**. B2 có list status "đang sửa" trong dropdown nhưng KHÔNG có user story riêng cho: ai trigger maintenance? Tự động block invoice tháng đó không? Khi maintenance done → status về vacant tự động? Without flow → developer sẽ tự decide, dễ ship bug. | §4B | Thêm story B4 (xem bên dưới) + state machine diagram |
| C3 | **Booking rename → ViewingAppointment chưa được sized**. Section 9c flag "ảnh hưởng nhiều file" nhưng không chốt: nó nằm trong Phase 02 (Foundation host profile) hay Phase 01 (DB migration)? Sized 3-4d cho Foundation đã cover chưa? Grep nhanh codebase: `Booking` xuất hiện trong model, router, helpers (push_notification types `booking_new`/`booking_approved`/...), `lib/providers/bookings_provider.dart`, `HostHomeScreen` line 57. Đây là **0.5-1 ngày dev + 0.5d test riêng** chưa được sized. | §9b, §9c | Tách thành Phase 01b hoặc explicit sub-task trong Phase 02 với sized 1d. Liệt kê file scope cụ thể trong Tech Plan Phase 3 |
| C4 | **Multi-tenant isolation chỉ ghi "WHERE host_id = current_user.id" — không đủ**. SQLAlchemy event listener (before_compile) hay Postgres RLS đều chưa được nhắc. Trên codebase hiện có `POST /api/houses` không có auth check (audit line 85). Nếu chỉ "trust developer add filter" → CERTAIN sẽ leak ở endpoint nào đó. Cần defense-in-depth strategy. | §5 AC kỹ thuật, §8 Risk | Thêm AC: "Mọi query trên ops tables PHẢI qua repository layer có auto-inject host_id; PR review checklist có item này; có integration test verify cross-host access bị 403" |
| C5 | **AC "Hot reload không vỡ Provider tree" không phải product AC**. Đây là developer concern, không phải user-facing acceptance criteria. Lẫn lộn AC product với dev hygiene → khi review không biết đâu là blocker. | §5 AC tổng | Move xuống "Definition of Done" hoặc "Engineering quality bar", KHÔNG đặt cùng AC product |
| C6 | **Postgres migration chưa nêu data preservation strategy**. SQLite hiện có data thật không (user đã đăng ký, listings)? Migration là (a) reset toàn bộ — OK nếu chưa launch, hoặc (b) dump SQLite → preserve → restore vào Postgres? Không clarify → Phase 01 dev sẽ guess. Khác biệt 0.5d (reset) vs 2-3d (preserve + verify). | §9c, Phase 01 | User confirm: SQLite hiện có data thật/user thật chưa? Nếu chưa launch → document explicit "OK to reset". Nếu có → thêm sub-task dump+restore+verify scripts |

---

## Important Issues (FIX — nên fix nhưng không block)

| # | Issue | Section | Suggested fix |
|---|---|---|---|
| I1 | **Thiếu story chuyển phòng (transfer room)**. Tenant đang ở phòng A muốn đổi sang phòng B trong cùng dãy → cần keep history, prorate tiền tháng đó, không tạo HĐ mới hoàn toàn. T2 nói có (chủ 20-50 phòng thường xuyên gặp). | §4C | Thêm story C7 + AC |
| I2 | **Thiếu handling roommates (nhiều tenant cùng phòng trọ)**. Đa số phòng trọ VN cho 2-4 người ở. Schema `Contract N—1 Tenant` (Section 7 Phase 02) ngụ ý 1 contract = 1 tenant. Khi 1 trong 4 roommate move out, giữ contract cũ hay tạo mới? Ai chịu trách nhiệm tiền điện nước? | §4C, §7 | Quyết định model: (a) Contract có nhiều Tenant (M:N) hay (b) Contract per person + share room → AC thay đổi nhiều |
| I3 | **Thiếu handling guest cancel homestay reservation**. E4 có "approve/reject + lý do" cho host, nhưng không có flow khi GUEST tự huỷ trước check-in. Có refund không? Trong bao lâu? Auto-release calendar slot không? | §4E | Thêm story E7 + cancel policy decision (rigid/flexible/none) |
| I4 | **"Bulk create rooms (template)" — hidden complexity**. Story B3 nghe nhẹ nhưng UX khó: user nhập gì để clone? Phòng-mẫu rồi nhân số lượng? Tự đánh số (101, 102, ...) hay user gõ tay? Số lượng phòng giống nhau 100% không (giá khác nhau theo tầng, diện tích khác)? Có lẽ sized 1-2d riêng. | §4B, §7 Phase 02 | Defer sang post-MVP (T2/T3 only) hoặc spec rõ format input + sized chính xác |
| I5 | **"Auto-generate invoice ngày 1 hàng tháng" — cần job scheduler infra**. Phase 03 mention "Job tự generate invoice ngày 1". Backend hiện chưa có cron/scheduler (audit không nhắc). Đây là +0.5-1d setup (APScheduler hoặc separate worker process) + monitoring nếu chạy production. | §7 Phase 03 (old) | MVP: cho user manual click "Tạo hoá đơn tháng X" cho cả dãy. Defer auto-cron. Tiết kiệm 1d + giảm ops complexity |
| I6 | **"Zalo deep-link cho gửi hoá đơn" cần render invoice trước**. Phase 06 mention. Nhưng deep-link `zalo.me/{phone}?text=...` chỉ chứa TEXT, không file. Vậy: gửi link tới invoice page (cần public-but-secret URL với token) hay paste plaintext invoice content (xấu, dài)? PDF generation chưa được sized ở phase nào. | §7 Phase 06 | Quyết định: (a) Public-link với UUID token (đơn giản, +0.5d) (b) PDF generation server-side (+1-1.5d, cần lib reportlab/weasyprint). Move quyết định lên BA doc |
| I7 | **CCCD photo storage không nói lưu ở đâu**. Audit cho thấy upload hiện local filesystem. Nhưng CCCD là PII nhạy (tương đương SSN). C2 yêu cầu upload "ảnh CCCD + ảnh khách + ảnh phòng". Không có encryption-at-rest, không có access audit. Pháp lý VN (NĐ 13/2023 về bảo vệ dữ liệu cá nhân) yêu cầu measures. | §4C, §8 Risk | Thêm risk: PDPL compliance; AC: CCCD ảnh phải lưu ở folder riêng có access log; encrypted-at-rest nếu di chuyển sang cloud |
| I8 | **Sized "~7-8 tuần dev" không include test/demo/buffer**. 8 phase × sized không phase nào có "+test day" hay "+demo day" hay "+integration buffer". Realistic: 7d Phase 03 → 7d dev + 1d demo + 0.5d buffer = 8.5d. Total: 9-11 tuần. | §9b | Recalibrate sizing bảng (xem "Sizing Realism Check" bên dưới) |

---

## Minor / Nitpicks

- §2 Tier %: "80% homestay T1" mâu thuẫn với research file homestay (research nói 88% qua Zalo direct, không chia tier rõ). Số 80% nên có source citation hoặc giảm confidence level
- §3a "Pháp lý: bắt buộc đăng ký tạm trú trong 12h" — chính xác hơn là **12h khu vực thường, 24h khu vực sâu xa**. Document nha-tro research dùng "12h" generic, document homestay research nói rõ split → align lại
- §4 F1 link `http://tbltkbtt.bocongan.gov.vn/` — confirm portal vẫn live 2026-06-22 (research nói launched 2026-05-21)
- §5 AC "< 10 phút", "< 3 phút", "< 5 giây" — chưa nêu measurement: từ thao tác đầu đến complete? Tính cả thời gian nhập liệu user không?
- §6 Out of scope thiếu "Multi-language UI tenant-facing form khai báo tạm trú (English cho foreigner guest)" — homestay có foreigner guest, form nên có EN version?
- §7 Phase 04 vẫn xài tên cũ "Homestay Core" nhưng §9b đã chuyển nó xuống Phase 07. Reader confused → consider xoá Section 7 hẳn, chỉ giữ §9b làm canonical phase list
- §7 Phase 02 "5-7 ngày" vs §9b Phase 03 "5-7d" — phase numbering thay đổi nhưng sized giữ nguyên. Khi tách rename Booking ra → sized phải cộng thêm
- §8 Risk table không có owner/mitigation deadline → nên mark mỗi risk thuộc Phase nào sẽ address

---

## Missing User Stories

| # | Story description | Tier | Priority |
|---|---|---|---|
| C5 | Là chủ trọ, khi tenant báo move out giữa kỳ, tôi muốn ghi nhận ngày trả phòng thực tế + tạo invoice cuối (prorate tiền nhà ngày + chốt điện nước cuối) + ghi nhận deposit refund (trừ hư hại nếu có) | T1,T2,T3 | **MUST** — ~30% case |
| C6 | Là chủ trọ, khi terminate contract, tôi muốn upload ảnh phòng lúc trả + ghi note hư hại để justify deposit deduction | T1,T2,T3 | **MUST** — dispute prevention |
| C7 | Là chủ trọ, khi tenant đổi phòng trong dãy (transfer), tôi muốn link HĐ cũ với phòng mới, prorate tiền tháng đó, không phải tạo HĐ mới hoàn toàn | T2,T3 | SHOULD |
| C8 | Là chủ trọ, tôi muốn 1 hợp đồng có nhiều tenant (roommates), trong đó 1 người là "primary contact" chịu trách nhiệm tiền, others là co-tenant phải khai báo tạm trú | T1,T2 | **MUST** — VN context phòng trọ 2-4 người ở chung là phổ biến |
| B4 | Là chủ trọ, tôi muốn set phòng status = maintenance với ngày start/end, auto-skip invoice tháng đó, hiện trên dashboard "X phòng đang sửa, ETA done" | T1,T2,T3 | **MUST** — flow đời sống thực |
| E7 | Là chủ homestay, khi guest cancel reservation trước check-in, tôi muốn apply cancel policy (full refund / partial / no refund tuỳ thời điểm), auto-release calendar slot, gửi noti nếu có waitlist | T1,T2,T3 | **MUST** — không có thì over-booking risk |
| E8 | Là chủ homestay, khi có nhiều booking request cho cùng ngày, tôi muốn xem chúng cùng lúc và pick 1 → auto-reject các request khác | T1,T2 | SHOULD |
| A3 | Là host (T1 chưa quen công nghệ), tôi muốn IMPORT từ Excel sẵn có của tôi (list phòng + tenant + giá) — không phải nhập tay từ đầu | T1,T2 | NICE-TO-HAVE — giảm entry barrier; cân nhắc cho phase sau |
| G4 | Là chủ trọ, tôi muốn export báo cáo tháng ra Excel/PDF để gửi kế toán / lưu sổ sách | T2,T3 | SHOULD |

---

## Missing Acceptance Criteria

- AC cho **data isolation testable**: "Host A login + GET /api/host/rooms → KHÔNG thấy room của Host B trong response, kể cả khi pass `?host_id=B` trong query param. Integration test bắt buộc."
- AC cho **state machine validity**: "Contract chỉ chuyển: draft → active → (expired | terminated). Không cho phép active → draft. Test với mỗi transition invalid → return 400."
- AC cho **invoice immutability sau paid**: "Invoice đã mark paid không cho phép edit line items. Phải tạo Credit Note / Adjustment riêng."
- AC cho **khai báo deadline visibility**: "Nếu sau check-in 12h chưa mark đã khai báo → notification + badge đỏ trên dashboard. Test simulate 12h sau, đảm bảo trigger."
- AC cho **soft delete contract**: "Contract terminated KHÔNG xoá DB, giữ history. Khi query active list mặc định filter `status != terminated`."
- AC cho **concurrent booking conflict** (homestay): "2 guest book cùng slot trong 1 giây → chỉ 1 thành công, người kia 409 Conflict. Test với race condition."

---

## Hidden Scope Creep Detected

1. **"Bulk create rooms (template)" (B3)** — UX phức tạp: template fields nào copy, fields nào unique (số phòng tự tăng, giá có thể khác theo tầng)? Sized 0.5d trong Phase 02 nhưng thực ra 1-2d nếu làm đúng. **Recommendation:** Defer sang post-MVP, MVP cho phép tạo 1 phòng và "Duplicate" 1 cái sang phòng kế (đơn giản hơn 5x).

2. **"Generate invoice ngày 1 hàng tháng tự động"** — yêu cầu cron/job scheduler + monitoring. Backend hiện không có. **Recommendation:** MVP là button "Tạo hoá đơn tháng X" manual cho cả dãy (1 click). Tiết kiệm 0.5-1d + ops complexity. Add auto-cron sau khi user thực sự dùng nhiều.

3. **"Zalo deep-link gửi hoá đơn"** — vô tình bao gồm PDF/HTML invoice rendering. Cần lib (reportlab/weasyprint) + template + style + test render. Sized chưa cover. **Recommendation:** MVP dùng public-link với UUID token (server render HTML web view), defer PDF.

4. **"Cảnh báo trước 30 ngày hết hạn HĐ" (C3)** — cần job scheduler chạy daily check + notification. Same infra issue như #2. **Recommendation:** Gộp chung quyết định scheduler với #2.

5. **"Reminder Zalo/SMS trước hạn 3 ngày" (D5)** — không chỉ cần scheduler, mà còn cần Zalo Business API access (research §1.3 nói cần OAuth + OA setup). Không phải "send anonymous"; phải có Zalo OA verified. **Recommendation:** Defer auto-send sang post-MVP. MVP: hiện danh sách "cần nhắn" trên dashboard, host tap → mở Zalo manual.

6. **"Báo cáo doanh thu tháng + năm" (G1)** — sized 3-4d Phase 06 cho 3 báo cáo (G1+G2+G3) + Zalo + notifications. Chart UI Flutter (fl_chart/syncfusion) chưa setup → +0.5d. Aggregate query trên Postgres không phải trivial nếu có refunds/adjustments. **Recommendation:** MVP table view trước, chart sau.

7. **"Marketplace ↔ Ops integration" Phase 08** — sized 3-4d. Thực ra: (a) khi tạo room → auto-publish lên House table với image sync (decision needed: sync ảnh hay link ảnh?), (b) khi guest book marketplace → auto-create Contract/Reservation draft → bao nhiêu field map, conflict resolution (guest đã có user account chưa?)... Realistic 5-7d. **Recommendation:** Sized lại honest hoặc cắt scope (chỉ 1 chiều: ops → marketplace, không reverse).

---

## Sizing Realism Check

Original sizing trong §9b: **~7-8 tuần (35-40 working days)**. Đánh giá lại:

| # | Phase | Original | Realistic | Justification |
|---|---|---|---|---|
| 01 | DB migration SQLite→Postgres | 1-2d | **2-3d** | Docker-compose Postgres setup + Alembic baseline cho TẤT CẢ tables (audit nói chỉ planning đã có migration; users/houses/bookings auto-create) + data migration script (nếu cần preserve) + test local + verify both DB modes still work |
| 01b | Booking → ViewingAppointment rename (NEW) | 0d (lẫn trong P02) | **1d** | Grep, rename model + router + helper notification types + Flutter provider + screens + chat house_id ref + test no regression |
| 02 | Foundation & Host Profile | 3-4d | **4-5d** | + 1d cho `require_host()` middleware + audit existing endpoints add auth check (audit nói chưa có) + onboarding 3-step UX có CCCD upload (+0.5d preview UI) |
| 03 | Nhà trọ Core (Building/Room/Tenant/Contract) | 5-7d | **7-9d** | + roommates (M:N Contract-Tenant nếu chọn option a) + room status state machine + transfer room story (+1d) + soft delete + state validation tests |
| 04 | Nhà trọ Ops (Invoice/Payment/Meter) | 7d | **8-10d** | + move-out invoice prorate logic (+1d) + final settle utilities (+0.5d) + debt aging query (+0.5d) + manual "generate invoice tháng X" UI thay cho cron (-0.5d offset) |
| 05 | Khai báo tạm trú | 3-4d | **4-5d** | + form rendering (PDF or HTML, decision needed +0.5d for picked option) + EN version cho foreigner guest (+0.5d) + reminder UI (12h timer) + roommate khai báo (mỗi tenant 1 record) |
| 06 | Reports + Zalo + Notifications | 3-4d | **5-6d** | + chart lib setup Flutter (+0.5d) + Zalo deep-link URL builder + scheduled notification UI (manual trigger MVP) + report export CSV/PDF (+1d) |
| 07 | Homestay Core (Calendar/Pricing/Reservation) | 7d | **9-11d** | + concurrent booking conflict prevention (+0.5d) + cancel policy logic (+1d) + pricing rules priority resolution (base vs weekend vs holiday) (+0.5d) + check-in/check-out workflow (+1d for proper UX) |
| 08 | Marketplace ↔ Ops integration | 3-4d | **5-7d** | + decision matrix sync ảnh vs link + draft Contract auto-create from booking + collision resolution if guest chưa có account |
| | **TOTAL** | **32-37d (~6.5-7.5w)** | **45-57d (~9-11.5w)** | |
| | **+ buffer (recommend 15%)** | | **+7-9d** | Demo prep, bug fix per phase, integration regression |
| | **GRAND TOTAL realistic** | | **52-66d (~10.5-13w)** | |

**Conclusion:** 7-8 tuần là 1.4-1.7x optimistic. Realistic là **10-13 tuần (2.5-3 tháng)**. Nếu vẫn muốn ship trong 7-8 tuần → phải cắt scope (xem recommendations cuts trong "Hidden Scope Creep").

---

## Recommended Decisions / Confirmations Cần User Approve

| # | Topic | Options | BA Leader recommendation |
|---|---|---|---|
| D1 | SQLite data preservation | (a) Reset toàn bộ — OK nếu chưa launch (b) Dump + restore + verify | Confirm app đã có user thật chưa. Nếu chưa → (a). Nếu rồi → (b) +2-3d |
| D2 | Roommates model | (a) Contract M:N Tenant (1 contract nhiều người) (b) Contract 1:1 Tenant, mỗi roommate 1 contract riêng share room | (a) — match thực tế VN: 1 hợp đồng cho cả nhóm thuê, 1 người đại diện trả tiền |
| D3 | Invoice rendering format | (a) Server-render HTML public-link (UUID token) (b) Server-generate PDF (c) Plaintext copy-paste | (a) — đơn giản nhất, gửi Zalo deeplink link → guest click view. PDF defer sang post-MVP |
| D4 | Auto-cron invoice/reminder | (a) Cron daily check 30d expiry, monthly invoice gen, 3d-before payment reminder (b) Manual button trên dashboard | (b) MVP — tránh infra scheduler. Phase 06 chỉ làm UI "danh sách cần action" |
| D5 | Bulk create rooms B3 | (a) Defer post-MVP (b) Simple "Duplicate this room" 1-click (c) Full template builder | (b) — simple duplicate là 80% giá trị với 20% effort |
| D6 | Multi-tenant isolation strategy | (a) Repository pattern auto-inject host_id (b) Postgres RLS policies (c) Trust developer per-query | (a) — 1-dev, không cần Postgres RLS complexity. Có repo layer wrap mọi query ops. Plus integration test cross-host. |
| D7 | CCCD storage | (a) Local filesystem (current) (b) Cloud (S3/R2) với encryption (c) Local + encrypted-at-rest + access log | (c) MVP — local + folder permissions + audit log table. Cloud sau khi production |
| D8 | T1 entry barrier (Excel import) | (a) Skip — T1 dùng app như-là (b) Import Excel feature ở Phase nào đó | Skip MVP. Theo dõi nếu T1 churn cao sau launch → add Phase 09 |
| D9 | Booking rename scope | (a) Sub-task trong Phase 02 (b) Standalone Phase 01b trước Phase 02 | (b) — clean separation, dễ revert nếu fail. Sized 1d |
| D10 | Cancel policy homestay | (a) Free cancel anytime (b) Rigid 24h before / 50% / 0% (c) Host-configurable | (b) MVP — simple fixed policy. (c) defer |

---

## Final Rating

- [ ] READY — có thể proceed Phase 3 (Tech Lead Planning) ngay
- [x] **NEEDS_REVISION** — phải fix Critical Issues trước
- [ ] NEEDS_REVISION_MINOR — fix Important Issues thôi cũng đủ

**Rating:** **NEEDS_REVISION**

Lý do: 6 critical issues đều ảnh hưởng schema design Phase 02-03. Nếu sang Tech Lead Planning ngay → Tech Lead sẽ phải guess answers, schema design lock vào early, sau này refactor đau. Tốt hơn dành 1-2h revise BA doc + user confirm 10 decisions (D1-D10) thì Phase 3 plan sẽ solid hơn rất nhiều.

---

## Next Action for BA

1. **Edit §4** thêm 9 user stories (C5, C6, C7, C8, B4, E7, E8, A3, G4) — đánh dấu MUST/SHOULD/NICE
2. **Edit §5 AC** chuyển "hot reload" xuống Engineering DoD, thêm 6 testable AC (xem "Missing AC" bên trên)
3. **Edit §6 Out of scope** thêm explicit: "Auto-cron job scheduler (defer)", "Excel import (defer)", "PDF generation (defer)", "Zalo Business API auto-send (defer — chỉ deep-link manual)"
4. **Edit §8 Risk** thêm: PDPL compliance cho CCCD storage, concurrent booking conflict homestay, Booking rename regression risk
5. **Edit §9b sizing** recalibrate theo bảng "Sizing Realism Check"; total realistic 10-13 tuần
6. **Hỏi user 10 quyết định D1-D10** trước khi sang Phase 3
7. **Xoá Section 7 (Phase Breakdown cũ)** hoặc note rõ "DEPRECATED — see §9b" để tránh reader confusion
8. **Section 9c** clarify Booking rename là Phase 01b riêng (per D9)

Sau khi BA hoàn tất 8 actions trên → present revised doc cho user approval → sang Phase 3.

---

## Unresolved Questions (cần user trả lời)

1. SQLite hiện đã có data user thật chưa? (ảnh hưởng D1 sizing)
2. Có agreement với Zalo Official Account chưa? Nếu chưa → Zalo deep-link OK, nhưng Zalo Business API auto-send phải defer
3. Target launch date — soft (3 tháng nữa) hay hard (cụ thể tháng/sự kiện)? Nếu hard → cần cắt scope thật
4. App đã có user nào dùng production chưa? Có thể "reset everything" hay phải migrate?
5. Có cần audit trail (ai-thay-đổi-gì-khi-nào) cho contract / invoice không? Pháp lý VN nhà trọ chưa bắt buộc nhưng dispute prevention thì rất nên có
