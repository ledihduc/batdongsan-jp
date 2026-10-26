// Internal shared primitives for priming sheets.
// Extracted to keep notification_priming_sheet.dart and camera_priming_sheet.dart
// under 200 lines each. Prefixed with "_" — not part of public API.

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Horizontal drag handle shown at top of bottom sheets.
class PrimingDragHandle extends StatelessWidget {
  const PrimingDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD0D0D0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Close button row aligned to end, with 48x48 tap target.
class PrimingCloseRow extends StatelessWidget {
  const PrimingCloseRow({
    super.key,
    required this.onClose,
    required this.semanticLabel,
  });

  final VoidCallback onClose;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Semantics(
          label: semanticLabel,
          button: true,
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 22, color: HD.inkMuted),
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular icon container for the permission type illustration.
class PrimingIconCircle extends StatelessWidget {
  const PrimingIconCircle({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.semanticLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 40, color: iconColor),
        ),
      ),
    );
  }
}

/// Bold headline text for priming sheets.
class PrimingHeadline extends StatelessWidget {
  const PrimingHeadline({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: HD.ink,
        height: 1.3,
      ),
    );
  }
}
