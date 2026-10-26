// Helper used at all 6 image_picker call sites.
// Inserts priming sheet before the OS picker when appropriate.
// Never calls permission_handler directly — image_picker handles OS dialog.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/permissions/permission_service.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/helpers/priming_presenter.dart';

/// One-liner used at all 6 image_picker call sites.
///
/// Flow:
/// 1. On web: skip priming, call picker directly (browser controls flow).
/// 2. Query [PermissionService.shouldShowCameraPriming]; if true, show sheet.
///    - User taps "Hủy" → [service.deferCamera] → return null (caller no-ops).
///    - User taps "Tiếp tục" → [service.grantCamera] → proceed.
/// 3. Call [ImagePicker.pickImage(source: source)]. image_picker triggers the
///    OS permission dialog on first call automatically (no permission_handler needed).
/// 4. Return [XFile?] to caller — null on cancel or perm deny.
///
/// [source]: ImageSource.camera or ImageSource.gallery.
/// [primingContext]: which [CameraContext] to record for this call site.
/// [userId]: current authenticated user ID as string.
Future<XFile?> withCameraPermission(
  BuildContext context, {
  required ImageSource source,
  required CameraContext primingContext,
  required String userId,
}) async {
  // Web: browser file input owns the permission flow — skip priming entirely.
  if (kIsWeb) {
    return ImagePicker().pickImage(source: source);
  }

  // Try to get PermissionService from Provider tree; degrade gracefully if absent.
  PermissionService? service;
  try {
    service = Provider.of<PermissionService>(context, listen: false);
  } catch (_) {
    // PermissionService not yet wired in Provider — skip priming, go straight to picker.
    // This can happen during development before main.dart injection is complete.
  }

  if (service != null) {
    final shouldPrime = await service.shouldShowCameraPriming(userId, primingContext);

    if (shouldPrime) {
      // context may be stale after async gap — check mount state.
      if (!context.mounted) return null;

      final outcome = await PrimingPresenter.presentCamera(context, primingContext);

      if (outcome == PrimingOutcome.accept) {
        await service.grantCamera(userId: userId, context: primingContext);
      } else {
        // User tapped "Hủy" — defer, return null without opening picker.
        await service.deferCamera(userId, primingContext);
        return null;
      }
    }
  }

  // Context safety check before picker call.
  if (!context.mounted) return null;

  // image_picker will trigger OS permission dialog on first call.
  // On permanent deny, it returns null silently — caller null-check handles this.
  return ImagePicker().pickImage(source: source);
}
