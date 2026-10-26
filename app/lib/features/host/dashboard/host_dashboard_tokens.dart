/// Legacy path — re-exports global design tokens.
///
/// The `HD` class and `HDHairline` widget moved to
/// `lib/core/theme/design_tokens.dart` and are now the single source of truth
/// for ALL screens (host + guest + auth), not just host dashboard.
///
/// Existing imports of `host_dashboard_tokens.dart` continue to work via this
/// re-export. New code should import from `core/theme/design_tokens.dart`.
///
/// This shim will be removed after phase 12 cleanup (260629 design refresh).
library;

export 'package:house_booking/core/theme/design_tokens.dart' show HD, HDHairline;
