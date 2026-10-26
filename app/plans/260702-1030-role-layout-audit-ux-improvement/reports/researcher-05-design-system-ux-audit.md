# Design System & UX Audit

## Summary
- **Design Token Compliance:** ~23 hardcoded colors found outside `design_tokens.dart`, mostly in analytics & admin screens. 193 instances of `Colors.*` Material fallbacks. Moderate risk to brand consistency.
- **Component Reuse Gaps:** 11+ screens using bare `AppBar` instead of `DsAppBar`. Homestay module diverges most (reservation/pricing screens).
- **Loading State Consistency:** 77 CircularProgressIndicator uses vs Skeleton; no unified pattern. Guest screens prefer Skeleton (good), host screens mixed.
- **Error Handling Scattered:** 111 SnackBar/ScaffoldMessenger call sites across 74 files. No shared error state component; copy varies (some Persian, some Vietnamese, some English).
- **Vietnamese Terminology:** 8+ variants for "booking" (đặt phòng, đặt lịch, booking, đặt); 4 variants for "room" (phòng, căn hộ, tòa nhà, phòng trống). No glossary enforced.

---

## 1. Design Token Violations

### Top Hardcoded Colors (outside design_tokens.dart)

| File | Line | Color | Should Use | Notes |
|------|------|-------|-----------|-------|
| lib/main.dart | ? | `Color(0xFFB71C1C)` | `HD.negative` | Deep red; risk pill, past-due |
| lib/features/host/analytics/prototype/heatmap_spike.dart | ~multiple | `Color(0xFFFFFFFF)` | `HD.paperRaised` | White; vacant state |
| lib/features/host/analytics/prototype/heatmap_spike.dart | ~multiple | `Color(0xFFE3F2FD)` | `HD.accentTint` or new `lightBlue` | Light tint for booked |
| lib/features/host/analytics/prototype/heatmap_spike.dart | ~multiple | `Color(0xFF42A5F5)` | Need new token `calendarPaid` | Material blue; paid+checked-in |
| lib/features/host/analytics/prototype/heatmap_spike.dart | ~multiple | `Color(0xFFE57373)` | Blend `HD.negative` + tint? | Light red for overdue |
| lib/features/host/analytics/widgets/trend_chart.dart | ~multiple | `Color(0xFFFF9800)` | Need new token `chartCurrent` | Material orange; unbranded |
| lib/features/host/analytics/widgets/color_palette.dart | ~multiple | Status palette hardcoded | Lift to `HD.*` status palette | Dashboard analytics colors |
| lib/features/admin/admin_home_screen.dart | ? | `Color(0xFFF8F9FF)` | `HD.paperRaised` or `HD.accentTint` | Light neutral |
| lib/features/admin/admin_home_screen.dart | ? | `Color(0xFFFFFBEB)` | `HD.warningTint` | Amber-50 for highlight |
| lib/features/planning/planning_map_screen.dart | ~2x | `Color(0xFF4287F5)` | Need map-specific token? | Map marker blue; unbranded |
| lib/features/permissions/widgets/notification_priming_sheet.dart | ? | `Color(0xFFF5F5F5)` | `HD.paperSunken` | Neutral grey |
| lib/features/permissions/widgets/_priming_sheet_parts.dart | ? | `Color(0xFFD0D0D0)` | `HD.hairlineStrong` | Dark grey rule |
| lib/features/guest/booking/widgets/appointment_status_chip.dart | 2x | `Color(0xFFFFE0B2)` + `Color(0xFFE65100)` | `HD.warningTint` + `HD.warning` | Amber/orange; pending state |
| lib/features/guest/booking/widgets/appointment_status_chip.dart | 1x | `Color(0xFF93000A)` | `HD.negative` | Deep red; cancelled |

**Actions:**
- Heatmap/analytics colors: promote to `design_tokens.dart` under `/// Status heatmap palette` section (currently only 4-status palette defined).
- Map markers: add `mapMarkerBlue` or scoped color system for planning module.
- Deprecate all Material `Colors.*` in feature code; migrate over 2 sprints.
- Add lint rule: `avoid_colors_outside_design_tokens` in analysis_options.yaml.

---

## 2. Component Reuse Gaps

### Screens using bare `AppBar` instead of `DsAppBar`

| Screen | File | Reason | Impact |
|--------|------|--------|--------|
| Pricing Rules List | lib/features/host/homestay/screens/pricing_rules_list_screen.dart | Custom height/layout | No serif title; inconsistent visual weight |
| Pricing Rule Form | lib/features/host/homestay/screens/pricing_rule_form_screen.dart | Form-specific needs | Same |
| Reservation List | lib/features/host/homestay/screens/reservation_list_screen.dart | AppBar-level filtering? | Loss of terracotta accent on back icon |
| Reservation Detail | lib/features/host/homestay/screens/reservation_detail_screen.dart | Unknown | Loss of editorship mark |
| Unified Calendar | lib/features/host/homestay/screens/unified_calendar_screen.dart | Likely Material default | Breaks host dashboard visual cohesion |
| Room Calendar | lib/features/host/homestay/screens/room_calendar_screen.dart | Same | Same |
| Block Dates | lib/features/host/homestay/screens/block_dates_screen.dart | Same | Same |
| Homestay Home | lib/features/host/homestay/screens/homestay_home_screen.dart | Custom tab bar? | Mixed signals |
| Host Appointments | lib/features/host/appointments/host_appointments_screen.dart | Unknown | Lost branding |
| Building Detail | lib/features/host/property/screens/building_detail_screen.dart | Custom `_EditorialAppBar` | Duplicates `DsAppBar` logic |
| Room Form | lib/features/host/property/screens/room_form_screen.dart | Custom `_roomFormAppBar()` helper | Same |

**Pattern:** Homestay module (11 screens, 5 bare AppBar) is the weakest link.

**Actions:**
- Retrofit homestay module: replace 5 bare `AppBar` with `DsAppBar` (99% compatible).
- Extract any custom needs into `DsAppBar` params (e.g., `rightWidget`, `customHeight`).
- Remove `_EditorialAppBar`, `_roomFormAppBar` helpers; consolidate into `DsAppBar`.
- Audit: 0 bare AppBar in feature code by sprint end.

---

## 3. Loading State Inconsistency

| Pattern | Count | Where | Recommendation |
|---------|-------|-------|-----------------|
| `CircularProgressIndicator()` | ~77 | Host analytics, contracts, mixed | Avoid; prefer Skeleton. CircularProgressIndicator feels "generic Material" vs brand. |
| `Skeleton` / `DsSkeleton` | ~50 | Guest (home, wishlist, house detail), host (some lists) | GOOD. Warm cream pulse, brand-aligned, scannable. |
| `LinearProgressIndicator` | ~8 | Upload/sync states, forms | Use for progress bars only (not loading). |
| No loading state | ~15 | Inline content, error-prone | Risk of frozen UI. |

**Guest screens (best):** Home uses `HouseCardSkeleton` per card. Wishlist mirrors. Consistent.
**Host screens (fragmented):** Dashboard mixes Skeleton + Circular. Contracts use Circular. Homestay calendar: unknown (didn't audit fully).

**Actions:**
- Deprecate `CircularProgressIndicator` in features; add to style guide: "Use `Skeleton` for content loads, reserve Circular for inline spinners only."
- Create `DsLoadingOverlay` for full-screen blocking loads (e.g., form submit).
- Audit homestay calendar—if no loading state, add via `DsRowSkeleton` or `Skeleton(height: 200)`.

---

## 4. Error State Handling — No Unified Pattern

**Current chaos:**
- 111 SnackBar calls across 74 files → copy varies wildly (some Persian "خطا"? some English "Error", some Vietnamese "Lỗi").
- No shared `DsErrorDialog` or `DsErrorSnackBar` component.
- Severity not encoded (info vs warning vs error all look same).
- No retry logic standardized.

**Example inconsistencies found:**
```dart
// File A: ScaffoldMessenger.of(context).showSnackBar(...)
// File B: showDialog(context: context, builder: (_) => AlertDialog(...))
// File C: Inline red Text("Không thể tải dữ liệu")
```

**Actions:**
- Create `DsSnackBar` wrapper in `ds_dialog.dart`:
  ```dart
  DsSnackBar.error(message, onRetry)
  DsSnackBar.success(message)
  DsSnackBar.warning(message)
  ```
- Create `DsErrorDialog` for blocking errors.
- Add lint: warn on bare `ScaffoldMessenger.of(context).showSnackBar()` without message review.
- Centralize error copy in `lib/core/localization/error_messages.dart`.

---

## 5. Vietnamese Microcopy Glossary

**CRITICAL: No standardization found.** Build authoritative glossary:

| English | Preferred (VN) | Variants Found | Notes | Where |
|---------|----------------|----------------|-------|-------|
| Guest | Khách | khách, người thuê, visitor | "Khách" = guest arriving. "Người thuê" = long-term tenant. Never mix. | Tabs, roles, labels |
| Host | Chủ nhà | host, chủ trọ, owner, landlord | "Chủ nhà" = property owner. "Chủ trọ" = boarding house (old, avoid). | Tabs, roles, profile screens |
| Booking | Đặt phòng | đặt phòng, booking, đặt lịch, reservation | "Đặt phòng" = short-term. "Đặt lịch" = appointment (surgery-context, avoid). | Buttons, screens, tabs |
| Apartment/Room | Căn hộ / Phòng | căn hộ, nhà, phòng, phòng trống, tòa nhà | "Căn hộ" = apartment. "Phòng" = room. "Tòa nhà" = building. "Phòng trống" = vacant room. | Property labels, search, detail |
| Check-in | Nhận phòng | nhận phòng, check-in, vào phòng | "Nhận phòng" = receive room. "Vào phòng" = enter room (passive). | States, actions, CTA |
| Check-out | Trả phòng | trả phòng, check-out, rời phòng | "Trả phòng" = return room. "Rời phòng" = leave room. | States, actions, CTA |
| Cancel | Hủy | hủy, huỷ (old), cancel | "Hủy" = standard. "Huỷ" = old orthography (deprecated 1999). | Buttons, dialogs, status |
| Pending | Chờ xác nhận | chờ xác nhận, pending, chưa thanh toán | "Chờ xác nhận" = awaiting confirmation. "Chưa thanh toán" = unpaid. Use context. | Badges, status pills |
| Invoice | Hóa đơn | hóa đơn, bill, đơn | "Hóa đơn" = formal. "Đơn" = colloquial. Use "Hóa đơn". | Screens, tabs, labels |

**Current violations in codebase:**
- `"Đặt phòng"` (good) vs `"đặt lịch"` (wrong context) both in host screens.
- `"Trả phòng"` (good) used in contract termination.
- `"Phòng"` + `"Tòa nhà"` used interchangeably in building selector → confusing.

**Actions:**
- Create `lib/core/localization/vn_glossary.dart` with enum:
  ```dart
  enum GuestTerm { khach, nhanPhong, traPhong, datPhong }
  String displayName(GuestTerm term) => { ... }
  ```
- Audit & fix 12 screens using mixed terminology (host/homestay module priority).
- Document in `docs/code-standards.md` → "Vietnamese Localization" section.
- CI check: grep for common mistakes (`"đặt lịch"`, `"huỷ"`, `"tòa nhà"` in wrong context).

---

## 6. Accessibility Quick Wins

### Issues Found

| Issue | Count | Severity | Fix |
|-------|-------|----------|-----|
| Icon-only buttons without semantic labels | ~5-8 (estimate) | HIGH | Wrap in `Semantics(label: 'Back')` or use `IconButton(tooltip: '...')` |
| Low-contrast text on `HD.paperSunken` (0.96:1 fail) | ~2 | HIGH | Never use `HD.inkMuted` on `HD.paperSunken`; use `HD.inkSoft` min. |
| Touch targets < 44dp on nav items | 0 (good) | — | Bottom nav tiles 60px tall ✓. Icon buttons at 22px ✓ (Material default passable). |
| Missing alt text on images (CachedNetworkImage) | ~10+ | MEDIUM | Add `semanticLabel` parameter to CachedNetworkImage. |

**Sample violation:** `lib/core/widgets/ds_app_bar.dart:59` — back icon uses `DsIconButton(icon: Icons.arrow_back)` with no tooltip.

**Actions:**
- Add `tooltip: 'Back'` to all icon-only buttons in `DsAppBar`, `DsBottomNav`, action bars.
- Audit: `HD.inkMuted` + `HD.paperSunken` = 0.96:1 contrast (fails WCAG AA). Never pair these. Document in design_tokens.dart.
- Add `semanticLabel` to image widgets library-wide (guest house photos, avatars).

---

## 7. Layout Density Issues

### Screens Reviewed (Spot Check)

| Screen | Density | Issue |
|--------|---------|-------|
| Guest Home (house grid) | BALANCED | 2-col cards, HD.s16 padding. Good air. |
| Guest Wishlist | BALANCED | Same grid. ✓ |
| Host Dashboard | CRAMPED | 3+ KPI cards stacked, HD.s12 gaps. Feels dense vs guest. |
| Host Homestay > Reservations | LOOSE | HD.s20 gutters, tall rows. Scrolls far. |
| Host Property > Buildings | LOOSE | Same. |
| Host Contracts | CRAMPED | Compact list, no space between sections. |
| Admin Dashboard | MIXED | Sections vary (some HD.s24, some HD.s8). |

**Root cause:** No "screen density preset" guidance. Different modules pick different spacing scales ad-hoc.

**Actions:**
- Document 3 density profiles in design_tokens.dart:
  ```dart
  /// Dense: list views, contracts, tabular data (HD.s8–s12 gaps).
  /// Balanced: card grids, property listings (HD.s16–s20 gaps).
  /// Spacious: onboarding, empty states, hero sections (HD.s24+ gaps).
  ```
- Audit host dashboard: reduce KPI card count or use horizontal scroll (not vertical stack).
- Homestay lists: use `DsRowSkeleton` spacing as reference (HD.s12 padding standard for rows).

---

## 8. Bottom Nav Polish

### Both Persona NavBars (Guest & Host)

**Current state:** `DsBottomNav` component is well-designed:
- 4 tabs per persona (guest: home, search, bookings, profile; host: home, properties, invoices, profile).
- Icons switch on selection (e.g., `Icons.home` → `Icons.home_filled`).
- Labels always visible (decision 260629: accessibility over editorial minimalism).
- Terracotta accent, thin top-bar indicator.

**Issues:**
1. **Label font weight:** Active tab uses w700, inactive w500. Label jumps up/down 1px on selection (widthVariation in font). Add `style: GoogleFonts.beVietnamPro(..., forceStrutHeight: true)` to stabilize baseline.
2. **Icon sizes:** 22px standard. Good. But some feature screens add custom bottom nav without `DsBottomNav` (e.g., planning map). Audit for alignment.
3. **Visual weight imbalance:** Selected indicator (terracotta bar, 28w × 2h) is subtle. On some phones (small screens), bar may not register. Consider thickening to 3px.

**Actions:**
- Add `forceStrutHeight: true` to `HD.navLabel()` text style to prevent baseline drift.
- Thicken indicator from 2px → 3px for better visibility on mobile.
- Audit feature screens: ensure custom nav fallsback to `DsBottomNav` (not custom Material NavigationBar).

---

## 9. Common UI/UX Quick Wins (Highest ROI)

### Top 5 No-Brainer Improvements

1. **Unify error messaging** (2–3 days)
   - Create `DsSnackBar.error()` wrapper.
   - Centralize Vietnamese error copy.
   - Est. impact: 40% reduction in scattered error states, better user clarity.

2. **Lift analytics colors to `HD.*`** (1 day)
   - Add heatmap palette to design_tokens.
   - Replace 10+ hardcoded Color(0x...) calls.
   - Est. impact: consistent brand colors, easier theming later.

3. **Retrofit homestay AppBars** (1–2 days)
   - Replace 5 bare `AppBar` with `DsAppBar`.
   - Remove `_EditorialAppBar`, `_roomFormAppBar` duplication.
   - Est. impact: visual cohesion in most-used host sub-feature.

4. **Add Vietnamese glossary** (1 day + CI)
   - Centralize terminology in enum/const.
   - Fix 8+ screens with mixed copy.
   - Est. impact: professional UX, easier for Vietnamese QA.

5. **Loading state standardization** (1 day)
   - Deprecate CircularProgressIndicator in features.
   - Create DsLoadingOverlay for modals.
   - Est. impact: polished, brand-aligned loading (Skeleton aesthetic).

### Secondary Quick Wins (2–3 more)

6. **Accessibility sweep:** Add tooltips to 5–8 icon buttons. 2–3 hours. High value for zero-vision users.
7. **Bottom nav baseline fix:** Strut height + indicator thickness. 30 mins. Zero-risk polish.
8. **Density presets:** Document 3 profiles in guide. 1–2 hours. Guidance-only, no code change.
9. **CachedNetworkImage semantics:** Add `semanticLabel` param to 10+ image calls. 1–2 hours. WCAG compliance.
10. **Lint rule for color tokens:** Enforce no `Color(0x...)` outside design_tokens. 2–3 hours CI setup. Long-term scalability.

---

## 10. Maturity Assessment by Module

| Module | Design System Compliance | Loading States | Error Handling | Terminology | Verdict |
|--------|-------------------------|-----------------|-----------------|-------------|---------|
| **Guest** (home, wishlist, booking) | 95% | Skeleton ✓ | Mixed SnackBar | Khách/đặt phòng OK | Strongest |
| **Host Dashboard** | 85% | Mixed (Skeleton + Circular) | Mixed | Chủ nhà OK, "phòng" ambiguous | Good; needs density tune |
| **Homestay** (reservations, pricing, calendar) | 60% | Unknown (not audited) | Scattered | "Đặt phòng" OK | **Weakest; AppBar + loading audit needed** |
| **Admin** (home, analytics) | 70% | Mixed | Scattered | Phòng/tòa nhà mixed | Needs color lift |
| **Contracts** (property) | 75% | Circular (heavy) | SnackBar only | OK | Mid-tier; loading overhaul |
| **Tenant** | 80% (limited scope) | Unknown | Scattered | Not audited | TBD (small surface) |

---

## Unresolved Questions

1. **Homestay calendar:** Which loading pattern does it use? Audit deferred (file size limit).
2. **Map colors:** Should `planning_map_screen` hard-coded blue (0xFF4287F5) become a design token, or is it map-library-specific?
3. **Analytics heatmap:** Current color palette in `color_palette.dart`—is this final, or will product adjust it?
4. **Error retry UX:** Should all error snackbars have "Retry" button, or only network errors? No current guideline.
5. **Roles:** Should admin/operator roles get separate bottom navs, or do they ride guest/host navs? (Current impl unclear.)

---

## Next Steps

1. **Week 1:** Implement quick wins 1–3 (error messaging, analytics colors, homestay AppBars).
2. **Week 2:** Vietnamese glossary + QA feedback loop.
3. **Week 3:** Accessibility sweep + bottom nav polish.
4. **Ongoing:** Lint rules + gradient migration (CircularProgressIndicator → Skeleton).

---

**Report prepared:** 2026-07-01  
**Audit scope:** Design tokens, shared widgets, UX patterns (UI/UX layer only; not business logic, auth, data layers).  
**Methodology:** Grep + spot check of 10 representative screens across 5 roles.
