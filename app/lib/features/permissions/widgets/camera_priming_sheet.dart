// Camera permission priming bottom sheet.
// Context-aware: displays context-specific copy from PrimingCopy.camera map.
// Uses brand green for camera icon circle background.
// Button labels per AC-C1: "Tiếp tục" (primary) / "Hủy" (secondary).
// NO permission logic — only UI + callbacks.

import 'package:flutter/material.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/copy/priming_copy.dart';
import 'package:house_booking/features/permissions/widgets/_priming_button_pair.dart';
import 'package:house_booking/features/permissions/widgets/_priming_sheet_parts.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Bottom sheet presenting camera permission priming to the user.
///
/// [cameraCtx]  — determines which copy variant is shown (6 contexts).
///               Named [cameraCtx] to avoid shadowing [BuildContext].
/// [onContinue] — called when user taps "Tiếp tục"; caller invokes image_picker.
/// [onCancel]   — called when user taps "Hủy" or close X.
class CameraPrimingSheet extends StatelessWidget {
  const CameraPrimingSheet({
    super.key,
    required this.cameraCtx,
    required this.onContinue,
    required this.onCancel,
  });

  final CameraContext cameraCtx;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  static const Color _iconBgColor = HD.positive;
  static const double _maxSheetWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final copy = PrimingCopy.camera[cameraCtx]!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Semantics(
      label: 'Yêu cầu cấp quyền camera',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxSheetWidth),
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PrimingDragHandle(),
                PrimingCloseRow(
                  onClose: onCancel,
                  semanticLabel: 'Đóng yêu cầu cấp quyền camera',
                ),
                const SizedBox(height: 16),
                PrimingIconCircle(
                  icon: Icons.camera_alt_rounded,
                  iconColor: _iconBgColor,
                  semanticLabel: 'Biểu tượng camera',
                ),
                const SizedBox(height: 20),
                PrimingHeadline(text: copy.title),
                const SizedBox(height: 12),
                _CameraBodyText(body: copy.body),
                const SizedBox(height: 24),
                PrimingButtonPair(
                  primaryLabel: PrimingCopy.btnContinue,
                  secondaryLabel: PrimingCopy.btnCancel,
                  onPrimary: onContinue,
                  onSecondary: onCancel,
                  primaryColor: _iconBgColor,
                  primarySemanticLabel: 'Tiếp tục và cấp quyền camera',
                  secondarySemanticLabel: 'Hủy yêu cầu cấp quyền camera',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders camera body copy; lines starting with "•" become bullet rows.
class _CameraBodyText extends StatelessWidget {
  const _CameraBodyText({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('•')) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.circle, size: 6, color: HD.positive),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.substring(2), // strip "• "
                    style: const TextStyle(
                        fontSize: 14, color: HD.inkSoft, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            line,
            style: const TextStyle(
                fontSize: 14, color: HD.inkSoft, height: 1.4),
          ),
        );
      }).toList(),
    );
  }
}
