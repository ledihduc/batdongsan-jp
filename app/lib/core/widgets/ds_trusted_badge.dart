import 'package:flutter/material.dart';

/// Cờ "Uy tín" badge — overlaid on house card / detail images when
/// `house.isTrusted == true`.
///
/// Two constructors:
/// - `DsTrustedBadge()` — icon + label "Uy tín" (default for image overlays).
/// - `DsTrustedBadge.iconOnly()` — compact icon-only for tight spaces.
///
/// This is SEPARATE from `_VerifiedBadge` (host KYC verified).
/// See plan decision D7: listing-trusted vs host-verified are distinct concepts.
///
/// Design: amber pill with white border + shadow, Material workspace_premium icon.
class DsTrustedBadge extends StatelessWidget {
  /// Whether to show the text label "Uy tín" beside the icon.
  final bool _showLabel;

  /// Default constructor: icon + "Uy tín" label.
  const DsTrustedBadge({super.key}) : _showLabel = true;

  /// Compact icon-only variant for tight overlays.
  const DsTrustedBadge.iconOnly({super.key}) : _showLabel = false;

  static const _bgColor = Color(0xFFB45309); // amber.shade700 — editorial warm gold
  static const _borderColor = Colors.white;
  static const _iconColor = Colors.white;
  static const _labelColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tin uy tín',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _showLabel ? 7 : 5,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium,
              color: _iconColor,
              size: 13,
            ),
            if (_showLabel) ...[
              const SizedBox(width: 4),
              const Text(
                'Uy tín',
                style: TextStyle(
                  color: _labelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
