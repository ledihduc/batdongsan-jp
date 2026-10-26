import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Editorial section header — eyebrow (small caps) + serif title + optional
/// trailing action (e.g. "See all").
class DsSectionHeader extends StatelessWidget {
  const DsSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.onTrailingTap,
    this.trailingLabel,
    this.padding = HD.gutterX,
    this.titleSize = 22,
    this.italic = true,
  });

  final String title;
  final String? eyebrow;

  /// Use either [trailing] (custom widget) OR [trailingLabel] + [onTrailingTap].
  final Widget? trailing;
  final VoidCallback? onTrailingTap;
  final String? trailingLabel;
  final EdgeInsets padding;
  final double titleSize;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final titleStyle = italic
        ? HD.sectionTitle(size: titleSize)
        : HD.masthead(size: titleSize);

    Widget? trailingWidget = trailing;
    if (trailingWidget == null && trailingLabel != null) {
      trailingWidget = InkWell(
        onTap: onTrailingTap,
        borderRadius: BorderRadius.circular(HD.r4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trailingLabel!,
                style: HD.body(size: 13, color: HD.accentDeep),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.arrow_forward,
                size: 14,
                color: HD.accentDeep,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: padding,
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
                Text(title, style: titleStyle),
              ],
            ),
          ),
          if (trailingWidget != null) trailingWidget,
        ],
      ),
    );
  }
}

/// Smaller variant — inline label for sub-sections inside a card or sheet.
class DsLabel extends StatelessWidget {
  const DsLabel({
    super.key,
    required this.label,
    this.trailing,
    this.tone,
  });

  final String label;
  final Widget? trailing;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label.toUpperCase(), style: HD.eyebrow(color: tone)),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
