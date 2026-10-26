// Shared button pair for permission priming sheets.
// BOTH buttons are full-width 48px — equal visual weight (research Section 8 anti-dark-pattern).
// Primary = ElevatedButton (brand color, filled).
// Secondary = OutlinedButton (same height/width — NOT a text link, CPPA compliant).

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Renders a stacked pair of full-width 48px buttons.
///
/// [primaryLabel]  — label for the filled primary action button.
/// [secondaryLabel] — label for the outlined secondary/defer button.
/// [primaryColor]  — fill color for the primary button (defaults to brand red).
/// [onPrimary]     — callback when primary button tapped.
/// [onSecondary]   — callback when secondary button tapped.
/// [primarySemanticLabel]   — accessibility label for primary button.
/// [secondarySemanticLabel] — accessibility label for secondary button.
class PrimingButtonPair extends StatelessWidget {
  const PrimingButtonPair({
    super.key,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    this.primaryColor = HD.accent,
    this.primarySemanticLabel,
    this.secondarySemanticLabel,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  /// Brand color for primary button background.
  final Color primaryColor;

  /// Screen-reader label for primary button (optional override).
  final String? primarySemanticLabel;

  /// Screen-reader label for secondary button (optional override).
  final String? secondarySemanticLabel;

  static const double _buttonHeight = 48.0;
  static const double _buttonGap = 12.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary — filled, brand-colored.
        Semantics(
          label: primarySemanticLabel ?? primaryLabel,
          button: true,
          child: SizedBox(
            width: double.infinity,
            height: _buttonHeight,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                // Ensure text contrast ≥ 4.5:1 (white on #B71C1C = 5.9:1 pass)
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(primaryLabel),
            ),
          ),
        ),

        const SizedBox(height: _buttonGap),

        // Secondary — outlined, equal height/width (anti-dark-pattern).
        Semantics(
          label: secondarySemanticLabel ?? secondaryLabel,
          button: true,
          child: SizedBox(
            width: double.infinity,
            height: _buttonHeight,
            child: OutlinedButton(
              onPressed: onSecondary,
              style: OutlinedButton.styleFrom(
                foregroundColor: HD.ink,
                side: const BorderSide(color: HD.inkSoft, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(secondaryLabel),
            ),
          ),
        ),
      ],
    );
  }
}
