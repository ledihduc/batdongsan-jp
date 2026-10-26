---
title: "BA Requirements — Revenue Analytics Full Rebuild"
description: "Module thống kê doanh thu cho host quản lý nhà trọ + homestay tại Việt Nam"
status: draft
priority: P1
audience: Host VN tự quản 5-100 phòng (mix dài hạn + ngắn hạn)
created: 2026-06-28
---

# Phase 00 — BA Requirements: Revenue Analytics Full Rebuild

## Context Links

- Market research: `research/researcher-market-revenue-analytics.md` (Airbnb / Cloudbeds / Hostaway / Guesty benchmark)
- Codebase audit: `research/researcher-codebase-audit.md` (65% Keep / 30% Refactor / 5% Delete)
- Existing Phase 06 plan (replaced by this rebuild): `plans/260622-0700-host-property-management/phase-06-reports-zalo-notifications.md`
- Domain models reuse: `lib/data/models/invoice_model.dart`, `payment_model.dart`, `contract_model.dart`, `revenue_report_model.dart`

---

## 1. Problem Statement

Host VN hiện không biết **phòng nào ế, tháng nào sụt, công nợ ra sao, có nên tăng giá không**. MVP hiện tại chỉ có table doanh thu + CSV export — không đủ để host ra quyết định kinh doanh.

**Pain points cụ thể:**

1. Mix gross vs net không rõ → host tưởng lãi nhiều, thực tế đã trừ commission/refund.
2. Không thấy trend (chỉ thấy 1 kỳ tại 1 thời điểm) → không biết tháng này tốt/xấu so với tháng trước/năm trước.
3. Không drill-down được → muốn biết "phòng nào yếu" phải mở từng phòng kiểm tra.
4. Báo cáo thuế thủ công → phải gõ lại số liệu cho kế toán, dễ sai.
5. Không có "early warning" → công nợ kéo dài 60+ ngày mới phát hiện.

**Business goal:** Biến module Revenue Analytics thành lý do host **giữ chân** sản phẩm thay vì chỉ dùng vài tháng rồi bỏ. Differentiator vs Luxstay/Booking: **tax-ready cho kế toán VN (Thông tư 200)**.

---

## 2. Target User

| Profile | Quy mô | Use case chính | Tần suất xem report |
|---|---|---|---|
| **Host nhỏ** (P0) | 5-15 phòng nhà trọ | Theo dõi thu/chi tháng, công nợ tenant | 1-2 lần/tuần |
| **Host vừa** (P0) | 16-50 phòng mix nhà trọ + homestay | Phòng nào ế, tối ưu giá homestay | 3-5 lần/tuần |
| **Host lớn** (P1) | 51-100+ phòng | KPI dashboard tổng hợp, forecast | Hàng ngày |
| **Kế toán thuê ngoài** (P2) | N/A | Export báo cáo thuế hàng tháng/quý | 1 lần/tháng |

Tất cả đều **mobile-first** (>80% truy cập qua phone, theo profile app hiện tại).

---

## 3. User Stories (US-01 → US-15)

### Epic A — Dashboard tổng quan (P0)

- **US-01** — Là host, tôi muốn thấy **5 KPI card** (Gross Revenue, Net Revenue, Occupancy %, ADR, Booking Pace) ngay khi mở Analytics → ra quyết định nhanh không cần drill-down.
- **US-02** — Là host, mỗi KPI card hiển thị **delta vs kỳ trước** (↑/↓ + %) → biết đang tốt lên hay xấu đi.
- **US-03** — Là host, tôi muốn **swipe trái/phải** trên hero card để đổi kỳ (tháng/năm trước-sau) → navigation mượt trên mobile.

### Epic B — Trend & Visualization (P0)

- **US-04** — Là host, tôi muốn thấy **line chart 12 tháng** doanh thu net (kỳ hiện tại vs kỳ trước, dual-line) → nhận diện mùa cao/thấp.
- **US-05** — Là host, tôi muốn thấy **heatmap calendar** occupancy theo phòng × ngày trong tháng → thấy ngay phòng nào ế.
- **US-06** — Là host, tôi muốn thấy **stacked bar** revenue breakdown theo nguồn (rent dài hạn / homestay / service fee / utilities) → biết đâu là nguồn chính.

### Epic C — Drill-down & Filter (P0)

- **US-07** — Là host, tap KPI card → mở full-screen modal với chi tiết per-tòa nhà/phòng/contract → tìm nguyên nhân.
- **US-08** — Là host, tôi muốn filter theo **tòa nhà, loại phòng, nguồn khách, kỳ tự chọn** qua bottom sheet → focus 1 phần data.
- **US-09** — Là host, tap row trong heatmap → mở detail booking/contract của ngày đó → trace cụ thể.

### Epic D — Comparison & Period (P0)

- **US-10** — Là host, tôi muốn so MoM/YoY trong cùng view (side-by-side KPI card + dual-line chart) → đánh giá tăng trưởng.
- **US-11** — Là host mới (chưa có data kỳ trước), tôi muốn set 1 mục tiêu doanh thu tháng và thấy progress bar so với goal → vẫn có giá trị từ ngày đầu (xem AC-18, §6.2 Option A).
- **US-11b** — Là host vừa onboard (0 invoice, 0 reservation), tôi muốn thấy empty state có illustration + CTA "Tạo invoice đầu tiên" / "Thêm phòng" → không thấy "0 ₫" chart rỗng gây nản (xem AC-13).

### Epic E — Forecast (P1 — defer, NOT in MVP)

- **US-12** (P1 defer) — Là host, tôi muốn thấy **forecast occupancy 30 ngày tới** dựa booking pace hiện tại → chủ động khuyến mãi nếu thấp.
- **US-13** (P1 defer) — Là host, tôi muốn nhận **price suggestion** rule-based (nếu occupancy >80% suggest +5%; nếu <30% suggest -10%) → tối ưu giá đơn giản.

### Epic F — Export & Compliance (P0 MVP = Excel, P1 = PDF)

- **US-14** — Là host, tôi muốn export **Excel monthly ledger Thông tư 200** (Invoice#, Date, Tenant, Nights, ADR, Gross, Refund, Net) → gửi kế toán 1 file là xong.
- **US-15** — Là host (P1), tôi muốn export **PDF tax-ready report** kèm chart → in nộp cơ quan thuế / share Zalo.

---

## 4. Acceptance Criteria

### AC-01 — KPI Dashboard load < 1.5s
- GET `/api/host/analytics/summary?period=month&date=YYYY-MM` trả về 5 KPI + delta trong 1 request.
- Cache 5 phút client-side (`ReportProvider.isFresh()`) — tab switch không refetch.

### AC-02 — Delta computation đúng
- Delta = (current - previous) / previous × 100, làm tròn 1 chữ số thập phân.
- Nếu previous = 0 hoặc null → hiển thị "—" (không hiển thị 100% gây hiểu nhầm).
- Nếu host mới (chưa có data) → hiển thị empty state với CTA "Set goal".

### AC-03 — Currency format VND đúng
- Số tiền format theo locale `vi_VN`: `1.250.000 ₫` (không phải `1,250,000 VND`).
- KPI card hiển thị abbreviated: `1.25M ₫` cho > 1M, `250K ₫` cho > 1K.
- Tooltip/detail luôn hiển thị full số.

### AC-04 — Gross vs Net rõ ràng (critical anti-pattern fix)
- Mỗi metric có label rõ "Gross" / "Net" — không bao giờ ambiguous.
- Net = Gross − Refund − Commission − Tax (theo công thức cố định trong service layer).
- Backend trả về cả 2 number, frontend chỉ hiển thị theo toggle user chọn.

### AC-05 — Refund attribution đúng kỳ
- Refund tính theo `CreditNote.issued_date` (ngày refund thực tế), KHÔNG theo `invoice_issued_at`.
- Edge case 1: invoice tháng 5, refund tháng 7 → tháng 5 vẫn gross full, tháng 7 trừ refund (hiển thị badge "(includes N refunds from prior periods)").
- Edge case 2 (cross-year): invoice 12/2025, refund 02/2026 → YoY comparison 2026 vs 2025 phải tính đúng (báo cáo 2025 KHÔNG bị revise retroactive).
- Edge case 3 (refund > invoice gốc): hiếm nhưng xảy ra với deposit double-counted → backend reject với HTTP 422, log alert, không cho âm net <0 trong cùng 1 invoice. UI hiển thị error toast.
- Edge case 4 (invoice voided sau export): nếu invoice bị `status=void` sau khi đã xuất Excel TT200, BẢN export cũ không bị thay đổi (immutable). Bản export mới reflect void. AC-10 phải có cột "Trạng thái HĐ" (Active/Void/Replaced).

### AC-06 — Multi-month booking không double-count
- Booking từ 25/5 → 5/6 → revenue chia tỷ lệ theo số đêm trong từng tháng (6 đêm tháng 5 + 5 đêm tháng 6). Công thức: `prorate_amount = total / total_nights × nights_in_period`.
- Backend implement prorate logic; unit test bắt buộc cover: (a) qua tháng 28 ngày (tháng 2), (b) qua tháng 30/31 ngày, (c) **qua đêm giao thừa 31/12 → 01/01 (cross-year)** — tháng 12 năm cũ + tháng 1 năm mới phải tách riêng cho YoY báo cáo thuế, (d) booking 1 đêm trong cùng tháng (no prorate), (e) booking đúng đầu/cuối tháng.
- Contract dài hạn (nhà trọ) prorate theo tháng (không phải đêm) — `monthly_rent / days_in_month × days_active_in_period`.

### AC-07 — Source attribution (Custom per Q2)
- Host CRUD `revenue_sources` table: tạo/sửa/xoá/archive nguồn khách custom (name, color hex, is_archived).
- Mỗi `host_id` có sẵn 3 default source khi onboarding: "Trực tiếp", "Marketplace nội bộ", "Khác" — host có thể rename/delete.
- Reservation + Contract có `source_id: FK(revenue_sources.id)` nullable.
- Stacked bar chart group theo source (max 8 source hiển thị, còn lại gộp "Khác").
- Filter "by source" multi-select chip ở filter bottom sheet.
- Validation: không cho xoá source đang dùng (>=1 reservation/contract liên kết) → chỉ cho archive (`is_archived=true`, ẩn khỏi dropdown nhưng giữ trong báo cáo cũ).
- Edge case: host archive source `S1` rồi tạo source mới tên `S1` → cho phép (unique constraint chỉ áp dụng cho `is_archived=false`). Báo cáo cũ vẫn link sang source `S1` archived (giữ history).
- Hard delete chỉ cho phép khi source CHƯA bao giờ có reservation/contract (ví dụ tạo nhầm) — backend check count=0 mới cho DELETE, ngược lại 409 Conflict.

### AC-08 — Heatmap calendar UX
- Mặc định hiển thị tháng hiện tại, row = phòng, col = ngày.
- **Mobile rendering strategy với 50-100 phòng:** virtualize row (chỉ build cell trong viewport), sticky first col (tên phòng), pinch-to-zoom + horizontal pan; cell tối thiểu 24×24px (a11y tap target). Nếu >30 rows → render aggregate "Tòa A: 80% occupied" row, expand on tap.
- Color scale (color-blind safe — dùng pattern + màu): trắng (vacant) → xanh nhạt (booked) → xanh đậm (paid + checked-in) → đỏ + sọc chéo (overdue).
- Tap cell → bottom sheet với detail booking/contract.
- Performance benchmark (xem AC-15): 60fps scroll với 30 rooms; degrade gracefully (group view) với 50-100 rooms.

### AC-09 — Filter bottom sheet
- Tòa nhà (multi-select chip), loại phòng (single/multi-bed), nguồn khách (chip), kỳ (date range picker).
- "Áp dụng" trigger refetch; "Reset" về default.
- Filter persist qua session (không persist qua app restart — keep simple).

### AC-10 — Excel export Thông tư 200 FULL (per Q1)
- **Full 50+ cột chuẩn TT200/2014/TT-BTC** — không phải subset, host gửi thẳng kế toán.
- Cấu trúc workbook:
  - Sheet **"Sổ Nhật ký chung"** (S03a-DN): TT, Ngày tháng GS, Số CT, Ngày CT, Diễn giải, TK đối ứng, Số phát sinh Nợ, Số phát sinh Có…
  - Sheet **"Sổ Cái TK 511"** (Doanh thu bán hàng) + **TK 5113** (Doanh thu dịch vụ — thuê phòng)
  - Sheet **"Bảng kê hoá đơn"** (Số hoá đơn, ký hiệu, ngày, mã KH, tên KH, MST, mặt hàng, đơn vị, SL, đơn giá, thành tiền chưa thuế, thuế suất, thuế GTGT, tổng thanh toán)
  - Sheet **"Bảng kê thu/chi"**: Phiếu thu (TK 111/112) + Phiếu chi (TK 111/112) chi tiết
  - Sheet **"Bảng kê công nợ"** (TK 131): Khách hàng / Số dư đầu kỳ / Phát sinh trong kỳ / Số dư cuối kỳ
  - Sheet **"Bảng kê giảm trừ doanh thu"** (TK 521): refund từ CreditNote
- Format đúng: số tiền VND không dấu phẩy, ngày `dd/mm/yyyy`, MST format `xxxxxxxxxx-xxx`.
- Filename: `so-ke-toan-{host_slug}-{YYYY-MM}.xlsx`.
- Backend stream để xử lý dataset lớn (>10K invoice) — không load toàn bộ vào memory.
- **Trạng thái hoá đơn:** Bảng kê hoá đơn phải có cột "Trạng thái" (Active / Void / Adjusted) — không xoá row của hoá đơn voided, đánh dấu để kế toán reconcile.
- **Immutability:** Export có metadata `exported_at`, `export_hash` (sha256 của data). Re-export cùng kỳ phải tạo bản mới với version `v2`, `v3`... — không overwrite. Tên file: `so-ke-toan-{host_slug}-{YYYY-MM}-v{N}.xlsx`.
- **Mitigation R3:** Template phải reference công văn Bộ Tài chính `200/2014/TT-BTC`; pilot với 2-3 kế toán thực tế trước launch.
- **Compliance disclaimer:** BA CHƯA verify từng cell mapping với primary source TT200 — Tech Lead phải có tax accountant review template trước Phase 9 dev, không assume BA spec đầy đủ-chính xác về kế toán.

### AC-11 — Forecast occupancy (P1 — defer per Q3)
- Tính theo booking pace 4 tuần gần nhất (avg bookings/day × 30), project tới 30 ngày.
- Hiển thị range = `[avg - 1σ, avg + 1σ]` (1 standard deviation), không phải single number.
- Confidence indicator: HIGH (>8 weeks data) / MEDIUM (4-8w) / LOW (<4w, không show forecast).
- Chú thích: "Dự báo dựa trên xu hướng đặt 4 tuần qua. Không đảm bảo chính xác."
- **Scope note:** Forecast deferred to P1 per Q3 user decision — US-12/US-13 không phải MVP scope, AC-11/AC-12 giữ làm reference cho Phase 12+.

### AC-12 — Price suggestion (P1)
- Rule-based: occupancy [0-30%] → suggest -10%; [30-60%] → giữ; [60-80%] → +5%; [80-100%] → +10%.
- Hiển thị dưới dạng banner trong room detail, KHÔNG auto-apply.
- A/B test track: host có tap "Apply suggestion" không.

### AC-13 — Empty / Error / Loading states
- Empty (host chưa có invoice): hero illustration + CTA "Tạo invoice đầu tiên".
- Error (API fail): icon + message + nút "Thử lại".
- Loading (initial fetch): skeleton card (không spinner full screen).
- Partial error (1 metric fail, 4 còn lại OK): hiển thị 4, metric fail có icon warning + retry inline.

### AC-14 — Deep link / URL share
- Mọi view có URL riêng: `/host/analytics`, `/host/analytics/revenue/:period/:date`, `/host/analytics/occupancy/:building_id/:month`.
- Browser back/forward hoạt động đúng (đã có go_router base từ migration trước).
- Chunk-split: analytics module load lazy (deferred import) — không bloat main bundle.

### AC-15 — Performance benchmark
- KPI summary fetch < 800ms p95 server response (measured trên prod-like với 1000-invoice/host dataset), < 1.5s render trên **Android Samsung A14 (4GB RAM, Android 13)** — baseline device for host VN.
- Chart render < 16ms/frame (60fps scroll heatmap với 30 rooms × 31 days); 30fps acceptable với 50-100 rooms.
- Excel export 12 tháng dataset < 3s server-side generation; download stream không block UI (progress indicator).
- iOS baseline: iPhone SE 2020 (3GB RAM) — same thresholds.

### AC-16 — Authorization & data isolation
- Mọi endpoint `/api/host/analytics/*` yêu cầu `host_id` từ JWT — không nhận từ query/body (chống IDOR).
- Backend filter mọi query bằng `WHERE host_id = current_user.host_id`, kể cả join qua reservation/contract/invoice.
- Source CRUD: `revenue_sources.host_id` enforce ownership — host A không thấy/sửa source của host B.
- Test case: host A tạo source, host B query không thấy; host A export TT200 không có data của host B.

### AC-17 — Concurrent edit & data race
- Source archive trong khi 1 reservation đang dùng → reservation giữ `source_id` cũ, source ẩn khỏi dropdown, vẫn group đúng trong báo cáo.
- Invoice voided trong khi report đang render → next refetch reflect; cached view (ReportProvider.isFresh 5min) có thể stale → hiển thị badge "Dữ liệu có thể cũ đến 5 phút" trên hero card.
- Export Excel đang stream khi host xoá invoice → snapshot tại t=start_export, không bị affect.

### AC-18 — Goal setting (US-11) MVP behavior
- Per §6.2 BA recommendation Option A: `HostProfile.monthly_revenue_goal: float?` — single value áp dụng all months.
- UI: trong KPI card Gross Revenue, hiển thị progress bar `current / goal` nếu goal được set; CTA "Set goal" nếu null.
- Validate: goal > 0, < 10 tỷ VND (sanity); update qua settings screen, không có UI per-month (defer Option B).
- Edge case: host set goal mid-month → progress bar tính từ đầu tháng hiện tại (không retroactive).

---

## 5. Out of Scope (Explicit)

| Item | Lý do defer | Phase tương lai |
|---|---|---|
| **ML demand forecast** (ARIMA, neural net) | Cần data warehouse + ML pipeline, ROI thấp cho host nhỏ | V2 nếu host >100 phòng request |
| **Dynamic pricing AI** (competitor scraping) | Legal risk (Airbnb ToS), cần infra crawler | V2 sau khi legal review |
| **Multi-currency** (KHR/THB) | App chỉ VN market hiện tại | V2 nếu expand Đông Nam Á |
| **Email digest scheduler** | Yêu cầu cron worker, defer per existing BA D4 "no cron" | V2 sau khi có notification backbone |
| **PDF export** (P1, defer khỏi MVP) | Excel đáp ứng 90% use case kế toán | MVP+1 sprint nếu user request |
| **Cohort LTV / retention** | Metric cho marketplace ops, không cho host owner | Backend ops dashboard riêng |
| **Push notification revenue alert** | Cần FCM topic management | Defer cùng FCM phase |
| **Dark mode** | Toàn app chưa support, scope riêng | Toàn app theme refactor |
| **Khai báo tạm trú integration** | Phase 05 đã handle riêng | N/A |
| **Booking.com / Airbnb sync** | Cần API partnership | V3 enterprise tier |
| **Invoice editing / voiding flow** (UI) | Đã có ở Invoice module, không thuộc Analytics | Existing invoice screen |
| **Partial payment reconciliation UI** | Analytics chỉ READ payment status, không thay đổi | Existing payment screen |
| **Tax accountant pilot user research** | BA hand-off cho UR team, không trong rebuild scope | Parallel UR track |

---

## 6. User Decisions (Resolved 2026-06-28)

| # | Question | Decision |
|---|---|---|
| **Q1** | Excel TT200 scope | **Full 50+ cột** (đầy đủ bookkeeping theo TT200) — host gửi thẳng kế toán không cần nhập tay |
| **Q2** | Source enum | **Cho host tự thêm custom** — cần thiết kế bảng `revenue_sources` riêng + autocomplete dropdown, không hardcode enum |
| **Q3** | Forecast P0 / P1 | **P1 defer** (default A1) — focus MVP, forecast sau khi có data baseline |
| **Q4** | Heatmap scope | **Cả nhà trọ + homestay** — nhà trọ = full-bar contract dài hạn, homestay = per-day cell |
| **Q5** | Commission tracking | **Backend CHƯA có** — xem §6.1 "Backend Investigation Findings" bên dưới. Cần migration + schema mới |
| **Q6** | Timezone | **Asia/Ho_Chi_Minh** — server lưu UTC nhưng query/aggregate convert TZ HCM trước khi group by day/month |
| **Q7** | Goal setting (US-11) | **Tech Lead đề xuất** ở Phase 3 — BA gợi ý options ở §6.2 |
| **Q8** | Drill-down depth | **Sâu Phòng → Contract → Tenant → Invoice** — full path 4 cấp |
| **Q9** | Chart library | **`fl_chart`** (MIT, mature, mobile-optimized) |
| **Q10** | Backend rebuild scope | **Rebuild toàn bộ `report_service.py`** — không patch, viết lại sạch từ đầu để fix gross/net + multi-month prorate + timezone từ gốc |

### 6.1 Backend Investigation Findings (Commission & Source)

Đã grep `ancu365-backend/app/models.py` (Invoice, Payment, Reservation, Contract):

| Field | Invoice | Payment | Reservation (homestay) | Contract (nhà trọ) |
|---|---|---|---|---|
| **Commission** | ❌ Không có | ❌ Không có | ❌ Không có | ❌ Không có |
| **Source / channel** | ❌ Không có | ❌ Không có | ✅ Có (`source: marketplace\|direct\|manual` — hardcode 3 giá trị, line 713-714) | ❌ Không có |
| **Refund** | Có `CreditNote` table riêng (line 500-517) — track `amount`, `reason`, `issued_date` ✅ | — | Có `refund_amount` field (line 711) ✅ | — |
| **Gross/Net split** | ❌ Chỉ có `total_amount`, `paid_amount` — không tách net | — | ❌ Chỉ có `total_amount`, `deposit_paid` | — |

**Kết luận cho Tech Lead:**

1. **Migration cần thiết (DB schema changes):**
   - Thêm `commission_rate: Float, commission_amount: Float` vào `invoices` và `reservations` (nullable, default 0 cho legacy data)
   - Tạo bảng mới `revenue_sources` (id, host_id, name, color, is_archived) — cho phép host CRUD custom source
   - Thay `Reservation.source` từ String enum → ForeignKey tới `revenue_sources.id` (nullable; backfill 3 giá trị hiện tại thành 3 row mặc định per host)
   - Thêm `source_id: int?` vào `Contract` (nhà trọ contract cũng có source)
   - Thêm `monthly_revenue_goal: float?` vào bảng host profile (xem §6.2)
2. **Service layer:** rebuild `report_service.py` từ đầu — implement gross/net split, multi-month prorate, refund attribution theo `CreditNote.issued_date`, timezone-aware aggregation.
3. **Legacy data:** Tất cả invoice/reservation cũ default `commission_amount=0` → net = gross (backward compatible cho host hiện tại).

### 6.2 Goal Setting Storage — BA Recommendations (Tech Lead decide)

3 options để Tech Lead chọn ở Phase 3:

| Option | Pros | Cons |
|---|---|---|
| **A** — Single field `HostProfile.monthly_revenue_goal: float?` | Đơn giản nhất, 1 migration | Không hỗ trợ goal khác nhau theo tháng/mùa |
| **B** — Bảng `host_revenue_goals` (host_id, period_type, period_value, target_amount) | Linh hoạt: goal khác nhau per tháng/quý/năm | Phức tạp hơn, cần CRUD UI |
| **C** — `UserPreference` JSON blob | Không cần migration | Khó query, không indexed, anti-pattern |

**BA recommendation:** **Option A** cho MVP (KISS), upgrade Option B nếu host request "goal theo mùa".

---

## 8. Impact / Risk

### Files / Modules ảnh hưởng

**KEEP (no change):**
- `lib/data/models/invoice_model.dart`, `payment_model.dart`, `contract_model.dart` — schema đúng (chỉ thêm field commission/source mapping)
- `lib/data/repositories/api_invoice_repository.dart` — 7 endpoints clean
- `lib/core/router/app_router.dart` — chỉ thêm route mới
- Backend: `app/models.py` Invoice/Payment/CreditNote core structure — chỉ thêm field commission

**REFACTOR (Flutter):**
- `lib/providers/report_provider.dart` — thêm cache `isFresh()`, method `fetchAnalyticsSummary()` + custom source CRUD
- `lib/data/repositories/api_report_repository.dart` — endpoint cũ replace bởi v2 (rebuild backend)
- `lib/data/models/revenue_report_model.dart` — thêm field `net`, `gross`, `delta_pct`, `source_breakdown[]`, `commission_total`
- `lib/features/host/reports/screens/revenue_report_screen.dart` — UI rebuild hoàn toàn (giữ provider logic mapping)

**DELETE:**
- `lib/features/host/reports/widgets/revenue_breakdown_table.dart` — thay bằng pie chart + drill-down
- Backend: **`app/services/report_service.py` xoá toàn bộ → rewrite as `app/services/analytics_service.py`** (per Q10 user decision)

**NEW (Flutter ~20-25 file):**
- `lib/features/host/analytics/screens/analytics_home_screen.dart` — hero + KPI grid
- `lib/features/host/analytics/screens/revenue_detail_screen.dart` — drill-down metric
- `lib/features/host/analytics/screens/occupancy_heatmap_screen.dart`
- `lib/features/host/analytics/screens/source_management_screen.dart` — **NEW per Q2** — CRUD custom revenue source
- `lib/features/host/analytics/screens/drill_room_contract_tenant_screen.dart` — **NEW per Q8** — full 4-level drill-down navigation
- `lib/features/host/analytics/widgets/kpi_card.dart`, `delta_chip.dart`, `period_swiper.dart`, `filter_bottom_sheet.dart`, `source_picker.dart`
- `lib/features/host/analytics/services/currency_formatter.dart`, `period_helper.dart`, `tz_helper.dart` (Asia/Ho_Chi_Minh per Q6)

**NEW (Backend ~10 file):**
- `app/services/analytics_service.py` — **rebuild from scratch per Q10** (gross/net, prorate, refund attribution, TZ-aware)
- `app/services/excel_exporter_tt200.py` — **full 50+ cột TT200 per Q1** (chuẩn theo template Bộ Tài chính)
- `app/services/source_service.py` — CRUD custom revenue source per Q2
- `app/routers/host_analytics.py` — 5+ endpoints mới (summary, trend, heatmap, source breakdown, excel-tt200)
- `app/routers/host_sources.py` — CRUD endpoints cho revenue_sources
- `app/schemas/analytics.py` — Pydantic v2 schemas
- Alembic migration: thêm `commission_rate`, `commission_amount` cho `invoices` + `reservations`; tạo `revenue_sources` table; thêm `source_id` FK cho `reservations` + `contracts`; thêm `monthly_revenue_goal` cho host profile (Option A per §6.2)

**Estimated LOC:** ~4000-5000 new Dart + ~1500-2000 new Python (tăng do rebuild backend + full TT200 + custom source).

### Risk

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **R1** — Gross/net mix bug → host kiện | Medium | High (reputation) | Backend schema enforce 2 cột riêng + unit test rigorous |
| **R2** — Multi-month booking prorate sai | Medium | Medium | Test fixture cover 5+ edge case (giao thừa, tháng 28 ngày…) |
| **R3** — Excel TT200 không đúng format → kế toán reject | Low | High | Lấy template từ Bộ Tài chính + review với 2-3 kế toán pilot |
| **R4** — Heatmap render lag với 100+ phòng × 31 ngày | Medium | Medium | Virtualize list (lazy build cell), benchmark trên thiết bị low-end |
| **R5** — Scope creep (forecast/ML/dynamic pricing) | High | High | BA leader gate cứng — out-of-scope list ở §5 |
| **R6** — Chart library breaking change | Low | Medium | `fl_chart` lock version, có fallback table view |
| **R7** — Backend aggregation chậm với host >50 phòng | Medium | Medium | Indexed query + materialized view (PostgreSQL) hoặc Redis cache |
| **R8** — Mobile data quota concern (host vùng sâu) | Low | Low | Cache aggressively, không refetch khi quay lại tab |
| **R9** — Migration breaks legacy `report_service.py` consumers (admin reports, Zalo digest hook) | Medium | High | Grep hết caller trước migration; viết shim layer hoặc dual-write; tests integration cho admin module |
| **R10** — Reservation.source enum → FK migration data loss (3 giá trị string cũ map sang 3 row mới) | Medium | High | Migration script với dry-run mode + manual review per host; rollback plan; backfill chạy in batch với progress log |
| **R11** — TT200 spec inaccurate (BA không phải kế toán) | High | High | Tax accountant review BẮT BUỘC trước Phase 9 dev start; treat AC-10 §10.x sub-bullets as draft until accountant sign-off |
| **R12** — Mobile drill-down 4 cấp deep navigation lost user | Medium | Medium | Breadcrumb sticky top, "back to summary" shortcut, max depth tested với 3 host pilot trước launch |

---

## 9. Success Metrics (post-launch)

- **M1** — DAU host xem Analytics ≥ 60% (vs <20% hiện tại với MVP table view)
- **M2** — Excel export tải về ≥ 30% host hoạt động hàng tháng (proxy for "tax compliance" value)
- **M3** — Median time to insight: < 30s (từ mở app đến thấy số liệu cần)
- **M4** — Churn rate giảm 15% sau 3 tháng launch (analytics là retention driver)
- **M5** — Crash-free rate ≥ 99.5% trong analytics module
- **M6** — Tap-through rate KPI card → drill-down ≥ 25% (engagement depth)

---

## 10. Timeline ước tính (Tech Lead refine ở Phase 3)

Adjusted theo user decisions (rebuild backend Q10 + full TT200 Q1 + custom source Q2 + drill 4 cấp Q8):

| Phase | Effort | Output |
|---|---|---|
| Phase 1: Backend migration + schema (commission, revenue_sources, source_id FK, monthly_goal) | 2-3d | Alembic migration + backfill 3 default source per host |
| Phase 2: Backend rebuild `analytics_service.py` from scratch | 7-9d | Gross/net split, multi-month prorate, refund attribution, TZ HCM, all aggregation queries |
| Phase 3: Backend endpoints + source CRUD + auth gate | 3-4d | `host_analytics.py` (5 endpoints) + `host_sources.py` (CRUD) + tests |
| Phase 4: Data layer Flutter (models, repos, provider cache) | 3-4d | Updated models, api_report_repo v2, ReportProvider analytics methods, helpers (currency, period, tz) |
| Phase 5: Analytics home + 5 KPI cards + period swiper | 4-5d | Hero card, swipe gesture, KPI grid + delta chip |
| Phase 6: Trend chart + heatmap + source breakdown | 5-7d | 3 chart screens với `fl_chart` (dual-line, heatmap calendar, stacked bar) |
| Phase 7: Drill-down 4 cấp (Phòng→Contract→Tenant→Invoice) + filter bottom sheet | 5-6d | Full navigation flow + multi-source filter + persistence |
| Phase 8: Source management CRUD screen | 2-3d | Source list + add/edit/archive UI + validation |
| Phase 9: Excel export Thông tư 200 full 50+ cột | 5-7d | 6 sheets exporter + template review với 2-3 kế toán |
| Phase 10: Empty/error/loading states + i18n + polish | 2-3d | Skeleton, illustration, retry UX, VND format |
| Phase 11: E2E test + performance benchmark | 3-4d | 80%+ coverage, perf report mobile mid-range |
| **TOTAL** | **41-55d (~8-11 tuần)** | + 15% buffer = **47-63d (~9-13 tuần)** |

Forecast (P1, Q3 defer) thêm 5-7d nếu user re-prioritize sau MVP.

**Note effort tăng so với draft ban đầu (30-40d → 41-55d):** do (a) rebuild backend toàn bộ thay vì extend (+5-7d), (b) full TT200 50+ cột thay vì subset (+2-3d), (c) custom source CRUD + migration (+2-3d), (d) drill 4 cấp thay vì 2 (+1-2d).

---

## 11. BA Leader Review Notes (Phase 2)

**Reviewer:** BA Leader (senior brainstormer agent)
**Date:** 2026-06-28
**Verdict:** **READY** with conditions (see "Critical issues" — must be acknowledged, but không block Tech Lead start)

### 11.1 Critical Issues (must be addressed before / during Phase 3)

1. **TT200 spec correctness — BA không phải kế toán chuyên môn.** AC-10 liệt kê 6 sheet + 50+ cột nhưng KHÔNG có primary-source citation per cell. Risk R11 (mới thêm) flag mandate: Tech Lead phải book tax accountant review trước Phase 9 dev start. Nếu không, scope AC-10 chỉ là "best-effort draft", không phải "compliance-ready".
2. **Mobile UX feasibility cho heatmap 50-100 phòng.** AC-08 đã được sharpened (virtualize, group view fallback) nhưng vẫn cần Tech Lead prototype trước Phase 6. Có thể phải downscope sang "max 30 rows + group rest" cho launch.
3. **Drill 4 cấp trên mobile.** Q8 chốt full depth, nhưng UX phone risk lạc navigation. R12 (mới thêm) đề xuất breadcrumb + back-to-summary shortcut. Tech Lead cần wireframe Phase 7 trước implement.
4. **Migration data-loss risk.** R10 (mới thêm) — Reservation.source enum → FK migration cần script dry-run + per-host manual review. KHÔNG được merge migration nếu chưa test trên prod-clone DB.
5. **Legacy consumer of report_service.py.** R9 (mới thêm) — `report_service.py` xoá toàn bộ (Q10), nhưng nếu có admin reports / Zalo digest hook / cron khác đang call → break silent. Tech Lead phải grep tất caller trước.
6. **TT200 immutability requirement.** AC-10 sharpened: export phải có version + hash, không overwrite — đây là legal requirement (kế toán cần audit trail), không phải nice-to-have.

### 11.2 Suggestions (non-blocking)

1. **§9 Success Metrics** — M3 "median time to insight <30s" thiếu instrumentation plan. Tech Lead nên thêm analytics tracking events (`analytics_opened`, `kpi_drilled`, `export_clicked`) ngay Phase 4 để measure được.
2. **§2 Target User** — "Kế toán thuê ngoài (P2)" liệt kê nhưng KHÔNG có US riêng. Nếu kế toán là user thật (mở Excel, complain format) → cần ít nhất 1 US (US-14 cover gián tiếp, OK cho MVP).
3. **AC-13 Empty/Error states** — đủ cho metric fail, nhưng thiếu "offline mode" — host vùng sâu mất net giữa session. Đề xuất: cached last-fetch hiển thị badge "Offline — dữ liệu lúc HH:mm".
4. **§10 Timeline** — 41-55d giả định 1 dev fullstack. Nếu split 1 BE + 1 FE parallel → có thể compress xuống 25-35d (Phase 1-3 BE parallel với Phase 4-5 FE data layer). Tech Lead clarify resource ở Phase 3.
5. **AC-14 Deep link URL share** — chia sẻ URL public có thể leak data (URL có `:building_id`). Cần auth gate enforce; đã cover gián tiếp ở AC-16 mới thêm.
6. **i18n consideration** — toàn doc Tiếng Việt mix English label ("Gross", "Net"). Nếu app có English mode → cần translation key. Hiện tại đang VN-only nên OK defer.

### 11.3 Open Risks for User Awareness

- **R11 (tax accountant cost)** — Pilot 2-3 kế toán review TT200 template = budget + thời gian Tech Lead chưa estimate. User nên prepare 1-2 tuần buffer cho việc này.
- **Effort 9-13 tuần là cho 1 fullstack dev.** Nếu user muốn launch sớm, cần xác nhận staffing.
- **Forecast P1 defer** — risk nếu host expect AI feature (Q3 đã chốt defer, nhưng cần communication plan).
- **Data privacy** — Excel TT200 export chứa MST khách, tên khách, doanh thu — nhạy cảm. Tech Lead phải thêm: download require re-auth (password / biometric), audit log mỗi lần export.

### 11.4 Edge Cases Added (đã sharpen vào doc)

- AC-05: cross-year refund, refund > invoice, voided invoice immutability
- AC-06: cross-year boundary (31/12 → 01/01), contract dài hạn prorate riêng
- AC-07: source name reuse sau archive, hard-delete chỉ khi count=0
- AC-08: virtualize + group view + color-blind safe pattern
- AC-10: invoice status column + immutable versioned export
- AC-16 (mới): authorization/IDOR/data isolation
- AC-17 (mới): concurrent edit & data race
- AC-18 (mới): goal setting MVP behavior (resolve ambiguity ở US-11)
- US-11b (mới): host onboard empty state
- R9-R12 (mới): legacy consumer, migration data loss, TT200 spec, drill-down UX

### 11.5 Approved Scope Summary

**Approved for Tech Lead Phase 3 planning:** Rebuild revenue analytics module với 16 user stories (US-01..US-15 + US-11b), 18 acceptance criteria (AC-01..AC-18), 12 risks (R1..R12), MVP scope = Epic A/B/C/D/F (Excel TT200 full 50+ cột, custom source CRUD, drill 4 cấp, heatmap, dual-line chart), forecast Epic E defer P1. Backend rebuild from scratch (analytics_service.py), schema migration thêm commission + revenue_sources + source_id FK + monthly_revenue_goal. Timeline 9-13 tuần cho 1 dev fullstack (có thể compress nếu split BE/FE parallel). 6 critical issues phải acknowledge trước Phase 3 — đặc biệt TT200 spec accountant review (R11) và migration safety (R9, R10).

### 11.6 Verdict

**READY** — User có thể approve cho Tech Lead Phase 3, với điều kiện acknowledge 6 critical issues ở §11.1. Tech Lead phải bắt đầu Phase 3 với:
- Grep audit `report_service.py` callers (R9)
- Tax accountant booking cho AC-10 review (R11)
- Heatmap + drill-down wireframe trước implement (R12 + heatmap risk)

---

**Status:** ✅ Q1-Q10 resolved by user 2026-06-28 — ✅ Phase 2 BA Leader review complete — **READY for Phase 3 (Tech Lead Planning)** with 6 acknowledged conditions
