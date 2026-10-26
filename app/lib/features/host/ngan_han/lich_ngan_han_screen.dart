import 'package:flutter/material.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/data/services/lich_ngan_han_api.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/nhan_phong_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/tra_phong_screen.dart';
import 'package:house_booking/features/host/ngan_han/ho_so_phong_ngan_han_screen.dart';
import 'package:house_booking/data/services/short_stay_api.dart';

/// LỊCH PHÒNG NGẮN HẠN — ma trận phòng × giờ của cả toà trong một ngày,
/// dựng theo mockup "Lịch phòng ngắn hạn" (12/09/2026).
///
/// Route: không — `Navigator.push` từ Sổ phòng (menu tên toà) và từ nút "Lịch"
/// ở màn quản trị phòng ngắn hạn.
/// API: [LichNganHanApi] đọc cả màn một lượt; [ShortStayApi] cho nhận/trả phòng
/// và bỏ khoá — một việc một đường.
///
/// Màn hồ sơ phòng trả lời "phòng này hôm nay thế nào". Màn này trả lời câu của
/// người trực quầy: **cả toà lúc này thế nào** — ai sắp trả, khe nào còn trống
/// để nhận người đang đứng trước mặt.
class LichNganHanScreen extends StatefulWidget {
  const LichNganHanScreen({
    super.key,
    required this.buildingId,
    this.api = const LichNganHanApi(),
    this.shortStayApi = const ShortStayApi(),
    this.caThueApi = const CaThueApi(),
    this.ngayBanDau,
  });

  final int buildingId;
  final LichNganHanApi api;
  final ShortStayApi shortStayApi;

  /// Quầy lễ tân — tách riêng để test bơm giả được.
  final CaThueApi caThueApi;

  /// 'YYYY-MM-DD' — chỉ để test ghim ngày.
  final String? ngayBanDau;

  @override
  State<LichNganHanScreen> createState() => _LichNganHanScreenState();
}

class _LichNganHanScreenState extends State<LichNganHanScreen> {
  /// Bề rộng một giờ trên lưới. 56px vừa đủ ghi "14:00" mà không phải thu nhỏ
  /// chữ tới mức phải ghé sát mắt.
  static const double _rongGio = 56;
  static const double _rongCotPhong = 72;

  /// Chiều cao hàng nhãn giờ — dùng chung cho cả cột phòng ghim.
  static const double _caoDauLuoi = 14;
  static const double _caoHang = 46;

  final _cuonNgang = ScrollController();
  LichNgay? _lich;
  String? _ngay;
  bool _dangTai = false;
  bool _dangLam = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _ngay = widget.ngayBanDau;
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  @override
  void dispose() {
    _cuonNgang.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final l = await widget.api.ngay(widget.buildingId, ngay: _ngay);
      if (!mounted) return;
      setState(() {
        _lich = l;
        _ngay = l.ngay;
      });
      _cuonToiGioHienTai();
    } catch (e) {
      if (mounted) {
        setState(() => _loi = e is ApiException ? e.message : 'Không tải được lịch phòng');
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  /// Mở màn ra là thấy NGAY khung giờ đang chạy, không phải cuộn tay từ 00:00.
  void _cuonToiGioHienTai() {
    final l = _lich;
    if (l == null || !_cuonNgang.hasClients) return;
    final gio = (l.bayGio ?? DateTime.now()).hour;
    if (l.ngay != _isoNgay(l.bayGio ?? DateTime.now())) return;
    final x = ((gio - 1) * _rongGio).clamp(0.0, _cuonNgang.position.maxScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cuonNgang.hasClients) _cuonNgang.jumpTo(x);
    });
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _lam(Future<void> Function() viec, String xong) async {
    if (_dangLam) return;
    setState(() => _dangLam = true);
    try {
      await viec();
      if (!mounted) return;
      _bao(xong);
      await _nap();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không thực hiện được');
    } finally {
      if (mounted) setState(() => _dangLam = false);
    }
  }

  Future<void> _doiNgay(int lech) async {
    final goc = DateTime.tryParse(_lich?.ngay ?? '') ?? DateTime.now();
    setState(() => _ngay = _isoNgay(
      DateTime(goc.year, goc.month, goc.day).add(Duration(days: lech)),
    ));
    await _nap();
  }

  Future<void> _chonNgay() async {
    final goc = DateTime.tryParse(_lich?.ngay ?? '') ?? DateTime.now();
    final ra = await showDatePicker(
      context: context,
      initialDate: goc,
      firstDate: DateTime(goc.year - 1),
      lastDate: DateTime(goc.year + 2),
    );
    if (ra == null) return;
    setState(() => _ngay = _isoNgay(ra));
    await _nap();
  }

  /// Mở một màn của quầy lễ tân rồi nạp lại lịch khi quay về.
  Future<void> _mo(Widget man) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => man));
    if (mounted) await _nap();
  }

  Future<void> _xuLy(ViecTrongNgay v) async {
    switch (v.loai) {
      // Nhận/trả phòng đi qua ĐÚNG quy trình quầy (thu tiền, kiểm phòng, khoá
      // dọn) chứ không đổi trạng thái trần — bấm một nút rồi quên thu tiền là
      // cách sổ sách lệch.
      case 'nhan_phong':
        await _mo(
          NhanPhongScreen(
            reservationId: v.reservationId!,
            api: widget.caThueApi,
          ),
        );
      case 'tra_phong':
        await _mo(
          TraPhongScreen(
            reservationId: v.reservationId!,
            api: widget.caThueApi,
          ),
        );
      case 'cho_duyet':
        // Duyệt/từ chối cần nhìn đơn trước — mở chi tiết, nút quyết nằm ở đó.
        await _mo(
          ChiTietCaThueScreen(
            reservationId: v.reservationId!,
            api: widget.caThueApi,
            shortStayApi: widget.shortStayApi,
          ),
        );
      case 'don_xong':
        await _lam(
          () => widget.shortStayApi.unblock(v.roomId, v.blockId!),
          'Phòng ${v.maPhong} đã dọn xong, sẵn sàng nhận khách.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _lich;
    return Scaffold(
      backgroundColor: HD.paper,
      body: SafeArea(
        child: Column(
          children: [
            _thanhTren(l),
            Expanded(
              child: RefreshIndicator(
                color: HD.accent,
                onRefresh: _nap,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                  children: [
                    if (_dangTai && l != null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: HD.s8),
                        child: LinearProgressIndicator(minHeight: 2, color: HD.accent),
                      ),
                    if (_loi != null)
                      Text(_loi!, style: HD.body(size: 13, color: HD.negative))
                    else if (l == null)
                      const Padding(
                        padding: EdgeInsets.all(HD.s32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      _chonNgayDai(l),
                      const SizedBox(height: 10),
                      _boKpi(l),
                      const SizedBox(height: 10),
                      _maTran(l),
                      const SizedBox(height: 10),
                      _viecTrongNgay(l),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thanhTren(LichNgay? l) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(HD.s8, HD.s8, HD.s12, HD.s8),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lịch phòng ngắn hạn', style: HD.bodyBold(size: 17)),
              Text(
                l == null
                    ? 'Quản lý lịch đặt phòng theo giờ, theo ngày'
                    : '${l.tenToa} · ${l.soPhong} phòng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 11, color: HD.inkMuted),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('chon-ngay-lich'),
          tooltip: 'Chọn ngày',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: _chonNgay,
        ),
      ],
    ),
  );

  Widget _chonNgayDai(LichNgay l) {
    final d = DateTime.tryParse(l.ngay) ?? DateTime.now();
    final homNay = DateTime.now();
    final lech = DateTime(d.year, d.month, d.day)
        .difference(DateTime(homNay.year, homNay.month, homNay.day))
        .inDays;
    final nhan = switch (lech) {
      0 => 'Hôm nay',
      1 => 'Ngày mai',
      -1 => 'Hôm qua',
      _ => 'Ngày ${_hai(d.day)}/${_hai(d.month)}',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('ngay-truoc'),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _doiNgay(-1),
          ),
          Expanded(
            child: InkWell(
              onTap: _chonNgay,
              child: Column(
                children: [
                  Text(nhan, style: HD.bodyBold(size: 14)),
                  Text(
                    '${_thu(d)}, ${_hai(d.day)}/${_hai(d.month)}/${d.year}',
                    style: HD.body(size: 11, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('ngay-sau'),
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _doiNgay(1),
          ),
        ],
      ),
    );
  }

  Widget _boKpi(LichNgay l) {
    final o = <(IconData, Color, String, String, String)>[
      (
        Icons.event_available,
        HD.accent,
        '${l.luotDat}',
        'Lượt đặt',
        l.ngay == _isoNgay(DateTime.now()) ? 'hôm nay' : 'trong ngày',
      ),
      (
        Icons.hotel,
        HD.positive,
        '${l.dangO}',
        'Đang ở',
        '${l.congSuat.toStringAsFixed(0)}% công suất',
      ),
      (
        Icons.logout,
        HD.svcAmber,
        '${l.sapTra}',
        'Sắp trả',
        'trong ${l.sapTraGio} giờ tới',
      ),
      if (l.xemTaiChinh)
        (
          Icons.payments_outlined,
          HD.accent,
          PriceFormat.compact(l.doanhThu),
          'Doanh thu',
          'các ca trong ngày',
        ),
    ];
    return Row(
      children: [
        for (var i = 0; i < o.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(HD.r12),
                border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: o[i].$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(HD.r8),
                    ),
                    child: Icon(o[i].$1, size: 13, color: o[i].$2),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(o[i].$3, style: HD.bodyBold(size: 16)),
                  ),
                  Text(o[i].$4, style: HD.body(size: 10, color: HD.inkSoft)),
                  Text(
                    o[i].$5,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 8.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _maTran(LichNgay l) {
    final bayGio = l.bayGio ?? DateTime.now();
    final laHomNay = l.ngay == _isoNgay(bayGio);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Lịch phòng trong ngày', style: HD.bodyBold(size: 13.5)),
              ),
              for (final (mau, chu) in [
                (HD.positive, 'Đang ở'),
                (HD.accent, 'Sắp đến'),
                (HD.svcBlue, 'Dọn'),
              ]) ...[
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(left: 8, right: 3),
                  decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
                ),
                Text(chu, style: HD.body(size: 9.5, color: HD.inkMuted)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (l.phong.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: HD.s16),
              child: Text(
                'Toà này chưa có phòng nào.',
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            )
          else
            // Cột tên phòng GHIM ngoài vùng cuộn: cuộn tới 21:00 mà không biết
            // hàng nào là phòng nào thì cả lưới vô dụng.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              SizedBox(
                width: _rongCotPhong,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: _caoDauLuoi,
                      child: Text(
                        'Phòng',
                        style: HD.bodyBold(size: 10.5, color: HD.inkSoft),
                      ),
                    ),
                    for (final p in l.phong) _oTenPhong(p),
                  ],
                ),
              ),
              Expanded(
              child: SingleChildScrollView(
              controller: _cuonNgang,
              scrollDirection: Axis.horizontal,
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hangGio(),
                      for (final p in l.phong) _hangPhong(p),
                    ],
                  ),
                  if (laHomNay)
                    Positioned(
                      left: _viTri(bayGio) - 1,
                      top: 14,
                      bottom: 0,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: HD.accent,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _gio(bayGio),
                              style: HD.bodyBold(size: 9, color: Colors.white),
                            ),
                          ),
                          Expanded(
                            child: Container(width: 2, color: HD.accent.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              ),
              ),
            ],
            ),
        ],
      ),
    );
  }

  double _viTri(DateTime t) => (t.hour + t.minute / 60) * _rongGio;

  /// Ô tên phòng của cột ghim — cao đúng bằng hàng lưới để hai bên thẳng dòng.
  /// Bấm vào là hồ sơ phòng: mở ca vãng lai, khoá dọn, xem giá — trước đây
  /// vãng lai chỉ mở được khi đi đường Sổ phòng → phòng.
  Widget _oTenPhong(HangPhongLich p) => InkWell(
    key: Key('lich-phong-${p.id}'),
    onTap: () => _mo(
      HoSoPhongNganHanScreen(roomId: p.id, ngayBanDau: _ngay),
    ),
    child: Container(
    height: _caoHang,
    alignment: Alignment.centerLeft,
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: HD.hairline, width: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(p.ma, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: HD.bodyBold(size: 12)),
        Text(
          p.hang ?? '${p.sucChua} khách',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 9, color: HD.inkMuted),
        ),
      ],
    ),
    ),
  );

  /// Hàng giờ CAO CỐ ĐỊNH 14 — phải khớp ô đầu của cột phòng ghim, không thì
  /// tên phòng lệch khỏi hàng của chính nó vài pixel.
  Widget _hangGio() => SizedBox(
    height: _caoDauLuoi,
    child: Row(
    children: [
      for (var h = 0; h < 24; h++)
        SizedBox(
          width: _rongGio,
          child: Text(
            '${_hai(h)}:00',
            style: HD.body(size: 9.5, color: HD.inkMuted),
          ),
        ),
    ],
    ),
  );

  Widget _hangPhong(HangPhongLich p) => Container(
    height: _caoHang,
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: HD.hairline, width: 0.5)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: _rongGio * 24,
          child: Stack(
            children: [
              Row(
                children: [
                  for (var h = 0; h < 24; h++)
                    Container(
                      width: _rongGio,
                      height: _caoHang,
                      decoration: BoxDecoration(
                        color: h.isEven ? HD.paper.withValues(alpha: 0.5) : null,
                        border: const Border(
                          left: BorderSide(color: HD.hairline, width: 0.4),
                        ),
                      ),
                    ),
                ],
              ),
              for (final m in p.muc) _khoi(m),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _khoi(KhoiLich m) {
    final trai = _viTri(m.tu);
    final rong = (_viTri(m.den) - trai).clamp(18.0, _rongGio * 24);
    final (mau, nen) = m.laChan
        ? (HD.svcBlue, HD.svcBlue.withValues(alpha: 0.12))
        : switch (m.trangThai) {
            'checked_in' => (HD.positive, HD.positiveTint),
            'approved' => (HD.accent, HD.accentTint),
            _ => (HD.svcAmber, HD.warningTint),
          };
    return Positioned(
      left: trai,
      top: 3,
      width: rong,
      height: _caoHang - 6,
      child: Tooltip(
        message: m.laChan
            ? (m.ghiChu ?? 'Khoá phòng')
            : '${m.ten ?? 'Ca thuê'} · ${m.nhanKieu}',
        child: GestureDetector(
          onTap: m.laChan ? null : () => _mo(
                ChiTietCaThueScreen(reservationId: m.id, api: widget.caThueApi),
              ),
          child: Container(
          key: ValueKey('khoi-${m.loai}-${m.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: nen,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(m.tranTruoc ? 0 : HD.r8),
              right: Radius.circular(m.tranSau ? 0 : HD.r8),
            ),
            border: Border.all(color: mau.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_gio(m.tu)}–${_gio(m.den)}',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: HD.bodyBold(size: 9, color: mau),
              ),
              Text(
                m.laChan ? (m.ghiChu ?? 'Dọn phòng') : (m.ten ?? m.nhanKieu),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 9, color: HD.inkSoft),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _viecTrongNgay(LichNgay l) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Việc phải làm trong ngày', style: HD.bodyBold(size: 13.5)),
        const SizedBox(height: 4),
        if (l.viec.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HD.s8),
            child: Text(
              'Không có việc nào: không ai nhận phòng, trả phòng hay chờ dọn.',
              style: HD.body(size: 12, color: HD.inkMuted),
            ),
          )
        else
          for (final v in l.viec) ...[
            const Divider(height: HD.s16, color: HD.hairline),
            _MucViec(
              viec: v,
              bayGio: l.bayGio ?? DateTime.now(),
              onLam: _dangLam ? null : () => _xuLy(v),
            ),
          ],
      ],
    ),
  );
}

// ── Định dạng ────────────────────────────────────────────────────────────────

String _hai(int n) => n.toString().padLeft(2, '0');

String _gio(DateTime d) => '${_hai(d.hour)}:${_hai(d.minute)}';

String _isoNgay(DateTime d) => '${d.year}-${_hai(d.month)}-${_hai(d.day)}';

String _thu(DateTime d) =>
    const ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'][d.weekday - 1];

/// 135 phút → 'trong 2h15'. Âm → 'quá 15 phút'.
String _conBao(Duration d) {
  final phut = d.inMinutes;
  final p = phut.abs();
  final chu = p < 60 ? '$p phút' : (p % 60 == 0 ? '${p ~/ 60}h' : '${p ~/ 60}h${p % 60}');
  return phut < 0 ? 'quá $chu' : 'trong $chu';
}

class _MucViec extends StatelessWidget {
  const _MucViec({required this.viec, required this.bayGio, this.onLam});

  final ViecTrongNgay viec;
  final DateTime bayGio;
  final VoidCallback? onLam;

  @override
  Widget build(BuildContext context) {
    final (icon, mau, tieuDe, nut) = switch (viec.loai) {
      'cho_duyet' => (
        Icons.mark_email_unread_outlined,
        HD.warning,
        'Đơn mới chờ duyệt${viec.ten == null ? '' : ' · ${viec.ten}'}'
            '${viec.sale == null ? '' : ' · qua sale ${viec.sale}'}',
        'Xem đơn',
      ),
      'nhan_phong' => (
        Icons.login,
        HD.accent,
        'Nhận phòng${viec.ten == null ? '' : ' · ${viec.ten}'}',
        'Nhận phòng',
      ),
      'tra_phong' => (
        Icons.logout,
        viec.quaGio ? HD.negative : HD.positive,
        'Trả phòng${viec.ten == null ? '' : ' · ${viec.ten}'}',
        'Trả phòng',
      ),
      _ => (
        Icons.cleaning_services_outlined,
        HD.svcBlue,
        viec.ghiChu ?? 'Dọn phòng',
        'Dọn xong',
      ),
    };
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_gio(viec.luc), style: HD.bodyBold(size: 12.5, color: mau)),
              Text(
                _conBao(viec.luc.difference(bayGio)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(
                  size: 9,
                  color: viec.quaGio ? HD.negative : HD.inkMuted,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: mau.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: mau),
        ),
        const SizedBox(width: HD.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${viec.maPhong} · $tieuDe',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(size: 12),
              ),
              Text(
                viec.quaGio ? 'Đã quá giờ trả' : viec.nhanKieu,
                style: HD.body(
                  size: 10.5,
                  color: viec.quaGio ? HD.negative : HD.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          key: ValueKey('viec-${viec.loai}-${viec.reservationId ?? viec.blockId}'),
          onPressed: onLam,
          style: OutlinedButton.styleFrom(
            foregroundColor: mau,
            side: BorderSide(color: mau.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HD.r8)),
            textStyle: HD.bodyBold(size: 11.5),
          ),
          child: Text(nut),
        ),
      ],
    );
  }
}
