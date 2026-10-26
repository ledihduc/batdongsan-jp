import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// "Cập nhật kết quả" sau buổi xem — sale ghi khách muốn thuê hay không.
/// API: `POST /api/sale/van-hanh/lich-xem/{id}/ket-qua`. Trả `true` khi đã lưu.
Future<bool> moCapNhatKetQua(
  BuildContext context, {
  required int appointmentId,
  required String phongTen,
  required String khachTen,
  SaleVanHanhApi api = const SaleVanHanhApi(),
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: SaleMau.nen,
    builder: (_) => _CapNhatKetQuaSheet(
      appointmentId: appointmentId,
      phongTen: phongTen,
      khachTen: khachTen,
      api: api,
    ),
  );
  return ok == true;
}

class _CapNhatKetQuaSheet extends StatefulWidget {
  const _CapNhatKetQuaSheet({
    required this.appointmentId,
    required this.phongTen,
    required this.khachTen,
    required this.api,
  });

  final int appointmentId;
  final String phongTen;
  final String khachTen;
  final SaleVanHanhApi api;

  @override
  State<_CapNhatKetQuaSheet> createState() => _CapNhatKetQuaSheetState();
}

class _CapNhatKetQuaSheetState extends State<_CapNhatKetQuaSheet> {
  bool? _muonThue;
  bool _dangGui = false;
  String? _loi;
  final _ghiChu = TextEditingController();

  @override
  void dispose() {
    _ghiChu.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    final chon = _muonThue;
    if (chon == null || _dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await widget.api.ghiKetQua(
        widget.appointmentId,
        muonThue: chon,
        ghiChu: _ghiChu.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = e is ApiException ? e.message : 'Chưa lưu được kết quả, thử lại nhé.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cập nhật kết quả xem', style: HD.bodyBold(size: 18, color: HD.ink)),
            const SizedBox(height: 4),
            Text(
              '${widget.phongTen} · Khách ${widget.khachTen}',
              style: HD.body(size: 13.5, color: HD.inkMuted),
            ),
            const SizedBox(height: 16),
            _LuaChon(
              key: const Key('kq-muon-thue'),
              chon: _muonThue == true,
              icon: Icons.check_rounded,
              mau: SaleMau.xanh,
              nen: SaleMau.xanhNen,
              tieuDe: 'Khách muốn thuê',
              phu: 'Chuyển sang chờ chủ nhà xác nhận chốt (hợp đồng).',
              onTap: () => setState(() => _muonThue = true),
            ),
            const SizedBox(height: 10),
            _LuaChon(
              key: const Key('kq-khong-thue'),
              chon: _muonThue == false,
              icon: Icons.close_rounded,
              mau: HD.accent,
              nen: HD.accentTint,
              tieuDe: 'Khách không thuê',
              phu: 'Kết thúc lịch xem, phòng trở lại trạng thái trống.',
              onTap: () => setState(() => _muonThue = false),
            ),
            const SizedBox(height: 16),
            Text('Ghi chú thêm (nếu có)', style: HD.bodyBold(size: 14, color: HD.ink)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('kq-ghi-chu'),
              controller: _ghiChu,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Nhập ghi chú…',
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
                key: const Key('kq-luu'),
                style: FilledButton.styleFrom(
                  backgroundColor: HD.accent,
                  disabledBackgroundColor: HD.accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _muonThue == null || _dangGui ? null : _luu,
                child: _dangGui
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Xác nhận', style: HD.bodyBold(size: 15, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LuaChon extends StatelessWidget {
  const _LuaChon({
    super.key,
    required this.chon,
    required this.icon,
    required this.mau,
    required this.nen,
    required this.tieuDe,
    required this.phu,
    required this.onTap,
  });

  final bool chon;
  final IconData icon;
  final Color mau;
  final Color nen;
  final String tieuDe;
  final String phu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: chon ? nen : SaleMau.nen,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: chon ? mau : SaleMau.vien, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tieuDe, style: HD.bodyBold(size: 15, color: mau)),
                  const SizedBox(height: 2),
                  Text(phu, style: HD.body(size: 12.5, color: HD.inkMuted)),
                ],
              ),
            ),
            Icon(
              chon ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: chon ? mau : HD.hairlineStrong,
            ),
          ],
        ),
      ),
    ),
  );
}
