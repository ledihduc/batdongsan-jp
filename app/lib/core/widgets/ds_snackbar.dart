/// Editorial Cockpit — SnackBar helpers.
///
/// Thin re-export layer around [AppFeedback] so new code can adopt the
/// `Ds*` naming convention without breaking existing call sites. When
/// [AppFeedback] is fully migrated, the compat alias below can be removed.
library;

import 'package:flutter/material.dart';

import '../localization/error_messages.dart';
import 'empty_state.dart' show AppFeedback;

/// SnackBar variants — all Editorial Cockpit toned.
///
/// Usage:
/// ```dart
/// DsSnackBar.error(context, 'Không tải được danh sách');
/// DsSnackBar.forType(context, AppErrorType.network);
/// DsSnackBar.success(context, 'Đã lưu thay đổi');
/// ```
class DsSnackBar {
  const DsSnackBar._();

  static void error(BuildContext context, String message) =>
      AppFeedback.error(context, message);

  static void success(BuildContext context, String message) =>
      AppFeedback.success(context, message);

  static void warning(BuildContext context, String message) =>
      AppFeedback.warning(context, message);

  static void info(BuildContext context, String message) =>
      AppFeedback.info(context, message);

  /// Shortcut — render the canonical Vietnamese copy for a known error type.
  /// Encourages using [AppErrorMessages] over ad-hoc strings.
  static void forType(BuildContext context, AppErrorType type) =>
      AppFeedback.error(context, AppErrorMessages.forType(type));
}
