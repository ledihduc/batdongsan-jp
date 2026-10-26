import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'ds_button.dart';

/// Editorial dialog — paper-raised surface, hairline border, no Material
/// scrim color (uses [HD.ink] at low alpha for a warm tint).
class DsDialog extends StatelessWidget {
  const DsDialog({
    super.key,
    required this.title,
    this.eyebrow,
    this.body,
    this.bodyText,
    this.actions = const [],
    this.maxWidth = 420,
    this.padding = const EdgeInsets.fromLTRB(HD.s24, HD.s24, HD.s24, HD.s20),
  });

  final String title;
  final String? eyebrow;
  final Widget? body;
  final String? bodyText;
  final List<Widget> actions;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(HD.r12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HD.r12),
              border: Border.all(color: HD.hairline),
              boxShadow: HD.modalShadow,
            ),
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(), style: HD.eyebrow()),
                  const SizedBox(height: HD.s4),
                ],
                Text(title, style: HD.sectionTitle()),
                if (bodyText != null || body != null) ...[
                  const SizedBox(height: HD.s12),
                  body ?? Text(bodyText!, style: HD.body()),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: HD.s24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: HD.s8),
                        actions[i],
                      ],
                    ],
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

/// Convenience: confirm dialog returning bool.
Future<bool> showDsConfirm({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Xác nhận',
  String cancelLabel = 'Hủy',
  bool destructive = false,
  String? eyebrow,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: HD.ink.withValues(alpha: 0.32),
    builder: (ctx) => DsDialog(
      title: title,
      eyebrow: eyebrow,
      bodyText: message,
      actions: [
        DsButton(
          label: cancelLabel,
          variant: DsButtonVariant.ghost,
          size: DsButtonSize.compact,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        DsButton(
          label: confirmLabel,
          variant: destructive
              ? DsButtonVariant.destructive
              : DsButtonVariant.primary,
          size: DsButtonSize.compact,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Convenience: alert dialog returning when dismissed.
Future<void> showDsAlert({
  required BuildContext context,
  required String title,
  String? message,
  String dismissLabel = 'Đã hiểu',
  String? eyebrow,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: HD.ink.withValues(alpha: 0.32),
    builder: (ctx) => DsDialog(
      title: title,
      eyebrow: eyebrow,
      bodyText: message,
      actions: [
        DsButton(
          label: dismissLabel,
          variant: DsButtonVariant.primary,
          size: DsButtonSize.compact,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}
