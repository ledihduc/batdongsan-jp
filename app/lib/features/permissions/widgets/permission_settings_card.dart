// Settings card widget for permission status display in profile/settings screen.
// ListTile-style card per phase spec and research Section 5 Pattern A.
// Shows current permission status and CTA to open OS settings when disabled.
// NO permission logic — only displays state passed by caller.

import 'package:flutter/material.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/copy/priming_copy.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Card-style widget showing a permission's current status with an action to enable.
///
/// [kind]       — notification or camera; selects icon and copy.
/// [isGranted]  — current OS grant status (fetched by Phase 4 service layer).
/// [onTapEnable] — called when user taps the enable CTA; caller opens app settings.
class PermissionSettingsCard extends StatelessWidget {
  const PermissionSettingsCard({
    super.key,
    required this.kind,
    required this.isGranted,
    required this.onTapEnable,
  });

  final PermissionKind kind;
  final bool isGranted;
  final VoidCallback onTapEnable;

  @override
  Widget build(BuildContext context) {
    final title = kind == PermissionKind.notification
        ? PrimingCopy.settingsNotifTitle
        : PrimingCopy.settingsCameraTitle;

    final statusText = isGranted
        ? PrimingCopy.settingsStatusEnabled
        : PrimingCopy.settingsStatusDisabled;

    final iconData = kind == PermissionKind.notification
        ? Icons.notifications_rounded
        : Icons.camera_alt_rounded;

    final statusColor = isGranted
        ? HD.positive
        : HD.inkMuted;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: HD.hairline),
      ),
      child: Semantics(
        label: '$title — $statusText',
        child: InkWell(
          onTap: isGranted ? null : onTapEnable,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Permission type icon with status-tinted background.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, size: 22, color: statusColor),
                ),
                const SizedBox(width: 14),

                // Title + status text.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: HD.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Trạng thái: $statusText',
                        style: TextStyle(
                          fontSize: 13,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // CTA or checkmark.
                if (isGranted) ...[
                  Semantics(
                    excludeSemantics: true,
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 22,
                      color: HD.positive,
                    ),
                  ),
                ] else ...[
                  // Minimum 48px tap target ensured by InkWell wrapping the full card.
                  Semantics(
                    label: PrimingCopy.settingsActionEnable,
                    button: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          PrimingCopy.settingsActionEnable,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: HD.accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: HD.accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
