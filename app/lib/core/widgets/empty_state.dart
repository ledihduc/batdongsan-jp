import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'ds_button.dart';

/// Empty state — Editorial Cockpit styled.
/// Kept under the legacy class name `EmptyState` so existing call sites
/// continue compiling. Internally rebuilt on HD tokens.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HD.s40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(HD.s20),
              decoration: const BoxDecoration(
                color: HD.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: HD.accentDeep),
            ),
            const SizedBox(height: HD.s20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: HD.sectionTitle(size: 20),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: HD.s8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: HD.body(size: 14),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: HD.s20),
              DsButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: DsButtonVariant.secondary,
                size: DsButtonSize.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// New name for clarity; same widget as [EmptyState].
typedef DsEmptyState = EmptyState;

/// SnackBar helpers — Editorial Cockpit toned.
class AppFeedback {
  static void error(BuildContext context, String message) {
    _show(context, message, HD.negative);
  }

  static void success(BuildContext context, String message) {
    _show(context, message, HD.positive);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, HD.ink);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message, HD.warning);
  }

  static void _show(BuildContext context, String message, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: HD.body(color: HD.paperRaised)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(HD.s16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HD.r8),
        ),
      ),
    );
  }
}
