// Soft re-ask banner for denied permissions.
// Dismissible top banner shown in-app — does NOT trigger OS dialog (AC-N3).
// Pattern B from research Section 5: inline banner with open-settings + dismiss CTAs.
// Uses StatefulWidget only to manage dismiss animation state.

import 'package:flutter/material.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/copy/priming_copy.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Top-of-screen dismissible banner for soft re-ask flow.
///
/// [kind]           — PermissionKind.notification or .camera; selects copy.
/// [onOpenSettings] — called when user taps "Mở Cài đặt"; caller delegates to service.
/// [onDismiss]      — called when user dismisses banner; caller records cooldown.
class SoftReaskBanner extends StatefulWidget {
  const SoftReaskBanner({
    super.key,
    required this.kind,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  final PermissionKind kind;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  State<SoftReaskBanner> createState() => _SoftReaskBannerState();
}

class _SoftReaskBannerState extends State<SoftReaskBanner>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;

  void _handleDismiss() {
    setState(() => _dismissed = true);
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final message = widget.kind == PermissionKind.notification
        ? PrimingCopy.softReaskNotif
        : PrimingCopy.softReaskCamera;

    final iconData = widget.kind == PermissionKind.notification
        ? Icons.notifications_off_outlined
        : Icons.no_photography_outlined;

    return Semantics(
      label: 'Thông báo yêu cầu cấp lại quyền: $message',
      child: Material(
        color: HD.warningTint, // amber.shade50
        elevation: 2,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info / permission icon.
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Semantics(
                    excludeSemantics: true,
                    child: Icon(iconData,
                        size: 20, color: HD.inkSoft),
                  ),
                ),
                const SizedBox(width: 10),

                // Message text.
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: HD.ink,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Action buttons row.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _actionButton(
                      label: PrimingCopy.softReaskOpenSettings,
                      semanticLabel: 'Mở Cài đặt để bật lại quyền',
                      color: HD.accent,
                      onTap: widget.onOpenSettings,
                    ),
                    const SizedBox(height: 4),
                    _actionButton(
                      label: PrimingCopy.softReaskDismiss,
                      semanticLabel: 'Bỏ qua thông báo này',
                      color: HD.inkMuted,
                      onTap: _handleDismiss,
                    ),
                  ],
                ),

                // Close X — minimum 48x48 tap target.
                Semantics(
                  label: 'Đóng thông báo',
                  button: true,
                  child: GestureDetector(
                    onTap: _handleDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const Icon(Icons.close,
                          size: 18, color: HD.inkMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required String semanticLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          // Minimum 44px wide tap area with visible text.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
