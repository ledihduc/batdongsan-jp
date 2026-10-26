import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:house_booking/data/models/trend_bucket_model.dart';
import 'package:house_booking/features/host/analytics/services/currency_formatter.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Dual-line trend chart wrapping fl_chart LineChart.
///
/// Lines:
///   - Current period (orange) — gross or net depending on [showNet]
///   - Prior period (grey) — prior gross or prior net
///
/// Tooltip: full unabbreviated VND on tap.
/// X-axis: period labels from model.periods[].
/// Y-axis: abbreviated VND values.
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.model,
    required this.showNet,
    required this.period,
  });

  final RevenueTrendModel model;

  /// True → show net lines (currentNet / priorNet).
  /// False → show gross lines (current / prior).
  final bool showNet;

  final PeriodType period;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  // Index of touched spot, or -1 when none.
  int _touchedIndex = -1;

  // ── Chart data colours ────────────────────────────────────────────────────

  static const Color _currentColor = Color(0xFFFF9800); // orange
  static const Color _priorColor = HD.inkMuted; // grey

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<double> get _currentSeries =>
      widget.showNet ? widget.model.currentNet : widget.model.current;

  List<double> get _priorSeries =>
      widget.showNet ? widget.model.priorNet : widget.model.prior;

  List<FlSpot> _toSpots(List<double> values) {
    return List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
  }

  /// X-axis label: last 3 chars of period key for brevity.
  /// "2026-07" → "T7" for month; "2026" → "26" for year.
  String _xLabel(int index) {
    final periods = widget.model.periods;
    if (index < 0 || index >= periods.length) return '';
    final key = periods[index];
    if (widget.period == PeriodType.month) {
      // "2026-07" → "T7"
      final parts = key.split('-');
      if (parts.length == 2) return 'T${int.tryParse(parts[1]) ?? parts[1]}';
    }
    // year → "2026" → last 2 digits
    return key.length >= 4 ? key.substring(2) : key;
  }

  double get _maxY {
    final allValues = [..._currentSeries, ..._priorSeries];
    if (allValues.isEmpty) return 1;
    return allValues.reduce((a, b) => a > b ? a : b) * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    return LineChart(
      _buildData(),
      duration: HD.motionShort,
    );
  }

  LineChartData _buildData() {
    final currentSpots = _toSpots(_currentSeries);
    final priorSpots = _toSpots(_priorSeries);
    final count = widget.model.periods.length;
    final maxY = _maxY;

    return LineChartData(
      minX: 0,
      maxX: count > 1 ? count.toDouble() - 1 : 1,
      minY: 0,
      maxY: maxY > 0 ? maxY : 1,
      clipData: const FlClipData.all(),
      lineTouchData: LineTouchData(
        enabled: true,
        touchCallback: (event, response) {
          setState(() {
            if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
              _touchedIndex = response.lineBarSpots!.first.spotIndex;
            } else {
              _touchedIndex = -1;
            }
          });
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => HD.ink.withValues(alpha: 0.9),
          getTooltipItems: (spots) => spots.map((spot) {
            final isCurrent = spot.barIndex == 0;
            final label = isCurrent
                ? (widget.showNet ? 'Thực kỳ này' : 'Gộp kỳ này')
                : (widget.showNet ? 'Thực kỳ trước' : 'Gộp kỳ trước');
            return LineTooltipItem(
              '$label\n${CurrencyFormatter.format(spot.y)}',
              HD.caption(color: Colors.white).copyWith(fontSize: 11),
            );
          }).toList(),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 4 : 1,
        getDrawingHorizontalLine: (_) => FlLine(
          color: HD.hairline,
          strokeWidth: 0.8,
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: HD.hairline),
          left: BorderSide(color: HD.hairline),
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 56,
            interval: maxY > 0 ? maxY / 4 : 1,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  CurrencyFormatter.format(value, abbreviated: true),
                  style: HD.caption().copyWith(fontSize: 9),
                  textAlign: TextAlign.right,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final idx = value.round();
              if (idx < 0 || idx >= count) return const SizedBox.shrink();
              // Show every other label when ≥8 periods to avoid crowding
              if (count >= 8 && idx % 2 != 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _xLabel(idx),
                  style: HD.caption().copyWith(fontSize: 9),
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        // Current period (orange, foreground)
        LineChartBarData(
          spots: currentSpots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: _currentColor,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
              radius: index == _touchedIndex ? 5 : 3,
              color: _currentColor,
              strokeColor: Colors.white,
              strokeWidth: 1.5,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _currentColor.withValues(alpha: 0.18),
                _currentColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        // Prior period (grey, background reference)
        LineChartBarData(
          spots: priorSpots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: _priorColor,
          barWidth: 1.5,
          dashArray: [4, 3],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TrendChartLegend — colour key below chart.
// ---------------------------------------------------------------------------

class TrendChartLegend extends StatelessWidget {
  const TrendChartLegend({super.key, required this.showNet});

  final bool showNet;

  @override
  Widget build(BuildContext context) {
    final currentLabel = showNet ? 'Thực kỳ này' : 'Gộp kỳ này';
    final priorLabel = showNet ? 'Thực kỳ trước' : 'Gộp kỳ trước';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Chip(color: const Color(0xFFFF9800), label: currentLabel),
        const SizedBox(width: HD.s16),
        _Chip(color: HD.inkMuted, label: priorLabel, dashed: true),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.color, required this.label, this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 2.5,
          decoration: dashed
              ? null
              : BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
          child: dashed
              ? CustomPaint(painter: _DashPainter(color: color))
              : null,
        ),
        const SizedBox(width: 6),
        Text(label, style: HD.caption()),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5;
    const dashW = 4.0;
    const gapW = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + dashW, size.height / 2), paint);
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
