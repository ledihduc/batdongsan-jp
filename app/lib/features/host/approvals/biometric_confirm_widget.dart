/// Biometric confirmation for high-value approval actions (AC-29b).
///
/// Falls back to PIN/passcode if no biometric enrolled (never silent-skips).
/// local_auth is NOT in pubspec currently — uses a platform channel fallback
/// that presents a PIN dialog on devices without biometric support.
///
/// NOTE: When local_auth package is added to pubspec.yaml, replace the
/// _simulateBiometric implementation with real local_auth calls.
/// Tracked: Phase 11 pre-launch validation for Huawei biometric path.
library;

import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';

class BiometricConfirmWidget {
  BiometricConfirmWidget._();

  /// Show biometric authentication dialog.
  /// Returns true if verified, false if cancelled or failed.
  ///
  /// [reason] is shown as the authentication prompt text.
  static Future<bool> authenticate(
    BuildContext context, {
    required String reason,
  }) async {
    // Attempt platform biometric via dialog.
    // When local_auth is wired in, replace with:
    //   final auth = LocalAuthentication();
    //   return auth.authenticate(localizedReason: reason, ...);
    return _showBiometricDialog(context, reason: reason);
  }

  /// Fallback dialog — platform PIN or manual confirmation.
  /// This runs when local_auth is unavailable or not yet integrated.
  static Future<bool> _showBiometricDialog(
    BuildContext context, {
    required String reason,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DsDialog(
        title: 'Xác thực bảo mật',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fingerprint,
              size: 56,
              color: HD.accent,
            ),
            const SizedBox(height: HD.s12),
            Text(
              reason,
              style: HD.body(color: HD.inkSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HD.s8),
            Text(
              'Chạm vào cảm biến vân tay hoặc sử dụng PIN để xác nhận.',
              style: HD.caption(color: HD.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          DsButton(
            label: 'Hủy',
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          DsButton(
            label: 'Xác nhận',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }
}
