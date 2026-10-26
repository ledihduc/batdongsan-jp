import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/homestay/providers/pricing_rule_provider.dart';

/// Phase 07 — pricing rule create form (manual + holiday + weekend + base).
class PricingRuleFormScreen extends StatefulWidget {
  const PricingRuleFormScreen({super.key, this.roomId});

  final int? roomId;

  @override
  State<PricingRuleFormScreen> createState() => _PricingRuleFormScreenState();
}

class _PricingRuleFormScreenState extends State<PricingRuleFormScreen> {
  String _type = 'manual';
  DateTime? _start;
  DateTime? _end;
  final _priceCtrl = TextEditingController();
  final _holidayNameCtrl = TextEditingController();
  // Weekend default: Fri + Sat (bit 4 + bit 5).
  int _weekdayMask = (1 << 4) | (1 << 5);
  bool _submitting = false;

  static const _types = ['base', 'weekend', 'holiday', 'manual'];
  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 3, 12, 31),
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
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', ''));
    if (price == null || _start == null || _end == null) return;
    setState(() => _submitting = true);
    final ok = await context.read<PricingRuleProvider>().create(
          roomId: widget.roomId,
          ruleType: _type,
          startDate: _iso(_start!),
          endDate: _iso(_end!),
          pricePerNight: price,
          weekdayMask: _type == 'weekend' ? _weekdayMask : null,
          holidayName: _type == 'holiday'
              ? (_holidayNameCtrl.text.trim().isEmpty
                  ? null
                  : _holidayNameCtrl.text.trim())
              : null,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      final err = context.read<PricingRuleProvider>().error ?? 'Lỗi';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Widget _weekdayPicker() {
    return Wrap(
      spacing: 6,
      children: [
        for (int i = 0; i < 7; i++)
          FilterChip(
            label: Text(_weekdayLabels[i]),
            selected: ((_weekdayMask >> i) & 1) == 1,
            onSelected: (sel) {
              setState(() {
                if (sel) {
                  _weekdayMask |= (1 << i);
                } else {
                  _weekdayMask &= ~(1 << i);
                }
              });
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(
        title: 'Thêm quy tắc giá',
      ),
      body: ListView(
        padding: const EdgeInsets.all(HD.s20),
        children: [
          Text('LOẠI QUY TẮC', style: HD.eyebrow()),
          const SizedBox(height: HD.s8),
          Wrap(
            spacing: 6,
            children: [
              for (final t in _types)
                ChoiceChip(
                  label: Text(t),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: HD.s24),
          Text('GIÁ MỖI ĐÊM (VND)', style: HD.eyebrow()),
          const SizedBox(height: HD.s8),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              filled: true,
              fillColor: HD.paperRaised,
              border: OutlineInputBorder(),
              hintText: 'VD: 500000',
            ),
          ),
          const SizedBox(height: HD.s24),
          Text('KHOẢNG NGÀY ÁP DỤNG', style: HD.eyebrow()),
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
          if (_type == 'weekend') ...[
            const SizedBox(height: HD.s24),
            Text('CÁC NGÀY ÁP DỤNG', style: HD.eyebrow()),
            const SizedBox(height: HD.s8),
            _weekdayPicker(),
          ],
          if (_type == 'holiday') ...[
            const SizedBox(height: HD.s24),
            Text('TÊN NGÀY LỄ (TUỲ CHỌN)', style: HD.eyebrow()),
            const SizedBox(height: HD.s8),
            TextField(
              controller: _holidayNameCtrl,
              decoration: const InputDecoration(
                filled: true,
                fillColor: HD.paperRaised,
                border: OutlineInputBorder(),
                hintText: 'VD: Quốc khánh 2/9',
              ),
            ),
          ],
          const SizedBox(height: HD.s32),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: HD.ink,
              padding: const EdgeInsets.symmetric(vertical: HD.s16),
            ),
            child: Text(_submitting ? 'Đang lưu…' : 'Lưu quy tắc'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _holidayNameCtrl.dispose();
    super.dispose();
  }
}
