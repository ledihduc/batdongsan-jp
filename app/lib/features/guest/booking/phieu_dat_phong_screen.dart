import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/dat_phong_api.dart';
import 'package:house_booking/features/guest/booking/room_booking_screen.dart';
import 'package:house_booking/features/guest/booking/schedule_booking_screen.dart'
    show TheSaleDon, anhDayDu;
import 'package:house_booking/features/guest/da_dat/sua_thong_tin_sheet.dart';
import 'package:house_booking/features/guest/da_dat/tien_trinh_lich_su.dart';
import 'package:house_booking/features/guest/review/write_review_screen.dart';

/// PHIẾU ĐẶT PHÒNG NGẮN HẠN — cùng khuôn "Phiếu hẹn xem nhà" (16/09/2026).
///
/// Mở ngay sau khi đặt, mở lại được bằng id (từ thông báo, từ Đã đặt).
///
/// Nói THẬT trạng thái: đơn vừa gửi là "chờ sale xác nhận phòng" — chưa ai giữ
/// phòng cho tới khi sale/chủ phòng duyệt. Tiền thanh toán tại quầy; app không
/// thu, nên không vẽ nút "thanh toán".
///
/// Liên hệ đi qua SALE (gọi / Zalo bằng SĐT thật, sau khi đã đặt). Huỷ chỉ hiện
/// khi server nói còn huỷ miễn phí (`huy_duoc`); quá hạn thì chỉ đường gọi sale.
class PhieuDatPhongScreen extends StatefulWidget {
  const PhieuDatPhongScreen({
    super.key,
    this.phieuBanDau,
    this.reservationId,
    this.api = const DatPhongApi(),
    this.moLink,
    this.moSan,
  }) : assert(phieuBanDau != null || reservationId != null);

  /// Mở phiếu rồi làm ngay một việc: 'doi_gio' | 'sua' | 'huy' — từ menu ⋯ ở
  /// trang Đã đặt, đỡ một lần bấm.
  final String? moSan;

  final PhieuDatPhong? phieuBanDau;
  final int? reservationId;
  final DatPhongApi api;

  /// Chỉ để test bắt link sẽ mở (tel, zalo, maps, calendar) mà không mở thật.
  final Future<void> Function(Uri uri)? moLink;

  @override
  State<PhieuDatPhongScreen> createState() => _PhieuDatPhongScreenState();
}

const Map<String, String> _tenHinhThuc = {
  'theo_gio': 'Theo giờ',
  'qua_dem': 'Qua đêm',
  'theo_ngay': 'Theo ngày',
};

class _PhieuDatPhongScreenState extends State<PhieuDatPhongScreen> {
  PhieuDatPhong? _p;
  String? _loi;
  bool _dangHuy = false;

  /// Tăng mỗi lần phiếu đổi để thẻ lịch sử tải lại.
  int _phien = 0;

  @override
  void initState() {
    super.initState();
    _p = widget.phieuBanDau;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_p == null) await _nap();
      final p = _p;
      if (p == null || !mounted) return;
      switch (widget.moSan) {
        case 'doi_gio' when p.huyDuoc:
          await _doiGio(p);
        case 'sua' when _suaDuoc(p):
          await _suaThongTin(p);
        case 'huy' when p.huyDuoc:
          await _huy(p);
      }
    });
  }

  bool _suaDuoc(PhieuDatPhong p) =>
      p.trangThai == 'pending' || p.trangThai == 'approved';

  Future<void> _doiGio(PhieuDatPhong p) async {
    final moi = await Navigator.of(context).push<PhieuDatPhong>(
      MaterialPageRoute(
        builder: (_) => RoomBookingScreen(
          api: widget.api,
          doiGioCho: p,
          args: RoomBookingArgs(
            roomId: p.phong.roomId,
            roomCode: p.phong.ma,
            buildingName: p.phong.toa,
            price: 0,
            saleName: '',
            houseId: p.phong.houseId,
          ),
        ),
      ),
    );
    if (moi == null || !mounted) return;
    setState(() {
      _p = moi;
      _phien++;
    });
    _bao('Đã đổi giờ · chờ sale xác nhận lại');
  }

  Future<void> _suaThongTin(PhieuDatPhong p) async {
    final doi = await moSuaThongTin(
      context,
      ten: p.tenKhach,
      sdt: p.sdtKhach,
      so: p.soKhach ?? 1,
      soToiDa: p.phong.sucChua ?? 10,
      nhanSo: 'Số khách ở',
      ghiChu: p.ghiChu,
      nhanGhiChu: 'Ghi chú cho nơi lưu trú',
    );
    if (doi == null || doi.trong || !mounted) return;
    try {
      final moi = await widget.api.suaThongTin(
        p.id,
        ten: doi.ten,
        sdt: doi.sdt,
        soKhach: doi.so,
        ghiChu: doi.ghiChu,
      );
      if (!mounted) return;
      setState(() {
        _p = moi;
        _phien++;
      });
      _bao('Đã lưu · sale và chủ nhà đã được báo');
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không lưu được, thử lại nhé');
    }
  }

  Future<void> _nap() async {
    try {
      final p = await widget.api.phieu(widget.reservationId ?? _p!.id);
      if (mounted) {
        setState(() {
          _p = p;
          _phien++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _loi = e is ApiException
              ? e.message
              : 'Không tải được phiếu đặt phòng',
        );
      }
    }
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _mo(Uri uri) async {
    if (widget.moLink != null) return widget.moLink!(uri);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _bao('Không mở được liên kết');
  }

  Uri _lichGoogle(PhieuDatPhong p) {
    final a = p.nhan ?? DateTime.now();
    final b = p.tra ?? a.add(const Duration(hours: 2));
    String f(DateTime d) =>
        '${d.year}${_hai(d.month)}${_hai(d.day)}T${_hai(d.hour)}${_hai(d.minute)}00';
    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'Nhận phòng ${p.phong.hang} · ${p.phong.ma}',
      'dates': '${f(a)}/${f(b)}',
      'ctz': 'Asia/Ho_Chi_Minh',
      'location': p.diemDen.diaChi,
      'details': [
        'Mã đặt phòng: #${p.ma}',
        'Tổng tiền: ${PriceFormat.full(p.tong)} · thanh toán tại quầy',
        if (p.sale != null) 'Sale phụ trách: ${p.sale!.ten} · ${p.sale!.sdt}',
      ].join('\n'),
    });
  }

  Uri _chiDuong(PhieuDatPhong p) => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': p.diemDen.coToaDo
        ? '${p.diemDen.lat},${p.diemDen.lng}'
        : p.diemDen.diaChi,
  });

  Future<void> _chiaSe(PhieuDatPhong p) async {
    await Share.share(
      [
        'Đặt phòng ${p.phong.hang} · ${p.phong.ma}',
        if (p.phong.toa.isNotEmpty) p.phong.toa,
        if (p.nhan != null) 'Nhận: ${_moc(p.nhan!)}',
        if (p.tra != null) 'Trả: ${_moc(p.tra!)}',
        if (p.diemDen.diaChi.isNotEmpty) 'Tại ${p.diemDen.diaChi}',
        'Mã: #${p.ma}',
      ].join('\n'),
    );
  }

  static const _lyDoHuy = [
    'Đổi kế hoạch, không đi nữa',
    'Đặt nhầm giờ',
    'Đã tìm được chỗ khác',
  ];

  Future<void> _huy(PhieuDatPhong p) async {
    var lyDo = '';
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, capNhat) => AlertDialog(
          title: const Text('Huỷ đặt phòng này?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phòng được nhả cho khách khác, '
                '${p.sale == null ? 'bên cho thuê' : 'sale ${p.sale!.ten}'} được '
                'báo ngay. Huỷ trong hạn nên không mất phí.',
                style: HD.body(size: 14, color: HD.inkMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in _lyDoHuy)
                    ChoiceChip(
                      label: Text(s),
                      selected: lyDo == s,
                      onSelected: (_) =>
                          capNhat(() => lyDo = lyDo == s ? '' : s),
                      showCheckmark: false,
                      selectedColor: HD.accentTint,
                      labelStyle: HD.body(size: 12),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            // Pop bằng context CỦA HỘP THOẠI (bẫy Navigator lồng theo tab).
            TextButton(
              key: const Key('phieu-dp-giu'),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Giữ phòng'),
            ),
            FilledButton(
              key: const Key('phieu-dp-huy-xac-nhan'),
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: HD.accent),
              child: const Text('Huỷ đặt phòng'),
            ),
          ],
        ),
      ),
    );
    if (dongY != true || !mounted) return;
    setState(() => _dangHuy = true);
    try {
      await widget.api.huy(p.id, lyDo: lyDo);
      final moi = await widget.api.phieu(p.id);
      if (!mounted) return;
      setState(() {
        _p = moi;
        _phien++;
      });
      _bao('Đã huỷ đặt phòng');
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không huỷ được, thử lại nhé');
    } finally {
      if (mounted) setState(() => _dangHuy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: Text('Phiếu đặt phòng', style: HD.bodyBold(size: 16)),
      ),
      body: p == null
          ? Center(
              child: _loi == null
                  ? const CircularProgressIndicator(color: HD.accent)
                  : Text(_loi!, style: HD.body(color: HD.inkMuted)),
            )
          : RefreshIndicator(
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _huyHieu(p),
                  if (!p.daDong) ...[
                    const SizedBox(height: 16),
                    TheTienTrinh(
                      cacBuoc: const [
                        'Đã đặt',
                        'Xác nhận',
                        'Nhận phòng',
                        'Trả phòng',
                      ],
                      buoc: switch (p.trangThai) {
                        'approved' => 2,
                        'checked_in' => 3,
                        'checked_out' => 4,
                        _ => 1,
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ve(p),
                  if (p.huyDuoc || _suaDuoc(p)) ...[
                    const SizedBox(height: 16),
                    TheSuaDoi(
                      khoaDoiGio: const Key('phieu-dp-doi-gio'),
                      khoaSua: const Key('phieu-dp-sua'),
                      khoaHuy: const Key('phieu-dp-huy'),
                      onDoiGio: p.huyDuoc ? () => _doiGio(p) : null,
                      onSuaThongTin: _suaDuoc(p) ? () => _suaThongTin(p) : null,
                      onHuy: p.huyDuoc && !_dangHuy ? () => _huy(p) : null,
                      ghiChu: p.huyMienPhiDen == null
                          ? null
                          : 'Đổi giờ, huỷ miễn phí đến ${_moc(p.huyMienPhiDen!)}. '
                                'Đổi giờ xong đơn chờ sale xác nhận lại.',
                    ),
                  ],
                  if (p.sale != null && !p.daDong) ...[
                    const SizedBox(height: 16),
                    TheSaleDon(
                      sale: p.sale!,
                      tieuDe: 'SALE PHỤ TRÁCH PHÒNG',
                      thanhTich: 'Gọi hoặc nhắn khi cần đổi giờ, hỏi đường',
                      nutLienHe: _lienHe(p),
                    ),
                  ],
                  if (!p.daDong) ...[
                    const SizedBox(height: 16),
                    _diemDen(p),
                    const SizedBox(height: 16),
                    _chinhSach(p),
                  ],
                  const SizedBox(height: 16),
                  TheLichSu(
                    tai: () => widget.api.lichSu(p.id),
                    phienBan: _phien,
                  ),
                  const SizedBox(height: 16),
                  _nutCuoi(p),
                ],
              ),
            ),
    );
  }

  // ── Huy hiệu ──────────────────────────────────────────────────────────────

  Widget _huyHieu(PhieuDatPhong p) {
    final (nen, mau, icon, chip, tieuDe, phu) = switch (p.trangThai) {
      'approved' => (
        HD.positiveTint,
        HD.positive,
        Icons.verified,
        'Đã xác nhận · phòng đang được giữ',
        'Phòng đã sẵn sàng!',
        'Đến đúng giờ nhận phòng, đưa mã hoặc QR cho lễ tân.',
      ),
      'checked_in' => (
        HD.positiveTint,
        HD.positive,
        Icons.hotel,
        'Đang ở',
        'Chúc bạn nghỉ ngơi thoải mái',
        'Cần gì thêm cứ gọi sale phụ trách.',
      ),
      'checked_out' => (
        const Color(0xFFF0F1F4),
        HD.inkMuted,
        Icons.task_alt,
        'Đã trả phòng',
        'Cảm ơn bạn đã ở cùng Vua Nhà',
        'Hẹn gặp lại bạn lần sau.',
      ),
      'rejected' => (
        const Color(0xFFF0F1F4),
        HD.inkMuted,
        Icons.event_busy,
        'Phòng không nhận được đơn này',
        'Đơn không được xác nhận',
        p.lyDoTuChoi.isEmpty
            ? 'Phòng không trống giờ này. Bạn thử giờ hoặc phòng khác nhé.'
            : 'Lý do: ${p.lyDoTuChoi}',
      ),
      'cancelled' => (
        const Color(0xFFF0F1F4),
        HD.inkMuted,
        Icons.event_busy,
        'Đã huỷ đặt phòng',
        'Bạn đã huỷ đặt phòng',
        'Phòng đã được nhả. Muốn ở thì đặt lại bất cứ lúc nào.',
      ),
      'no_show' => (
        const Color(0xFFF0F1F4),
        HD.inkMuted,
        Icons.event_busy,
        'Không đến nhận phòng',
        'Đơn đã đóng',
        'Đơn đóng vì không nhận phòng đúng giờ.',
      ),
      _ => (
        HD.warningTint,
        HD.svcAmber,
        Icons.check_circle,
        'Đã gửi · chờ sale xác nhận phòng',
        'Đặt phòng thành công!',
        p.sale == null
            ? 'Bên cho thuê sẽ xác nhận và giữ phòng cho bạn.'
            : 'Sale ${p.sale!.ten} sẽ xác nhận và giữ phòng cho bạn trong ít phút.',
      ),
    };
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: p.daDong || p.trangThai == 'checked_out'
                ? const Color(0xFFF0F1F4)
                : const Color(0xFF6FFBBE),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 36,
            color: p.daDong || p.trangThai == 'checked_out'
                ? HD.inkMuted
                : const Color(0xFF002113),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: nen,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            chip,
            key: const Key('phieu-dp-trang-thai'),
            style: HD.bodyBold(size: 12, color: mau),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tieuDe,
          textAlign: TextAlign.center,
          style: HD.bodyBold(size: 22, color: HD.ink),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 300,
          child: Text(
            phu,
            textAlign: TextAlign.center,
            style: HD.body(size: 14, color: HD.inkMuted),
          ),
        ),
      ],
    );
  }

  // ── Vé ────────────────────────────────────────────────────────────────────

  Widget _ve(PhieuDatPhong p) {
    final ph = p.phong;
    final dong = p.daDong;
    final soLuong = p.soLuong > 0 ? '${p.soLuong} ${p.donVi}' : '';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD2D9F4).withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: ph.anh == null
                              ? Container(
                                  color: const Color(0xFFEAEDFF),
                                  child: const Icon(
                                    Icons.bed_outlined,
                                    color: HD.inkMuted,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: anhDayDu(ph.anh!),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      Container(color: const Color(0xFFEAEDFF)),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ph.hang} · ${ph.ma}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HD.bodyBold(size: 15, color: HD.ink),
                            ),
                            if (ph.toa.isNotEmpty)
                              Text(
                                ph.toa,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HD.body(size: 12, color: HD.inkSoft),
                              ),
                            Text(
                              [
                                if (ph.dienTich != null)
                                  '${ph.dienTich!.toStringAsFixed(0)} m²',
                                if (p.soKhach != null) '${p.soKhach} khách',
                              ].join(' · '),
                              style: HD.body(size: 12, color: HD.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _oVe(
                        'NHẬN PHÒNG',
                        p.nhan == null ? '—' : _gio(p.nhan!),
                        p.nhan == null ? '' : _ngayDai(p.nhan!),
                        khoa: const Key('phieu-dp-nhan'),
                        gach: dong,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _oVe(
                        'TRẢ PHÒNG',
                        p.tra == null ? '—' : _gio(p.tra!),
                        p.tra == null ? '' : _ngayDai(p.tra!),
                        khoa: const Key('phieu-dp-tra'),
                        gach: dong,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TỔNG TIỀN',
                              style: HD.bodyBold(size: 10, color: HD.inkMuted),
                            ),
                            Text(
                              PriceFormat.full(p.tong),
                              key: const Key('phieu-dp-tong'),
                              style: HD.bodyBold(size: 18, color: HD.accent),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            [
                              _tenHinhThuc[p.hinhThuc] ?? '',
                              soLuong,
                            ].where((x) => x.isNotEmpty).join(' · '),
                            style: HD.bodyBold(size: 13, color: HD.ink),
                          ),
                          Text(
                            'Thanh toán tại quầy',
                            style: HD.body(size: 11.5, color: HD.inkMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!dong) ...[
            _rangCua(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MÃ ĐẶT PHÒNG',
                              style: HD.bodyBold(size: 10, color: HD.inkMuted),
                            ),
                            Text(
                              '#${p.ma}',
                              key: const Key('phieu-dp-ma'),
                              style: HD
                                  .bodyBold(size: 17, color: HD.accent)
                                  .copyWith(letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAEDFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.qr_code_scanner,
                              size: 14,
                              color: HD.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Đưa lễ tân',
                              style: HD.bodyBold(size: 11, color: HD.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          key: const Key('phieu-dp-qr'),
                          data: 'ancu365:dat-phong:${p.ma}',
                          size: 144,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF131B2E),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF131B2E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lễ tân quét mã này để nhận phòng cho bạn',
                          textAlign: TextAlign.center,
                          style: HD.body(size: 12, color: HD.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rangCua() => Row(
    children: [
      Container(
        width: 12,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFFFAF8FF),
          borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (_, c) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < (c.maxWidth / 10).floor(); i++)
                Container(width: 5, height: 2, color: const Color(0xFFE2E7FF)),
            ],
          ),
        ),
      ),
      Container(
        width: 12,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFFFAF8FF),
          borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
        ),
      ),
    ],
  );

  Widget _oVe(
    String nhan,
    String chinh,
    String phu, {
    Key? khoa,
    bool gach = false,
  }) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F3FF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: HD.bodyBold(size: 10, color: HD.inkMuted)),
        const SizedBox(height: 4),
        Text(
          chinh,
          key: khoa,
          style: HD
              .bodyBold(size: 18, color: HD.ink)
              .copyWith(decoration: gach ? TextDecoration.lineThrough : null),
        ),
        Text(phu, style: HD.bodyBold(size: 12, color: HD.accent)),
      ],
    ),
  );

  // ── Liên hệ sale ──────────────────────────────────────────────────────────

  Widget _lienHe(PhieuDatPhong p) {
    final so = p.sale!.sdt.replaceAll(RegExp(r'\D'), '');
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: FilledButton.icon(
              key: const Key('phieu-dp-goi'),
              onPressed: so.isEmpty
                  ? null
                  : () => _mo(Uri(scheme: 'tel', path: so)),
              icon: const Icon(Icons.phone_in_talk, size: 18),
              label: const Text('Gọi sale'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6FFBBE).withValues(alpha: 0.5),
                foregroundColor: const Color(0xFF002113),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: HD.bodyBold(size: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 44,
            child: FilledButton.icon(
              key: const Key('phieu-dp-zalo'),
              onPressed: so.isEmpty
                  ? null
                  : () => _mo(Uri.https('zalo.me', '/$so')),
              icon: const Icon(Icons.chat, size: 18, color: HD.accent),
              label: const Text('Nhắn Zalo'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEAEDFF),
                foregroundColor: HD.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: HD.bodyBold(size: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Địa chỉ ───────────────────────────────────────────────────────────────

  Widget _diemDen(PhieuDatPhong p) => _The(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: HD.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.near_me, size: 18, color: HD.accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Địa chỉ nhận phòng',
                    style: HD.bodyBold(size: 15, color: HD.ink),
                  ),
                  Text(
                    p.diemDen.diaChi.isEmpty ? '—' : p.diemDen.diaChi,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (p.diemDen.diaChi.isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            key: const Key('phieu-dp-chi-duong'),
            onTap: () => _mo(_chiDuong(p)),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions, size: 20, color: HD.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mở Google Maps chỉ đường',
                      style: HD.bodyBold(size: 12.5, color: HD.ink),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: HD.inkMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  // ── Chính sách ────────────────────────────────────────────────────────────

  Widget _chinhSach(PhieuDatPhong p) {
    final han = p.huyMienPhiDen;
    final conHan = p.huyDuoc;
    return _The(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 20, color: HD.accent),
              const SizedBox(width: 8),
              Text('Lưu ý khi nhận phòng', style: HD.bodyBold(size: 15)),
            ],
          ),
          const SizedBox(height: 8),
          if (han != null &&
              (p.trangThai == 'pending' || p.trangThai == 'approved'))
            _dong(
              conHan
                  ? Icons.event_available_outlined
                  : Icons.event_busy_outlined,
              conHan
                  ? 'Huỷ miễn phí đến ${_moc(han)}'
                  : 'Đã quá hạn huỷ miễn phí (${_moc(han)}) — cần đổi/huỷ thì '
                        'gọi sale.',
              mau: conHan ? HD.positive : HD.svcAmber,
            ),
          for (final s in p.chinhSach) _dong(Icons.check_circle_outline, s),
          if (p.ghiChu.isNotEmpty)
            _dong(Icons.sticky_note_2_outlined, 'Yêu cầu của bạn: ${p.ghiChu}'),
        ],
      ),
    );
  }

  Widget _dong(IconData icon, String s, {Color mau = HD.positive}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: mau),
        const SizedBox(width: 8),
        Expanded(
          child: Text(s, style: HD.body(size: 12.5, color: HD.inkSoft)),
        ),
      ],
    ),
  );

  // ── Nút cuối ──────────────────────────────────────────────────────────────

  Widget _nutCuoi(PhieuDatPhong p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Ở xong là lúc đánh giá — server chấp nhận đơn đặt qua chính tin này
      // làm bằng chứng đã ở (kể cả tin neo hạng phòng).
      if (p.trangThai == 'checked_out' && p.phong.houseId != null) ...[
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const Key('phieu-dp-danh-gia'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WriteReviewScreen(
                  houseId: p.phong.houseId!,
                  houseTitle: p.phong.toa.isNotEmpty ? p.phong.toa : p.phong.hang,
                ),
              ),
            ),
            icon: const Icon(Icons.star_rate_rounded, size: 20),
            label: Text(
              'Đánh giá kỳ lưu trú',
              style: HD.bodyBold(size: 15, color: Colors.white),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: HD.accentDeep,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      if (!p.daDong && p.trangThai != 'checked_out') ...[
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const Key('phieu-dp-luu-lich'),
            onPressed: () => _mo(_lichGoogle(p)),
            icon: const Icon(Icons.calendar_month, size: 20),
            label: Text(
              'Lưu giờ nhận phòng vào lịch',
              style: HD.bodyBold(size: 15, color: Colors.white),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: HD.accentDeep,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      Row(
        children: [
          if (!p.daDong) ...[
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const Key('phieu-dp-chia-se'),
                  onPressed: () => _chiaSe(p),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Chia sẻ'),
                  style: _nutPhu(),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const Key('phieu-dp-quay-lai'),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(p.daDong ? 'Quay lại xem phòng khác' : 'Quay lại'),
                style: _nutPhu(),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  ButtonStyle _nutPhu() => FilledButton.styleFrom(
    backgroundColor: const Color(0xFFEAEDFF),
    foregroundColor: HD.ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: HD.bodyBold(size: 13),
  );
}

String _hai(int n) => n.toString().padLeft(2, '0');

String _gio(DateTime d) => '${_hai(d.hour)}:${_hai(d.minute)}';

String _thuDai(int w) => const [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
][(w - 1).clamp(0, 6)];

String _ngayDai(DateTime d) =>
    '${_thuDai(d.weekday)}, ${_hai(d.day)}/${_hai(d.month)}';

/// '13:00 · T5 18/09'
String _moc(DateTime d) =>
    '${_gio(d)} · ${const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][(d.weekday - 1).clamp(0, 6)]} '
    '${_hai(d.day)}/${_hai(d.month)}';

class _The extends StatelessWidget {
  const _The({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}
