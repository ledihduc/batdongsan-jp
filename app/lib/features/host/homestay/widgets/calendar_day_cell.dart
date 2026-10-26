import 'package:flutter/material.dart';
import 'package:house_booking/data/models/homestay_calendar_model.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Phase 07 — single day cell on the calendar.
///
/// Editorial style: warm paper background, hairline border, tabular price.
/// Status colour band runs along the left edge — never a flat colour fill.
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.day,
    this.isSelected = false,
    this.onTap,
    this.compact = false,
  });

  final CalendarDay day;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool compact;

  Color get _statusBar {
    if (day.isReserved) return HD.accent;
    if (day.isBlocked) return HD.inkMuted;
    return HD.positive; // available
  }

  String get _statusLabel {
    if (day.isReserved) return 'Đã đặt';
    if (day.isBlocked) return 'Chặn';
    return 'Trống';
  }

  String _formatPrice(double v) {
    if (v <= 0) return '–';
    if (v >= 1_000_000) {
      return '${(v / 1_000_000).toStringAsFixed(v % 1_000_000 == 0 ? 0 : 1)}M';
    }
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  String get _dayNumber {
    final parts = day.date.split('-');
    return parts.length == 3 ? parts[2] : day.date;
  }

  @override
  Widget build(BuildContext context) {
    final width = compact ? 64.0 : 92.0;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: compact ? 64 : 84,
        decoration: BoxDecoration(
          color: isSelected ? HD.paper : HD.paperRaised,
          border: Border.all(
            color: isSelected ? HD.ink : HD.hairline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(width: 3, color: _statusBar),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dayNumber, style: HD.tabular(size: 14)),
                    if (!compact)
                      Text(_statusLabel, style: HD.caption()),
                    Text(
                      _formatPrice(day.pricePerNight),
                      style: HD.tabular(size: compact ? 11 : 12, color: HD.ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
