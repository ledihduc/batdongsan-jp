// Static helpers wrapping showModalBottomSheet for permission priming flows.
// Returns PrimingOutcome enum so caller can record analytics and decide next step.
// These helpers only show UI — the actual OS permission request happens in Phase 4.
// MUST NOT import permission_handler or firebase_messaging here.

import 'package:flutter/material.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/widgets/camera_priming_sheet.dart';
import 'package:house_booking/features/permissions/widgets/notification_priming_sheet.dart';
import 'package:house_booking/features/permissions/widgets/soft_reask_banner.dart';

/// Presentation-layer helpers for showing priming UI.
///
/// Each method returns a [PrimingOutcome] value so the caller (Phase 4 service)
/// knows whether to proceed with the OS permission dialog or record a defer.
///
/// Usage:
/// ```dart
/// final outcome = await PrimingPresenter.presentNotification(context, UserRole.guest);
/// if (outcome == PrimingOutcome.accept) { ... trigger OS permission ... }
/// ```
class PrimingPresenter {
  PrimingPresenter._();

  // ─────────────────────────────────────────────────────────────────────────
  // Notification priming
  // ─────────────────────────────────────────────────────────────────────────

  /// Shows the notification priming bottom sheet and returns the user's outcome.
  ///
  /// Sheet height is ~70% of screen (`initialChildSize: 0.7`).
  /// Returns [PrimingOutcome.accept] when user taps "Bật ngay".
  /// Returns [PrimingOutcome.defer] when user taps "Để sau" or closes the sheet.
  static Future<PrimingOutcome> presentNotification(
    BuildContext context,
    UserRole role,
  ) async {
    final outcome = await showModalBottomSheet<PrimingOutcome>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: NotificationPrimingSheet(
            role: role,
            onAccept: () => Navigator.of(context, rootNavigator: true)
                .pop(PrimingOutcome.accept),
            onDefer: () => Navigator.of(context, rootNavigator: true)
                .pop(PrimingOutcome.defer),
            onClose: () => Navigator.of(context, rootNavigator: true)
                .pop(PrimingOutcome.defer),
          ),
        ),
      ),
    );

    // If user dismissed by tapping outside (null), treat as defer per spec M2.
    return outcome ?? PrimingOutcome.defer;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Camera priming
  // ─────────────────────────────────────────────────────────────────────────

  /// Shows the camera priming bottom sheet and returns the user's outcome.
  ///
  /// Returns [PrimingOutcome.accept] when user taps "Tiếp tục".
  /// Returns [PrimingOutcome.defer] when user taps "Hủy" or closes the sheet.
  static Future<PrimingOutcome> presentCamera(
    BuildContext context,
    CameraContext primingContext,
  ) async {
    final outcome = await showModalBottomSheet<PrimingOutcome>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: CameraPrimingSheet(
            cameraCtx: primingContext,
            onContinue: () => Navigator.of(context, rootNavigator: true)
                .pop(PrimingOutcome.accept),
            onCancel: () => Navigator.of(context, rootNavigator: true)
                .pop(PrimingOutcome.defer),
          ),
        ),
      ),
    );

    return outcome ?? PrimingOutcome.defer;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Soft re-ask
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a [SoftReaskBanner] widget for the caller to embed in a Column/Stack.
  ///
  /// This is NOT a modal — caller inserts it at the top of the screen.
  /// [onOpenSettings] should delegate to service.openAppSettings() in Phase 4.
  /// [onDismiss] should record the 30-day cooldown.
  static Widget buildSoftReaskBanner(
    PermissionKind kind, {
    required VoidCallback onOpenSettings,
    required VoidCallback onDismiss,
  }) {
    return SoftReaskBanner(
      kind: kind,
      onOpenSettings: onOpenSettings,
      onDismiss: onDismiss,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internal helper (not public API): map null sheet result → defer outcome.
  // ─────────────────────────────────────────────────────────────────────────

  /// Shows a bottom sheet returning [PrimingOutcome]. Null result → [PrimingOutcome.defer].
  static Future<void> showSoftReask(
    BuildContext context,
    PermissionKind kind, {
    required VoidCallback onOpenSettings,
  }) async {
    // Not a modal — this method is a no-op helper for interface completeness.
    // Callers should use [buildSoftReaskBanner] and insert it into the widget tree.
    // Kept here so Phase 4 can call it without knowing the implementation details.
  }
}
