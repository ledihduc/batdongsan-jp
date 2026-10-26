# Phase 03 — Priming UI Widgets

**Status:** pending | **Effort:** 6h | **Depends on:** Phase 1 | **Blocks:** Phase 4

## Context Links

- BA Section 4 (all AC-N + AC-C + AC-V), Section 10.1 (revised ACs)
- Copy bank: `reports/researcher-priming-ux-copy.md` Sections 3 (A–F), 6 (wireframe), 8 (a11y)
- Existing brand: `lib/theme/` (red `#B71C1C`, green `#00A65A`)
- Existing UI patterns: `lib/widgets/` (reuse `AppButton` if present)

## Overview

Build presentation layer — pure stateless/stateful widgets that consume `PermissionService` callbacks but contain NO permission logic themselves. Role/context routing is data-driven (lookup map) to avoid 9-arm switch.

## Key Insights

- **Copy is VERBATIM from researcher Section 3** — do not paraphrase (BA review L1 + research already validated tone).
- **Buttons must have equal visual weight** (research Section 8) — both primary AND secondary are full-width 48px-tall. "Để Sau" is NOT a text link.
- **Sheet height ~70% of screen**, not full-screen modal (research Section 6) — feels less pushy.
- **Web sheet uses same widget tree** (responsive) — branching only inside `PermissionService`, not in UI.
- **Soft re-ask banner** is separate widget — appears in-app, no OS dialog (AC-N3).

## Requirements

### Functional

- 4 widget classes: notification priming sheet, camera priming sheet, soft re-ask banner, settings card.
- Notification sheet has 3 role variants (guest/host/admin) — copy lookup by `UserRole` enum.
- Camera sheet has 6 context variants (CCCD/post_house/contract/contract_terminate/avatar/report) — copy lookup by `CameraContext` enum.
- Web variant of notification sheet does NOT render if `Notification.permission == 'granted'` (AC-N6) — pre-check happens in `PermissionService`, widget receives a `bool shouldRender` from controller.

### Non-functional

- VN copy only (i18n-ready structure — keys live in a single `priming_copy.dart` file).
- WCAG AA: 4.5:1 contrast, 48px touch targets, screen reader labels.
- Lottie illustrations optional (use icon + colored circle background as MVP fallback to avoid asset blocker).
- All copy strings centralized — Phase 7 tests can assert exact strings.

## Architecture

```
lib/features/permissions/
├── widgets/
│   ├── notification_priming_sheet.dart   (modal bottom sheet, role-aware)
│   ├── camera_priming_sheet.dart         (modal bottom sheet, context-aware)
│   ├── soft_reask_banner.dart            (top banner, dismissible)
│   ├── permission_settings_card.dart     (settings screen tile)
│   └── _priming_button_pair.dart         (shared "Bật / Để sau" component)
├── copy/
│   └── priming_copy.dart                 (all VN strings — single source of truth)
└── helpers/
    └── priming_presenter.dart            (showModalBottomSheet wrappers, returns enum)
```

## Related Code Files

### Create (all NEW)

- `lib/features/permissions/widgets/notification_priming_sheet.dart`
- `lib/features/permissions/widgets/camera_priming_sheet.dart`
- `lib/features/permissions/widgets/soft_reask_banner.dart`
- `lib/features/permissions/widgets/permission_settings_card.dart`
- `lib/features/permissions/widgets/_priming_button_pair.dart`
- `lib/features/permissions/copy/priming_copy.dart`
- `lib/features/permissions/helpers/priming_presenter.dart`

### Modify

- None this phase (integration in Phase 4).

### Delete

- None.

## Copy Source-of-Truth (`priming_copy.dart`)

Reference labels from `reports/researcher-priming-ux-copy.md`:

| Widget | Role / Context | Section | Variant to use |
|--------|---------------|---------|----------------|
| Notification sheet | guest | Section 3.A | **Medium (30 words)** |
| Notification sheet | host | Section 3.B | **Medium (35 words)** |
| Notification sheet | admin | Section 3.C | **Medium (35 words)** |
| Camera sheet | cccdUpload | Section 3.D | **Medium (40 words)** |
| Camera sheet | postHousePhoto | Section 3.E | **Medium (40 words)** |
| Camera sheet | profileAvatar | Section 3.F | **Medium (40 words)** |
| Camera sheet | contractPhoto | Section 3.D adapted | Medium (use CCCD wording, swap "chứng minh thư" → "hợp đồng") |
| Camera sheet | contractTerminatePhoto | Section 3.D adapted | Medium (swap → "biên bản kết thúc") |
| Camera sheet | reportErrorPhoto | NEW (not in research — write inline) | "Chụp ảnh sự cố để chúng tôi xử lý nhanh hơn. Ảnh giúp đội hỗ trợ hiểu vấn đề chính xác trong vài giây." |
| Soft re-ask banner | notification | Section 5 Pattern B (inline) | "Bạn đã tắt thông báo. Bật trong Cài đặt để không bỏ lỡ tin nhắn." |
| Soft re-ask banner | camera | Section 5 Pattern B (inline) | "Bạn đã tắt camera. Bật trong Cài đặt để chụp ảnh phòng." |
| Settings card | notification | Section 5 Pattern A | "Bật thông báo → Đi tới Cài đặt" |

**Button labels (universal):** "Bật ngay" (primary) / "Để sau" (secondary) / "Đóng" (close X).

## ASCII Wireframes

### Notification priming sheet (per researcher Section 6, adapted for ancu365 brand)

```
┌─────────────────────────────────────────┐
│  ✕                                       │  ← close button, top-right
├─────────────────────────────────────────┤
│         ┌───────────┐                   │
│         │    🔔     │                   │  ← 64px icon, brand red circle bg
│         └───────────┘                   │
│                                          │
│   Đừng bỏ lỡ phòng yêu thích             │  ← headline, role-specific
│                                          │
│   Nhận thông báo khi có phòng mới được   │  ← body, Medium variant
│   đăng, tin nhắn từ chủ nhà, và các ưu  │
│   đãi đặc biệt dành riêng cho bạn.       │
│                                          │
│   ☑ Tắt bất kỳ lúc nào                  │  ← trust signal
│   ☑ Không spam — chỉ thông tin hữu ích  │
│                                          │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐    │
│  │       Bật thông báo              │    │  ← primary, full-width 48px, red
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │       Để sau                     │    │  ← secondary, outline, SAME size
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### Camera priming sheet (CCCD context)

```
┌─────────────────────────────────────────┐
│  ✕                                       │
├─────────────────────────────────────────┤
│         ┌───────────┐                   │
│         │    📷     │                   │  ← 64px camera icon
│         └───────────┘                   │
│                                          │
│   Xác minh danh tính với CCCD           │
│                                          │
│   Xác minh danh tính nhanh chóng với    │  ← Section 3.D Medium variant
│   ảnh chứng minh thư:                   │
│   • Quá trình xác minh tự động (<1 phút)│
│   • Ảnh của bạn được mã hóa và lưu     │
│     trữ an toàn                          │
│   • Chúng tôi không bao giờ chia sẻ    │
│     ảnh của bạn với bên thứ ba         │
│                                          │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐    │
│  │       Tiếp tục                   │    │  ← primary (camera uses "Tiếp tục" per AC-C1)
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │       Huỷ                        │    │  ← secondary per AC-C1
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### Soft re-ask banner (in-app, dismissible — Pattern B)

```
┌─────────────────────────────────────────────────────────────┐
│ ℹ  Bạn đã tắt thông báo. Bật trong Cài đặt để không bỏ lỡ │
│    tin nhắn.   [Mở Cài đặt]  [Bỏ qua]                  ✕   │
└─────────────────────────────────────────────────────────────┘
```

### Settings card (in profile/settings screen — Pattern A)

```
┌──────────────────────────────────────┐
│  🔔  Thông báo                       │
│      Trạng thái: Đã tắt              │
│                                      │
│            [Bật → Đi tới Cài đặt]   │
└──────────────────────────────────────┘
```

## Widget Signatures

### `notification_priming_sheet.dart`

```dart
class NotificationPrimingSheet extends StatelessWidget {
  const NotificationPrimingSheet({
    super.key,
    required this.role,
    required this.onAccept,   // controller calls service.grantNotification(...)
    required this.onDefer,    // controller calls service.deferNotification(...)
    required this.onClose,    // same as defer per AC + M2 (kill = defer)
  });
  final UserRole role;
  final VoidCallback onAccept;
  final VoidCallback onDefer;
  final VoidCallback onClose;
}
```

### `camera_priming_sheet.dart`

```dart
class CameraPrimingSheet extends StatelessWidget {
  const CameraPrimingSheet({
    super.key,
    required this.context,    // CameraContext (re-named field to avoid shadowing build context)
    required this.onContinue, // service.grantCamera(...)
    required this.onCancel,
  });
  final CameraContext context;
  final VoidCallback onContinue;
  final VoidCallback onCancel;
}
```

### `soft_reask_banner.dart`

```dart
class SoftReaskBanner extends StatelessWidget {
  const SoftReaskBanner({
    super.key,
    required this.kind,             // PermissionKind
    required this.onOpenSettings,   // service.openSettingsForNotification(...)
    required this.onDismiss,
  });
  final PermissionKind kind;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;
}
```

### `permission_settings_card.dart`

```dart
class PermissionSettingsCard extends StatelessWidget {
  const PermissionSettingsCard({
    super.key,
    required this.kind,
    required this.isGranted,       // current OS status (Phase 4 fetches)
    required this.onTapEnable,     // opens settings
  });
  final PermissionKind kind;
  final bool isGranted;
  final VoidCallback onTapEnable;
}
```

### `priming_presenter.dart`

```dart
class PrimingPresenter {
  /// Wraps showModalBottomSheet. Returns the outcome enum so caller knows
  /// what to record. Height ~70%, isDismissible=true, isScrollControlled=true.
  static Future<PrimingOutcome> presentNotification(
    BuildContext context, UserRole role,
  );

  static Future<PrimingOutcome> presentCamera(
    BuildContext context, CameraContext primingContext,
  );

  /// Inline insert (not modal): caller wraps in Column/ListView at top of screen.
  static Widget buildSoftReaskBanner(PermissionKind kind, {
    required VoidCallback onOpenSettings,
    required VoidCallback onDismiss,
  });
}
```

## Implementation Steps

1. Create `priming_copy.dart` — define `class PrimingCopy { static String notificationHeadline(UserRole r); static String notificationBody(UserRole r); ... }`. All strings VERBATIM from research table above.
2. Create `_priming_button_pair.dart` — shared `Column` of two `SizedBox(width: double.infinity, height: 48)` buttons. Primary = `ElevatedButton` (red), Secondary = `OutlinedButton` (same height).
3. Build `NotificationPrimingSheet` — root is `Container` with `BorderRadius.vertical(top: Radius.circular(20))`, padding 24, contains close X + icon circle + headline (titleLarge bold) + body (bodyMedium) + trust bullets + `_PrimingButtonPair`.
4. Build `CameraPrimingSheet` — same scaffold, swap copy and button labels per AC-C1.
5. Build `SoftReaskBanner` — `Material` with `Colors.amber.shade50`, icon + text + 2 text buttons + close X.
6. Build `PermissionSettingsCard` — `Card` with `ListTile`-style layout for settings screen reuse.
7. Build `PrimingPresenter.presentNotification` — calls `showModalBottomSheet<PrimingOutcome>(isScrollControlled: true, useSafeArea: true, ...)` returning the chosen outcome.
8. Add `aria-label` equivalents via `Semantics` wrappers on close X + both buttons (researcher Section 8).
9. Golden tests (Phase 7) verify per-role rendering — leave file stubs.

## Todo List

- [ ] `priming_copy.dart` with all VN strings keyed by enum
- [ ] `_priming_button_pair.dart` shared button row
- [ ] `NotificationPrimingSheet` widget + 3 role variants render
- [ ] `CameraPrimingSheet` widget + 6 context variants render
- [ ] `SoftReaskBanner` widget
- [ ] `PermissionSettingsCard` widget
- [ ] `PrimingPresenter` static helpers
- [ ] Semantics labels on all interactive elements
- [ ] Widget compiles for iOS + Android + Web (run `flutter build web` smoke)

## Success Criteria

- All 4 widgets render correctly on 5.4" iPhone SE, 6.7" Pixel 7 Pro, Chrome desktop 1280×720.
- Touch targets ≥48×48px (run Flutter Inspector).
- Contrast ratio ≥4.5:1 on text (verify with Accessibility Scanner).
- Copy strings match research table verbatim (Phase 7 has string-match test).
- AC-V1 (visual consistency), AC-V3 (i18n-ready) met.
- AC-C1 wireframe matches research Section 6 exactly.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Copy drift between research and code | M | M | `priming_copy_test.dart` asserts exact strings; reviewer cross-checks |
| Bottom sheet jumps when keyboard appears (rare on this sheet) | L | L | `useSafeArea: true` + no text fields in sheets |
| Web responsive — sheet looks awkward on wide screen | M | M | Cap maxWidth: 480 on web via `MediaQuery`; centered |
| Icon-only fallback feels cold | M | M | Acceptable for MVP; add Lottie post-launch (research Section 7) |
| Accidental "Don't Allow" styling = text link (dark pattern, CPPA) | L | H | Lint rule: code reviewer confirms `_PrimingButtonPair` used everywhere |

## Security Considerations

- No user data rendered in copy.
- No external image URLs (illustrations baked in `assets/`).
- Web sheet: no `dangerouslySetInnerHTML`-equivalent (Flutter Web uses RenderObjects, safe by default).
- Settings deep-link button delegates to service layer — widget never calls `openAppSettings()` directly.

## Next Steps

- Phase 4 wires `PrimingPresenter` into login flow + 6 image_picker call sites.
- Phase 7 writes widget golden tests + per-role rendering tests.
