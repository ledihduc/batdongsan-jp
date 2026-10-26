import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Form section — eyebrow heading + optional helper text + body fields.
/// Use as the outermost wrapper for each group of form inputs.
class DsFormSection extends StatelessWidget {
  const DsFormSection({
    super.key,
    required this.title,
    this.helper,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(HD.s20, HD.s20, HD.s20, HD.s8),
    this.spacing = HD.s16,
  });

  final String title;
  final String? helper;
  final List<Widget> children;
  final EdgeInsets padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(), style: HD.eyebrow()),
          if (helper != null) ...[
            const SizedBox(height: HD.s4),
            Text(helper!, style: HD.caption()),
          ],
          const SizedBox(height: HD.s12),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Two-column row inside a form — labels on left, values/inputs on right.
/// Useful for compact summary screens (review before submit, settings).
class DsFormRow extends StatelessWidget {
  const DsFormRow({
    super.key,
    required this.label,
    required this.child,
    this.labelWidth = 120,
  });

  final String label;
  final Widget child;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HD.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: HD.s4),
              child: Text(label, style: HD.caption().copyWith(height: 1.4)),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
