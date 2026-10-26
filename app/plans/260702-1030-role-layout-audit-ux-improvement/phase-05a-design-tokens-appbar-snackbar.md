# Phase 05a — Design Tokens + DsAppBar Retrofit + DsSnackBar

**Priority:** P1 | **Status:** pending | **Estimate:** 1.5 ngày | **Depends on:** none (parallel với 01/02)

## Context

Split từ Phase 05 v1 (2–3 ngày) thành 2 phase (05a + 05b) để scope realistic hơn (từ M3 Tech Lead review).

Phase 05a: tokens + AppBar retrofit + snackbar shared component (mechanical work).
Phase 05b: loading/error/empty state pattern sweep (design decision heavier).

Từ researcher-05: 23 hardcoded colors, 11 bare AppBar, 111 SnackBar rải rác.

## Requirements

**Functional:**
- 0 hardcoded `Color(0x...)` hoặc `Colors.*` trong `lib/features/` (chỉ trong `lib/core/theme/`)
- 0 bare `AppBar()` trong feature files — dùng `DsAppBar`
- Error state: dùng `DsSnackBar.error/success/warning/info` shared component

**Non-functional:**
- Không break visual — trước/sau phải giống nhau tương đối
- Không rewrite theme core
- **Dark mode readiness (M6):** token mới add phải có variant dark-ready (dù dark mode chưa enable — chỉ đảm bảo token structure hỗ trợ)

## Related files

**Đọc / mở rộng:**
- `lib/core/theme/design_tokens.dart` — thêm tokens mới (heatmap palette, chart colors, warningTint variants)
- `lib/core/widgets/ds_dialog.dart` — thêm `DsSnackBar`
- `lib/core/widgets/ds_app_bar.dart` — verify API compatibility

**Modify (bulk):**
- 23 file có hardcoded colors — replace bằng `HD.*`
- 11 file dùng bare AppBar — thay bằng `DsAppBar`:
  - `lib/features/host/homestay/screens/pricing_rules_list_screen.dart`
  - `lib/features/host/homestay/screens/pricing_rule_form_screen.dart`
  - `lib/features/host/homestay/screens/reservation_list_screen.dart`
  - `lib/features/host/homestay/screens/reservation_detail_screen.dart`
  - `lib/features/host/homestay/screens/unified_calendar_screen.dart`
  - `lib/features/host/homestay/screens/room_calendar_screen.dart`
  - `lib/features/host/homestay/screens/block_dates_screen.dart`
  - `lib/features/host/homestay/screens/homestay_home_screen.dart`
  - `lib/features/host/appointments/host_appointments_screen.dart`
  - `lib/features/host/property/screens/building_detail_screen.dart` (custom `_EditorialAppBar`)
  - `lib/features/host/property/screens/room_form_screen.dart` (custom `_roomFormAppBar`)

**Tạo mới:**
- `lib/core/widgets/ds_snackbar.dart` với `DsSnackBar.error/success/warning/info`
- `lib/core/localization/error_messages.dart` — Vietnamese error copy

## Implementation steps

1. **Design tokens mở rộng** (0.5 ngày):
   - Thêm heatmap palette: `HD.calendarVacant`, `HD.calendarBooked`, `HD.calendarPaid`, `HD.calendarOverdue`
   - Thêm chart colors: `HD.chartCurrent`, `HD.chartPrevious`, `HD.chartAverage`
   - Thêm tint variants: `HD.warningTint`, `HD.dangerTint`
   - Comment mapping cũ → mới cho reference
   - **Dark-ready structure:** mỗi token nếu có variant thì grouped (`HD.light.chartCurrent` + `HD.dark.chartCurrent`) — nếu chỉ 1 variant, comment `// TODO dark mode`
2. **DsSnackBar + error messages** (0.5 ngày):
   - Tạo `DsSnackBar` với 4 variants — icon + color + retry callback optional
   - Centralize copy trong `error_messages.dart` — enum `AppErrorType { network, notFound, permission, validation, unknown }`
   - Migration guide: `ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(...))` → `DsSnackBar.error(ctx, 'message')`
3. **AppBar retrofit** (0.5 ngày):
   - Grep 11 file, replace `AppBar(...)` → `DsAppBar(...)` — 99% API compatible
   - Xóa `_EditorialAppBar`, `_roomFormAppBar` helpers
   - Verify: back button, title, actions all preserved
4. **Color audit** (0.5 ngày):
   - Grep `Color(0x` và `Colors\.` trong `lib/features/`
   - Cross-reference bảng trong researcher-05 report
   - Replace theo mapping

## Testing

**Automated:**
- `flutter analyze` = 0 issues
- Golden test cho DsSnackBar 4 variants (nếu chọn testing budget)

**Manual:**
- Visual regression: screenshot before/after 10 màn key
- Run app trên guest + host mode, spot check color/appbar consistency

## TODO checklist

- [ ] Design tokens: heatmap + chart + tint palette (dark-ready structure)
- [ ] `DsSnackBar` 4 variants
- [ ] `error_messages.dart` centralized copy
- [ ] Retrofit 11 file bare AppBar → DsAppBar
- [ ] Xóa `_EditorialAppBar`, `_roomFormAppBar`
- [ ] Replace hardcoded colors (23 instances)
- [ ] `flutter analyze` clean
- [ ] Visual spot check 10 màn

## Success criteria

- `grep -rn "Color(0x" lib/features/` → 0 kết quả
- `grep -rn "^\s*AppBar(" lib/features/` → 0 kết quả
- SnackBar usage: 100% migrate sang DsSnackBar (11 known + rest via grep)
- Design tokens có dark-ready structure

## Risk

- **Visual regression:** replace bulk có thể vỡ layout. Mitigation: screenshot diff, spot check key màn.
- **Homestay complexity:** custom AppBar có behavior đặc thù. Mitigation: extract behavior thành props của DsAppBar (`rightWidget`, `bottom` param).

## Out of scope

- Không rebuild design tokens core (typography, spacing scale)
- Không thay đổi color palette brand (chỉ mở rộng semantic tokens)
- Không loading/error/empty state pattern (Phase 05b)
- Không animation/transition mới
