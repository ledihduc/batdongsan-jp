import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/hoa_don_thang_api.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/providers/service_fee_provider.dart';
import 'package:house_booking/features/host/billing/screens/invoice_detail_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_list_screen.dart';
import 'package:house_booking/features/host/billing/screens/service_fee_list_screen.dart';
import 'package:house_booking/features/host/dien_nuoc/dien_nuoc_chung.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';

/// DỊCH VỤ & HOÁ ĐƠN — bước hai của việc lập hoá đơn tháng, dựng theo mockup
/// "Dịch vụ & hóa đơn" (12/09/2026): thẻ phòng · tổng thanh toán + hạn · lưới
/// dịch vụ trong tháng (bật/tắt hoặc đếm lượt) · chi tiết từng dòng tiền · lịch
/// sử hoá đơn · thanh dưới "Nhắc thanh toán" / "Gửi hoá đơn".
///
/// Route: không — `Navigator.push` từ màn Điện nước (nút "Tiếp tục").
/// API: [HoaDonThangApi] (`/api/host/hoa-don/xem-truoc`, `/chot`).
///
/// Mỗi lần bật/tắt dịch vụ hoặc sửa giảm trừ là gọi lại XEM TRƯỚC, không tự
/// cộng trừ ở máy: con số trên màn phải là con số server sẽ ghi vào hoá đơn,
/// lệch một nghìn đồng là mất lòng tin cả trang.
class DichVuHoaDonScreen extends StatefulWidget {
  const DichVuHoaDonScreen({
    super.key,
    required this.contractId,
    required this.thang,
    this.api = const HoaDonThangApi(),
    this.moHoaDonThu,
  });

  final int contractId;

  /// 'YYYY-MM'.
  final String thang;
  final HoaDonThangApi api;

  /// Chỉ dùng trong test: thay lượt mở màn Chi tiết hoá đơn (màn đó tự gọi
  /// mạng, widget test không nên đi theo).
  final void Function(int invoiceId)? moHoaDonThu;

  @override
  State<DichVuHoaDonScreen> createState() => _DichVuHoaDonScreenState();
}

class _DichVuHoaDonScreenState extends State<DichVuHoaDonScreen> {
  late String _thang = widget.thang;
  HoaDonThang? _hd;

  /// `null` = chưa ai đụng vào: để server dùng mặc định của hợp đồng.
  Map<int, double>? _chon;
  double _giamTru = 0;
  bool _dangTai = false;
  bool _dangChot = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final hd = await widget.api.xemTruoc(
        widget.contractId,
        _thang,
        dichVu: _chon,
        giamTru: _giamTru,
      );
      if (!mounted) return;
      setState(() {
        _hd = hd;
        // Lượt đầu: lấy lựa chọn mặc định của hợp đồng làm điểm bắt đầu, để
        // lần bật/tắt sau gửi lên đúng cả những dịch vụ đang bật sẵn.
        _chon ??= hd.chon;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loi = e is ApiException ? e.message : 'Không tải được hoá đơn tháng');
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _bat(DichVuThang d, bool bat) async {
    final chon = {...?_chon};
    if (bat) {
      chon[d.id] = d.theoLuot ? (d.soLuong > 0 ? d.soLuong : 1) : 1;
    } else {
      chon.remove(d.id);
    }
    setState(() => _chon = chon);
    await _nap();
  }

  Future<void> _doiSoLuong(DichVuThang d, double moi) async {
    final chon = {...?_chon};
    if (moi <= 0) {
      chon.remove(d.id);
    } else {
      chon[d.id] = moi;
    }
    setState(() => _chon = chon);
    await _nap();
  }

  Future<void> _suaGiamTru() async {
    final c = TextEditingController(
      text: _giamTru == 0 ? '' : _giamTru.toStringAsFixed(0),
    );
    final ra = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Giảm trừ tháng này'),
        content: TextField(
          key: const ValueKey('o-giam-tru'),
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Số tiền giảm (đ)',
            helperText: 'Ưu đãi, trừ cọc, bù hỏng hóc…',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Huỷ')),
          TextButton(
            key: const ValueKey('luu-giam-tru'),
            onPressed: () => Navigator.pop(d, double.tryParse(c.text.trim()) ?? 0),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ra == null) return;
    setState(() => _giamTru = ra < 0 ? 0 : ra);
    await _nap();
  }

  Future<void> _doiThang() async {
    final ds = _muoiHaiThang();
    final ra = await showModalBottomSheet<String>(
      context: context,
      builder: (d) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in ds)
              ListTile(
                title: Text(nhanThang(t)),
                trailing: t == _thang
                    ? const Icon(Icons.check, color: HD.accent)
                    : null,
                onTap: () => Navigator.pop(d, t),
              ),
          ],
        ),
      ),
    );
    if (ra == null || ra == _thang) return;
    setState(() {
      _thang = ra;
      // Lựa chọn dịch vụ là của TỪNG tháng — đổi tháng thì quay về mặc định
      // của hợp đồng, không mang số lượt giặt sấy tháng trước sang.
      _chon = null;
      _giamTru = 0;
      _hd = null;
    });
    await _nap();
  }

  static List<String> _muoiHaiThang() {
    final n = DateTime.now();
    return [
      for (int i = 0; i < 12; i++)
        () {
          final d = DateTime(n.year, n.month - i);
          return '${d.year}-${d.month.toString().padLeft(2, '0')}';
        }(),
    ];
  }

  Future<void> _moHoaDon(int id) async {
    final thu = widget.moHoaDonThu;
    if (thu != null) {
      thu(id);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => InvoiceProvider(),
          child: InvoiceDetailScreen(invoiceId: id),
        ),
      ),
    );
  }

  Future<void> _moTatCaHoaDon() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => InvoiceProvider(),
        child: const InvoiceListScreen(),
      ),
    ),
  );

  Future<void> _moCaiDatDichVu() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ServiceFeeProvider()),
            ChangeNotifierProvider(create: (_) => BuildingProvider()),
          ],
          child: const ServiceFeeListScreen(),
        ),
      ),
    );
    // Sửa đơn giá / thêm dịch vụ xong thì lưới phải đổi theo.
    if (mounted) await _nap();
  }

  Future<void> _guiHoaDon() async {
    final hd = _hd;
    if (hd == null || _dangChot) return;
    if (!hd.chiSoDaDuyet) {
      final tiep = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Chưa có chỉ số đã duyệt'),
          content: Text(
            '${hd.canhBaoChiSo ?? 'Chỉ số điện nước tháng này chưa được duyệt.'}\n\n'
            'Gửi bây giờ thì hoá đơn KHÔNG có tiền điện nước.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Quay lại chụp'),
            ),
            TextButton(
              key: const ValueKey('gui-thieu-chi-so'),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Vẫn gửi'),
            ),
          ],
        ),
      );
      if (tiep != true) return;
    }
    setState(() => _dangChot = true);
    try {
      final kq = await widget.api.chot(
        widget.contractId,
        _thang,
        dichVu: _chon,
        giamTru: _giamTru,
        gui: true,
      );
      if (!mounted) return;
      _bao('Đã gửi hoá đơn ${kq.so} · ${PriceFormat.full(kq.tong)}');
      await _moHoaDon(kq.invoiceId);
      if (mounted) await _nap();
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không gửi được hoá đơn');
    } finally {
      if (mounted) setState(() => _dangChot = false);
    }
  }

  /// Nhắc bằng tin nhắn tới đúng số của khách — app không tự gửi thay họ.
  Future<void> _nhacThanhToan() async {
    final hd = _hd;
    if (hd == null) return;
    final sdt = hd.khachSdt.trim();
    final loi =
        'Phòng ${hd.maPhong} ${nhanThang(_thang).toLowerCase()}: '
        '${PriceFormat.full(hd.tong)}, hạn ${ngayVN(hd.hanDong)}. '
        'Cảm ơn anh/chị.';
    if (sdt.isEmpty) {
      await Clipboard.setData(ClipboardData(text: loi));
      _bao('Phòng này chưa có số điện thoại — đã sao chép nội dung nhắc.');
      return;
    }
    final ok = await launchUrl(
      Uri(scheme: 'sms', path: sdt, queryParameters: {'body': loi}),
    );
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: '$sdt — $loi'));
      if (mounted) _bao('Không mở được tin nhắn — đã sao chép nội dung.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hd = _hd;
    return Scaffold(
      backgroundColor: HD.paper,
      body: SafeArea(
        child: Column(
          children: [
            _thanhTren(),
            Expanded(
              child: RefreshIndicator(
                color: HD.accent,
                onRefresh: _nap,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  children: [
                    if (_dangTai && hd != null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: HD.s8),
                        child: LinearProgressIndicator(minHeight: 2, color: HD.accent),
                      ),
                    if (_loi != null)
                      Text(_loi!, style: HD.body(size: 13, color: HD.negative))
                    else if (hd == null)
                      const Padding(
                        padding: EdgeInsets.all(HD.s32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      _TheThongTinPhong(hd: hd, onMoChiSo: _moChiSo),
                      const SizedBox(height: 14),
                      _TheTongThanhToan(hd: hd, thang: _thang),
                      if (hd.canhBaoChiSo != null) ...[
                        const SizedBox(height: 14),
                        _CanhBao(chu: hd.canhBaoChiSo!, onChup: _moChiSo),
                      ],
                      const SizedBox(height: 14),
                      _LuoiDichVu(
                        ds: hd.dichVu,
                        onBat: _bat,
                        onSoLuong: _doiSoLuong,
                        onCaiDat: _moCaiDatDichVu,
                      ),
                      const SizedBox(height: 14),
                      _TheChiTiet(
                        hd: hd,
                        thang: _thang,
                        onSuaGiamTru: _suaGiamTru,
                        onXemHoaDon: hd.hoaDon == null
                            ? null
                            : () => _moHoaDon(hd.hoaDon!.id),
                      ),
                      const SizedBox(height: 14),
                      _TheLichSu(
                        ds: hd.lichSu,
                        onMo: _moHoaDon,
                        onTatCa: _moTatCaHoaDon,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (hd != null) _thanhDuoi(hd),
          ],
        ),
      ),
    );
  }

  /// Quay lại bước chỉ số điện nước để chụp / duyệt.
  void _moChiSo() => Navigator.maybePop(context);

  Widget _thanhTren() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(HD.s8, HD.s8, HD.s12, HD.s8),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: Text(
            'Dịch vụ & hóa đơn',
            style: HD.bodyBold(size: 17),
            textAlign: TextAlign.center,
          ),
        ),
        InkWell(
          key: const ValueKey('chon-thang'),
          onTap: _doiThang,
          borderRadius: BorderRadius.circular(HD.r12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 5),
            decoration: BoxDecoration(
              color: HD.paper,
              borderRadius: BorderRadius.circular(HD.r12),
              border: Border.all(color: HD.hairline),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14),
                const SizedBox(width: 5),
                Text(_nhanThangNgan(_thang), style: HD.bodyBold(size: 12)),
                const Icon(Icons.expand_more, size: 16, color: HD.inkMuted),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  static String _nhanThangNgan(String t) {
    final p = t.split('-');
    return p.length == 2 ? 'Tháng ${int.tryParse(p[1]) ?? p[1]}/${p[0]}' : t;
  }

  Widget _thanhDuoi(HoaDonThang hd) {
    final daGui = hd.hoaDon?.daGui ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, HD.s12, 14, HD.s12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: HD.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('nhac-thanh-toan'),
              onPressed: hd.hoaDon == null ? null : _nhacThanhToan,
              icon: const Icon(Icons.notifications_none, size: 18),
              label: const Text('Nhắc thanh toán'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HD.accent,
                side: const BorderSide(color: HD.accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
              ),
            ),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('gui-hoa-don'),
              onPressed: _dangChot || daGui ? null : _guiHoaDon,
              icon: _dangChot
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(daGui ? Icons.check : Icons.send, size: 18),
              label: Text(daGui ? 'Đã gửi' : 'Gửi hóa đơn'),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ trắng bo 16 — khuôn chung của mọi khối trên trang.
class _The extends StatelessWidget {
  const _The({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    child: child,
  );
}

class _TheThongTinPhong extends StatelessWidget {
  const _TheThongTinPhong({required this.hd, required this.onMoChiSo});

  final HoaDonThang hd;
  final VoidCallback onMoChiSo;

  @override
  Widget build(BuildContext context) {
    final anh = hd.anhToa;
    return _The(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(HD.r12),
            child: anh == null
                ? Container(
                    width: 64,
                    height: 64,
                    color: HD.paperSunken,
                    child: const Icon(Icons.apartment, color: HD.inkMuted),
                  )
                : Image.network(
                    anhTuyetDoi(anh),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 64,
                      height: 64,
                      color: HD.paperSunken,
                      child: const Icon(Icons.apartment, color: HD.inkMuted),
                    ),
                  ),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hd.tenToa, style: HD.bodyBold(size: 15)),
                if (hd.diaChi.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      hd.diaChi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 11.5, color: HD.inkMuted),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Phòng ${hd.maPhong}', style: HD.bodyBold(size: 13.5)),
                    const SizedBox(width: HD.s8),
                    if (hd.trangThaiPhong == 'occupied')
                      const _NhanTron(
                        chu: 'Đang thuê',
                        mau: HD.accent,
                        icon: Icons.person,
                      ),
                  ],
                ),
                if (hd.khachTen.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [hd.khachTen, hd.khachSdt].where((x) => x.isNotEmpty).join(' · '),
                      style: HD.body(size: 11, color: HD.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('xem-chi-so'),
            tooltip: 'Xem chỉ số điện nước',
            icon: const Icon(Icons.chevron_right, color: HD.inkMuted),
            onPressed: onMoChiSo,
          ),
        ],
      ),
    );
  }
}

class _TheTongThanhToan extends StatelessWidget {
  const _TheTongThanhToan({required this.hd, required this.thang});

  final HoaDonThang hd;
  final String thang;

  @override
  Widget build(BuildContext context) {
    final tt = _nhanTrangThai(hd);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HD.accentTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HD.accentSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: HD.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long, color: HD.accent, size: 20),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng thanh toán ${_nhanThangNho(thang)}',
                  style: HD.body(size: 12, color: HD.inkSoft),
                ),
                const SizedBox(height: 4),
                Text(
                  PriceFormat.full(hd.tong),
                  style: HD.bodyBold(size: 24, color: HD.accent),
                ),
                const SizedBox(height: 5),
                Text.rich(
                  TextSpan(
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                    children: [
                      TextSpan(text: 'Hạn thanh toán: ${ngayVN(hd.hanDong)} '),
                      TextSpan(
                        text: _conLai(hd.conNgay),
                        style: HD.bodyBold(size: 11.5, color: HD.accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _NhanTron(chu: tt.chu, mau: tt.mau, icon: tt.icon),
        ],
      ),
    );
  }

  static String _nhanThangNho(String t) {
    final p = t.split('-');
    return p.length == 2 ? 'tháng ${int.tryParse(p[1]) ?? p[1]}/${p[0]}' : t;
  }

  static String _conLai(int n) {
    if (n < 0) return '(quá hạn ${-n} ngày)';
    if (n == 0) return '(hôm nay)';
    return '(còn $n ngày)';
  }

  static ({String chu, Color mau, IconData icon}) _nhanTrangThai(HoaDonThang hd) {
    final inv = hd.hoaDon;
    if (inv == null) {
      return (chu: 'Chưa lập', mau: HD.inkMuted, icon: Icons.edit_note);
    }
    return switch (inv.trangThai) {
      'paid' => (chu: 'Đã thanh toán', mau: HD.positive, icon: Icons.check_circle),
      'partial' => (chu: 'Trả một phần', mau: HD.svcAmber, icon: Icons.pie_chart),
      'overdue' => (chu: 'Quá hạn', mau: HD.negative, icon: Icons.error_outline),
      'draft' => (chu: 'Hoá đơn nháp', mau: HD.inkMuted, icon: Icons.edit_note),
      _ => (chu: 'Chưa thanh toán', mau: HD.accent, icon: Icons.schedule),
    };
  }
}

/// Vì sao tiền điện nước đang là 0 — kèm lối quay lại chụp công tơ.
class _CanhBao extends StatelessWidget {
  const _CanhBao({required this.chu, required this.onChup});

  final String chu;
  final VoidCallback onChup;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.warningTint,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.warning.withValues(alpha: 0.5)),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, size: 18, color: HD.svcAmber),
        const SizedBox(width: HD.s8),
        Expanded(child: Text(chu, style: HD.body(size: 12, color: HD.inkSoft))),
        TextButton(
          key: const ValueKey('quay-lai-chup'),
          onPressed: onChup,
          child: const Text('Chụp số'),
        ),
      ],
    ),
  );
}

class _LuoiDichVu extends StatelessWidget {
  const _LuoiDichVu({
    required this.ds,
    required this.onBat,
    required this.onSoLuong,
    required this.onCaiDat,
  });

  final List<DichVuThang> ds;
  final void Function(DichVuThang, bool) onBat;
  final void Function(DichVuThang, double) onSoLuong;
  final VoidCallback onCaiDat;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text('Dịch vụ trong tháng', style: HD.bodyBold(size: 15)),
          ),
          TextButton.icon(
            key: const ValueKey('cai-dat-dich-vu'),
            onPressed: onCaiDat,
            icon: const Icon(Icons.settings, size: 14),
            label: const Text('Cài đặt dịch vụ'),
            style: TextButton.styleFrom(
              foregroundColor: HD.accent,
              padding: const EdgeInsets.symmetric(horizontal: HD.s8),
              textStyle: HD.bodyBold(size: 12),
            ),
          ),
        ],
      ),
      const SizedBox(height: HD.s8),
      if (ds.isEmpty)
        _The(
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: HD.inkMuted),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Text(
                  'Toà này chưa khai dịch vụ nào. Thêm ở "Cài đặt dịch vụ".',
                  style: HD.body(size: 12, color: HD.inkMuted),
                ),
              ),
            ],
          ),
        )
      else
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.78,
          children: [
            for (final d in ds)
              _TheDichVu(
                dv: d,
                onBat: (b) => onBat(d, b),
                onSoLuong: (n) => onSoLuong(d, n),
              ),
          ],
        ),
    ],
  );
}

class _TheDichVu extends StatelessWidget {
  const _TheDichVu({
    required this.dv,
    required this.onBat,
    required this.onSoLuong,
  });

  final DichVuThang dv;
  final void Function(bool) onBat;
  final void Function(double) onSoLuong;

  /// Biểu tượng đoán theo tên — danh mục dịch vụ do chủ nhà tự gõ, không có mã.
  static IconData _icon(String ten) {
    final t = ten.toLowerCase();
    if (t.contains('internet') || t.contains('wifi') || t.contains('mạng')) {
      return Icons.wifi;
    }
    if (t.contains('xe')) return Icons.two_wheeler;
    if (t.contains('rác')) return Icons.delete_outline;
    if (t.contains('vệ sinh') || t.contains('dọn')) return Icons.cleaning_services;
    if (t.contains('giặt') || t.contains('sấy')) return Icons.local_laundry_service;
    if (t.contains('nước uống') || t.contains('bình')) return Icons.water_drop;
    if (t.contains('thang')) return Icons.elevator;
    if (t.contains('bảo vệ') || t.contains('an ninh')) return Icons.shield_outlined;
    if (t.contains('máy lạnh') || t.contains('điều hoà')) return Icons.ac_unit;
    return Icons.miscellaneous_services;
  }

  @override
  Widget build(BuildContext context) {
    final bat = dv.dangBat;
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bat ? HD.accentSoft : HD.hairline.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: bat ? HD.accentTint : HD.paperSunken,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon(dv.ten),
                  size: 16,
                  color: bat ? HD.accent : HD.inkMuted,
                ),
              ),
              const Spacer(),
              if (!dv.theoLuot)
                Transform.scale(
                  scale: 0.72,
                  child: Switch(
                    key: ValueKey('bat-${dv.id}'),
                    value: bat,
                    activeThumbColor: Colors.white,
                    activeTrackColor: HD.accent,
                    onChanged: onBat,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dv.ten,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HD.body(size: 12, color: HD.inkSoft),
          ),
          Text(PriceFormat.full(dv.donGia), style: HD.bodyBold(size: 13)),
          Text(
            dv.theoLuot ? '/lượt' : '/tháng',
            style: HD.body(size: 10, color: HD.inkMuted),
          ),
          if (dv.theoLuot) ...[
            const Spacer(),
            _Dem(
              id: dv.id,
              so: dv.dangBat ? dv.soLuong : 0,
              onDoi: onSoLuong,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ô đếm lượt cho dịch vụ tính theo lần (giặt sấy, bình nước).
class _Dem extends StatelessWidget {
  const _Dem({required this.id, required this.so, required this.onDoi});

  final int id;
  final double so;
  final void Function(double) onDoi;

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    decoration: BoxDecoration(
      color: HD.paperSunken.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(HD.r8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _nut(
          const ValueKey('giam'),
          Icons.remove,
          so <= 0 ? null : () => onDoi(so - 1),
        ),
        Text(
          so.toStringAsFixed(0),
          key: ValueKey('so-luong-$id'),
          style: HD.bodyBold(size: 12),
        ),
        _nut(const ValueKey('tang'), Icons.add, () => onDoi(so + 1)),
      ],
    ),
  );

  Widget _nut(Key k, IconData icon, VoidCallback? onTap) => InkWell(
    key: ValueKey('${(k as ValueKey).value}-$id'),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(
        icon,
        size: 14,
        color: onTap == null ? HD.hairlineStrong : HD.inkSoft,
      ),
    ),
  );
}

class _TheChiTiet extends StatelessWidget {
  const _TheChiTiet({
    required this.hd,
    required this.thang,
    required this.onSuaGiamTru,
    this.onXemHoaDon,
  });

  final HoaDonThang hd;
  final String thang;
  final VoidCallback onSuaGiamTru;
  final VoidCallback? onXemHoaDon;

  @override
  Widget build(BuildContext context) {
    final tenDichVu = [
      for (final d in hd.dong)
        if (d.loai == 'service') d.moTa,
    ];
    return _The(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chi tiết hóa đơn ${_nhanThangNho(thang)}',
                  style: HD.bodyBold(size: 14.5),
                ),
              ),
              if (onXemHoaDon != null)
                TextButton.icon(
                  key: const ValueKey('xem-hoa-don'),
                  onPressed: onXemHoaDon,
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Xem hóa đơn'),
                  style: TextButton.styleFrom(
                    foregroundColor: HD.accent,
                    padding: const EdgeInsets.symmetric(horizontal: HD.s8),
                    textStyle: HD.bodyBold(size: 12),
                  ),
                ),
            ],
          ),
          const Divider(height: HD.s16, color: HD.hairline),
          _DongChiTiet(
            icon: Icons.home_outlined,
            nhan: 'Tiền phòng',
            tien: hd.tienPhong,
          ),
          _DongChiTiet(
            icon: Icons.bolt,
            nhan: 'Tiền điện',
            phu: '(${soDienNuoc(hd.dienDung)} kWh)',
            tien: hd.tienDien,
          ),
          _DongChiTiet(
            icon: Icons.water_drop_outlined,
            nhan: 'Tiền nước',
            phu: '(${soDienNuoc(hd.nuocDung)} m³)',
            tien: hd.tienNuoc,
          ),
          _DongChiTiet(
            icon: Icons.cleaning_services_outlined,
            nhan: 'Dịch vụ',
            phu: tenDichVu.isEmpty ? '(không có)' : '(${tenDichVu.join(', ')})',
            tien: hd.tienDichVu,
          ),
          _DongChiTiet(
            key: const ValueKey('dong-giam-tru'),
            icon: Icons.local_offer_outlined,
            nhan: 'Giảm trừ',
            phu: '(ưu đãi, cọc, khác)',
            tien: -hd.giamTru,
            mauTien: hd.giamTru > 0 ? HD.positive : null,
            onTap: onSuaGiamTru,
          ),
          const Divider(height: HD.s16, color: HD.hairline),
          Row(
            children: [
              Expanded(
                child: Text('Tổng thanh toán', style: HD.bodyBold(size: 15)),
              ),
              Text(
                PriceFormat.full(hd.tong),
                style: HD.bodyBold(size: 19, color: HD.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _nhanThangNho(String t) {
    final p = t.split('-');
    return p.length == 2 ? 'tháng ${int.tryParse(p[1]) ?? p[1]}/${p[0]}' : t;
  }
}

class _DongChiTiet extends StatelessWidget {
  const _DongChiTiet({
    super.key,
    required this.icon,
    required this.nhan,
    required this.tien,
    this.phu,
    this.mauTien,
    this.onTap,
  });

  final IconData icon;
  final String nhan;
  final String? phu;
  final double tien;
  final Color? mauTien;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dong = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: HD.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: HD.body(size: 13, color: HD.inkSoft),
                children: [
                  TextSpan(text: nhan),
                  if (phu != null)
                    TextSpan(
                      text: ' $phu',
                      style: HD.body(size: 12, color: HD.inkMuted),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: HD.s8),
          Text(
            tien == 0 && mauTien == null
                ? PriceFormat.full(0)
                : (tien < 0 ? '-${PriceFormat.full(-tien)}' : PriceFormat.full(tien)),
            style: HD.bodyBold(size: 13, color: mauTien),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.edit, size: 13, color: HD.inkMuted),
            ),
        ],
      ),
    );
    return onTap == null ? dong : InkWell(onTap: onTap, child: dong);
  }
}

class _TheLichSu extends StatelessWidget {
  const _TheLichSu({
    required this.ds,
    required this.onMo,
    required this.onTatCa,
  });

  final List<HoaDonTomTat> ds;
  final void Function(int) onMo;
  final VoidCallback onTatCa;

  @override
  Widget build(BuildContext context) => _The(
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text('Lịch sử hóa đơn', style: HD.bodyBold(size: 14.5))),
            TextButton.icon(
              key: const ValueKey('xem-tat-ca-hoa-don'),
              onPressed: onTatCa,
              icon: const Text('Xem tất cả'),
              label: const Icon(Icons.chevron_right, size: 16),
              style: TextButton.styleFrom(
                foregroundColor: HD.accent,
                padding: const EdgeInsets.symmetric(horizontal: HD.s8),
                textStyle: HD.bodyBold(size: 12),
              ),
            ),
          ],
        ),
        const Divider(height: HD.s16, color: HD.hairline),
        if (ds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HD.s8),
            child: Text(
              'Phòng này chưa có hoá đơn nào.',
              style: HD.body(size: 12, color: HD.inkMuted),
            ),
          )
        else
          for (final (i, inv) in ds.indexed) ...[
            if (i > 0) const Divider(height: 1, color: HD.hairline),
            _MucLichSu(inv: inv, onMo: () => onMo(inv.id)),
          ],
      ],
    ),
  );
}

class _MucLichSu extends StatelessWidget {
  const _MucLichSu({required this.inv, required this.onMo});

  final HoaDonTomTat inv;
  final VoidCallback onMo;

  @override
  Widget build(BuildContext context) {
    final tt = switch (inv.trangThai) {
      'paid' => (chu: 'Đã thanh toán', mau: HD.positive, icon: Icons.check_circle),
      'partial' => (chu: 'Trả một phần', mau: HD.svcAmber, icon: Icons.pie_chart),
      'overdue' => (chu: 'Quá hạn', mau: HD.negative, icon: Icons.error_outline),
      'draft' => (chu: 'Nháp', mau: HD.inkMuted, icon: Icons.edit_note),
      _ => (chu: 'Chờ thanh toán', mau: HD.accent, icon: Icons.schedule),
    };
    return InkWell(
      key: ValueKey('hoa-don-${inv.id}'),
      onTap: onMo,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: HD.s12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: HD.paperSunken,
                borderRadius: BorderRadius.circular(HD.r8),
              ),
              child: const Icon(Icons.description_outlined, size: 16, color: HD.inkMuted),
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nhanThangGon(inv.ky), style: HD.bodyBold(size: 13)),
                  Text(
                    '${PriceFormat.full(inv.tong)} · '
                    '${inv.daTraDu ? 'Thanh toán' : 'Hạn'}: ${ngayVN(inv.hanDong)}',
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            _NhanTron(chu: tt.chu, mau: tt.mau, icon: tt.icon),
            const Icon(Icons.chevron_right, size: 16, color: HD.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// '2024-07' → 'Tháng 7/2024'.
String nhanThangGon(String thang) {
  final p = thang.split('-');
  return p.length == 2 ? 'Tháng ${int.tryParse(p[1]) ?? p[1]}/${p[0]}' : thang;
}

class _NhanTron extends StatelessWidget {
  const _NhanTron({required this.chu, required this.mau, required this.icon});

  final String chu;
  final Color mau;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 3),
    decoration: BoxDecoration(
      color: mau.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: mau),
        const SizedBox(width: 4),
        Text(chu, style: HD.bodyBold(size: 10.5, color: mau)),
      ],
    ),
  );
}
