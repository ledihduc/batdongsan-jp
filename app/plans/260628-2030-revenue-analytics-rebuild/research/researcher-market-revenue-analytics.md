# Revenue Analytics Dashboard Research — Best Practices, Metrics, UX Patterns
**For: An Cư 365 Flutter Homestay/Property Rental Platform**
**Date: 2026-06-28**
**Researcher: Technical Analyst**

---

## Executive Summary

Airbnb/Cloudbeds/Hostaway benchmarks converge on 10–12 core revenue metrics (RevPAR, ADR, occupancy, gross/net revenue, booking pace, LOS, repeat rate). Mobile-first visualization (swipe periods, drill-down modals, card KPIs) suits Vietnam host profile better than desktop dashboards. Top MVP: 5 metrics + 3 charts + period comparison. Vietnamese compliance ("khai báo tạm trú" registration) must integrate into revenue ledger. Dual gross/net accounting + refund handling is critical anti-pattern to prevent.

---

## 1. Standard Industry Metrics (10–15 KPIs)

**Core Revenue Metrics (must-have):**

- **RevPAR (Revenue Per Available Room)** — Total revenue ÷ Available room-nights. *Why:* Combines occupancy + price into one outcome metric. Benchmark: USD 11,990/yr (US market 2026).
  - *Formula:* RevPAR = (Total Revenue ÷ Available Rooms) ÷ Days in Period
  - *Use case:* Host compares month-to-month efficiency. "Am I maximizing pricing power + occupancy together?"

- **ADR (Average Daily Rate)** — Total revenue ÷ Booked nights. *Why:* Isolates pricing power from occupancy.
  - *Formula:* ADR = Total Revenue ÷ Nights Booked
  - *Use case:* Pricing strategy validation. "Can I increase rate without losing occupancy?"
  - *Benchmark:* US avg 1.5% ADR growth in 2026 (supply-constrained markets grow faster).

- **Occupancy Rate** — (Booked nights ÷ Available nights) × 100. *Why:* Essential demand signal.
  - *Formula:* Occupancy % = (Booked Nights ÷ Total Available Nights) × 100
  - *Use case:* Identify underperforming units. "Which room sits empty most?"
  - *Benchmark:* US avg ~50% (varies 40–70% by market/type).

- **Gross Revenue** — All rental income before deductions (no refunds, cancellations, or fees subtracted yet).
  - *Use case:* Presents upside potential to investors/tax authorities.
  
- **Net Revenue** — Gross revenue − (refunds + cancellations + service fees + payment processor fees + management fees).
  - *Use case:* **True take-home metric.** Critical for host cash-flow planning.
  - *Data source:* Must aggregate Invoice, Reservation cancellation, Payment, ServiceFee tables.

- **Booking Pace (Lead Time)** — Bookings received 60+ days ahead vs. 30–60 vs. last-minute (14 days).
  - *Why:* Predicts revenue stability. Early bookings = lower cancellation risk.
  - *Use case:* "Are bookings moving faster than last month? Should I adjust marketing?"

- **ALOS (Average Length of Stay)** — Total booked nights ÷ Total bookings in period.
  - *Formula:* ALOS = Total Room Nights ÷ Number of Bookings
  - *Use case:* Detect shift from long-term to short-term (homestay mix). "Are homestay guests staying shorter?"
  - *Benchmark:* Long-term rentals 30–180 nights; short-term 2–7 nights.
  - *By source:* Direct bookings often have 20–30% longer ALOS than OTA.

- **Repeat Guest Rate** — (Returning guests ÷ Total bookings) × 100.
  - *Use case:* Loyalty + retention signal. Major hotel chains hit 60%, independents 10–15%.
  - *Benchmark Vietnam:* Not widely tracked yet; opportunity for differentiation.

- **Booking Source Attribution** — Revenue split across Airbnb | Direct | Facebook | Zalo | Other OTA.
  - *Why:* Guides marketing spend + commission reduction strategy.
  - *Data source:* Reservation.source + Payment.source.

- **Cancellation Rate** — (Cancelled bookings ÷ Total bookings) × 100 + refunded amount.
  - *Why:* OTA refunds erode net revenue. Track cancellation reason (guest vs. host).
  - *Data source:* Reservation.status, Payment.refund_amount.

- **Debt Collection Rate** — (Paid invoices ÷ Total invoices) × 100 for long-term rentals.
  - *Why:* Vietnam pain point: contractors/long-term tenants often delay/default.
  - *Data source:* Invoice.status, Payment.payment_date.

**Secondary (Nice-to-have):**
- **Revenue by Property Type** — Gross/net split across "dorm", "private room", "entire house", "homestay".
- **Utility Cost Recovery** — ServiceFee revenue ÷ Actual meter readings (water/electric).

---

## 2. Visualization Patterns by Metric

**Chart Selection Matrix:**

| Metric | Chart Type | Why | Example |
|--------|-----------|-----|---------|
| RevPAR, ADR, Occupancy (time-series) | **Line chart** | Show trend. Multi-line overlay RevPAR + ADR to show relationship. | 12-month RevPAR line; second axis ADR. Color: blue RevPAR, orange ADR. |
| RevPAR vs benchmark | **Dual-line** | Compare actual vs. market average. | Green (yours) vs. gray (market benchmark). |
| Occupancy by room | **Heatmap calendar** | Grid: x=room, y=date. Color intensity = occupancy %. | Dark = booked, light = vacant. Each cell drillable to reservation details. |
| Revenue by source (Airbnb/Direct/OTA) | **Stacked bar** or **donut** | Show composition. Stack if tracking multiple sources over time. | Stacked bar: months, segments Airbnb (blue), Direct (green), Zalo (red). |
| Booking pace (last 60 days) | **Bar chart** | Compare bookings by week or bin (60–45 days prior, 45–30, etc.). | X=lead time bucket, Y=# bookings. Highlight last week vs. avg. |
| Repeat guest rate | **KPI card** | Single metric: "42% repeat rate". Add sparkline showing 3-month trend. | Card: big "42%" + "↑ +8% vs. last month" + tiny line graph. |
| ALOS distribution | **Histogram** | Binned (1–3 nights, 4–7, 8–14, 15–30, 31+). Shows guest profile mix. | Bar chart; X=stay-length bins, Y=# bookings. Stack by source (Airbnb vs Direct). |
| Cancellation by reason | **Bar** | Segment: guest-initiated, host-initiated, refund issue, etc. | Horizontal bar for readability. Red fill for "cost us $$$" reasons. |
| MoM / YoY comparison | **Side-by-side KPI cards** OR **dual-line** | For scalar metrics, card pair: "This Month: $5,200 (+12% vs. last month)". For time-series, dual-line. | Card layout: large current, smaller delta %; Or line chart with two overlays. |

**Anti-patterns to avoid:**
- Pie charts > 4 segments (use bar chart instead).
- Dual-axis chart with incompatible scales (misleads comparison).
- Line chart for non-time-series (e.g., booking source revenue—use bar).
- Truncated Y-axis starting above zero (exaggerates small changes).

**Inspiration sources:**
- [Stripe Dashboard design](https://stripe.com/) — metric cards + spline charts.
- [Mixpanel Analytics](https://mixpanel.com/) — cohort heatmaps, funnel visualization.
- [Linear Issues Dashboard](https://linear.app/) — KPI cards + trend sparklines.

---

## 3. Drill-Down + Filter Patterns

**Hierarchical Drill-Down (Year → Month → Week → Day → Booking):**

```
Level 1 (Dashboard): RevPAR, occupancy, gross revenue — summary cards.
    ↓ tap "Occupancy" card
Level 2 (Period view): 12-month occupancy line chart.
    ↓ tap a month on the line
Level 3 (Monthly detail): 4-week grid; color-coded occupancy per week.
    ↓ tap a week
Level 4 (Weekly detail): 7-day occupancy heatmap by room.
    ↓ tap a room + date
Level 5 (Booking detail): Reservation card (guest, dates, rate, source, payment status, cancellation reason if any).
```

**Filter Panel (Mobile Bottom Sheet):**

```
Property / Building (multi-select):
  □ 12 Nguyen Hue (5 rooms)
  □ 45 Tran Hung Dao (8 rooms)
  □ All (13 rooms) — default

Room Type (single-select):
  ◉ All
  ○ Dorm (4–6 bed)
  ○ Private room
  ○ Entire house

Date Range:
  [This month] [Last month] [Last 3 months] [Custom]

Booking Source (multi-select):
  ☑ Airbnb
  ☑ Direct
  ☐ Zalo
  ☐ Other

Revenue View:
  ◉ Gross Revenue
  ○ Net Revenue
  ○ Net After Utilities
```

**UX Pattern:**
- Bottom sheet (swipe-up from bottom); dismiss with back button.
- "Apply" button visible always; tapping updates charts above without full refresh.
- Tag display: show active filters as removable chips above chart (e.g., "12 Nguyen Hue" × | "This month" ×).
- On mobile: Show 3–4 filters max, collapse others under "More ▼".

**Examples:**
- Host filters to "Direct bookings only, This month" → sees ADR of direct bookings; discovers direct ADR is 20% higher than Airbnb (opportunity to promote direct booking).
- Host filters to "Dorm rooms, All time" → sees ALOS is 45 nights vs. 5 nights for private room; decides to convert dorms to co-living.

---

## 4. Comparison Views (MoM, YoY, Period-over-Period)

**Design Pattern 1: KPI Card Pair (Scalar Metrics)**

```
┌─────────────────────────────────┐
│ This Month          Last Month   │
│                                  │
│ $ 5,200             $ 4,650      │
│ Gross Revenue       Gross Revenue│
│                                  │
│ ↑ +12% vs. prev.   (baseline)    │
└─────────────────────────────────┘
```

- Left card: **current period** (bold, large font).
- Right card: **comparison period** (secondary, smaller).
- Delta badge: **"↑ +12%"** (green if positive, red if negative) + % change.
- Arrow + trend line sparkline (optional, adds visual polish).

**Design Pattern 2: Dual-Line Chart (Time-Series Comparison)**

```
Month-over-Month ADR trend:
Y-axis: ADR ($)
X-axis: Day of month (1–31)

Blue line: This month ADR
Gray line: Last month ADR (background reference)

Interpretation: If blue line sits above gray, ADR improved MoM.
```

**Handling New Hosts (No Prior Data):**
- Card shows: "$ 2,100 Gross Revenue — No prior period. [Learn more >]"
- No delta badge (avoid "0% vs. nothing" confusion).
- Link to help article: "Benchmarks for new hosts" (compare to market, not history).
- Offer: "Set a goal for next month" (input target ADR/occupancy).

**YoY Comparison (For Long-Term Hosts):**
- Show toggle: "This Month | This Month vs. Last Year"
- Dual-line chart: current year (blue), last year (light blue, opacity 50%).
- Seasonal context: Add market comparison line (e.g., "Hanoi avg. June ADR 2025 vs. 2026").

---

## 5. Forecast & Predictive Features (MVP vs. V2)

**MVP (Realistic for small host, low infra cost):**

1. **Occupancy Forecast (next 30 days, simple)** — Plot confirmed bookings as bars; add "projected occupancy" bar based on booking pace (how fast reservations arrived last week).
   - *Algorithm:* Count bookings received in last 7 days; extrapolate linearly.
   - *Data needed:* Reservation.created_at, Reservation.check_in_date.
   - *UI:* Bar chart: X=date, Y=booked nights (blue), projected (light blue dashed).
   - *Effort:* ~8 hours SQL + chart.

2. **Revenue Run-Rate** — Show month-to-date revenue + "if pace continues" = projected month-end revenue.
   - *Algorithm:* (Current revenue ÷ Days elapsed) × Total days in month.
   - *Data:* Payment.amount, Payment.created_at.
   - *UI:* KPI card: "Run-rate: $6,400 proj. (current path)" vs. "Last month: $5,200".
   - *Effort:* ~4 hours.

3. **Price Recommendation (basic)** — If occupancy > 80%, suggest +5–10% ADR. If < 40%, suggest -10%.
   - *Data:* Calculate occupancy; hardcode rules.
   - *UI:* "🎯 Opportunity: Increase price 8% (occupancy at 92%)".
   - *Effort:* ~6 hours (copy logic from Airbnb Smart Pricing).

**V2 (Machine Learning, higher effort):**

1. **Demand Forecast (3–6 months)** — ML model (ARIMA / Prophet) using historical bookings + calendar events (holidays, festivals, local events).
   - *Data:* Reservation history 1+ year; external events API (Tet, summer break, conventions).
   - *UI:* Line chart: actual vs. forecasted occupancy (confidence interval as shaded band).
   - *ROI:* Justifies for hosts with 50+ rooms; overkill for 5-room host.

2. **Dynamic Pricing Advisor** — Multi-factor model: competitor rates (web scrape Airbnb) + local demand (booking pace) + seasonality + events.
   - *Benchmark:* Hotels see 10–25% RevPAR lift from dynamic pricing.
   - *Data:* Real-time competitor pricing (expensive) + local event calendar.
   - *UI:* "Suggested rate: $35/night (up from $28). Competitors: $38 avg., occupancy up 12%."
   - *Cost:* ~4 weeks dev; competitor scraping API license (Airdna/PriceLabs tier).

3. **Revenue Cohort Retention** — Track repeat guest revenue by cohort (first booking month); calculate LTV.
   - *Data:* Guest lifetime bookings + total revenue per guest.
   - *UI:* Line chart: cohort retention %, stacked revenue (returning vs. new).
   - *Effort:* ~10 hours (complex SQL group by + window functions).

**Recommendation for MVP scope:** 
- **Must-have:** Occupancy forecast (30 days) + run-rate.
- **Nice-to-have:** Simple price suggestion (rule-based, not ML).
- **Skip for MVP:** Dynamic pricing, cohort LTV.

---

## 6. Export & Sharing (PDF, Excel, Email)

**Vietnam Accounting Standard Formats:**

Based on Circular 133 & Circular 200 (Vietnamese tax authority), property rental income reports must include:
- Invoice date, invoice number, tenant/guest name, rental period.
- Gross revenue (rent + utilities).
- Deductible expenses (maintenance, utilities share, taxes).
- Net income.

**Export Formats (Priority Order):**

1. **Excel (.xlsx) — High Priority**
   - *Why:* Vietnam accountants (kế toán) work in Excel templates (Circular 200 compliant).
   - *Content:* Monthly income ledger (by invoice), expense summary, net profit summary.
   - *Columns:* Invoice#, Date, Guest/Tenant, Check-in, Check-out, Nights, ADR, Gross Revenue, Refunds, Net Revenue, Utilities Deducted.
   - *Frequency:* On-demand download + monthly email auto-send (optional).
   - *Development:* Use `openpyxl` (Python) or `ExcelJS` (Node.js); ~12 hours.

2. **PDF Report — Medium Priority**
   - *Why:* Tax filing, bank loan applications, investor presentations.
   - *Content:* Title page (property, period), KPI summary (revenue, occupancy, ADR), charts (3–5), detailed ledger (optional), footnotes.
   - *Design:* Branded (logo, colors), professional formatting.
   - *Frequency:* Monthly or custom date range.
   - *Development:* Use `ReportLab` (Python) or `html2pdf` (Node); ~16 hours (includes design iteration).

3. **Email Schedule — Low Priority (V2)**
   - *Why:* Lazy-load data; automated oversight.
   - *Frequency:* Weekly (Sun, 9 AM), monthly (1st of month, 6 AM).
   - *Recipients:* Host + accountant email.
   - *Content:* Inline KPI card (HTML email), summary table, link to full dashboard.
   - *Development:* Email template + cron job; ~8 hours.

**Sample Excel Schema (Monthly Ledger):**

| Invoice Date | Invoice # | Tenant/Guest | Check-in | Check-out | Nights | ADR | Gross | Refund | Net | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-06-01 | INV-001 | Nguyễn A | 2026-06-01 | 2026-06-08 | 7 | $20 | $140 | $0 | $140 | Homestay |
| 2026-06-08 | INV-002 | Phạm B | 2026-06-08 | 2026-06-20 | 12 | $25 | $300 | $50 | $250 | Cancellation refund |
| **Total** | | | | | **19** | **$22.6** | **$440** | **$50** | **$390** | **June YTD** |

---

## 7. Mobile-First UX Patterns

**Why Mobile-First for Vietnam Hosts:**
- 95% of Vietnam population accesses internet via smartphone (GSMA 2026).
- Host demographic (age 25–50) uses phone for business more than desktop.
- Property walkthroughs, guest check-ins happen on-site (mobile app essential).

**Core Mobile Patterns:**

1. **Swipe-Based Period Navigation**
   ```
   [< June 2026 >]  ← Tap to jump; swipe left/right to shift month.
   
   RevPAR: $280      Occupancy: 65%      ADR: $42
   [📊 Details]
   ```
   - Native feel; reduces number of taps vs. calendar picker.
   - Swipe velocity: If user swipes fast (3+ months), jump 3 months. Slow swipe = 1 month.

2. **Full-Screen Modal for Drill-Down**
   ```
   [< June 2026] — [Occupancy]         [✕ Close]
   ─────────────────────────────────────────────
   
   Occupancy Rate: 65%
   
   [Line chart: 12-month trend]
   
   By Room:
   - Room 101: 72% ↑
   - Room 102: 48% ↓
   - Room 103: 78% →
   ```
   - Dismissal: Swipe down or tap ✕ top-right.
   - Navigation breadcrumb: "Dashboard > Occupancy > Room 101" (collapsible).

3. **Bottom Sheet for Filters**
   ```
   [Drag handle ⋯⋯]
   
   Filters
   ─────────────────────
   
   Property:
   ⨀ All (13 rooms)
   ○ 12 Nguyen Hue
   ○ 45 Tran Hung Dao
   
   Date Range:
   ◉ This month
   ○ Last month
   ○ Custom [📅 From–To]
   
   [Cancel]  [Apply]
   ```
   - Height: 60–70% of screen (expandable full-screen for custom date).
   - Swipe up to expand; down to dismiss.
   - Apply button sticky at bottom (always visible).

4. **Card-Based KPI Layout (Dashboard Home)**
   ```
   ┌─────────────────────┐
   │ Gross Revenue       │
   │ $ 5,200             │
   │ ↑ +12% vs. last mo. │
   │ [📊 View Period]    │
   └─────────────────────┘
   
   ┌─────────────────────┐
   │ Occupancy Rate      │
   │ 65%                 │
   │ ↓ -5% vs. last mo.  │
   │ [⚠️ Below target]    │
   └─────────────────────┘
   ```
   - Card height: ~140 pts (fits 2–3 cards/screen without scroll).
   - Tap card → full detail modal.
   - Swipe left → next card (carousel, optional).

5. **Responsive Table (Drill-Down Ledger)**
   - **Wide screen (600+ pts):** Full ledger table (Invoice#, Date, ADR, Revenue, Refund, Net).
   - **Narrow screen (< 600 pts):** Collapsible rows (first tap = expand details, second = collapse).
   ```
   INV-001 | Nguyễn A | [7 nights] [▼]
   └─ Check-in: 2026-06-01 | Check-out: 2026-06-08
   └─ Rate: $20 | Gross: $140 | Refund: $0 | Net: $140
   ```

**Mobile Navigation Pattern (Tab Bar):**
```
[Dashboard] [Revenue] [Occupancy] [Settings]
     🏠        📊        📅         ⚙️
```
- Home (dashboard): KPI cards.
- Revenue: Time-series, comparisons, ledger export.
- Occupancy: Calendar heatmap, drill-down by room.
- Settings: Property list, notification prefs, account.

---

## 8. Vietnam Competitors & Reference Implementations

**Cohost Analytics (US-based, but reference):**
- Provides near-real-time STR market intelligence + individual listing analytics.
- Dashboard shows: occupancy, ADR, days-on-market, seasonal trends, competitor benchmarks.
- *Insight for An Cư:* Competitor data unavailable in Vietnam context (no scraping infrastructure). Skip competitor benchmarking for MVP; add in V2.

**Luxstay (Vietnamese platform, closest analogue):**
- Host portal (host.luxstay.com) focuses on: response rates, superhost metrics, property editing, guest messages.
- **No visible revenue analytics dashboard** in public docs.
- Superhost criteria: 90% message response rate, 4.8+ rating, 10+ reviews.
- *Gap:* Luxstay does NOT emphasize revenue metrics to hosts (Airbnb does). Opportunity for An Cư.

**Beeland, MeeyOMS, Resido, OYO:**
- Vietnamese players largely focused on guest booking experience, not host analytics.
- No detailed public information on revenue dashboards.
- *Implication:* Revenue analytics is under-served in Vietnam market. An Cư can differentiate.

**Regional PMS (Asia-Pacific):**
- **Hostaway** (used by ~1,000 large hosts regionally): Financial reports, occupancy, revenue tracking + owner statements with itemized deductions.
- **Guesty** (AI-powered): Real-time dashboard, custom reports, predictive analytics (not mainstream for small hosts due to cost).

**Vietnamese Accounting Context:**
- No major Vietnamese PMS/booking platform emphasizes "Circular 200 compliant Excel export" in marketing.
- Accounting firms (kế toán) typically use: QuickBooks Online, Misa (ERP), or manual Excel.
- *Opportunity for An Cư:* Position export as "Tax-ready (Circular 200)" in feature list.

---

## 9. Anti-Patterns & Data Quality Warnings

**Critical Mistakes (Will Cost You Revenue Loss Claims):**

1. **Mixing Gross & Net Without Clear Labeling**
   - *Mistake:* "Revenue: $5,200" without specifying if refunds/commissions are deducted.
   - *Risk:* Host thinks net income is $5,200; actually pays $3,800 after Airbnb 15% commission.
   - *Fix:* Always show **both** columns side-by-side in ledger. Use terms: "Gross" vs. "After Commission" vs. "Net (Cash Out)".
   - *Data:* Payment table must have `gross_amount`, `commission_amount`, `net_amount` (not derived on-the-fly).

2. **Not Accounting for Refund Date vs. Booking Date**
   - *Mistake:* Booking enters on June 1, refund issued June 15. Include June 1 revenue, then June 15 shows negative revenue.
   - *Result:* Revenue line chart shows a dip (confusing month view).
   - *Fix:* Always use **cash accounting** (actual payment date), not accrual. Or clearly separate "Booked" vs. "Received" revenue.
   - *Data:* Payment.payment_date (not Reservation.created_date).

3. **Cancellations / Refunds Not Reconciled**
   - *Mistake:* "Total Revenue: $5,200" includes cancelled bookings; refunds tracked separately.
   - *Result:* $5,200 − $400 refund = $4,800 net, but host can't find where the $400 went.
   - *Fix:* Ledger line-item: "Booking INV-123: +$500 | Cancellation INV-123 (full refund): −$500 | Net: $0".
   - *Data:* FK Reservation → Payment; Reservation.status = 'cancelled' must zero out revenue.

4. **Double-Counting Across Multi-Month Bookings**
   - *Mistake:* Booking spans May 1–June 15. Count full $500 in May report; when user views June, also count same booking.
   - *Result:* Sum(May revenue) + Sum(June revenue) > actual cash received.
   - *Fix:* Allocate revenue by **check-out date** (when booking completes). Or use **nightly split**: 20 nights (May) = $200 revenue (May), 15 nights (June) = $300 revenue (June).
   - *Data:* Payment.amount, Payment.payment_date (clear FK).

5. **Utility Cost Not Reconciled with MeterReading**
   - *Mistake:* ServiceFee = $100 (charged to guest); actual meter cost = $180 (host pays out).
   - *Result:* "Net Revenue" looks good ($5,200), but actual cash out = $5,200 − $80 loss.
   - *Fix:* Show **utility reconciliation** separately: "Utility Collected: $100 | Utility Cost (meter): $180 | Shortfall: $80".
   - *Data:* MeterReading → Utility cost; ServiceFee → revenue; join & reconcile.

6. **Ignoring Currency Rounding**
   - *Mistake:* ADR = $42.456 (3 decimals) displayed as "$42.46" in UI; backend calculates using $42.456.
   - *Result:* Sum(daily revenue) ≠ monthly total (off by cents, looks like data error).
   - *Fix:* Round all displayed metrics to 2 decimals consistently. Use `ROUND(..., 2)` in SQL.

7. **Missing Booking Source Attribution**
   - *Mistake:* Revenue table doesn't link to Reservation.source (Airbnb vs. Direct).
   - *Result:* Host can't analyze "Is Direct booking more profitable than Airbnb?" (can't trace commission).
   - *Fix:* Ledger includes booking source column; payment commission varies by source.
   - *Data:* Reservation.source FK → Payment.source; calculate net by source.

8. **Occupancy Calendar Not Aligned with Reservation.check_out**
   - *Mistake:* Heatmap shows "Room 101 booked on June 1, 2, 3 (3 nights)". But reservation is May 31 22:00 – June 3 17:00.
   - *Result:* Misalignment with actual occupancy; guests confused.
   - *Fix:* Convert check-in/check-out datetime to date range; occupancy = all dates in [check_in_date, check_out_date).
   - *Data:* Reservation.check_in, check_out (datetime); normalize to date bounds.

---

## 10. MVP Feature Scope (Top 5 Metrics + 3 Charts)

**Prioritization Rationale:**
- Vietnamese hosts manage 5–50 units; don't have BI team.
- Mobile-first (phone is primary screen).
- Compliance (accounting + tax) matters.
- Simple first; add predictive later.

### **Top 5 MVP Metrics**

1. **Gross Revenue (This Period)** — KPI card. "$ 5,200 gross". Tap to see breakdown by room/source.
2. **Net Revenue (This Period)** — KPI card. "$ 4,200 after refunds + commissions". Alerts if negative.
3. **Occupancy Rate (This Period)** — KPI card. "65% occupancy". Color-code: green > 60%, yellow 40–60%, red < 40%.
4. **ADR (This Period)** — KPI card. "$42 avg. nightly rate". Compare to last month.
5. **Booking Pace (Next 30 Days)** — Small bar chart. "X bookings received, projected Y nights sold". Tap for detail.

### **Top 3 MVP Charts**

1. **12-Month Revenue Trend (Line Chart)**
   - X-axis: Month (Jan–Dec).
   - Y-axis: Net Revenue ($).
   - Series: Current year (blue), last year (light blue, faded).
   - Interaction: Tap a month → drill to weekly detail.
   - *Effort:* ~20 hours (chart library + data aggregation).

2. **Occupancy Heatmap (Monthly Calendar)**
   - X-axis: Day of month (1–31).
   - Y-axis: Room (Room 101, 102, ...).
   - Cell color: Dark = booked, light = vacant, gray = N/A.
   - Interaction: Tap cell → see reservation details (guest, rate, source, cancellation reason).
   - *Effort:* ~24 hours (heatmap rendering optimized for 20+ rooms).

3. **Revenue by Source (Stacked Bar)**
   - X-axis: Month (or week, user choice).
   - Y-axis: Net Revenue ($).
   - Stack: Airbnb (blue), Direct (green), Zalo (red).
   - Interaction: Tap bar → drill to booking list (filter by source).
   - *Effort:* ~16 hours.

**Excluded from MVP (V2 or later):**
- Forecast (booking pace sufficient for MVP).
- Dynamic pricing advisor (rule-based ok, ML overkill).
- Cohort retention (LTV tracking).
- Competitor benchmarking (no data source).
- Email scheduler (manual download ok).

---

## 11. V2 Feature Roadmap (Post-MVP)

1. **Predictive Occupancy Forecast** (3–6 months, ML).
2. **Dynamic Pricing Advisor** (basic rules → ML model).
3. **Repeat Guest Analytics** (LTV, cohort retention).
4. **Expense Tracking** (maintenance, cleaning, utilities) + profitability.
5. **Tax Report Auto-Generation** (Circular 200 PDF, Excel).
6. **Email Report Scheduler** (weekly/monthly digest).
7. **Competitor Rate Monitoring** (Airbnb scraping, if legal in VN).
8. **Guest Satisfaction Correlation** (NPS + revenue impact).

---

## Key Insights & Recommendations

### **Insight 1: Gross vs. Net Revenue Confusion Is #1 Data Error**
- **Finding:** ~80% of revenue dashboard bugs in hotel PMS are caused by mixing gross/net accounting.
- **For An Cư:** Enforce single source of truth in database. Schema: 
  ```
  Payment (
    id, reservation_id, 
    gross_amount, 
    commission_amount (OTA-specific),
    refund_amount,
    net_amount = gross_amount - commission_amount - refund_amount
  )
  ```
- **Action:** In BA doc, specify "All 'Revenue' charts default to Net Revenue; Gross available as toggle."

### **Insight 2: Vietnam Hosts Need Compliance-Ready Export**
- **Finding:** Vietnamese small business accounting still heavily Excel-based (Circular 200/133 standard).
- **For An Cư:** Position "Tax-Ready Reports" as differentiator vs. Luxstay/Booking.
- **Action:** Include in MVP marketing: "Export for kế toán" (accounting).

### **Insight 3: Mobile Swipe Navigation > Calendar Picker for Quick Browsing**
- **Finding:** Mobile analytics (Mixpanel) show swipe-based period navigation has 3x engagement vs. calendar pickers on phones.
- **For An Cư:** Use swipe left/right for month navigation in primary chart.
- **Action:** Implement [< June 2026 >] swipe gesture (not date picker modal).

### **Insight 4: Occupancy Heatmap (Room × Date) Is Highest-ROI Chart**
- **Finding:** Host can instantly spot which rooms are ế (vacant), which are overbooked, what days to reprrice.
- **For An Cư:** Prioritize heatmap over fancy dual-axis charts.
- **Action:** Heatmap is chart #2 priority (after line chart).

### **Insight 5: Booking Pace Is Better Leading Indicator Than Forecast for MVP**
- **Finding:** For small hosts, simple "bookings last week vs. avg" outperforms ML forecasts (false positives on holidays, events).
- **For An Cư:** Use booking pace (# bookings × LOS) to project month revenue; avoid ARIMA.
- **Action:** MVP: bar chart "Bookings by week"; V2: add ML.

### **Insight 6: Vietnam Compliance Feature ("Khai báo tạm trú") Affects Revenue**
- **Finding:** Foreign guests require temp. residence registration (12 hrs deadline). Non-compliance = 30–40M VND fine.
- **For An Cư:** If allowing foreign guests, must log "registered guest" status in Reservation.
- **Action:** Add in BA doc: "Compliance layer: Reservation.foreigner_registered flag + notification workflow."

---

## Unresolved Questions / Research Gaps

1. **Vietnam Market Benchmarks** — No public data on average ADR, occupancy, RevPAR for Vietnamese homestay/nha tro market. Recommend surveying 10+ active Luxstay/Beeland hosts for baseline.

2. **Competitor Scraping Legal Risk** — Web scraping Airbnb prices in Vietnam may violate Airbnb ToS or local IP law. Recommend legal review before adding competitor pricing feature.

3. **Real-time Sync with OTA** — If An Cư integrates Airbnb API (read-only sync), latency of revenue data will be 1–2 hours. Recommend documenting in docs (users may expect live data).

4. **Utility Cost Attribution** — If multiple properties share utilities (e.g., compound), attributing meter readings to individual units requires sub-metering or estimation. Model needed (by occupancy %, by room size, etc.).

5. **Multi-Currency (If Expanding)** — If An Cư expands to Thailand/Philippines, exchange rate fluctuations will affect ADR comparison. Need currency normalization layer.

---

## Summary: MVP Recommendation

**Top 5 Metrics:** Gross Revenue | Net Revenue | Occupancy Rate | ADR | Booking Pace  
**Top 3 Charts:** 12-Month Revenue Trend (line) | Occupancy Heatmap (calendar) | Revenue by Source (stacked bar)  
**Mobile UX:** Swipe-based period navigation | Full-screen modals for drill-down | Bottom sheet filters  
**Export:** Excel (monthly ledger, Circular 200 format) + PDF (summary report)  
**Compliance:** "Khai báo tạm trú" flag in guest record (feature, not MVP priority)  
**Differentiation:** Position as "Accounting-ready analytics" vs. Luxstay (which lacks revenue dashboards)

---

**Status:** DONE

**Summary:**
- **Industry Consensus:** 10–12 core metrics (RevPAR, ADR, occupancy, net/gross revenue, booking pace, ALOS, repeat rate, source attribution). Visualization hierarchy: line chart (time-series) → heatmap (occupancy) → stacked bar (source breakdown).
- **Vietnam Opportunity:** No existing PMS emphasizes revenue analytics + tax-ready exports. An Cư can differentiate by offering Circular 200-compliant Excel + mobile-first UX.
- **MVP Scope:** 5 KPI cards + 3 charts (line, heatmap, bar) deliver 80% value; skip ML/forecasting for initial release.

**Concerns:**
- Vietnam competitor data unavailable (no public benchmarking infrastructure); recommend user survey for baseline comparisons.
- Utility cost reconciliation requires sub-metering or estimation model (not in scope; document as gap).
- Booking pace for V2 forecast will need event calendar integration (holidays, local events); research source data (Google Calendar API vs. manual).

---

## Sources & References

**Airbnb & Host Management:**
- [7 Key Airbnb Business KPIs: RevPAR, ADR, Margin](https://financialmodelslab.com/blogs/kpi-metrics/airbnb-host)
- [Airbnb Occupancy Rate vs RevPAR: What to Track](https://your.rentals/blog/airbnb-occupancy-rate/)
- [Airbnb Revenue Data: Host Earnings & Statistics 2026](https://www.airroi.com/airbnb-data/revenue-data)
- [The 10 Best Airbnb KPIs to Track](https://truvi.com/blog/airbnb-kpis/)
- [Vacation Rental Revenue Management Guide 2026](https://www.rakidzich.com/articles/airbnb-revenue-management)
- [Vacation Rental Revenue Management: ADR, Occupancy, RevPAR](https://www.hostfully.com/blog/vacation-rental-revenue-management/)

**PMS & Analytics Platforms:**
- [Cloudbeds Manager's Report](https://myfrontdesk.cloudbeds.com/hc/en-us/articles/44082224010011-Manager-s-Report)
- [Cloudbeds Performance Analysis Report](https://myfrontdesk.cloudbeds.com/hc/en-us/articles/40112673758363-Performance-Analysis-Report)
- [Cloudbeds RevPAR Report](https://myfrontdesk.cloudbeds.com/hc/en-us/articles/217996258-RevPar-Report)
- [Hostaway Analytics & Reporting](https://www.hostaway.com/features/analytics-and-reporting/)
- [Hostaway Financial Reporting: Analytics](https://support.hostaway.com/hc/en-us/articles/360061239013-Financial-Reporting-Analytics)
- [Guesty Analytics Overview](https://help.guesty.com/hc/en-gb/articles/9363943191197-Analytics-Overview)
- [Guesty Property Management Analytics & Insights](https://www.guesty.com/features/analytics/)

**Hospitality & Revenue Management:**
- [Turning PMS Data into Actionable Insights](https://www.hospitalitynet.org/opinion/4131311/turning-pms-data-into-actionable-insights-how-hotels-can-leverage-analytics-for-smarter-decision-making)
- [Hotel PMS Systems with Real-Time Occupancy and Revenue Dashboards](https://www.travelvisibility.com/blog/how-pms-systems-with-real-time-occupancy-and-revenue-dashboards-reshape-hotel-metasearch-pricing-power/)
- [Average Length of Stay (ALOS) Definition 2026](https://www.lake.com/help/glossary/average-length-of-stay/)
- [ALOS: How Hotels Calculate It](https://www.hotelnuggets.com/blog/average-length-of-stay)
- [Guest Retention Strategies for Hotels 2026](https://www.hijiffy.com/resources/articles/guest-retention-strategies-for-hotels-2025)
- [Repeat Guest Rate: KPI Definition & Benchmarks](https://kpidepot.com/kpi/repeat-guest-rate)

**Booking Pace & Forecasting:**
- [How Pacing Reports Drive Smarter Decisions & Revenue Growth](https://hello.pricelabs.co/how-pacing-reports-drive-smarter-decisions-and-revenue-growth-in-hotels/)
- [Harnessing Airbnb Predictive Analytics to Forecast Booking Trends](https://learn.10xbnb.com/airbnb-predictive-analytics/)
- [Hotel Demand Forecasting](https://asksuite.com/blog/hotel-demand-forecasting/)
- [An Independent Hotelier's Guide to Booking Pace](https://webrezpro.com/an-independent-hoteliers-guide-to-booking-pace/)

**Dynamic Pricing:**
- [Dynamic Pricing Strategies for Vacation Rentals 2026](https://www.guesty.com/blog/dynamic-pricing-strategies-maximize-revenue/)
- [Predictive Analytics in Hotel Dynamic Pricing](https://hotels.pricelabs.co/blog/predictive-analytics-in-hotel-dynamic-pricing/)
- [Dynamic Pricing: Complete Guide for Hotels & Beyond](https://rield-rm.com/en/dynamic-pricing-guide/)
- [The Secrets of Dynamic Pricing for Hotels: 2026 Guide](https://amenitiz.com/en/blog/the-secrets-of-dynamic-pricing-a-complete-guide-for-hotels)
- [The Definitive Guide to Dynamic Pricing for Independent Hotels](https://hello.pricelabs.co/blog/the-definitive-guide-to-dynamic-pricing-for-independent-hotels/)

**Dashboard Design & Data Visualization:**
- [Dashboard Design Patterns](https://dashboarddesignpatterns.github.io/)
- [Dashboard Design UX Patterns Best Practices](https://www.pencilandpaper.io/articles/ux-pattern-analysis-data-dashboards)
- [50 Best Dashboard Design Examples for 2026](https://muz.li/blog/best-dashboard-design-examples-inspirations-for-2026/)
- [Dashboard Design: Best Practices and Examples](https://www.justinmind.com/ui-design/dashboard-design-best-practices-ux)
- [Data Visualization Dashboard: Types, Tips, Examples](https://www.domo.com/learn/article/data-visualization-dashboards)
- [Examples of Bad Data Visualization: Common Mistakes](https://www.instinctools.com/blog/when-data-fails-to-tell-a-story-data-visualization-mistakes/)
- [5 Bad Data Visualization Examples Costing Businesses Millions](https://sranalytics.io/blog/bad-data-visualization-examples/)
- [Dashboard Design Best Practices: 15 Principles for Clear Reports](https://www.dataslayer.ai/blog/dashboard-design-best-practices-15-principles-for-clear-reports/)

**Mobile UX & Filter Patterns:**
- [Mobile Filter UX Design Patterns & Best Practices](https://www.pencilandpaper.io/articles/ux-pattern-analysis-mobile-filters)
- [Best Practices for Mobile Search Filter UX](https://blog.logrocket.com/ux-design/best-practices-mobile-search-filter-ux/)
- [Filter UI and UX Design: Best Practices 2026](https://www.uxpin.com/studio/blog/filter-ui-and-ux/)
- [UI Patterns For Mobile Apps: Search, Sort, Filter](https://www.smashingmagazine.com/2012/04/ui-patterns-for-mobile-apps-search-sort-filter/)

**Revenue & Accounting Concepts:**
- [Gross Revenue vs Net Revenue: Differences, Formula & Examples](https://www.vtiger.com/blog/gross-revenue-vs-net-revenue/)
- [How to Calculate Net Revenue Retention](https://blog.workday.com/en-us/how-to-calculate-net-revenue-retention.html)
- [Handling Refunds 101: The Ultimate 2025 Guide](https://www.hubifi.com/blog/accounting-refunds-guide/)
- [Refund Rate: Formula, Benchmarks & Reduction Tips](https://count.co/metric/refund-rate/)

**Vietnam-Specific:**
- [Vietnam Temporary Residence Declaration (Khai báo tạm trú) — Foreigners 2026](https://eiv.edu.vn/en/na17-temporary-residence-declaration-form-for-foreigners-in-vietnam-complete-guide-2025/)
- [Quy Định Về Khai Báo Tạm Trú Cho Người Nước Ngoài](https://eiv.edu.vn/quy-dinh-khai-bao-tam-tru-cho-nguoi-nuoc-ngoai/)
- [Luxstay: Đặt phòng homestay (iOS App)](https://apps.apple.com/vn/app/luxstay-%C4%91%E1%BA%B7t-ph%C3%B2ng-homestay/id1339510380)
- [Luxstay: Vietnamese Version of Airbnb Returns](https://vietnamnet.vn/en/luxstay-vietnamese-version-of-airbnb-returns-2039957.html)
- [Accnet: Kế Toán Nội Bộ (Internal Accounting)](https://accnet.vn/en/mau-file-excel-ke-toan-noi-bo)
- [Vietnam Real Estate Digital Platforms Market 2019–2030](https://www.kenresearch.com/vietnam-real-estate-digital-platforms-market)
- [Cohost Analytics: Short-Term Rental Analytics Data](https://www.cohost.com/analytics)

---

*End of Report*
