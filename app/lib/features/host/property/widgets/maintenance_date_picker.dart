import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Compact date picker pair for maintenance_start / maintenance_end.
class MaintenanceDatePicker extends StatefulWidget {
  final String? initialStart;
  final String? initialEnd;
  final ValueChanged<(String, String?)> onChanged;

  const MaintenanceDatePicker({
    super.key,
    this.initialStart,
    this.initialEnd,
    required this.onChanged,
  });

  @override
  State<MaintenanceDatePicker> createState() => _MaintenanceDatePickerState();
}

class _MaintenanceDatePickerState extends State<MaintenanceDatePicker> {
  DateTime? _start;
  DateTime? _end;

  static final _fmt = DateFormat('dd/MM/yyyy');
  static final _iso = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    if (widget.initialStart != null) {
      _start = DateTime.tryParse(widget.initialStart!);
    }
    if (widget.initialEnd != null) {
      _end = DateTime.tryParse(widget.initialEnd!);
    }
  }

  void _notify() {
    if (_start == null) return;
    widget.onChanged((_iso.format(_start!), _end != null ? _iso.format(_end!) : null));
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? (_start ?? DateTime.now()) : (_end ?? (_start ?? DateTime.now()));
    final first = isStart ? DateTime.now() : (_start ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('vi'),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = null;
      } else {
        _end = picked;
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thời gian bảo trì', style: HD.bodyBold(size: 13)),
        const SizedBox(height: HD.s8),
        Row(
          children: [
            Expanded(
              child: _dateButton(
                label: 'Bắt đầu *',
                value: _start != null ? _fmt.format(_start!) : null,
                onTap: () => _pickDate(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dateButton(
                label: 'Kết thúc (tuỳ chọn)',
                value: _end != null ? _fmt.format(_end!) : null,
                onTap: _start != null ? () => _pickDate(false) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dateButton({
    required String label,
    String? value,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s12),
        decoration: BoxDecoration(
          border: Border.all(color: HD.hairline),
          borderRadius: BorderRadius.circular(HD.r8),
          color: disabled ? HD.paperSunken : HD.paperRaised,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: HD.eyebrow()),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: HD.inkSoft),
                const SizedBox(width: HD.s4),
                Text(
                  value ?? 'Chọn ngày',
                  style: HD.body(
                    size: 12,
                    color: value != null ? HD.ink : HD.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
