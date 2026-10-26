import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:house_booking/core/utils/viet_qr.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/ngan_hang_vn.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// "Tài khoản nhận tiền" của MỘT toà hoặc MỘT phòng — khách bấm "Thanh toán
/// ngay" ở hoá đơn là thấy đúng tài khoản này kèm mã VietQR (điền sẵn số tiền,
/// nội dung) để chuyển khoản ngay trong app.
///
/// Toà: khai một lần, mọi phòng dùng chung. Phòng: mặc định dùng của toà, bật
/// "tài khoản riêng" khi phòng thu về tài khoản khác (vd phòng của chủ khác).
/// API: `GET|PUT /api/host/so-chu-nha/{toa-nha|phong}/{id}/tai-khoan`.
class TaiKhoanNhanScreen extends StatefulWidget {
  const TaiKhoanNhanScreen.toa({super.key, required int toaId, this.api = const SoChuNhaApi()})
      : id = toaId,
        laPhong = false;

  const TaiKhoanNhanScreen.phong({super.key, required int roomId, this.api = const SoChuNhaApi()})
      : id = roomId,
        laPhong = true;

  final int id;
  final bool laPhong;
  final SoChuNhaApi api;

  @override
  State<TaiKhoanNhanScreen> createState() => _TaiKhoanNhanScreenState();
}

class _TaiKhoanNhanScreenState extends State<TaiKhoanNhanScreen> {
  TaiKhoanNhanCN? _d;
  Object? _loi;
  bool _dang = false;
  bool _rieng = false;
  NganHangVN? _nh;
  final _so = TextEditingController();
  final _chu = TextEditingController();

  @override
  void initState() {
    super.initState();
    _so.addListener(() => setState(() {}));
    _tai();
  }

  @override
  void dispose() {
    _so.dispose();
    _chu.dispose();
    super.dispose();
  }

  Future<void> _tai() async {
    try {
      final d = widget.laPhong
          ? await widget.api.taiKhoanPhong(widget.id)
          : await widget.api.taiKhoanToa(widget.id);
      if (mounted) setState(() => _nap(d));
    } catch (e) {
      if (mounted) setState(() => _loi = e);
    }
  }

  void _nap(TaiKhoanNhanCN d) {
    _d = d;
    final tk = widget.laPhong ? d.rieng : d.taiKhoan;
    _rieng = widget.laPhong && d.rieng != null;
    _nh = nganHangTheoBin(tk?.bin);
    _so.text = tk?.so ?? '';
    _chu.text = tk?.chu ?? '';
  }

  bool get _dangKhai => !widget.laPhong || _rieng;

  Future<void> _luu({bool xoa = false}) async {
    final boTrong = xoa || !_dangKhai;
    if (!boTrong && (_nh == null || _so.text.trim().isEmpty || _chu.text.trim().isEmpty)) {
      baoCN(context, 'Chọn ngân hàng và nhập đủ số tài khoản, tên chủ tài khoản', loi: true);
      return;
    }
    setState(() => _dang = true);
    try {
      final bin = boTrong ? '' : _nh!.bin;
      final so = boTrong ? '' : _so.text.trim();
      final chu = boTrong ? '' : _chu.text.trim();
      final d = widget.laPhong
          ? await widget.api.suaTaiKhoanPhong(widget.id, bin: bin, so: so, chu: chu)
          : await widget.api.suaTaiKhoanToa(widget.id, bin: bin, so: so, chu: chu);
      if (!mounted) return;
      setState(() {
        _nap(d);
        _dang = false;
      });
      baoCN(context, boTrong ? 'Đã bỏ tài khoản' : 'Đã lưu tài khoản nhận tiền');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dang = false);
      baoCN(context, loiCN(e), loi: true);
    }
  }

  Future<void> _chonNganHang() async {
    final chon = await showModalBottomSheet<NganHangVN>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MauCN.the,
      builder: (_) => const _ChonNganHang(),
    );
    if (chon != null && mounted) setState(() => _nh = chon);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return ManCN(
      tieuDe: widget.laPhong ? 'Tài khoản nhận tiền – phòng' : 'Tài khoản nhận tiền – tòa',
      day: d == null
          ? null
          : NutCN('Lưu', key: const Key('tk-luu'), onPressed: _luu, dangChay: _dang),
      body: d == null
          ? (_loi != null
                ? RongCN(loiCN(_loi!), icon: Icons.cloud_off_rounded)
                : const Center(child: CircularProgressIndicator(color: HD.accent)))
          : ListView(
              key: const Key('tk-nhan-tien'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'Khách bấm "Thanh toán ngay" ở hóa đơn sẽ thấy tài khoản này kèm mã QR '
                  'đã điền sẵn số tiền và nội dung.',
                  style: HD.body(size: 13.5, color: HD.inkMuted),
                ),
                const SizedBox(height: 12),
                if (widget.laPhong) ...[
                  _theDangDung(d),
                  const SizedBox(height: 12),
                  CongTacCN(
                    cacO: const ['Dùng của tòa', 'Tài khoản riêng'],
                    chon: _rieng ? 1 : 0,
                    khoa: const [Key('tk-dung-toa'), Key('tk-rieng')],
                    onChon: (i) => setState(() => _rieng = i == 1),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_dangKhai) ..._form(),
                if (!widget.laPhong && d.taiKhoan != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('tk-xoa'),
                    onPressed: _dang ? null : () => _luu(xoa: true),
                    child: Text('Bỏ tài khoản của tòa', style: HD.body(size: 14, color: HD.negative)),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _theDangDung(TaiKhoanNhanCN d) {
    final tk = d.hieuLuc;
    final nguon = switch (tk?.nguon) {
      'phong' => 'tài khoản riêng của phòng',
      'toa' => 'tài khoản của tòa',
      'ho_so' => 'tài khoản trong hồ sơ của bạn',
      _ => '',
    };
    return TheCN(
      key: const Key('tk-dang-dung'),
      child: Text(
        tk == null
            ? 'Chưa có tài khoản nào — khách chưa chuyển khoản được qua app. '
                  'Khai ở tòa để mọi phòng dùng chung.'
            : 'Khách đang thấy $nguon: ${tk.nganHang} · ${tk.so} · ${tk.chu}',
        style: HD.body(size: 13.5, color: tk == null ? MauCN.cam : HD.ink),
      ),
    );
  }

  List<Widget> _form() {
    final so = _so.text.replaceAll(RegExp(r'[\s.\-]'), '');
    final coQr = _nh != null && RegExp(r'^[0-9A-Za-z]{4,30}$').hasMatch(so);
    return [
      Text('Ngân hàng', style: HD.bodyBold(size: 14, color: HD.ink)),
      const SizedBox(height: 8),
      InkWell(
        key: const Key('tk-ngan-hang'),
        onTap: _chonNganHang,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: kieuONhapCN(goiY: 'Chọn ngân hàng'),
          isEmpty: _nh == null,
          child: _nh == null
              ? null
              : Text('${_nh!.tenNgan} · ${_nh!.ten}', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
      const SizedBox(height: 14),
      ONhapCN(nhan: 'Số tài khoản', ctrl: _so, so: true, goiY: 'VD 0011001234567', khoa: const Key('tk-so')),
      const SizedBox(height: 14),
      ONhapCN(nhan: 'Tên chủ tài khoản', ctrl: _chu, goiY: 'VD NGUYEN VAN A', khoa: const Key('tk-chu')),
      if (coQr) ...[
        const SizedBox(height: 18),
        Center(
          child: Column(
            children: [
              QrImageView(
                key: const Key('tk-qr'),
                data: chuoiVietQr(bin: _nh!.bin, soTaiKhoan: so),
                size: 160,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 4),
              Text(
                'Mã khách sẽ quét (khi thanh toán có kèm số tiền)',
                style: HD.body(size: 12.5, color: HD.inkMuted),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}

/// Chọn ngân hàng — gõ để lọc theo tên ngắn / tên đầy đủ / mã.
class _ChonNganHang extends StatefulWidget {
  const _ChonNganHang();

  @override
  State<_ChonNganHang> createState() => _ChonNganHangState();
}

class _ChonNganHangState extends State<_ChonNganHang> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final ds = [
      for (final n in dsNganHangVN)
        if (q.isEmpty ||
            n.tenNgan.toLowerCase().contains(q) ||
            n.ten.toLowerCase().contains(q) ||
            n.ma.toLowerCase().contains(q))
          n,
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const Key('tk-tim-ngan-hang'),
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: kieuONhapCN(goiY: 'Tìm ngân hàng (VD: Vietcombank, MB, TCB)'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ds.length,
                itemBuilder: (context, i) => ListTile(
                  key: Key('tk-nh-${ds[i].bin}'),
                  title: Text(ds[i].tenNgan, style: HD.bodyBold(size: 15, color: HD.ink)),
                  subtitle: Text(ds[i].ten, style: HD.body(size: 12.5, color: HD.inkMuted)),
                  onTap: () => Navigator.pop(context, ds[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
