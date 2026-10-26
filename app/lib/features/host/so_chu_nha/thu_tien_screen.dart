import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/the_dong_tien.dart';

/// Màn 8 — CHI TIẾT THU TIỀN của một phòng.
///
/// Kỳ thu (chọn tháng) → các dòng tiền + Tổng tiền → Hình thức thu (Tiền mặt /
/// Chuyển khoản / Ví) → "Xác nhận đã thu". Kỳ chưa có hoá đơn thì server lập +
/// gửi hoá đơn đúng các dòng đang hiện rồi ghi thu.
/// API: `GET|POST /api/host/so-chu-nha/phong/{id}/thu-tien`.
class ThuTienScreen extends StatefulWidget {
  const ThuTienScreen({super.key, required this.roomId, this.thang, this.api = const SoChuNhaApi()});

  final int roomId;
  final String? thang;
  final SoChuNhaApi api;

  @override
  State<ThuTienScreen> createState() => _ThuTienScreenState();
}

class _ThuTienScreenState extends State<ThuTienScreen> {
  late String? _thang = widget.thang;
  String _hinhThuc = 'tien_mat';
  KyThuCN? _ky;
  Object? _loi;
  bool _dang = false;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    setState(() => _loi = null);
    try {
      final k = await widget.api.kyThu(widget.roomId, thang: _thang);
      if (mounted) setState(() => _ky = k);
    } catch (e) {
      if (mounted) setState(() => _loi = e);
    }
  }

  Future<void> _xacNhan(KyThuCN k) async {
    setState(() => _dang = true);
    try {
      final moi = await widget.api.xacNhanThu(widget.roomId, k.thang, _hinhThuc);
      if (!mounted) return;
      setState(() {
        _ky = moi;
        _dang = false;
      });
      baoCN(context, 'Đã ghi nhận thu ${tienCN(k.conLai)}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dang = false);
      baoCN(context, loiCN(e), loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _ky;
    final daThu = k?.trangThai == 'da_thu';
    return ManCN(
      tieuDe: 'Chi tiết thu tiền',
      day: k == null
          ? null
          : NutCN(
              daThu ? 'Đã thu đủ' : 'Xác nhận đã thu',
              key: const Key('cn-xac-nhan-thu'),
              icon: daThu ? Icons.task_alt_rounded : Icons.check_rounded,
              dangChay: _dang,
              onPressed: daThu || k.conLai <= 0 ? null : () => _xacNhan(k),
            ),
      body: k == null
          ? (_loi != null
                ? RongCN(loiCN(_loi!), icon: Icons.cloud_off_rounded)
                : const Center(child: CircularProgressIndicator(color: HD.accent)))
          : ListView(
              key: const Key('cn-thu-tien'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(k.tenPhong, style: HD.bodyBold(size: 18, color: HD.ink)),
                const SizedBox(height: 14),
                OChonKyCN(
                  nhan: 'Kỳ thu',
                  ky: k.thang,
                  cacKy: k.kyChon,
                  onChon: (t) {
                    _thang = t;
                    _tai();
                  },
                ),
                const SizedBox(height: 16),
                if (daThu || k.daTra > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MauCN.xanhNen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.task_alt_rounded, color: MauCN.xanh, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            daThu
                                ? 'Kỳ này đã thu đủ ${tienCN(k.daTra)}'
                                : 'Đã thu ${tienCN(k.daTra)} · còn ${tienCN(k.conLai)}',
                            style: HD.bodyBold(size: 13.5, color: MauCN.xanh),
                          ),
                        ),
                      ],
                    ),
                  ),
                TheDongTienCN(ky: k),
                if (!daThu) ...[
                  const SizedBox(height: 20),
                  Text('Hình thức thu', style: HD.bodyBold(size: 15.5, color: HD.ink)),
                  const SizedBox(height: 8),
                  TheCN(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: RadioGroup<String>(
                      groupValue: _hinhThuc,
                      onChanged: (v) => setState(() => _hinhThuc = v ?? _hinhThuc),
                      child: Column(
                        children: [
                          for (final (ma, ten, icon) in const [
                            ('tien_mat', 'Tiền mặt', Icons.payments_outlined),
                            ('chuyen_khoan', 'Chuyển khoản', Icons.account_balance_outlined),
                            ('vi', 'Ví điện tử', Icons.account_balance_wallet_outlined),
                          ])
                            RadioListTile<String>(
                              key: Key('cn-hinh-thuc-$ma'),
                              value: ma,
                              activeColor: HD.accent,
                              controlAffinity: ListTileControlAffinity.trailing,
                              title: Row(
                                children: [
                                  Icon(icon, size: 20, color: HD.inkSoft),
                                  const SizedBox(width: 10),
                                  Text(ten, style: HD.body(size: 15, color: HD.ink)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
