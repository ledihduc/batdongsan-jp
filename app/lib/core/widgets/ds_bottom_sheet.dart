import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Editorial bottom sheet — paper-raised, hairline top border, drag handle.
/// Wrap [child] in a [DsBottomSheet]; call [showDsBottomSheet] to present.
class DsBottomSheet extends StatelessWidget {
  const DsBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.eyebrow,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(HD.s20, HD.s8, HD.s20, HD.s24),
    this.showDragHandle = true,
  });

  final Widget child;
  final String? title;
  final String? eyebrow;
  final Widget? trailing;
  final EdgeInsets padding;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(HD.r12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDragHandle)
              Center(
                child: Container(
                  width: 32,
                  height: 3,
                  margin: const EdgeInsets.only(top: HD.s12, bottom: HD.s8),
                  decoration: BoxDecoration(
                    color: HD.hairlineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HD.s20,
                  HD.s8,
                  HD.s20,
                  HD.s12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eyebrow != null) ...[
                            Text(eyebrow!.toUpperCase(), style: HD.eyebrow()),
                            const SizedBox(height: 2),
                          ],
                          Text(title!, style: HD.sectionTitle()),
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              const HDHairline(),
            ],
            Flexible(
              child: SingleChildScrollView(
                padding: padding,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<T?> showDsBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
  bool useSafeArea = true,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    useSafeArea: useSafeArea,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: HD.ink.withValues(alpha: 0.32),
    builder: builder,
  );
}
