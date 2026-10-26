import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// "Đổi lịch" — sale đề xuất 1–3 khung giờ khác, khách chọn lại.
/// API: `GET …/{id}/gio-trong` + `POST …/{id}/doi-gio` (endpoint sẵn có).
/// Trả `true` khi đã gửi đề xuất.
Future<bool> moDoiLich(
  BuildContext context, {
  required int appointmentId,
  LichXemApi api = const LichXemApi(),
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: SaleMau.nen,
    builder: (_) => _DoiLichSheet(appointmentId: appointmentId, api: api),
  );
  return ok == true;
}

class _DoiLichSheet extends StatefulWidget {
  const _DoiLichSheet({required this.appointmentId, required this.api});

  final int appointmentId;
  final LichXemApi api;

  @override
  State<_DoiLichSheet> createState() => _DoiLichSheetState();
}

class _DoiLichSheetState extends State<_DoiLichSheet> {
  static const _toiDa = 3;
  List<NgayTrong>? _ngay;
  String? _loi;
  int _ngayChon = 0;
  final _chon = <GioDeXuat>[];
  final _lyDo = TextEditingController();
  bool _dangGui = false;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _lyDo.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    try {
      final ds = await widget.api.gioTrong(widget.appointmentId);
      if (mounted) setState(() => _ngay = ds.where((n) => n.gio.isNotEmpty).toList());
    } catch (e) {
      if (mounted) {
        setState(() => _loi = e is ApiException ? e.message : 'Chưa tải được giờ trống.');
      }
    }
  }

  void _bat(GioDeXuat g) => setState(() {
    if (_chon.contains(g)) {
      _chon.remove(g);
    } else if (_chon.length < _toiDa) {
      _chon.add(g);
    }
  });

  Future<void> _gui() async {
    if (_chon.isEmpty || _dangGui) return;
    setState(() => _dangGui = true);
    try {
      await widget.api.doiGio(
        widget.appointmentId,
        deXuat: List.of(_chon),
        lyDo: _lyDo.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = e is ApiException ? e.message : 'Chưa gửi được đề xuất, thử lại nhé.';
      });
    }
  }

  String _tenNgay(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const thu = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return '${thu[d.weekday - 1]} ${ngayThang(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ngay;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Đổi lịch xem', style: HD.bodyBold(size: 18, color: HD.ink)),
              const SizedBox(height: 4),
              Text(
                'Chọn tối đa $_toiDa khung giờ để khách chọn lại.',
                style: HD.body(size: 13.5, color: HD.inkMuted),
              ),
              const SizedBox(height: 14),
              if (ds == null && _loi == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: HD.accent)),
                )
              else if (ds != null && ds.isEmpty)
                const RongSale(
                  chu: 'Bảy ngày tới không còn khung giờ trống.',
                  icon: Icons.event_busy_outlined,
                )
              else if (ds != null) ...[
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ds.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ChoiceChip(
                      key: Key('ngay-${ds[i].ngay}'),
                      label: Text(_tenNgay(ds[i].ngay)),
                      selected: i == _ngayChon,
                      selectedColor: HD.accent,
                      labelStyle: HD.bodyBold(
                        size: 13,
                        color: i == _ngayChon ? Colors.white : HD.inkSoft,
                      ),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _ngayChon = i),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final gio in ds[_ngayChon].gio)
                      () {
                        final g = GioDeXuat(ngay: ds[_ngayChon].ngay, gio: gio);
                        final chon = _chon.contains(g);
                        return FilterChip(
                          key: Key('gio-${g.ngay}-$gio'),
                          label: Text(khungGio(gio)),
                          selected: chon,
                          selectedColor: HD.accentTint,
                          checkmarkColor: HD.accent,
                          side: BorderSide(color: chon ? HD.accent : SaleMau.vien),
                          labelStyle: HD.body(size: 13, color: chon ? HD.accent : HD.ink),
                          onSelected: (_) => _bat(g),
                        );
                      }(),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _lyDo,
                maxLength: 200,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Lý do đổi lịch (không bắt buộc)',
                  hintStyle: HD.body(size: 14, color: HD.inkMuted),
                  filled: true,
                  fillColor: SaleMau.nenXam,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_loi != null) ...[
                const SizedBox(height: 8),
                Text(_loi!, style: HD.body(size: 13, color: HD.accent)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const Key('gui-doi-lich'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HD.accent,
                    disabledBackgroundColor: HD.accent.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _chon.isEmpty || _dangGui ? null : _gui,
                  child: Text(
                    _chon.isEmpty ? 'Gửi đề xuất' : 'Gửi ${_chon.length} khung giờ',
                    style: HD.bodyBold(size: 15, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
