import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Status chip cho ViewingAppointment — dùng chung giữa list card và
/// detail screen. Size `normal` cho card, `large` cho detail header.
enum AppointmentChipSize { normal, large }

class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({
    super.key,
    required this.status,
    this.size = AppointmentChipSize.normal,
  });

  final String status;
  final AppointmentChipSize size;

  @override
  Widget build(BuildContext context) {
    final spec = _resolve(context, status);
    final isLarge = size == AppointmentChipSize.large;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 14 : 10,
        vertical: isLarge ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: spec.bg,
        borderRadius: BorderRadius.circular(isLarge ? 24 : 20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: isLarge ? 18 : 14, color: spec.fg),
          SizedBox(width: isLarge ? 6 : 4),
          Text(
            spec.label,
            style: TextStyle(
              color: spec.fg,
              fontSize: isLarge ? 13 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static _ChipSpec _resolve(BuildContext context, String status) {
    final l = AppLocalizations.of(context);
    switch (status) {
      case 'pending':
        return _ChipSpec(
          bg: const Color(0xFFFFE0B2),
          fg: const Color(0xFFE65100),
          label: l.apptChipPending,
          icon: Icons.pending_actions,
        );
      case 'doi_gio':
        return _ChipSpec(
          bg: HD.warningTint,
          fg: HD.svcAmber,
          label: 'Bên bán bận · chọn giờ mới',
          icon: Icons.event_repeat,
        );
      case 'approved':
        return _ChipSpec(
          bg: HD.positiveTint.withOpacity(0.2),
          fg: HD.positive,
          label: l.apptChipApproved,
          icon: Icons.check_circle_outline,
        );
      case 'completed':
        return _ChipSpec(
          bg: HD.accentTint,
          fg: HD.inkSoft,
          label: l.apptChipCompleted,
          icon: Icons.task_alt,
        );
      case 'cancelled':
        return _ChipSpec(
          bg: Colors.grey.shade200,
          fg: Colors.grey.shade700,
          label: l.apptChipCancelled,
          icon: Icons.cancel_outlined,
        );
      case 'rejected':
        return _ChipSpec(
          bg: HD.negativeTint,
          fg: const Color(0xFF93000A),
          label: l.apptChipRejected,
          icon: Icons.block,
        );
      case 'locked':
        return _ChipSpec(
          bg: HD.positive.withOpacity(0.18),
          fg: HD.positive,
          label: l.apptChipLocked,
          icon: Icons.lock_outline,
        );
      case 'lost':
        return _ChipSpec(
          bg: Colors.grey.shade200,
          fg: Colors.grey.shade700,
          label: l.apptChipLost,
          icon: Icons.do_not_disturb_on_outlined,
        );
      default:
        return _ChipSpec(
          bg: Colors.grey.shade400,
          fg: Colors.white,
          label: status,
          icon: Icons.info_outline,
        );
    }
  }
}

class _ChipSpec {
  const _ChipSpec({
    required this.bg,
    required this.fg,
    required this.label,
    required this.icon,
  });
  final Color bg;
  final Color fg;
  final String label;
  final IconData icon;
}
