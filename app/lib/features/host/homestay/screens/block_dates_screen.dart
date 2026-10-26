import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/homestay/providers/homestay_calendar_provider.dart';

/// Phase 07 — block (or unblock) a contiguous date range for a room.
class BlockDatesScreen extends StatefulWidget {
  const BlockDatesScreen({super.key, required this.roomId});

  final int roomId;

  @override
  State<BlockDatesScreen> createState() => _BlockDatesScreenState();
}

class _BlockDatesScreenState extends State<BlockDatesScreen> {
  DateTime? _start;
  DateTime? _end;
  String _action = 'block'; // block | unblock
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month - 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: (_start != null && _end != null)
          ? DateTimeRange(start: _start!, end: _end!)
          : null,
    );
    if (range != null) {
      setState(() {
        _start = range.start;
        _end = range.end;
      });
    }
  }

  Future<void> _submit() async {
    if (_start == null || _end == null) return;
    setState(() => _submitting = true);
    final ok = await context.read<HomestayCalendarProvider>().blockRange(
          roomId: widget.roomId,
          startDate: _iso(_start!),
          endDate: _iso(_end!),
          action: _action,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(_action == 'block' ? 'Đã chặn lịch' : 'Đã mở lịch')),
      );
      Navigator.pop(context);
    } else {
      final err = context.read<HomestayCalendarProvider>().error ?? 'Lỗi';
      messenger.showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(
        title: 'Chặn / mở lịch',
      ),
      body: Padding(
        padding: const EdgeInsets.all(HD.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HÀNH ĐỘNG', style: HD.eyebrow()),
            const SizedBox(height: HD.s8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'block', label: Text('Chặn')),
                ButtonSegment(value: 'unblock', label: Text('Mở')),
              ],
              selected: {_action},
              onSelectionChanged: (s) => setState(() => _action = s.first),
            ),
            const SizedBox(height: HD.s24),
            Text('KHOẢNG NGÀY', style: HD.eyebrow()),
            const SizedBox(height: HD.s8),
            InkWell(
              onTap: _pickRange,
              child: Container(
                padding: const EdgeInsets.all(HD.s16),
                decoration: BoxDecoration(
                  color: HD.paperRaised,
                  border: Border.all(color: HD.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: HD.ink),
                    const SizedBox(width: HD.s12),
                    Expanded(
                      child: Text(
                        _start == null
                            ? 'Chọn khoảng ngày'
                            : '${_iso(_start!)} → ${_iso(_end!)}',
                        style: HD.body(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: HD.s24),
            Text('GHI CHÚ (TUỲ CHỌN)', style: HD.eyebrow()),
            const SizedBox(height: HD.s8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                filled: true,
                fillColor: HD.paperRaised,
                border: OutlineInputBorder(),
                hintText: 'VD: Bảo trì điện…',
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_start == null || _submitting) ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: HD.ink,
                  padding: const EdgeInsets.symmetric(vertical: HD.s16),
                ),
                child: Text(_submitting ? 'Đang xử lý…' : 'Xác nhận'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }
}
