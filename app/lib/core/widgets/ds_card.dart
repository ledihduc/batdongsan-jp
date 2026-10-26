import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Editorial card — paper-raised surface, hairline border, no elevation shadow.
/// Use for grouped content where a clear "block" feel helps scanability.
/// For dense lists, prefer rows separated by [HDHairline] instead.
class DsCard extends StatelessWidget {
  const DsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HD.s16),
    this.onTap,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = HD.r12,
    this.float = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;

  /// If true, adds a subtle [HD.floatShadow]. Use sparingly for FAB-style.
  final bool float;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? HD.paperRaised,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? HD.hairline,
        width: borderWidth,
      ),
      boxShadow: float ? HD.floatShadow : null,
    );

    if (onTap == null) {
      return Container(
        decoration: decoration,
        padding: padding,
        child: child,
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: HD.accentTint,
          highlightColor: HD.accentSoft,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Inset variant — flat tint, used for "sunken" content blocks (e.g. a quote,
/// a callout, a draft preview).
class DsCardInset extends StatelessWidget {
  const DsCardInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HD.s16),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? HD.paperSunken,
        borderRadius: BorderRadius.circular(HD.r8),
      ),
      child: child,
    );
  }
}
