import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'ds_chip.dart';

/// Display numeral — serif italic, tabular figures, optional suffix unit.
/// Used as a hero KPI on dashboard sections and analytics drill-downs.
class DsBigNumeral extends StatelessWidget {
  const DsBigNumeral({
    super.key,
    required this.value,
    this.unit,
    this.label,
    this.delta,
    this.deltaTone = DsStatusTone.neutral,
    this.size = 48,
    this.alignment = CrossAxisAlignment.start,
  });

  final String value;
  final String? unit;
  final String? label;
  final String? delta;
  final DsStatusTone deltaTone;
  final double size;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: HD.s4),
            child: Text(label!.toUpperCase(), style: HD.eyebrow()),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: HD.bigNumeral(size: size)),
            if (unit != null) ...[
              const SizedBox(width: HD.s4),
              Padding(
                padding: EdgeInsets.only(bottom: size * 0.18),
                child: Text(
                  unit!,
                  style: HD.caption(color: HD.inkMuted).copyWith(
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (delta != null) ...[
          const SizedBox(height: HD.s4),
          DsStatusPill(label: delta!, tone: deltaTone, dense: true),
        ],
      ],
    );
  }
}
