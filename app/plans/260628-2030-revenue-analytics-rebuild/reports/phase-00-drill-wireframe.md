---
title: "Phase 00 — Drill 4-Level Navigation Wireframe Spec"
condition: "BA Leader §11.1 #3 (R12)"
status: completed_textual
prepared_by: Tech Lead (Claude)
date: 2026-06-28
blocks_phase: 07 (Drill-down + filter bottom sheet)
---

# Phase 00 Gate — Drill 4-Level Wireframe Spec

## Goal
Spec navigation path **Phòng → Contract → Tenant → Invoice** for mobile (>80% users) with breadcrumb + back-to-summary shortcut, per Q8 user decision + BA Leader §11.1 #3 risk (R12 — mobile drill-down lost user). Acts as **design contract** for Phase 07 implementation; designer can convert ASCII spec to Figma high-fi separately.

---

## Information Architecture

```
[Analytics Home]
       │
       └─► Tap KPI card "Net Revenue" / "Occupancy"  (US-07)
                │
                ▼
         [Level 1] Room List (filterable by building)   ← back to Home
                │
                └─► Tap row "Phòng 101 - Tòa A"
                       │
                       ▼
                [Level 2] Contracts/Reservations for Room
                       │
                       └─► Tap row "Hợp đồng #C-1234"
                              │
                              ▼
                       [Level 3] Tenants on Contract
                              │
                              └─► Tap row "Nguyễn Văn A"
                                     │
                                     ▼
                              [Level 4] Invoices for Tenant
                                     │
                                     └─► Tap row "HD-2026-05-001"  → opens existing invoice detail screen (no new level)
```

---

## Screen Wireframes (ASCII Mobile 360×640)

### Level 1: Room List

```
┌─────────────────────────────────────┐
│ ←  [Summary > Rooms]            ⋯   │  ← Breadcrumb sticky
├─────────────────────────────────────┤
│ 🔍 Search room name            [▼]  │  ← Filter chip
├─────────────────────────────────────┤
│ ▼ Tòa A (15 rooms)                  │  ← Collapsible group
│   ┌─────────────────────────────┐   │
│   │ Phòng 101              [→]  │   │  ← Tap row
│   │ 28 đêm · 5.2M ₫  · 82% occ  │   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │ Phòng 102              [→]  │   │
│   │ 31 đêm · 6.0M ₫  · 100%     │   │
│   └─────────────────────────────┘   │
│   ...                                │
│ ▼ Tòa B (8 rooms)                   │
│   ...                                │
├─────────────────────────────────────┤
│ [⌂ Về Tổng Quan]                    │  ← Back-to-summary CTA (sticky bottom)
└─────────────────────────────────────┘
```

### Level 2: Contracts for Room

```
┌─────────────────────────────────────┐
│ ← [Summary > Rooms > Phòng 101]  ⋯  │  ← Breadcrumb (truncated middle if long)
├─────────────────────────────────────┤
│ Phòng 101 · Tòa A                   │  ← Context header
│ Tháng 5/2026 · 5.2M ₫               │
├─────────────────────────────────────┤
│ Hợp đồng / Đặt phòng (3)            │
│ ┌─────────────────────────────────┐ │
│ │ HD #C-1234 · 01/05→31/05    [→] │ │
│ │ Tenant: Nguyễn Văn A            │ │
│ │ 5.0M ₫ · paid                   │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ Reservation #R-5678 (homestay)  │ │
│ │ 28/05→30/05 · 2 đêm             │ │
│ │ 1.2M ₫ · checked_out            │ │
│ └─────────────────────────────────┘ │
│ ...                                 │
├─────────────────────────────────────┤
│ [⌂ Tổng Quan]  [↑ Rooms]            │  ← Two-button: summary + prev level
└─────────────────────────────────────┘
```

### Level 3: Tenants on Contract

```
┌─────────────────────────────────────┐
│ ← [...Contract #C-1234]         ⋯   │  ← Breadcrumb collapses w/ "..." prefix
├─────────────────────────────────────┤
│ Hợp đồng #C-1234                    │
│ 01/05/2026 → 31/05/2026 · paid      │
├─────────────────────────────────────┤
│ Người thuê (2)                      │
│ ┌─────────────────────────────────┐ │
│ │ 👤 Nguyễn Văn A          [→]    │ │
│ │ Người ký HĐ · 0901234567        │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ 👤 Trần Thị B            [→]    │ │
│ │ Đồng người thuê · 0987654321    │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Hóa đơn của hợp đồng (3)            │  ← Direct shortcut: skip level 3 →4
│ ┌─────────────────────────────────┐ │
│ │ HD-2026-05-001 · 5.0M ₫ · paid  │ │
│ │ HD-2026-04-001 · 5.0M ₫ · paid  │ │
│ │ ...                              │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ [⌂ Tổng Quan]                       │
└─────────────────────────────────────┘
```

### Level 4: Invoices for Tenant (filtered)

```
┌─────────────────────────────────────┐
│ ← [...Nguyễn Văn A]             ⋯   │
├─────────────────────────────────────┤
│ Nguyễn Văn A                        │
│ Phòng 101 · HD C-1234               │
├─────────────────────────────────────┤
│ Hóa đơn (3)                         │
│ ┌─────────────────────────────────┐ │
│ │ HD-2026-05-001       [paid]     │ │
│ │ 5.0M ₫ · 31/05/2026             │ │
│ │ → Xem chi tiết                   │ │  ← Tap → existing invoice screen
│ └─────────────────────────────────┘ │
│ ...                                 │
├─────────────────────────────────────┤
│ [⌂ Tổng Quan]                       │
└─────────────────────────────────────┘
```

---

## Component Specs

### 1. Breadcrumb (sticky top)

- **Widget:** `Breadcrumb` (new in `lib/features/host/analytics/widgets/breadcrumb.dart`)
- **Behavior:**
  - Show full path on Level 1-2: `Summary > Rooms`
  - Truncate middle with `…` on Level 3-4: `Summary > … > Contract #C-1234`
  - Each segment tappable → pop back to that level (`Navigator.popUntil`)
  - Max height 44dp; horizontal scroll if overflow on long labels
- **A11y:** `Semantics(label: "Breadcrumb: Summary, Rooms, Phòng 101", button: true)`
- **Token reuse:** `HD.inkMuted` for inactive segments, `HD.ink` for current

### 2. Back-to-Summary CTA (sticky bottom)

- **Widget:** `BackToSummaryButton`
- **Variants:**
  - Level 1: single button `[⌂ Về Tổng Quan]`
  - Level 2-4: two buttons `[⌂ Tổng Quan]` + `[↑ {Previous Level Name}]`
- **Always visible** — even on scroll (per BA Leader §11.1 #3 mitigation: "back-to-summary shortcut")
- **Hit target:** ≥48dp tall
- **Behavior:** `context.go('/host/analytics')` for summary; `context.pop()` for prev level

### 3. Row Card Pattern

- Each level row shows: primary label + secondary stat + trailing arrow `[→]`
- Tap entire card (Material InkWell)
- Min height 56dp
- Border bottom: 1px `HD.divider`

### 4. Empty State (per level)

- Illustration + message + CTA back-to-prev or summary
- Example Level 2 empty: "Phòng này chưa có hợp đồng tháng 5/2026 — chỉ có data từ tháng 3-4."

### 5. Loading Skeleton

- Per level: 5-row shimmer skeleton on data fetch (consistent w/ AC-13)

---

## Routing (go_router)

Routes to add at `lib/core/router/app_router.dart`:

```dart
GoRoute(
  path: '/host/analytics/drill/rooms',
  builder: (ctx, st) => DrillRoomListScreen(
    period: st.uri.queryParameters['period'] ?? 'month',
    date: st.uri.queryParameters['date']!,
    buildingId: st.uri.queryParameters['building_id'],
  ),
),
GoRoute(
  path: '/host/analytics/drill/room/:roomId/contracts',
  builder: (ctx, st) => DrillRoomContractsScreen(
    roomId: int.parse(st.pathParameters['roomId']!),
    period: st.uri.queryParameters['period']!,
    date: st.uri.queryParameters['date']!,
  ),
),
GoRoute(
  path: '/host/analytics/drill/contract/:contractId/tenants',
  builder: (ctx, st) => DrillContractTenantsScreen(
    contractId: int.parse(st.pathParameters['contractId']!),
  ),
),
GoRoute(
  path: '/host/analytics/drill/tenant/:tenantId/invoices',
  builder: (ctx, st) => DrillTenantInvoicesScreen(
    tenantId: int.parse(st.pathParameters['tenantId']!),
    contractId: int.parse(st.uri.queryParameters['contract_id']!),
  ),
),
```

**Deep link:** Each drill screen has its own URL → browser back/forward + share-link work. Per AC-14.

---

## UX Risks Mitigated

| Risk | Mitigation in spec |
|---|---|
| User lost in 4-deep navigation | Breadcrumb + back-to-summary visible on every level |
| Long screen titles overflow | Middle truncation `…` |
| Phone screen too small for breadcrumb | Horizontal scroll fallback |
| User wants to skip level 3 (tenant) | Level 2 has "Hóa đơn của hợp đồng" shortcut → direct level 2 → 4 |
| Empty state at level 3 (no tenant) | Skeleton + "Hợp đồng chưa có tenant" + CTA back |

---

## Designer Handoff Notes

For designer to convert this ASCII spec to Figma:

1. Use Material 3 token from `host_dashboard_tokens.dart`
2. Color palette: stay within existing app palette — neutral grey for breadcrumb, ink for current, primary accent for tap state
3. Icon set: Material Icons (already in app) — `home_rounded` for summary, `arrow_upward_rounded` for prev level, `chevron_right_rounded` for row arrow
4. Test on devices: Samsung A14 (1080×2408, 270dpi), iPhone SE 2020 (375×667, 326ppi), Pixel 7 (1080×2400)
5. Animation: 200ms ease-out for level transition (Flutter default `MaterialPageRoute`)
6. A11y check: TalkBack/VoiceOver — breadcrumb segments announced as buttons

---

## Validation Checklist (Phase 07 dev gate)

- [ ] Breadcrumb tested w/ 4-segment long labels (truncation works)
- [ ] Back-to-summary visible on every scrolled position
- [ ] Empty state at each level renders
- [ ] Deep link to level 4 works directly (auth gate redirects to login if not host)
- [ ] Back button OS-level (Android) pops levels correctly (no jump-to-home)
- [ ] iOS swipe-back gesture pops one level

---

## Sign-off

- Tech Lead Claude — spec drafted 2026-06-28
- ⏳ **Designer Figma high-fi (optional)** — spec is implementation-ready as-is; designer polish later if budget allows
- ⏳ **Host pilot review** — recommend show this spec (or Figma) to 2 host pilots for UX sanity check
- Gate condition #3 (R12): **CLEARED on Tech Lead side** — Phase 07 dev can proceed using this spec as design contract

**Gate condition #3 (R12): ✅ CLEARED (designer polish optional, host pilot validation recommended)**
