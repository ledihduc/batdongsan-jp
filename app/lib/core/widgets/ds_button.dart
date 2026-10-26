import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Editorial Cockpit button.
///
/// Variants:
/// * [DsButtonVariant.primary] — terracotta fill, paper text. Default CTA.
/// * [DsButtonVariant.secondary] — paper fill, hairline border, ink text.
/// * [DsButtonVariant.ghost] — no fill, no border, ink text. Inline action.
/// * [DsButtonVariant.destructive] — negative fill, paper text. Delete/revoke.
///
/// Sizes:
/// * [DsButtonSize.regular] — default (vertical 16, horizontal 24).
/// * [DsButtonSize.compact] — inline rows (vertical 10, horizontal 16).
/// * [DsButtonSize.large] — hero CTAs (vertical 20, horizontal 32).
enum DsButtonVariant { primary, secondary, ghost, destructive }

enum DsButtonSize { regular, compact, large }

class DsButton extends StatelessWidget {
  const DsButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.size = DsButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final DsButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final visuals = _visualsFor(variant, disabled);
    final padding = _paddingFor(size);
    final iconSize = size == DsButtonSize.large ? 20.0 : 16.0;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: visuals.foreground,
            ),
          ),
          const SizedBox(width: HD.s8),
        ] else if (icon != null) ...[
          Icon(icon, size: iconSize, color: visuals.foreground),
          const SizedBox(width: HD.s8),
        ],
        if (expand)
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: HD.buttonLabel(color: visuals.foreground),
            ),
          )
        else
          Text(label, style: HD.buttonLabel(color: visuals.foreground)),
        if (trailingIcon != null && !isLoading) ...[
          const SizedBox(width: HD.s8),
          Icon(trailingIcon, size: iconSize, color: visuals.foreground),
        ],
      ],
    );

    final button = Material(
      color: visuals.background,
      borderRadius: BorderRadius.circular(HD.r8),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(HD.r8),
        splashColor: visuals.splash,
        highlightColor: visuals.highlight,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HD.r8),
            border: visuals.border,
          ),
          child: content,
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  _ButtonVisuals _visualsFor(DsButtonVariant v, bool disabled) {
    if (disabled) {
      return _ButtonVisuals(
        background: HD.paperSunken,
        foreground: HD.inkMuted,
        border: Border.all(color: HD.hairline),
        splash: HD.hairline,
        highlight: HD.hairline,
      );
    }
    switch (v) {
      case DsButtonVariant.primary:
        return _ButtonVisuals(
          background: HD.accent,
          foreground: HD.paperRaised,
          border: null,
          splash: HD.accentDeep,
          highlight: HD.accentDeep.withValues(alpha: 0.2),
        );
      case DsButtonVariant.secondary:
        return _ButtonVisuals(
          background: HD.paperRaised,
          foreground: HD.ink,
          border: Border.all(color: HD.hairlineStrong),
          splash: HD.accentTint,
          highlight: HD.accentSoft,
        );
      case DsButtonVariant.ghost:
        return _ButtonVisuals(
          background: Colors.transparent,
          foreground: HD.ink,
          border: null,
          splash: HD.accentTint,
          highlight: HD.accentSoft,
        );
      case DsButtonVariant.destructive:
        return _ButtonVisuals(
          background: HD.negative,
          foreground: HD.paperRaised,
          border: null,
          splash: HD.negative.withValues(alpha: 0.8),
          highlight: HD.negative.withValues(alpha: 0.2),
        );
    }
  }

  EdgeInsets _paddingFor(DsButtonSize s) {
    switch (s) {
      case DsButtonSize.compact:
        return const EdgeInsets.symmetric(vertical: 10, horizontal: HD.s16);
      case DsButtonSize.large:
        return const EdgeInsets.symmetric(vertical: HD.s20, horizontal: HD.s32);
      case DsButtonSize.regular:
        return const EdgeInsets.symmetric(vertical: HD.s16, horizontal: HD.s24);
    }
  }
}

class _ButtonVisuals {
  const _ButtonVisuals({
    required this.background,
    required this.foreground,
    required this.border,
    required this.splash,
    required this.highlight,
  });
  final Color background;
  final Color foreground;
  final BoxBorder? border;
  final Color splash;
  final Color highlight;
}

/// Small icon-only button used in toolbars/rows. Always ghost variant.
class DsIconButton extends StatelessWidget {
  const DsIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 22,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final fg = color ?? (disabled ? HD.inkMuted : HD.ink);
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: HD.accentTint,
        highlightColor: HD.accentSoft,
        child: Padding(
          padding: const EdgeInsets.all(HD.s8),
          child: Icon(icon, size: size, color: fg),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
