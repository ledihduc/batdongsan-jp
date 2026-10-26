import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Màn 10 — DỊCH VỤ PHÒNG: danh sách dịch vụ + giá, bút sửa từng dòng,
/// "+ Thêm dịch vụ" ở đáy.
///
/// Phòng đang có hợp đồng: giá + bật/tắt ghi trên hợp đồng đó. Phòng trống:
/// giá dịch vụ là giá chung của toà (màn nói rõ).
/// API: `GET|POST /api/host/so-chu-nha/phong/{id}/dich-vu`, `PATCH …/dich-vu/{ma}`.
class DichVuPhongScreen extends StatefulWidget {
  const DichVuPhongScreen({super.key, required this.roomId, this.api = const SoChuNhaApi()});

  final int roomId;
  final SoChuNhaApi api;

  @override
  State<DichVuPhongScreen> createState() => _DichVuPhongScreenState();
}

class _DichVuPhongScreenState extends State<DichVuPhongScreen> {
  DichVuPhongCN? _d;
  Object? _loi;

  @override
  void initState() {
    super.initState();
    widget.api.dichVu(widget.roomId).then(
      (d) {
        if (mounted) setState(() => _d = d);
      },
      onError: (Object e) {
        if (mounted) setState(() => _loi = e);
      },
    );
  }

  Future<void> _chay(Future<DichVuPhongCN> Function() viec, String xong) async {
    try {
      final d = await viec();
      if (!mounted) return;
      setState(() => _d = d);
      baoCN(context, xong);
    } catch (e) {
      if (mounted) baoCN(context, loiCN(e), loi: true);
    }
  }

  Future<T?> _sheet<T>(Widget noi) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MauCN.the,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => noi,
  );

  Future<void> _sua(DichVuPhongCN d, DichVuCN dv) async {
    final kq = await _sheet<(double, bool, String)>(
      _SheetSuaDichVu(dv: dv, giaChungToa: !d.coHopDong && int.tryParse(dv.ma) != null),
    );
    if (kq == null || !mounted) return;
    await _chay(
      () => widget.api.suaDichVu(
        widget.roomId,
        dv.ma,
        gia: kq.$1,
        apDung: dv.xoaDuoc && kq.$2 != dv.apDung ? kq.$2 : null,
        cachTinh: dv.doiCachTinh && kq.$3 != dv.cachTinh ? kq.$3 : null,
      ),
      'Đã cập nhật ${dv.ten.toLowerCase()}',
    );
  }

  Future<void> _them() async {
    final kq = await _sheet<(String, double, String)>(const _SheetThemDichVu());
    if (kq == null || !mounted) return;
    await _chay(
      () => widget.api.themDichVu(widget.roomId, ten: kq.$1, gia: kq.$2, cachTinh: kq.$3),
      'Đã thêm dịch vụ ${kq.$1}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return ManCN(
      tieuDe: 'Dịch vụ phòng',
      day: d == null
          ? null
          : NutCN(
              'Thêm dịch vụ',
              key: const Key('cn-them-dich-vu'),
              kieu: KieuNutCN.vien,
              icon: Icons.add_rounded,
              onPressed: _them,
            ),
      body: d == null
          ? (_loi != null
                ? RongCN(loiCN(_loi!), icon: Icons.cloud_off_rounded)
                : const Center(child: CircularProgressIndicator(color: HD.accent)))
          : ListView(
              key: const Key('cn-dich-vu'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(d.tenPhong, style: HD.bodyBold(size: 18, color: HD.ink)),
                const SizedBox(height: 4),
                Text(
                  d.coHopDong
                      ? 'Giá áp dụng cho hợp đồng đang thuê'
                      : 'Phòng chưa có người thuê · dịch vụ theo giá chung của tòa',
                  style: HD.body(size: 13, color: HD.inkMuted),
                ),
                const SizedBox(height: 14),
                if (d.coHopDong) _soNguoi(d),
                for (final dv in d.dichVu) _dong(d, dv),
              ],
            ),
    );
  }

  Future<void> _suaSoNguoi(DichVuPhongCN d) async {
    final so = await _sheet<int>(_SheetSoNguoi(hienTai: d.soNguoi));
    if (so == null || !mounted) return;
    await _chay(() => widget.api.datSoNguoi(widget.roomId, so), 'Đã cập nhật số người ở');
  }

  /// Thẻ "Số người ở" — nhân với các khoản tính theo người.
  Widget _soNguoi(DichVuPhongCN d) {
    return TheCN(
      key: const Key('cn-so-nguoi'),
      margin: const EdgeInsets.only(bottom: 14),
      onTap: () => _suaSoNguoi(d),
      child: Row(
        children: [
          const OIconCN(Icons.groups_outlined, mau: MauCN.xanh, nen: MauCN.xanhNen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Số người ở', style: HD.bodyBold(size: 15, color: HD.ink)),
                const SizedBox(height: 2),
                Text(
                  d.soNguoiTuKhai ? 'Dùng cho khoản tính theo người' : 'Đếm theo hợp đồng · chạm để sửa',
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
              ],
            ),
          ),
          Text('${d.soNguoi} người', style: HD.bodyBold(size: 16, color: HD.ink)),
          const SizedBox(width: 4),
          const Icon(Icons.edit_outlined, color: HD.inkMuted, size: 18),
        ],
      ),
    );
  }

  Widget _dong(DichVuPhongCN d, DichVuCN dv) {
    final (icon, mau) = bieuTuongDichVu(dv.ma, dv.ten);
    return Opacity(
      opacity: dv.apDung ? 1 : 0.55,
      child: TheCN(
        key: Key('cn-dv-${dv.ma}'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            OIconCN(icon, mau: mau, nen: mau.withValues(alpha: 0.12)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(dv.ten, style: HD.bodyBold(size: 15, color: HD.ink))),
                      const SizedBox(width: 8),
                      if (dv.theoNguoi)
                        const NhanCN('Theo người', mau: MauCN.xanh, nen: MauCN.xanhNen)
                      else if (dv.doiCachTinh)
                        const NhanCN('Theo đơn giá', mau: MauCN.lam, nen: MauCN.lamNen),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (!dv.apDung) 'Chưa áp dụng',
                      '${tienCN(dv.gia)}/${dv.donVi}',
                      if (dv.theoNguoi && d.coHopDong) '× ${d.soNguoi} = ${tienCN(dv.gia * d.soNguoi)}',
                    ].join(' · '),
                    style: HD.body(size: 13.5, color: dv.apDung ? HD.accent : HD.inkMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('cn-sua-dv-${dv.ma}'),
              tooltip: 'Sửa',
              onPressed: () => _sua(d, dv),
              icon: const Icon(Icons.edit_outlined, color: HD.inkMuted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}


/// Sheet sửa giá (+ cách tính + bật/tắt trên hợp đồng). Trả `(giá, áp dụng, cách tính)`.
class _SheetSuaDichVu extends StatefulWidget {
  const _SheetSuaDichVu({required this.dv, required this.giaChungToa});

  final DichVuCN dv;
  final bool giaChungToa;

  @override
  State<_SheetSuaDichVu> createState() => _SheetSuaDichVuState();
}

class _SheetSuaDichVuState extends State<_SheetSuaDichVu> {
  late final _gia = TextEditingController(text: tienCN(widget.dv.gia).replaceAll('đ', ''));
  late bool _apDung = widget.dv.apDung;
  late String _cachTinh = widget.dv.cachTinh;

  @override
  void dispose() {
    _gia.dispose();
    super.dispose();
  }

  void _luu() {
    final so = docSoCN(_gia.text);
    if (so == null) {
      baoCN(context, 'Đơn giá không hợp lệ', loi: true);
      return;
    }
    Navigator.pop(context, (so, _apDung, _cachTinh));
  }

  @override
  Widget build(BuildContext context) {
    final dv = widget.dv;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sửa ${dv.ten.toLowerCase()}', style: HD.bodyBold(size: 18, color: HD.ink)),
          if (widget.giaChungToa) ...[
            const SizedBox(height: 4),
            Text(
              'Phòng chưa có người thuê — giá này áp dụng chung cho cả tòa.',
              style: HD.body(size: 13, color: HD.inkMuted),
            ),
          ],
          const SizedBox(height: 16),
          if (dv.doiCachTinh) ...[
            Text('Cách tính', style: HD.bodyBold(size: 14, color: HD.ink)),
            const SizedBox(height: 8),
            CongTacCN(
              cacO: [dv.ma == 'nuoc' ? 'Theo chỉ số' : 'Theo đơn giá', 'Theo người'],
              chon: _cachTinh == 'theo_nguoi' ? 1 : 0,
              khoa: const [Key('cn-dv-don-gia'), Key('cn-dv-theo-nguoi')],
              onChon: (i) => setState(() => _cachTinh = i == 1 ? 'theo_nguoi' : 'don_gia'),
            ),
            const SizedBox(height: 14),
          ],
          ONhapCN(
            nhan: 'Đơn giá',
            ctrl: _gia,
            so: true,
            duoi: _cachTinh == 'theo_nguoi'
                ? 'đ/người/tháng'
                : (dv.ma == 'nuoc' ? 'đ/m³' : (dv.ma == 'dien' ? 'đ/kWh' : 'đ/tháng')),
            khoa: const Key('cn-dv-gia'),
          ),
          if (dv.xoaDuoc) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('cn-dv-ap-dung'),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: HD.accent,
              title: Text('Áp dụng cho phòng này', style: HD.body(size: 15, color: HD.ink)),
              value: _apDung,
              onChanged: (v) => setState(() => _apDung = v),
            ),
          ],
          const SizedBox(height: 16),
          NutCN('Lưu', key: const Key('cn-dv-luu'), onPressed: _luu),
        ],
      ),
    );
  }
}

/// Sheet thêm dịch vụ. Trả `(tên, giá, chu kỳ)`.
class _SheetThemDichVu extends StatefulWidget {
  const _SheetThemDichVu();

  @override
  State<_SheetThemDichVu> createState() => _SheetThemDichVuState();
}

class _SheetThemDichVuState extends State<_SheetThemDichVu> {
  final _ten = TextEditingController();
  final _gia = TextEditingController();
  String _cachTinh = 'don_gia';

  @override
  void dispose() {
    _ten.dispose();
    _gia.dispose();
    super.dispose();
  }

  void _them() {
    final t = _ten.text.trim();
    final g = docSoCN(_gia.text);
    if (t.isEmpty || g == null) {
      baoCN(context, 'Nhập tên và đơn giá dịch vụ', loi: true);
      return;
    }
    Navigator.pop(context, (t, g, _cachTinh));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thêm dịch vụ', style: HD.bodyBold(size: 18, color: HD.ink)),
          const SizedBox(height: 16),
          ONhapCN(nhan: 'Tên dịch vụ', ctrl: _ten, goiY: 'VD: Gửi xe', khoa: const Key('cn-dv-ten')),
          const SizedBox(height: 14),
          Text('Cách tính', style: HD.bodyBold(size: 14, color: HD.ink)),
          const SizedBox(height: 8),
          CongTacCN(
            cacO: const ['Theo đơn giá', 'Theo người'],
            chon: _cachTinh == 'theo_nguoi' ? 1 : 0,
            khoa: const [Key('cn-dv-moi-don-gia'), Key('cn-dv-moi-theo-nguoi')],
            onChon: (i) => setState(() => _cachTinh = i == 1 ? 'theo_nguoi' : 'don_gia'),
          ),
          const SizedBox(height: 14),
          ONhapCN(
            nhan: 'Đơn giá',
            ctrl: _gia,
            so: true,
            duoi: _cachTinh == 'theo_nguoi' ? 'đ/người/tháng' : 'đ/tháng',
            khoa: const Key('cn-dv-gia-moi'),
          ),
          const SizedBox(height: 18),
          NutCN('Thêm', key: const Key('cn-dv-them-luu'), onPressed: _them),
        ],
      ),
    );
  }
}


/// Sheet chọn số người ở (1–50). Trả số người.
class _SheetSoNguoi extends StatefulWidget {
  const _SheetSoNguoi({required this.hienTai});

  final int hienTai;

  @override
  State<_SheetSoNguoi> createState() => _SheetSoNguoiState();
}

class _SheetSoNguoiState extends State<_SheetSoNguoi> {
  late int _so = widget.hienTai < 1 ? 1 : widget.hienTai;

  Widget _nut(IconData icon, Key khoa, VoidCallback? onTap) => Material(
    color: onTap == null ? HD.paperSunken : HD.accentTint,
    shape: const CircleBorder(),
    child: InkWell(
      key: khoa,
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, color: onTap == null ? HD.inkMuted : HD.accent),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số người ở', style: HD.bodyBold(size: 18, color: HD.ink)),
            const SizedBox(height: 4),
            Text(
              'Nhân với nước và dịch vụ tính theo người.',
              style: HD.body(size: 13, color: HD.inkMuted),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _nut(Icons.remove_rounded, const Key('cn-so-nguoi-tru'), _so > 1 ? () => setState(() => _so--) : null),
                SizedBox(
                  width: 110,
                  child: Text(
                    '$_so người',
                    key: const Key('cn-so-nguoi-gia-tri'),
                    textAlign: TextAlign.center,
                    style: HD.bodyBold(size: 22, color: HD.ink),
                  ),
                ),
                _nut(Icons.add_rounded, const Key('cn-so-nguoi-cong'), _so < 50 ? () => setState(() => _so++) : null),
              ],
            ),
            const SizedBox(height: 20),
            NutCN('Lưu', key: const Key('cn-so-nguoi-luu'), onPressed: () => Navigator.pop(context, _so)),
          ],
        ),
      ),
    );
  }
}
