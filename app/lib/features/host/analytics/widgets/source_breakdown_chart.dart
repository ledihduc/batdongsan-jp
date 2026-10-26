import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:house_booking/data/models/revenue_report_model.dart';
import 'package:house_booking/data/models/source_breakdown_model.dart';
import 'package:house_booking/features/host/analytics/services/currency_formatter.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Source breakdown donut chart.
///
/// Delta from spec: spec mentioned "stacked bar by month × source" but Phase 04
/// source_breakdown endpoint returns a single-period snapshot — not multi-month
/// time-series data. Rendering as PieChart (donut) for the current period is the
/// correct interpretation of the available data. Multi-month stacked bar would
/// require a different endpoint (Phase 07 drill-down scope). Documented here.
///
/// Data: items[].colorHex provided by backend (parsed as hex string).
class SourceBreakdownChart extends StatefulWidget {
  const SourceBreakdownChart({
    super.key,
    required this.model,
  });

  final SourceBreakdownModel model;

  @override
  State<SourceBreakdownChart> createState() => _SourceBreakdownChartState();
}

class _SourceBreakdownChartState extends State<SourceBreakdownChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final items = widget.model.items;

    if (items.isEmpty) {
      return Center(
        child: Text('Chưa có dữ liệu nguồn',
            style: HD.body(color: HD.inkMuted)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 54,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (response?.touchedSection != null) {
                      _touchedIndex =
                          response!.touchedSection!.touchedSectionIndex;
                    } else {
                      _touchedIndex = -1;
                    }
                  });
                },
              ),
              sections: List.generate(items.length, (i) {
                final item = items[i];
                final isTouched = i == _touchedIndex;
                final radius = isTouched ? 72.0 : 62.0;
                return PieChartSectionData(
                  value: item.pct,
                  color: _parseColor(item.colorHex),
                  radius: radius,
                  title: item.pct >= 5
                      ? '${item.pct.toStringAsFixed(0)}%'
                      : '',
                  titleStyle: HD.caption(color: Colors.white)
                      .copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                  badgeWidget: isTouched ? _TooltipBadge(item: item) : null,
                  badgePositionPercentageOffset: 1.3,
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: HD.s16),
        // Legend table
        ...items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final isHighlighted = i == _touchedIndex;
          return _LegendRow(
            item: item,
            isHighlighted: isHighlighted,
            onTap: () => setState(
              () => _touchedIndex = _touchedIndex == i ? -1 : i,
            ),
          );
        }),
      ],
    );
  }

  /// Parse "#FF9800" or "FF9800" → Color.
  static Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      final full = clean.length == 6 ? 'FF$clean' : clean;
      return Color(int.parse(full, radix: 16));
    } catch (_) {
      return HD.inkMuted; // fallback grey
    }
  }
}

// ---------------------------------------------------------------------------
// _LegendRow — one source entry with swatch + name + amount + pct.
// ---------------------------------------------------------------------------

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.item,
    required this.isHighlighted,
    required this.onTap,
  });

  final SourceBreakdownItem item;
  final bool isHighlighted;
  final VoidCallback onTap;

  static Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      final full = clean.length == 6 ? 'FF$clean' : clean;
      return Color(int.parse(full, radix: 16));
    } catch (_) {
      return HD.inkMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: HD.motionShort,
        padding: const EdgeInsets.symmetric(vertical: HD.s8, horizontal: HD.s12),
        decoration: BoxDecoration(
          color: isHighlighted ? HD.paperRaised : Colors.transparent,
          border: isHighlighted ? Border.all(color: HD.hairline) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _parseColor(item.colorHex),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Text(item.sourceName, style: HD.body(size: 13)),
            ),
            Text(
              CurrencyFormatter.format(item.amount, abbreviated: true),
              style: HD.tabular(size: 12),
            ),
            const SizedBox(width: HD.s8),
            SizedBox(
              width: 42,
              child: Text(
                CurrencyFormatter.formatPct(item.pct, decimals: 1),
                style: HD.caption(),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TooltipBadge — shown above touched pie section.
// ---------------------------------------------------------------------------

class _TooltipBadge extends StatelessWidget {
  const _TooltipBadge({required this.item});

  final SourceBreakdownItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HD.ink.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${item.sourceName}\n${CurrencyFormatter.format(item.amount, abbreviated: true)}',
        style: HD.caption(color: Colors.white).copyWith(fontSize: 10),
        textAlign: TextAlign.center,
      ),
    );
  }
}
