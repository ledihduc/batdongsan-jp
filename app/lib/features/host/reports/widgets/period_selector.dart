import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Compact month/year selector chip.
/// Calls [onChanged] with the new value when the user taps a chip or arrow.
class PeriodSelector extends StatelessWidget {
  final String period; // 'month' | 'year'
  final String date; // 'YYYY-MM' (month) or 'YYYY' (year)
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<String> onDateChanged;

  const PeriodSelector({
    super.key,
    required this.period,
    required this.date,
    required this.onPeriodChanged,
    required this.onDateChanged,
  });

  String _shiftDate(int delta) {
    if (period == 'year') {
      final y = int.tryParse(date) ?? DateTime.now().year;
      return '${y + delta}';
    }
    // Month: YYYY-MM
    final parts = date.split('-');
    var y = int.tryParse(parts.first) ?? DateTime.now().year;
    var m = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    m += delta;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    return '$y-${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ChoiceChip(
          label: const Text('Tháng'),
          selected: period == 'month',
          onSelected: (_) {
            if (period != 'month') {
              final now = DateTime.now();
              onPeriodChanged('month');
              onDateChanged(
                '${now.year}-${now.month.toString().padLeft(2, '0')}',
              );
            }
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Năm'),
          selected: period == 'year',
          onSelected: (_) {
            if (period != 'year') {
              onPeriodChanged('year');
              onDateChanged('${DateTime.now().year}');
            }
          },
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          onPressed: () => onDateChanged(_shiftDate(-1)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: HD.hairline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(date, style: HD.bodyBold(size: 13)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          onPressed: () => onDateChanged(_shiftDate(1)),
        ),
      ],
    );
  }
}
