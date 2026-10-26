import 'package:flutter/material.dart';
import 'package:house_booking/data/services/short_stay_api.dart';

/// Shared picker for search, booking and manual blocks; callbacks invalidate quotes.
class StayPicker extends StatelessWidget {
  const StayPicker({
    super.key,
    required this.mode,
    required this.start,
    required this.end,
    required this.onChanged,
    this.modes = const ['theo_gio', 'qua_dem', 'theo_ngay'],
    this.showModes = true,
  });
  final String mode;
  final DateTime start, end;
  final List<String> modes;
  final bool showModes;
  final void Function(String mode, DateTime start, DateTime end) onChanged;

  static (DateTime, DateTime) defaults(String mode) {
    final tomorrow = stayNow().add(const Duration(days: 1));
    final start = DateTime.utc(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      mode == 'qua_dem' ? 21 : 14,
    );
    return (
      start,
      start.add(
        Duration(
          hours: mode == 'theo_gio'
              ? 2
              : mode == 'qua_dem'
              ? 12
              : 24,
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, bool arrival) async {
    final current = arrival ? start : end;
    final now = stayNow();
    final date = await showDatePicker(
      context: context,
      initialDate: current.isBefore(now) ? now : current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 760)),
    );
    if (date == null || !context.mounted) return;
    if (mode == 'qua_dem' && showModes) {
      final ci = DateTime.utc(date.year, date.month, date.day, 21);
      onChanged(mode, ci, ci.add(const Duration(hours: 12)));
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (pickedTime == null || !context.mounted) return;
    final picked = DateTime.utc(
      date.year,
      date.month,
      date.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (arrival) {
      onChanged(mode, picked, picked.add(end.difference(start)));
    } else {
      onChanged(mode, start, picked);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showModes)
        Wrap(
          spacing: 8,
          children: modes
              .map(
                (m) => ChoiceChip(
                  label: Text(shortStayModes[m]!),
                  selected: mode == m,
                  onSelected: (_) {
                    final (a, b) = defaults(m);
                    onChanged(m, a, b);
                  },
                ),
              )
              .toList(),
        ),
      const SizedBox(height: 8),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          mode == 'qua_dem' && showModes ? 'Ngày nhận · 21:00' : 'Nhận phòng',
        ),
        subtitle: Text(stayTime(stayIso(start))),
        trailing: const Icon(Icons.calendar_today_outlined),
        onTap: () => _pick(context, true),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Trả phòng'),
        subtitle: Text(stayTime(stayIso(end))),
        trailing: mode == 'qua_dem' && showModes
            ? null
            : const Icon(Icons.event_outlined),
        onTap: mode == 'qua_dem' && showModes
            ? null
            : () => _pick(context, false),
      ),
      const Text('Giờ Việt Nam (UTC+7)'),
    ],
  );
}
