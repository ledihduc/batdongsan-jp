import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'ds_big_numeral.dart';
import 'ds_chip.dart';

/// KPI tile — compact, hairline-bordered card with eyebrow label,
/// big numeral, optional delta pill, and optional subtitle.
/// Use in stats grids on dashboard, analytics drill-downs, summary cards.
class DsKpiCard extends StatelessWidget {
  const DsKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.subtitle,
    this.delta,
    this.deltaTone = DsStatusTone.neutral,
    this.icon,
    this.numeralSize = 32,
    this.onTap,
    this.padding = const EdgeInsets.all(HD.s16),
  });

  final String label;
  final String value;
  final String? unit;
  final String? subtitle;
  final String? delta;
  final DsStatusTone deltaTone;
  final IconData? icon;
  final double numeralSize;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label.toUpperCase(), style: HD.eyebrow()),
              ),
              if (icon != null) Icon(icon, size: 16, color: HD.inkMuted),
            ],
          ),
          const SizedBox(height: HD.s8),
          DsBigNumeral(
            value: value,
            unit: unit,
            size: numeralSize,
          ),
          if (subtitle != null || delta != null) ...[
            const SizedBox(height: HD.s8),
            Row(
              children: [
                if (delta != null) ...[
                  DsStatusPill(label: delta!, tone: deltaTone, dense: true),
                  const SizedBox(width: HD.s8),
                ],
                if (subtitle != null)
                  Expanded(
                    child: Text(
                      subtitle!,
                      style: HD.caption(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(HD.r12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HD.r12),
        splashColor: HD.accentTint,
        highlightColor: HD.accentSoft,
        child: card,
      ),
    );
  }
}
