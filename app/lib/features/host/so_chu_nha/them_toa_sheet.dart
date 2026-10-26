import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Sheet "Thêm tòa nhà" mở từ nút + ở màn Tòa nhà của tôi. Trả về id toà mới.
/// API: `POST /api/host/buildings`.
class ThemToaSheet extends StatefulWidget {
  const ThemToaSheet({super.key, this.api = const SoChuNhaApi()});

  final SoChuNhaApi api;

  @override
  State<ThemToaSheet> createState() => _ThemToaSheetState();
}

class _ThemToaSheetState extends State<ThemToaSheet> {
  final _ten = TextEditingController();
  final _diaChi = TextEditingController();
  final _phuong = TextEditingController();
  final _thanhPho = TextEditingController();
  bool _dang = false;

  @override
  void dispose() {
    for (final c in [_ten, _diaChi, _phuong, _thanhPho]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _luu() async {
    if (_ten.text.trim().isEmpty) {
      baoCN(context, 'Nhập tên tòa nhà', loi: true);
      return;
    }
    setState(() => _dang = true);
    try {
      final id = await widget.api.themToa(
        ten: _ten.text.trim(),
        diaChi: _diaChi.text.trim(),
        phuong: _phuong.text.trim(),
        thanhPho: _thanhPho.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) {
        setState(() => _dang = false);
        baoCN(context, loiCN(e), loi: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: HD.hairline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Thêm tòa nhà', style: HD.bodyBold(size: 18, color: HD.ink)),
            const SizedBox(height: 16),
            ONhapCN(nhan: 'Tên tòa nhà', ctrl: _ten, goiY: 'VD: Sunrise Tower', khoa: const Key('cn-toa-ten')),
            const SizedBox(height: 14),
            ONhapCN(nhan: 'Địa chỉ', ctrl: _diaChi, goiY: 'Số nhà, đường'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: ONhapCN(nhan: 'Phường/Xã', ctrl: _phuong)),
                const SizedBox(width: 12),
                Expanded(child: ONhapCN(nhan: 'Tỉnh/Thành phố', ctrl: _thanhPho)),
              ],
            ),
            const SizedBox(height: 20),
            NutCN('Lưu', key: const Key('cn-toa-luu'), onPressed: _luu, dangChay: _dang),
          ],
        ),
      ),
    );
  }
}
