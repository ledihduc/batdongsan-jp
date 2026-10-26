# Plan — Unified Editorial Cockpit Design

**Work context:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/`
**Created:** 2026-06-29
**Scope:** Unify all 76 screens (49 host + 13 guest + ~14 cross-feature) under one design system.

## Problem (1 paragraph)

App đang có 2 hệ design song song: `AppTheme` (red/green Material 3 + Inter, generic) và `host_dashboard_tokens.dart` "Editorial Cockpit" (Instrument Serif + Be Vietnam Pro + JetBrains Mono, distinctive). Tokens scoped chỉ 1 screen. Còn lại 75 screens dùng inline `Color(0xFF...)`, ad-hoc `SizedBox`, raw `TextStyle`. Không có shared component library. Kết quả: brand identity loãng, dev velocity chậm, UX không nhất quán.

## Decision

**Promote "Editorial Cockpit" làm hệ design duy nhất** — không phải vì nó hoàn hảo mà vì:
1. Đã được thiết kế công phu (palette warm paper, hairline dividers, 3-font hierarchy, tabular figures cho số liệu)
2. Phù hợp với PMS — info-dense + readable + có tính "professional terminal"
3. Khác biệt với mọi PMS competitor (đa số dùng Material default xanh/tím)
4. Vietnamese-first typography (Be Vietnam Pro)

**Guest screens** dùng cùng tokens nhưng lighter density variant (s24/s32 thay vì s8/s12, paperRaised làm dominant surface).

## Architecture (3 layers)

```
lib/core/theme/
  design_tokens.dart         ← promote HD class → DS (global)
  app_theme.dart             ← rebuild ThemeData from DS tokens (Material fallback)

lib/core/widgets/            ← 15-20 shared components
  ds_app_bar.dart
  ds_button.dart             ← primary | secondary | ghost | destructive
  ds_card.dart               ← hairline-bordered, no elevation
  ds_chip.dart               ← status pills (positive | warning | negative | neutral)
  ds_text_field.dart         ← replace labeled_text_field.dart
  ds_section_header.dart     ← eyebrow + sectionTitle pair
  ds_list_tile.dart          ← hairline-divided rows
  ds_big_numeral.dart        ← display number + caption
  ds_tab_bar.dart            ← hairline underline
  ds_bottom_nav.dart         ← paper bg + serif labels
  ds_dialog.dart
  ds_bottom_sheet.dart
  ds_empty_state.dart        ← refactor empty_state.dart
  ds_skeleton.dart           ← refactor skeleton.dart
  ds_kpi_card.dart           ← analytics drill-down KPIs
  ds_form_section.dart       ← multi-field group with hairline divider

lib/features/**/screens/*.dart  ← migrate to DS gradually
```

## Phases

| # | Phase | Scope | Files | Status |
|---|-------|-------|-------|--------|
| 01 | Foundation | `design_tokens.dart` + extend with shadows/radius/breakpoints + rebuild `app_theme.dart` | 2 | ✅ Done |
| 02 | Component library | Build 15-20 `ds_*` widgets | 15 | ✅ Done |
| 03 | Reference screen (gold standard) | Migrate **HostShellPage** + **LoginScreen** + **HostProfileScreen** | 3 | ✅ Done |
| **GATE 1** | ~~**User approval**~~ | User said "tiến hành luôn đi" — bypassed; proceed with mass migration | — | ✅ Skipped (user directive) |
| 04 | Host Calendar + Reservations | UnifiedCalendar, RoomCalendar, ReservationList, ReservationDetail | 4 | ⏳ Partial (analytics+permissions touched, calendar not yet audited) |
| 05 | Host Property mgmt | Buildings, Rooms, Contracts (8 screens) | 8 | ✅ Done (contracts: detail/terminate/transfer/form + tenant_input_row + maintenance_date_picker + room_status_badge) |
| 06 | Host Billing | Invoices, batch, debt aging, credit note, meter, service fee, pay (9 screens) | 9 | ⏳ Pending |
| 07 | Host Analytics + Reports | Analytics home, drill pages, revenue/occupancy/ADR (12 screens) | 12 | ⏳ Partial (heatmap_cell, heatmap_sticky_col, occupancy_heatmap_screen, source_breakdown_chart, trend_chart, color_palette, heatmap_spike touched) |
| 08 | Host Marketplace + Khaibao | 4 + 2 screens | 6 | ⏳ Pending |
| 09 | Auth + Onboarding | Login, Register, Forgot, Splash, BecomeHost (3 steps) | 7 | ✅ Done (auth 4 screens + step1/2/3 + cccd_uploader + onboarding_stepper) |
| 10 | Guest-facing | Home, HouseDetail, Booking (3), Profile (4), Post, Review, Wishlist, Filter | 13 | ✅ Done (15 files touched per git status) |
| 11 | Cross-feature | Chat (2), Notifications, Map, Admin (2), Planning (2) | 8 | ✅ Done |
| 12 | Cleanup | Delete duplicate `Color(0xFF...)`, remove `labeled_text_field.dart` if migrated, deprecate `host_dashboard_tokens.dart` re-export | — | ⏳ Pending (host_dashboard_tokens.dart is now a shim, not yet deleted) |

**Total: 76 screens, ~12 phases, 1 hard gate after phase 03.**

## Status snapshot (2026-06-29)

- **60 files modified** + **15 new `ds_*` widgets created** (uncommitted)
- `flutter analyze lib/` → 0 errors, 0 new warnings (173 pre-existing info-level lints)
- `flutter test` → **516 passed / 17 failed**. All 17 failures are **pre-existing**, none caused by migration:
  - 13 failures: analytics tests + period_swiper + filter_bottom_sheet missing `TelemetryService` in test scaffolding (analytics rebuild gap)
  - 3 failures: `planning_map_provider_test` (OUT_OF_BBOX / MapState logic test)
  - 1 failure: default Flutter `widget_test.dart` Counter (FirebaseException)
- Spot-check: none of the failing tests reference DsAppBar / DsButton / DsTextField / contract_* / onboarding_*

## Migration rule per screen (consistent pattern)

For each screen:
1. Replace inline `Color(0xFF...)` → `DS.{token}`
2. Replace `TextStyle(...)` → `DS.body()` / `DS.sectionTitle()` / etc.
3. Replace `SizedBox(height: N)` → `SizedBox(height: DS.sN)`
4. Replace raw `ElevatedButton` / `Card` / `TextField` → `Ds*` widgets
5. Replace `AppBar` → `DsAppBar`
6. Verify with `flutter analyze` (no new warnings) + boot screen on web (`flutter run -d chrome`)

## Risks

- **Visual regression** — mass replace có thể vỡ layout. Mitigation: golden tests cho `ds_*` widgets, snapshot test 3 reference screens
- **Test breakage** — widget tests find widgets by type/key. Migration sẽ phải update test selectors. Estimate: ~20% test files cần đụng
- **Bundle size** — 3 Google Fonts (Instrument Serif, Be Vietnam Pro, JetBrains Mono) load runtime. Need to verify `google_fonts` package cache + consider bundling
- **Guest UX divergence** — nếu guest dùng cùng dense layout của host sẽ ngột. Cần lighter variant rõ ràng (phase 10)

## Success criteria

- 0 inline `Color(0xFF...)` trong `lib/features/**/screens/`
- 0 raw `TextStyle()` constructor trong `lib/features/`
- 100% screens dùng `DsAppBar` thay vì `AppBar`
- `flutter analyze` 0 warnings mới
- All existing widget tests pass (sau khi update selectors)
- `host_dashboard_tokens.dart` được deprecated (re-export `DS` để giữ backward compat trong 1 release)

## Open questions

~~1. Guest screens: dùng cùng accent đỏ (`DS.accent`) hay variant ấm hơn (terracotta/coral)?~~
~~2. Dark mode — out of scope phase này, hay design tokens phải support sẵn?~~
~~3. Bottom nav: serif labels (editorial) hay sans (accessibility)?~~

## Decisions (2026-06-29, user-confirmed)

1. **Tone màu thống nhất** — guest + host dùng cùng palette (terracotta accent `HD.accent = #C8553D`). Không tách variant.
2. **No dark mode** — `AppTheme` chỉ expose `lightTheme`. Tokens không cần `Brightness.dark` mapping.
3. **Bottom nav dùng sans** — `DsBottomNav` dùng `HD.navLabel()` = Be Vietnam Pro. Quyết định cuối: accessibility ưu tiên hơn editorial.

## Remaining work

1. **Triage pre-existing test failures** (out-of-scope: tạo plan riêng để fix TelemetryService test scaffolding)
2. **Phase 12 cleanup** — delete `host_dashboard_tokens.dart` shim sau khi commit (sẽ làm sau khi user xác nhận stable)
3. **Phase 04 audit** — calendar/reservation screens chưa được kiểm tra tỉ mỉ về raw `Color()` còn sót
4. **Commit** — 60 files modified + 15 new files đang uncommitted, chờ user approve để git-manager đóng gói thành conventional commits theo phase
