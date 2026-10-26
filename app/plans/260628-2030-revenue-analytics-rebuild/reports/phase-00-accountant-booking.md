---
title: "Phase 00 — Tax Accountant Booking Brief (TT200 Pilot Review)"
condition: "BA Leader §11.1 #1 (R11)"
status: draft_pending_user_action
prepared_by: Tech Lead (Claude)
date: 2026-06-28
blocks_phase: 09 (Excel TT200 export)
---

# Phase 00 Gate — TT200 Accountant Booking Brief

## Goal
Book 2-3 Vietnamese accountants (kế toán) experienced with Thông tư 200/2014/TT-BTC to validate the Excel TT200 export template (`phase-09-excel-tt200-export.md` AC-10 spec) BEFORE Phase 09 dev starts. Per BA Leader §11.1 #1 — BA không phải kế toán chuyên môn, AC-10 hiện là "best-effort draft", chỉ "compliance-ready" sau accountant sign-off.

**Action required: USER (founder/PM) executes this brief, not Tech Lead.** Tech Lead prepares template + scope; user executes outreach.

---

## Scope of Review (for accountant)

Accountant cần review:

1. **Template structure** — 6 sheets per AC-10:
   - Sổ Nhật ký chung (S03a-DN)
   - Sổ Cái TK 511 (Doanh thu bán hàng) + TK 5113 (Doanh thu dịch vụ)
   - Bảng kê hoá đơn (S05-DN equivalent)
   - Bảng kê thu/chi (TK 111, TK 112)
   - Bảng kê công nợ (TK 131)
   - Bảng kê giảm trừ doanh thu (TK 521)

2. **Field mapping** — confirm each column maps to correct TT200 schema:
   - Số chứng từ, Ngày tháng GS, Số hiệu TK, Diễn giải, TK đối ứng, Phát sinh Nợ, Phát sinh Có…
   - MST format (10 chars vs 13 chars), date `dd/mm/yyyy`, currency without thousand separator
   - Tax line items (TK 3331 GTGT đầu ra, TK 3334 thuế TNDN)

3. **Edge cases compliance:**
   - Refund attribution: TK 521 (giảm trừ doanh thu) hay TK 511 (negative)?
   - Multi-month booking prorate: ghi nhận theo ngày phát sinh hay ngày chốt invoice?
   - Commission to platform: TK 642 (chi phí quản lý)?
   - Voided invoice immutability: phải có lịch sử version hay không?

4. **Filename + delivery convention:**
   - `so-ke-toan-{host_slug}-{YYYY-MM}.xlsx` — accountant chấp nhận?
   - Versioned export (`v1`, `v2` suffix) per AC-10 immutability — accountant cần?

5. **Practical fit:**
   - Họ có thể import thẳng vào phần mềm kế toán (MISA, Fast, Bravo) không?
   - Hay phải copy-paste thủ công?

---

## Candidate Profile (who to approach)

| Criteria | Required | Nice-to-have |
|---|---|---|
| Chứng chỉ kế toán viên (CPA / KTV cấp Bộ Tài chính) | ✅ | — |
| Kinh nghiệm với host nhà trọ / homestay (5+ năm) | ✅ | — |
| Đã làm việc với phần mềm MISA / Fast / Bravo | ✅ | — |
| Biết quy định TT133 (DN nhỏ) lẫn TT200 (DN vừa+) | nice | — |
| Có host pilot đang là khách | — | ✅ |
| Sẵn sàng làm 1 round review trong 5-7 ngày | ✅ | — |

**Acquisition channels:**
- Host pilot pool — ask existing power host: "ai làm kế toán cho bạn?"
- Cộng đồng kế toán Facebook (group "Kế Toán Việt Nam", "Cộng đồng kế toán xây dựng")
- Linkedin filter "Accountant + Vietnam + Hospitality"
- Freelance platforms (Fiverr VN, Vlance.vn)

---

## Engagement Template

### Scope of Work (cho accountant pilot)

> "Chúng tôi đang xây dựng tính năng xuất báo cáo kế toán Thông tư 200 cho host quản lý nhà trọ / homestay. Cần kế toán có kinh nghiệm review template Excel xuất ra, đảm bảo:
> 1. Đúng cấu trúc 6 sheet theo TT200/2014/TT-BTC
> 2. Mã TK đối ứng đúng (TK 511, 5113, 521, 111, 112, 131, 3331, 642)
> 3. Format số/ngày/MST đúng
> 4. Edge case refund / multi-month / commission / void invoice xử lý đúng theo nguyên tắc kế toán
> 5. Import được vào phần mềm kế toán phổ biến (MISA / Fast)
>
> Deliverable: bảng nhận xét + Excel sample đánh dấu lỗi/đề xuất sửa.
> Thời gian: 5-7 ngày làm việc.
> Phí: thoả thuận (ước tính 3-5 triệu/lần review)."

### Materials chuẩn bị gửi accountant

1. **Excel sample anonymized** (sau khi Phase 09 build xong sample v1):
   - 1 tháng dữ liệu mẫu
   - PII đã anonymize: tenant tên giả ("Khách A", "Khách B"), MST giả `0123456789`
   - File `so-ke-toan-pilot-2026-05.xlsx`
2. **AC-10 spec document** — đính kèm bản tóm tắt yêu cầu (translate sang Tiếng Việt thuần)
3. **Edge case scenario file** — 5 scenario test (refund cross-month, void invoice, commission, multi-month, no tax_id host)
4. **NDA** — accountant ký trước khi nhận sample data

---

## Cost & ETA Estimate

| Item | Estimate |
|---|---|
| Phí mỗi accountant (1 round review) | 3-5 triệu VND |
| 3 accountants × 1 round | **9-15 triệu VND** |
| 2nd round nếu cần sửa | +50% |
| ETA total | **1-2 tuần kể từ ngày gửi sample** |
| Buffer | +1 tuần (accountant bận, lịch khó) |

**Total accountant budget reservation: 15-25 triệu VND + 2-3 tuần lead time.**

---

## Timeline Sequencing

```
Now ─→ User outreach 3 candidates (3-5 ngày)
     ─→ Sign NDA + engagement letter (2 ngày)
     ─→ Phase 09 dev produces Excel v1 sample (depends on Phase 02 + 09 dev start)
     ─→ Send sample to accountants (1 ngày)
     ─→ Round 1 review (5-7 ngày)
     ─→ Tech Lead consolidate feedback + fix template (3-5 ngày)
     ─→ Round 2 review if changes major (5 ngày)
     ─→ Sign-off
Phase 09 launch BLOCKED until sign-off (R11).
```

**Critical insight:** Outreach + NDA can start NOW (parallel with Phase 01-08 dev). Sample needs Phase 09 v1 → may need to send mock sample first (current `report_service.export_invoices_csv` output + manual TT200 expansion) just for "template structure" review even before code is ready.

---

## Recommended User Actions (next 3-7 days)

- [ ] Identify 5 candidate accountants from sources above
- [ ] Send initial outreach email/Zalo with Scope of Work
- [ ] Negotiate fee + NDA with top 3
- [ ] Sign engagement letter
- [ ] Prepare anonymized sample data (Tech Lead can help generate from seed.py)
- [ ] Schedule round 1 review window
- [ ] Document accountant contact info + commitment in section below

---

## Accountant Pilot Roster (USER FILLS IN)

| # | Name | Cert | Experience | Contact | Fee | Status | ETA |
|---|---|---|---|---|---|---|---|
| 1 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | not started | _TBD_ |
| 2 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | not started | _TBD_ |
| 3 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | not started | _TBD_ |

---

## Sign-off

- Tech Lead Claude — brief prepared 2026-06-28
- ⏳ **User action required** — outreach + signing
- Gate condition #1 (R11): **PENDING USER EXECUTION** — does not block Phase 01-08 dev, BLOCKS Phase 09 sign-off

**Gate condition #1 (R11): 🟡 BRIEF READY — awaiting user action (Phase 09 blocked until ≥1 accountant commitment)**

---

## Fallback if accountant cannot be found within 4 weeks

1. **Soft launch TT200 as "BETA" feature** — disclaimer banner: "Báo cáo này dựa trên TT200 best-effort. Vui lòng tự verify với kế toán riêng trước khi nộp thuế."
2. **Defer TT200 export to follow-up sprint** — keep CSV export (current AC-10 fallback) for MVP launch
3. **Partner with accounting platform** (MISA SME, Fast Online) — let them validate template + offer co-marketing

**Recommended decision point:** If after 2 weeks no accountant secured → Tech Lead + PM decide between fallback options.
