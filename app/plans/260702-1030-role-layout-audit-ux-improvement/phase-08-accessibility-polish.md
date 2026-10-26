# Phase 08 — Accessibility & Polish

**Priority:** P3 | **Status:** pending | **Estimate:** 1 ngày | **Depends on:** Phase 05

## Context

Từ researcher-05: 5-8 icon-only button thiếu tooltip; 2 chỗ dùng `HD.inkMuted` trên `HD.paperSunken` (contrast 0.96:1, fail WCAG AA); 10+ CachedNetworkImage thiếu `semanticLabel`. Bottom nav baseline drift do font weight thay đổi. Density presets chưa document.

## Requirements

**Functional:**
- Icon-only button có tooltip
- Text contrast pass WCAG AA (4.5:1 cho body, 3:1 cho large)
- Image có semantic label
- Bottom nav: text baseline stable khi active/inactive

**Non-functional:**
- Không đổi visual đáng kể — polish only
- Không break dark mode nếu có

## Related files

**Modify:**
- `lib/core/widgets/ds_app_bar.dart` — tooltip cho back button + action icons
- `lib/core/widgets/ds_bottom_nav.dart` — forceStrutHeight + indicator thickness 2→3
- `lib/core/theme/design_tokens.dart` — density preset comment, contrast warning cho inkMuted/paperSunken pair
- Search `Icons\.` trong Icon-only IconButton — add tooltip
- Search `CachedNetworkImage(` — add semanticLabel

**Tạo mới:**
- `docs/accessibility-checklist.md`
- Breadcrumb widget `lib/core/widgets/ds_breadcrumb.dart` (optional cho phase sau)

## Implementation steps

1. **Bottom nav baseline fix** (30 phút):
   - Add `forceStrutHeight: true` vào text style của nav label
   - Indicator height 2px → 3px trong `DsBottomNav`
2. **Icon tooltip sweep** (2 giờ):
   - Grep `IconButton(icon: Icon(` không có `tooltip:` param
   - Add tooltip cho: back button (DsAppBar), share, favorite, more (DsCard actions), menu (drawer opener)
3. **Contrast fix** (1 giờ):
   - Grep `HD.inkMuted` + verify parent background
   - Nếu parent là `HD.paperSunken` → thay bằng `HD.inkSoft` (min 4.5:1)
   - Comment warning trong `design_tokens.dart`: "❌ inkMuted on paperSunken = 0.96:1"
4. **Semantic label cho images** (1 giờ):
   - Grep `CachedNetworkImage(`
   - Add `semanticLabel: house.title` cho house photos, `semanticLabel: user.name` cho avatar
5. **Density presets doc** (30 phút):
   - Comment trong `design_tokens.dart`:
     ```dart
     /// Density presets:
     /// - Dense: HD.s8–s12 (contract list, tabular)
     /// - Balanced: HD.s16–s20 (card grid, property list)
     /// - Spacious: HD.s24+ (onboarding, empty state)
     ```
6. **Accessibility checklist doc** (30 phút):
   - Checklist trong `docs/accessibility-checklist.md`
   - Reference từ CLAUDE.md
7. **Breadcrumb (optional):**
   - Nếu còn budget: `DsBreadcrumb` cho screen 3+ level deep (building → room → contract)
   - Nếu không: defer

## TODO checklist

- [ ] Bottom nav forceStrutHeight + indicator 3px
- [ ] Tooltip cho 5–8 icon button
- [ ] Fix inkMuted-on-paperSunken (2 chỗ)
- [ ] Semantic label cho CachedNetworkImage (10+ chỗ)
- [ ] Density presets comment
- [ ] `docs/accessibility-checklist.md`
- [ ] (Optional) DsBreadcrumb widget
- [ ] Smoke test với VoiceOver 3 màn (guest home, host dashboard, checkout)

## Success criteria

- Tooltip xuất hiện khi long-press icon-only button
- Bottom nav label không drift baseline khi active
- 0 WCAG AA fail cho main content (verified qua Flutter Accessibility Scanner hoặc manual)
- VoiceOver đọc được image label

## Risk

- **VoiceOver test cần thiết bị thật hoặc iOS Simulator** — nếu không có mobile toolchain (chưa cài Android SDK / Xcode incomplete), skip test này, giữ code change.
- **Font strut height có thể phá visual** trên một số ngôn ngữ khác — nhưng app chỉ Vietnamese, không worry.

## Out of scope

- Không add screen reader announcements cho SnackBar (Flutter handle)
- Không dark mode (nếu chưa có)
- Không keyboard navigation (mobile app)
- Không rebuild theme
