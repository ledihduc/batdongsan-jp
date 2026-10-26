import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

const kLyDoTuChoi = [
  'Phòng đã có khách',
  'Chủ nhà không sắp xếp được giờ này',
  'Thông tin khách chưa phù hợp',
  'Lý do khác',
];

/// Từ chối một lịch xem khách đặt — chọn lý do (khách đọc được lý do này).
/// API: `PATCH /api/viewing-appointments/{id}/status` (rejected). Trả `true`
/// khi đã từ chối.
Future<bool> moTuChoiLich(
  BuildContext context, {
  required int appointmentId,
  SaleVanHanhApi api = const SaleVanHanhApi(),
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: SaleMau.nen,
    builder: (_) => _TuChoiSheet(appointmentId: appointmentId, api: api),
  );
  return ok == true;
}

class _TuChoiSheet extends StatefulWidget {
  const _TuChoiSheet({required this.appointmentId, required this.api});

  final int appointmentId;
  final SaleVanHanhApi api;

  @override
  State<_TuChoiSheet> createState() => _TuChoiSheetState();
}

class _TuChoiSheetState extends State<_TuChoiSheet> {
  String _lyDo = kLyDoTuChoi.first;
  bool _dangGui = false;
  String? _loi;

  Future<void> _gui() async {
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await widget.api.tuChoiLich(widget.appointmentId, lyDo: _lyDo);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = e is ApiException ? e.message : 'Chưa từ chối được, thử lại nhé.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Từ chối lịch xem?', style: HD.bodyBold(size: 18, color: HD.ink)),
          const SizedBox(height: 4),
          Text(
            'Khách sẽ nhận được thông báo kèm lý do.',
            style: HD.body(size: 13.5, color: HD.inkMuted),
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _lyDo,
            onChanged: (v) => setState(() => _lyDo = v ?? _lyDo),
            child: Column(
              children: [
                for (final l in kLyDoTuChoi)
                  RadioListTile<String>(
                    key: Key('ly-do-$l'),
                    value: l,
                    contentPadding: EdgeInsets.zero,
                    activeColor: HD.accent,
                    title: Text(l, style: HD.body(size: 14.5, color: HD.ink)),
                  ),
              ],
            ),
          ),
          if (_loi != null) Text(_loi!, style: HD.body(size: 13, color: HD.accent)),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('xac-nhan-tu-choi'),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _dangGui ? null : _gui,
              child: Text('Từ chối lịch', style: HD.bodyBold(size: 15, color: Colors.white)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Không', style: HD.body(size: 14, color: HD.inkMuted)),
          ),
        ],
      ),
    ),
  );
}
