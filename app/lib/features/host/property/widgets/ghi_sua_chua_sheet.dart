import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ho_so_phong_api.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Ghi một lần sửa chữa / sự cố của phòng. Mở bằng `showModalBottomSheet` từ hồ
/// sơ phòng; đóng với `true` khi đã lưu. API: `POST /api/host/rooms/{id}/sua-chua`.
class GhiSuaChuaSheet extends StatefulWidget {
  const GhiSuaChuaSheet({
    super.key,
    required this.roomId,
    this.api = const HoSoPhongApi(),
    this.hienChiPhi = true,
  });

  final int roomId;
  final HoSoPhongApi api;

  /// Sale ghi được sự cố nhưng không thấy tiền của chủ nhà — ô chi phí chỉ hiện
  /// cho người xem được tài chính của phòng.
  final bool hienChiPhi;

  @override
  State<GhiSuaChuaSheet> createState() => _GhiSuaChuaSheetState();
}

class _GhiSuaChuaSheetState extends State<GhiSuaChuaSheet> {
  final _tieuDe = TextEditingController();
  final _moTa = TextEditingController();
  final _nguoi = TextEditingController();
  final _chiPhi = TextEditingController();
  DateTime _ngay = DateTime.now();
  bool _dangXuLy = false;
  bool _dangLuu = false;
  String? _loi;

  @override
  void dispose() {
    for (final c in [_tieuDe, _moTa, _nguoi, _chiPhi]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _hai(int n) => n.toString().padLeft(2, '0');

  Future<void> _chonNgay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _ngay,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null && mounted) setState(() => _ngay = d);
  }

  Future<void> _luu() async {
    final tieuDe = _tieuDe.text.trim();
    if (tieuDe.isEmpty) {
      setState(() => _loi = 'Ghi rõ hỏng gì / sửa gì');
      return;
    }
    String? chu(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      await widget.api.ghiSuaChua(
        widget.roomId,
        tieuDe: tieuDe,
        ngay: '${_ngay.year}-${_hai(_ngay.month)}-${_hai(_ngay.day)}',
        moTa: chu(_moTa),
        nguoiThucHien: chu(_nguoi),
        chiPhi: widget.hienChiPhi ? double.tryParse(_chiPhi.text.trim()) : null,
        dangXuLy: _dangXuLy,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangLuu = false;
        _loi = e is ApiException ? e.message : 'Không lưu được. Thử lại.';
      });
    }
  }

  InputDecoration _o(String nhan, {String? goiY}) => InputDecoration(
    labelText: nhan,
    hintText: goiY,
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(HD.r12)),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(HD.s20, HD.s16, HD.s20, HD.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ghi sửa chữa / sự cố', style: HD.bodyBold(size: 16)),
            const SizedBox(height: HD.s16),
            TextField(
              key: const ValueKey('sc-tieu-de'),
              controller: _tieuDe,
              textCapitalization: TextCapitalization.sentences,
              decoration: _o('Hỏng gì / sửa gì *', goiY: 'VD: Điều hoà chảy nước'),
            ),
            const SizedBox(height: HD.s12),
            TextField(
              key: const ValueKey('sc-mo-ta'),
              controller: _moTa,
              maxLines: 2,
              decoration: _o('Mô tả', goiY: 'Nguyên nhân, cách xử lý…'),
            ),
            const SizedBox(height: HD.s12),
            TextField(
              key: const ValueKey('sc-nguoi'),
              controller: _nguoi,
              decoration: _o('Người thực hiện', goiY: 'Thợ, đơn vị sửa…'),
            ),
            if (widget.hienChiPhi) ...[
              const SizedBox(height: HD.s12),
              TextField(
                key: const ValueKey('sc-chi-phi'),
                controller: _chiPhi,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _o('Chi phí (đ)'),
              ),
            ],
            const SizedBox(height: HD.s4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Ngày'),
              trailing: Text(
                '${_hai(_ngay.day)}/${_hai(_ngay.month)}/${_ngay.year}',
                style: HD.bodyBold(size: 13),
              ),
              onTap: _chonNgay,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _dangXuLy,
              onChanged: (v) => setState(() => _dangXuLy = v),
              title: const Text('Chưa xong — đang xử lý'),
            ),
            if (_loi != null)
              Padding(
                padding: const EdgeInsets.only(bottom: HD.s8),
                child: Text(_loi!, style: HD.body(size: 12, color: HD.negative)),
              ),
            const SizedBox(height: HD.s8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _dangLuu ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Huỷ'),
                  ),
                ),
                const SizedBox(width: HD.s12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('luu-sua-chua'),
                    style: FilledButton.styleFrom(backgroundColor: HD.accent),
                    onPressed: _dangLuu ? null : _luu,
                    child: _dangLuu
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Lưu'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
