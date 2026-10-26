import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Editorial list row — paper background, hairline separator below.
/// Compose with [DsListGroup] to wrap a list section.
class DsListTile extends StatelessWidget {
  const DsListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dense = false,
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
  });

  /// Free-form leading widget. For a typed icon, pass `Icon(...)`.
  final Widget? leading;

  /// Title text.
  final String title;

  /// Subtitle below the title. Optional.
  final String? subtitle;

  /// Free-form trailing (chip, icon, value).
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool dense;
  final EdgeInsets? padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: HD.s16,
          vertical: dense ? HD.s8 : HD.s12,
        );
    final row = Padding(
      padding: effectivePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: HD.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: titleStyle ?? HD.bodyBold(size: dense ? 13 : 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: subtitleStyle ?? HD.caption(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: HD.s8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: HD.accentTint,
        highlightColor: HD.accentSoft,
        child: row,
      ),
    );
  }
}

/// Group wrapper that auto-separates [DsListTile] children with hairlines.
class DsListGroup extends StatelessWidget {
  const DsListGroup({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.borderColor,
    this.background,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final Color? borderColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(HDHairline(color: borderColor ?? HD.hairline));
      }
    }
    return Container(
      margin: padding,
      decoration: BoxDecoration(
        color: background ?? HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: borderColor ?? HD.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HD.r12),
        child: Column(children: rows),
      ),
    );
  }
}
