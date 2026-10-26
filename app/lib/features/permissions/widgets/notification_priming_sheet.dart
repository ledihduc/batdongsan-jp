// Notification permission priming bottom sheet.
// Role-aware: displays role-specific copy from PrimingCopy.notification map.
// Layout follows research Section 6 wireframe and phase spec ASCII art.
// NO permission logic — only UI + callbacks (AC constraint).

import 'package:flutter/material.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/copy/priming_copy.dart';
import 'package:house_booking/features/permissions/widgets/_priming_button_pair.dart';
import 'package:house_booking/features/permissions/widgets/_priming_sheet_parts.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Bottom sheet presenting notification permission priming to the user.
///
/// [role]      — determines which copy variant is shown (guest/host/admin).
/// [onAccept]  — called when user taps "Bật ngay"; caller triggers OS permission.
/// [onDefer]   — called when user taps "Để sau"; caller saves cooldown timestamp.
/// [onClose]   — called when close X tapped; semantically same as defer per spec M2.
class NotificationPrimingSheet extends StatelessWidget {
  const NotificationPrimingSheet({
    super.key,
    required this.role,
    required this.onAccept,
    required this.onDefer,
    required this.onClose,
  });

  final UserRole role;
  final VoidCallback onAccept;
  final VoidCallback onDefer;
  final VoidCallback onClose;

  static const Color _iconBgColor = HD.accent;
  static const double _maxSheetWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final copy = PrimingCopy.notification[role]!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Semantics(
      label: 'Yêu cầu cấp quyền thông báo',
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
                  onClose: onClose,
                  semanticLabel: 'Đóng yêu cầu cấp quyền thông báo',
                ),
                const SizedBox(height: 16),
                PrimingIconCircle(
                  icon: Icons.notifications_rounded,
                  iconColor: _iconBgColor,
                  semanticLabel: 'Biểu tượng thông báo',
                ),
                const SizedBox(height: 20),
                PrimingHeadline(text: copy.title),
                const SizedBox(height: 12),
                _BenefitLines(copy: copy),
                const SizedBox(height: 12),
                _TrustSignals(),
                const SizedBox(height: 24),
                PrimingButtonPair(
                  primaryLabel: PrimingCopy.btnEnable,
                  secondaryLabel: PrimingCopy.btnDefer,
                  onPrimary: onAccept,
                  onSecondary: onDefer,
                  primaryColor: _iconBgColor,
                  primarySemanticLabel: 'Bật thông báo ngay bây giờ',
                  secondarySemanticLabel:
                      'Hủy yêu cầu cấp quyền, có thể yêu cầu lại sau',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three role-specific benefit lines with check icons.
class _BenefitLines extends StatelessWidget {
  const _BenefitLines({required this.copy});

  final NotificationCopy copy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(copy.line1),
        const SizedBox(height: 8),
        _line(copy.line2),
        const SizedBox(height: 8),
        _line(copy.line3),
      ],
    );
  }

  Widget _line(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_rounded,
              size: 18, color: HD.positive),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 14, color: HD.inkSoft, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Trust signal block shown below benefit list.
class _TrustSignals extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _trustLine(PrimingCopy.trustCanDisable),
          const SizedBox(height: 4),
          _trustLine(PrimingCopy.trustNoSpam),
        ],
      ),
    );
  }

  Widget _trustLine(String text) {
    return Row(
      children: [
        const Icon(Icons.check_box_rounded, size: 16, color: HD.inkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: HD.inkMuted)),
        ),
      ],
    );
  }
}
