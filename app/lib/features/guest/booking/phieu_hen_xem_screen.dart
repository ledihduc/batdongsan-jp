// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:house_booking/features/guest/booking/doi_gio_sheet.dart';
import 'package:house_booking/features/guest/da_dat/sua_thong_tin_sheet.dart';
import 'package:house_booking/features/guest/da_dat/tien_trinh_lich_su.dart';
import 'package:house_booking/features/guest/booking/schedule_booking_screen.dart'
    show TheSaleDon;
import 'package:house_booking/features/guest/booking/ket_qua_sau_xem_screen.dart';
import 'package:house_booking/features/guest/booking/thue_ngay_action.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// PHIẾU HẸN XEM NHÀ — dựng theo mockup "Booking Confirmation" (15/09/2026).
///
/// Mở ngay sau khi đặt lịch, và mở lại được bằng id (từ thông báo, từ Đã đặt).
///
/// Nói THẬT trạng thái: lịch vừa gửi là "chờ sale xác nhận", không phải "xác
/// nhận tức thì" như bản vẽ — hệ thống chưa tự xác nhận, ghi sai là khách đến
/// sảnh mà không có ai đón.
///
/// Mọi nút đều làm được việc thật: gọi / Zalo bằng SĐT sale thật, chỉ đường
/// bằng Google Maps, lưu lịch bằng Google Calendar, chia sẻ bằng bảng chia sẻ
/// của máy. Không vẽ "cách bạn 3,2km" hay "vé gửi xe 3.000đ" khi không có số.
class PhieuHenXemScreen extends StatefulWidget {
  const PhieuHenXemScreen({
    super.key,
    this.phieuBanDau,
    this.appointmentId,
    this.api = const LichXemApi(),
    this.viewingV2Api = const ViewingV2Api(),
    this.rentalJourneyApi = const RentalJourneyApi(),
    this.moLink,
    this.moSan,
    this.bayGio,
  }) : assert(phieuBanDau != null || appointmentId != null);

  /// Mở phiếu rồi làm ngay: 'doi_gio' | 'sua' | 'huy' (từ menu ⋯ trang Đã đặt).
  final String? moSan;

  final PhieuHen? phieuBanDau;
  final int? appointmentId;
  final LichXemApi api;
  final ViewingV2Api viewingV2Api;
  final RentalJourneyApi rentalJourneyApi;

  /// Ghim thời gian trong kiểm thử; bản thật tự chuyển nút đúng giờ hẹn.
  final DateTime? bayGio;

  /// Chỉ để test bắt link sẽ mở (tel, zalo, maps, calendar) mà không mở thật.
  final Future<void> Function(Uri uri)? moLink;

  @override
  State<PhieuHenXemScreen> createState() => _PhieuHenXemScreenState();
}

class _PhieuHenXemScreenState extends State<PhieuHenXemScreen> {
  PhieuHen? _p;
  String? _loi;
  bool _dangChon = false;
  Timer? _henGio;

  /// Tăng mỗi lần phiếu đổi để thẻ lịch sử tải lại.
  int _phien = 0;

  @override
  void initState() {
    super.initState();
    _p = widget.phieuBanDau;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_p != null) _lapHenGio(_p!);
      if (_p == null) await _nap();
      final p = _p;
      if (p == null || !mounted) return;
      switch (widget.moSan) {
        case 'doi_gio' when _doiLichDuoc(p):
          await _khachDoiLich(p);
        case 'sua' when _suaDuoc(p):
          await _suaThongTin(p);
        case 'huy' when p.huyDuoc:
          await _huy(p);
      }
    });
  }

  @override
  void dispose() {
    _henGio?.cancel();
    super.dispose();
  }

  DateTime get _bayGio => widget.bayGio ?? DateTime.now();

  bool _daDenGio(PhieuHen p) => p.luc != null && !_bayGio.isBefore(p.luc!);

  void _lapHenGio(PhieuHen p) {
    _henGio?.cancel();
    if (widget.bayGio != null || p.luc == null || _daDenGio(p)) return;
    _henGio = Timer(
      p.luc!.difference(DateTime.now()) + const Duration(milliseconds: 100),
      () {
        if (mounted) setState(() {});
      },
    );
  }

  bool _doiLichDuoc(PhieuHen p) =>
      p.trangThai == 'pending' || p.trangThai == 'approved';
  bool _suaDuoc(PhieuHen p) => _doiLichDuoc(p) || p.choKhachChonGio;

  void _capNhat(PhieuHen moi) {
    setState(() {
      _p = moi;
      _phien++;
    });
    _lapHenGio(moi);
  }

  Future<void> _thueNgay(PhieuHen p) async {
    if (_dangChon) return;
    setState(() => _dangChon = true);
    try {
      await moThueNgay(
        context,
        phieu: p,
        viewingApi: widget.viewingV2Api,
        rentalApi: widget.rentalJourneyApi,
      );
    } catch (e) {
      if (mounted) _bao('Chưa mở được hồ sơ thuê. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _dangChon = false);
    }
  }

  Future<void> _khachDoiLich(PhieuHen p) async {
    final moi = await moChonGioKhac(
      context,
      appointmentId: p.id,
      api: widget.api,
      khachTuDoi: true,
      ngayHienTai: p.ngay,
      gioHienTai: p.gio,
    );
    if (moi == null || !mounted) return;
    _capNhat(moi);
    _bao('Đã đổi lịch · chờ bên bán duyệt lại');
  }

  Future<void> _suaThongTin(PhieuHen p) async {
    final doi = await moSuaThongTin(
      context,
      ten: p.tenKhach,
      sdt: p.sdtKhach,
      so: p.soNguoi,
      soToiDa: 10,
      nhanSo: 'Số người đi xem',
      ghiChu: p.loiNhan,
      nhanGhiChu: 'Lời nhắn cho sale',
      hinhThuc: p.hinhThuc,
    );
    if (doi == null || doi.trong || !mounted) return;
    try {
      final moi = await widget.api.suaThongTin(
        p.id,
        ten: doi.ten,
        sdt: doi.sdt,
        soNguoi: doi.so,
        hinhThuc: doi.hinhThuc,
        loiNhan: doi.ghiChu,
      );
      if (!mounted) return;
      _capNhat(moi);
      _bao('Đã lưu · sale và chủ nhà đã được báo');
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không lưu được, thử lại nhé');
    }
  }

  Future<void> _nap() async {
    try {
      final p = await widget.api.phieu(widget.appointmentId ?? _p!.id);
      if (mounted) _capNhat(p);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _loi = e is ApiException ? e.message : 'Không tải được phiếu hẹn',
        );
      }
    }
  }

  /// Khách bấm một giờ bên bán đề xuất → xác nhận ngay (server tự duyệt).
  Future<void> _chonDeXuat(PhieuHen p, GioDeXuat g) async {
    if (_dangChon) return;
    setState(() => _dangChon = true);
    try {
      final moi = await widget.api.chonGio(p.id, g);
      if (!mounted) return;
      _capNhat(moi);
      _bao(
        moi.daXacNhan
            ? 'Đã chốt ${ngayGioNgan(g.ngay, g.gio)} · bên bán đã xác nhận'
            : 'Đã gửi giờ mới · chờ bên bán duyệt',
      );
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không chọn được giờ này');
      await _nap();
    } finally {
      if (mounted) setState(() => _dangChon = false);
    }
  }

  Future<void> _chonGioKhac(PhieuHen p) async {
    final moi = await moChonGioKhac(
      context,
      appointmentId: p.id,
      api: widget.api,
    );
    if (moi == null || !mounted) return;
    _capNhat(moi);
    _bao(
      moi.daXacNhan
          ? 'Đã chốt giờ mới · bên bán đã xác nhận'
          : 'Đã gửi giờ mới · chờ bên bán duyệt',
    );
  }

  static const _lyDoHuy = [
    'Bận việc, không đi được',
    'Đã tìm được chỗ khác',
    'Đổi ý, không xem nữa',
  ];

  /// Hỏi lại trước khi huỷ — một chạm nhầm là mất giờ đã giữ.
  Future<void> _huy(PhieuHen p) async {
    var lyDo = '';
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, capNhat) => AlertDialog(
          title: const Text('Huỷ lịch hẹn này?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${p.sale == null ? 'Bên bán' : 'Chuyên viên ${p.sale!.ten}'} '
                'sẽ được báo ngay, giờ đã giữ được nhả cho người khác.',
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
            // Pop bằng context CỦA HỘP THOẠI: màn này nằm trong Navigator lồng
            // theo tab, pop bằng context màn là hộp thoại treo lại.
            TextButton(
              key: const Key('phieu-huy-giu-lai'),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Giữ lịch'),
            ),
            FilledButton(
              key: const Key('phieu-huy-xac-nhan'),
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: HD.accent),
              child: const Text('Huỷ lịch'),
            ),
          ],
        ),
      ),
    );
    if (dongY != true || !mounted) return;
    setState(() => _dangChon = true);
    try {
      final moi = await widget.api.huy(p.id, lyDo: lyDo);
      if (!mounted) return;
      _capNhat(moi);
      _bao('Đã huỷ lịch hẹn');
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không huỷ được, thử lại nhé');
    } finally {
      if (mounted) setState(() => _dangChon = false);
    }
  }

  Widget _nutHuy(PhieuHen p, {String nhan = 'Huỷ lịch hẹn'}) => Center(
    child: TextButton.icon(
      key: const Key('phieu-huy'),
      onPressed: _dangChon ? null : () => _huy(p),
      icon: const Icon(Icons.event_busy_outlined, size: 18),
      label: Text(nhan),
      style: TextButton.styleFrom(
        foregroundColor: HD.accentDeep,
        textStyle: HD.bodyBold(size: 13),
      ),
    ),
  );

  /// Lịch đã huỷ / bị từ chối: không bày vé, QR, quy trình đón cho một buổi
  /// không còn diễn ra.
  Widget _daDong(PhieuHen p) {
    final (nhan, tieuDe, loi) = switch (p.trangThai) {
      'rejected' => (
        'Bên bán từ chối lịch',
        'Lịch hẹn không được nhận',
        'Bên bán không tiếp được giờ này. Bạn có thể đặt lại giờ khác.',
      ),
      'lost' => (
        'Phòng đã có người chốt',
        'Phòng không còn trống',
        'Rất tiếc, phòng đã được người khác thuê trước.',
      ),
      _ => (
        'Đã huỷ lịch hẹn',
        'Bạn đã huỷ lịch hẹn',
        'Bên bán đã được báo. Muốn xem lại thì đặt một lịch mới bất cứ lúc nào.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F1F4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy, size: 34, color: HD.inkMuted),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              nhan,
              key: const Key('phieu-trang-thai'),
              style: HD.bodyBold(size: 12, color: HD.inkMuted),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tieuDe,
          textAlign: TextAlign.center,
          style: HD.bodyBold(size: 22, color: HD.ink),
        ),
        const SizedBox(height: 4),
        Text(
          loi,
          textAlign: TextAlign.center,
          style: HD.body(size: 14, color: HD.inkMuted),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EAF2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.tin.tieuDe, style: HD.bodyBold(size: 15)),
              if (p.luc != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Lịch cũ: ${_gio(p.luc!)} · ${_thuDai(p.luc!.weekday)}, '
                  '${_hai(p.luc!.day)}/${_hai(p.luc!.month)} · #${p.ma}',
                  style: HD
                      .body(size: 13, color: HD.inkMuted)
                      .copyWith(decoration: TextDecoration.lineThrough),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            key: const Key('phieu-xem-phong-khac'),
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Quay lại'),
            style: FilledButton.styleFrom(
              backgroundColor: HD.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: HD.bodyBold(size: 15),
            ),
          ),
        ),
      ],
    );
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

  Uri _lichGoogle(PhieuHen p) {
    final bd = p.luc ?? DateTime.now();
    final kt = bd.add(const Duration(hours: 1));
    String f(DateTime d) =>
        '${d.year}${_hai(d.month)}${_hai(d.day)}T${_hai(d.hour)}${_hai(d.minute)}00';
    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'Xem nhà: ${p.tin.tieuDe}',
      'dates': '${f(bd)}/${f(kt)}',
      'ctz': 'Asia/Ho_Chi_Minh',
      'location': p.diemDon.diaChi,
      'details': [
        'Mã phiếu hẹn: #${p.ma}',
        p.laVideo ? 'Hình thức: video call' : 'Hình thức: xem trực tiếp',
        if (p.sale != null) 'Chuyên viên: ${p.sale!.ten} · ${p.sale!.sdt}',
      ].join('\n'),
    });
  }

  Uri _chiDuong(PhieuHen p) => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': p.diemDon.coToaDo
        ? '${p.diemDon.lat},${p.diemDon.lng}'
        : p.diemDon.diaChi,
  });

  Future<void> _chiaSe(PhieuHen p) async {
    final luc = p.luc;
    final noiDung = [
      'Lịch hẹn xem ${p.tin.tieuDe}',
      if (luc != null)
        'Lúc ${_gio(luc)} ${_thuDai(luc.weekday)} ${luc.day}/${luc.month}',
      if (p.diemDon.diaChi.isNotEmpty) 'Tại ${p.diemDon.diaChi}',
      'Mã phiếu: #${p.ma}',
    ].join('\n');
    await Share.share(noiDung);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        backgroundColor: HD.accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.white,
          ),
        ),
        title: Text(
          'Chi tiết lịch xem',
          style: HD.bodyBold(size: 17, color: Colors.white),
        ),
      ),
      body: p == null
          ? Center(
              child: _loi == null
                  ? const CircularProgressIndicator(color: HD.accent)
                  : Text(_loi!, style: HD.body(color: HD.inkMuted)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (p.daDong)
                  _daDong(p)
                else if (p.choKhachChonGio) ...[
                  // Vé in giờ CŨ — giờ bên bán vừa báo bận. Bày QR, "lưu vào
                  // lịch", quy trình đón cho một giờ không còn hiệu lực là dẫn
                  // khách tới sảnh không có ai.
                  _theDoiGio(p),
                  if (p.sale != null) ...[
                    const SizedBox(height: 16),
                    TheSaleDon(
                      sale: p.sale!,
                      tieuDe: 'CHUYÊN VIÊN PHỤ TRÁCH',
                      nutLienHe: _lienHe(p),
                    ),
                  ],
                ] else
                  _chiTietLichMoi(p),
                if (p.choKhachChonGio && _suaDuoc(p)) ...[
                  const SizedBox(height: 16),
                  TheSuaDoi(
                    khoaSua: const Key('phieu-sua'),
                    onSuaThongTin: () => _suaThongTin(p),
                  ),
                ],
                const SizedBox(height: 16),
                TheLichSu(tai: () => widget.api.lichSu(p.id), phienBan: _phien),
              ],
            ),
    );
  }

  Widget _chiTietLichMoi(PhieuHen p) {
    final daXacNhan = p.trangThai == 'approved' || p.trangThai == 'completed';
    final coTheGuiKetQua = daXacNhan && _daDenGio(p);
    final sale = p.sale;
    final so = (sale?.sdt ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final lienHeDuoc = sale != null && !sale.sdtDaChe && so.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Giữ tên cũ như một nhãn ngữ cảnh để người dùng nhận ra đúng loại
        // chứng từ, trong khi tiêu đề chính theo thiết kế mới là Chi tiết lịch.
        Text('Phiếu hẹn xem nhà', style: HD.body(size: 11, color: HD.inkMuted)),
        const SizedBox(height: HD.s8),
        ViewingPropertyCard(phieu: p),
        const SizedBox(height: HD.s16),
        ViewingStatusBox(
          icon: daXacNhan ? Icons.check_circle : Icons.hourglass_top_rounded,
          title: daXacNhan ? 'Đã xác nhận lịch' : 'Chưa xác nhận lịch',
          message: daXacNhan
              ? 'Lịch hẹn đã được xác nhận. Hãy đến đúng giờ bạn nhé.'
              : 'Sale hoặc chủ nhà sẽ sớm phản hồi lịch hẹn của bạn.',
          color: daXacNhan ? HD.positive : HD.warning,
        ),
        const SizedBox(height: 6),
        Text(
          daXacNhan ? 'Sale đã xác nhận lịch' : 'Đã gửi · chờ sale xác nhận',
          key: const Key('phieu-trang-thai'),
          textAlign: TextAlign.center,
          style: HD.bodyBold(
            size: 11.5,
            color: daXacNhan ? HD.positive : HD.warning,
          ),
        ),
        if (p.doiGio != null && p.doiGio!.gioCu.contains(' ')) ...[
          const SizedBox(height: 3),
          Text(
            'Đã đổi từ ${ngayGioNgan(p.doiGio!.gioCu.split(' ')[0], p.doiGio!.gioCu.split(' ')[1])}',
            key: const Key('phieu-da-doi-tu'),
            textAlign: TextAlign.center,
            style: HD.body(size: 11.5, color: HD.warning),
          ),
        ],
        const SizedBox(height: HD.s16),
        ViewingInfoRow(
          icon: Icons.calendar_month_outlined,
          text: viewingPrettyDate(p.ngay),
        ),
        ViewingInfoRow(
          icon: p.laVideo ? Icons.videocam : Icons.confirmation_number_outlined,
          text: p.laVideo ? 'Video call' : '#${p.ma}',
        ),
        if (!p.laVideo)
          Center(
            child: Container(
              key: const Key('phieu-qr'),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: HD.paperSunken,
                borderRadius: BorderRadius.circular(HD.r8),
              ),
              child: const Icon(Icons.qr_code_2, size: 32, color: HD.ink),
            ),
          ),
        const SizedBox(height: HD.s8),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.access_time, size: 21, color: Color(0xFF173B75)),
              const SizedBox(width: HD.s12),
              Text(p.gio.split('-').first, style: HD.body(size: 13.5)),
              Text(
                p.gio.contains('-') ? ' - ${p.gio.split('-').last}' : '',
                style: HD.body(size: 13.5),
              ),
            ],
          ),
        ),
        ViewingInfoRow(
          icon: Icons.location_on,
          text: p.diemDon.diaChi.isEmpty ? p.tin.diaChi : p.diemDon.diaChi,
        ),
        const SizedBox(height: HD.s4),
        Text('Người phụ trách', style: HD.body(size: 12, color: HD.inkMuted)),
        const SizedBox(height: HD.s8),
        ViewingSectionCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: HD.paperSunken,
                child: const Icon(Icons.person, color: HD.inkMuted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale?.ten ?? 'Đang phân công',
                      style: HD.bodyBold(size: 13.5),
                    ),
                    Text(
                      sale == null
                          ? 'Sale / Chủ nhà phụ trách'
                          : 'Sale phụ trách lịch xem',
                      style: HD.body(size: 11.5, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('phieu-goi'),
                onPressed: lienHeDuoc
                    ? () => _mo(Uri(scheme: 'tel', path: so))
                    : null,
                icon: const Icon(Icons.call, color: HD.accent),
              ),
              IconButton(
                key: const Key('phieu-zalo'),
                onPressed: lienHeDuoc
                    ? () => _mo(Uri.https('zalo.me', '/$so'))
                    : null,
                icon: const Icon(Icons.chat_bubble, color: HD.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: HD.s8),
        Row(
          children: [
            if (!p.laVideo && p.diemDon.diaChi.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('phieu-chi-duong'),
                  style: viewingOutlineButton(color: const Color(0xFF173B75)),
                  onPressed: () => _mo(_chiDuong(p)),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Chỉ đường'),
                ),
              ),
            if (!p.laVideo && p.diemDon.diaChi.isNotEmpty)
              const SizedBox(width: HD.s8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('phieu-luu-lich'),
                style: viewingOutlineButton(color: const Color(0xFF173B75)),
                onPressed: () => _mo(_lichGoogle(p)),
                icon: const Icon(Icons.event_available, size: 18),
                label: const Text('Lưu lịch'),
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s16),
        if (coTheGuiKetQua) ...[
          FilledButton.icon(
            key: const Key('phieu-gui-ket-qua'),
            style: viewingPrimaryButton(),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => KetQuaSauXemScreen(
                  appointmentId: p.id,
                  phieu: p,
                  managementApi: const ManagementReadModelApi(),
                ),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Đã xem · Gửi kết quả'),
          ),
          const SizedBox(height: HD.s8),
          OutlinedButton.icon(
            style: viewingOutlineButton(color: const Color(0xFF173B75)),
            onPressed: () => _bao('Đã lưu · ứng dụng sẽ nhắc bạn phản hồi sau'),
            icon: const Icon(Icons.schedule),
            label: const Text('Chưa xem · Nhắc lại sau'),
          ),
        ] else ...[
          if (daXacNhan) ...[
            FilledButton.icon(
              key: const Key('phieu-thue-ngay'),
              style: viewingPrimaryButton(),
              onPressed: _dangChon ? null : () => _thueNgay(p),
              icon: const Icon(Icons.favorite),
              label: const Text('Muốn thuê ngay'),
            ),
            const SizedBox(height: HD.s8),
          ],
          FilledButton.icon(
            key: const Key('phieu-nhac-xac-nhan'),
            style: viewingPrimaryButton(),
            onPressed: _dangChon
                ? null
                : () {
                    if (lienHeDuoc) {
                      _mo(Uri.https('zalo.me', '/$so'));
                    } else {
                      _bao('Đã ghi nhận yêu cầu nhắc xác nhận lịch.');
                    }
                  },
            icon: Icon(
              daXacNhan ? Icons.notifications_active : Icons.notifications_none,
            ),
            label: Text(daXacNhan ? 'Nhắc lịch' : 'Nhắc xác nhận'),
          ),
          if (_suaDuoc(p)) ...[
            const SizedBox(height: HD.s8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('phieu-doi-lich'),
                    style: viewingOutlineButton(),
                    onPressed: _dangChon ? null : () => _khachDoiLich(p),
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Đổi giờ'),
                  ),
                ),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('phieu-huy'),
                    style: viewingOutlineButton(),
                    onPressed: _dangChon || !p.huyDuoc ? null : () => _huy(p),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Hủy yêu cầu'),
                  ),
                ),
              ],
            ),
            TextButton(
              key: const Key('phieu-sua'),
              onPressed: _dangChon ? null : () => _suaThongTin(p),
              child: const Text('Chỉnh thông tin người đi xem'),
            ),
          ],
        ],
      ],
    );
  }

  // ── Huy hiệu ──────────────────────────────────────────────────────────────

  Widget _huyHieu(PhieuHen p) {
    final xong = p.daXacNhan;
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF6FFBBE),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: HD.positive.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle,
                size: 38,
                color: Color(0xFF002113),
              ),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: HD.accentDeep,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: xong ? HD.positiveTint : HD.warningTint,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: xong ? HD.positive : HD.svcAmber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                xong ? 'Sale đã xác nhận lịch' : 'Đã gửi · chờ sale xác nhận',
                key: const Key('phieu-trang-thai'),
                style: HD.bodyBold(
                  size: 12,
                  color: xong ? HD.positive : HD.svcAmber,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Đặt lịch xem nhà thành công!',
          textAlign: TextAlign.center,
          style: HD.bodyBold(size: 22, color: HD.ink),
        ),
        if (p.doiGio != null && p.doiGio!.gioCu.contains(' ')) ...[
          const SizedBox(height: 4),
          Text(
            'Đã đổi từ ${ngayGioNgan(p.doiGio!.gioCu.split(' ')[0], p.doiGio!.gioCu.split(' ')[1])}',
            key: const Key('phieu-da-doi-tu'),
            style: HD.body(size: 12, color: HD.svcAmber),
          ),
        ],
        const SizedBox(height: 4),
        SizedBox(
          width: 290,
          child: Text(
            p.sale == null
                ? 'Chuyên viên sẽ liên hệ xác nhận lịch với bạn sớm nhất.'
                : 'Chuyên viên ${p.sale!.ten} sẽ gọi xác nhận và đón bạn chu đáo.',
            textAlign: TextAlign.center,
            style: HD.body(size: 14, color: HD.inkMuted),
          ),
        ),
      ],
    );
  }

  // ── Bên bán bận · chọn giờ mới ────────────────────────────────────────────

  Widget _theDoiGio(PhieuHen p) {
    final dg = p.doiGio ?? const DoiGio(dangChoChon: true);
    final cu = dg.gioCu.split(' ');
    final gioCu = cu.length == 2 ? ngayGioNgan(cu[0], cu[1]) : dg.gioCu;
    final ai = dg.nguoiDoi.isEmpty
        ? (dg.laSale ? 'Chuyên viên' : 'Chủ nhà')
        : '${dg.laSale ? 'Chuyên viên' : 'Chủ nhà'} ${dg.nguoiDoi}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: HD.warningTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_repeat, size: 34, color: HD.svcAmber),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: HD.warningTint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Bên bán bận · chờ bạn chọn giờ mới',
              key: const Key('phieu-trang-thai'),
              style: HD.bodyBold(size: 12, color: HD.svcAmber),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chọn lại giờ xem nhà',
          textAlign: TextAlign.center,
          style: HD.bodyBold(size: 22, color: HD.ink),
        ),
        const SizedBox(height: 4),
        Text(
          '$ai bận lúc $gioCu'
          '${dg.lyDo.isEmpty ? '' : ' — “${dg.lyDo}”'}. '
          'Chọn một giờ bên dưới, lịch được xác nhận ngay.',
          textAlign: TextAlign.center,
          style: HD.body(size: 14, color: HD.inkMuted),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EAF2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'GIỜ ${dg.laSale ? 'CHUYÊN VIÊN' : 'CHỦ NHÀ'} ĐỀ XUẤT',
                style: HD.bodyBold(size: 11, color: HD.inkMuted),
              ),
              const SizedBox(height: 10),
              if (dg.deXuat.isEmpty)
                Text(
                  'Bên bán nhờ bạn chọn một giờ trống khác.',
                  style: HD.body(size: 13, color: HD.inkMuted),
                ),
              for (final g in dg.deXuat) ...[
                _oDeXuat(p, g),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  key: const Key('chon-gio-khac'),
                  onPressed: _dangChon ? null : () => _chonGioKhac(p),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(
                    dg.deXuat.isEmpty
                        ? 'Chọn giờ trống'
                        : 'Không hợp giờ nào? Chọn giờ khác',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HD.accent,
                    side: const BorderSide(color: HD.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: HD.bodyBold(size: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _nutHuy(p, nhan: 'Không đi được nữa? Huỷ lịch'),
      ],
    );
  }

  Widget _oDeXuat(PhieuHen p, GioDeXuat g) {
    final d = DateTime.tryParse(g.ngay);
    final het = !g.conTrong;
    return InkWell(
      key: Key('de-xuat-${g.ngay}-${g.batDau}'),
      borderRadius: BorderRadius.circular(14),
      onTap: het || _dangChon ? null : () => _chonDeXuat(p, g),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: het ? const Color(0xFFF3F4F6) : HD.accentTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: het
                ? const Color(0xFFE5E7EB)
                : HD.accent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              size: 20,
              color: het ? HD.inkMuted : HD.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.gio.replaceAll('-', ' – '),
                    style: HD
                        .bodyBold(size: 15, color: het ? HD.inkMuted : HD.ink)
                        .copyWith(
                          decoration: het ? TextDecoration.lineThrough : null,
                        ),
                  ),
                  Text(
                    d == null
                        ? g.ngay
                        : '${_thuDai(d.weekday)}, ${_hai(d.day)}/${_hai(d.month)}',
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            if (het)
              Text(
                'Đã có người đặt',
                style: HD.body(size: 12, color: HD.inkMuted),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: HD.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Chọn',
                  style: HD.bodyBold(size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Vé ────────────────────────────────────────────────────────────────────

  Widget _thePhieuHen(PhieuHen p) {
    final luc = p.luc;
    final ngay = luc == null
        ? p.ngay
        : '${_thuDai(luc.weekday)}, ${_hai(luc.day)}/${_hai(luc.month)}';
    final gio = luc == null ? p.gio.split('-').first : _gio(luc);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD2D9F4).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.home_work_outlined, color: HD.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.tin.tieuDe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.bodyBold(size: 15, color: HD.ink),
                    ),
                    if (p.tin.diaChi.isNotEmpty)
                      Text(
                        p.tin.diaChi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 12, color: HD.inkMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _chiTietPhieu(
                  Icons.schedule_outlined,
                  'Thời gian xem',
                  gio,
                  ngay,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _chiTietPhieu(
                  p.laVideo ? Icons.videocam_outlined : Icons.people_outline,
                  'Hình thức hẹn',
                  p.laVideo ? 'Video call' : 'Trực tiếp',
                  p.laVideo ? 'Sale gọi Zalo' : '${p.soNguoi} người đi xem',
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MÃ PHIẾU HẸN',
                      style: HD.bodyBold(size: 10, color: HD.inkMuted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#${p.ma}',
                      style: HD.bodyBold(size: 18, color: HD.accent),
                    ),
                  ],
                ),
              ),
              Container(
                key: const Key('phieu-qr'),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 34,
                  color: HD.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chiTietPhieu(IconData icon, String nhan, String chinh, String phu) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: HD.accent),
            const SizedBox(height: 6),
            Text(nhan, style: HD.body(size: 10, color: HD.inkMuted)),
            Text(chinh, style: HD.bodyBold(size: 14, color: HD.ink)),
            Text(
              phu,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HD.body(size: 11, color: HD.inkMuted),
            ),
          ],
        ),
      );

  Widget _lienHe(PhieuHen p) {
    final so = p.sale!.sdt.replaceAll(RegExp(r'\D'), '');
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: FilledButton.icon(
              key: const Key('phieu-goi'),
              onPressed: so.isEmpty
                  ? null
                  : () => _mo(Uri(scheme: 'tel', path: so)),
              icon: const Icon(Icons.phone_in_talk, size: 18),
              label: const Text('Gọi ngay'),
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
              key: const Key('phieu-zalo'),
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

  // ── Điểm đón ──────────────────────────────────────────────────────────────

  Widget _diemDon(PhieuHen p) => Container(
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
              child: Icon(
                p.laVideo ? Icons.videocam_outlined : Icons.near_me,
                size: 18,
                color: HD.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.laVideo ? 'Căn hộ sẽ xem qua video' : 'Điểm đón tiếp',
                    style: HD.bodyBold(size: 15, color: HD.ink),
                  ),
                  Text(
                    p.diemDon.diaChi.isEmpty ? '—' : p.diemDon.diaChi,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!p.laVideo && p.diemDon.diaChi.isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            key: const Key('phieu-chi-duong'),
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

  // ── Quy trình ─────────────────────────────────────────────────────────────

  Widget _nhacNho(PhieuHen p) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFA36700).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFDDB8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: Color(0xFF2A1700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Không đi được? Huỷ lịch ngay tại đây để chuyên viên biết và nhả giờ '
            'cho người khác.',
            style: HD.body(size: 12.5, color: HD.ink),
          ),
        ),
        if (p.huyDuoc)
          TextButton(
            key: const Key('phieu-nhac-huy'),
            onPressed: _dangChon ? null : () => _huy(p),
            style: TextButton.styleFrom(
              foregroundColor: HD.accentDeep,
              textStyle: HD.bodyBold(size: 13),
            ),
            child: const Text('Huỷ lịch'),
          ),
      ],
    ),
  );

  Widget _nutCuoi(PhieuHen p) => Column(
    children: [
      SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('phieu-luu-lich'),
          onPressed: () => _mo(_lichGoogle(p)),
          icon: const Icon(Icons.calendar_month, size: 20),
          label: Text(
            'Lưu vào lịch của tôi',
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
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const Key('phieu-chia-se'),
                onPressed: () => _chiaSe(p),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Chia sẻ lịch hẹn'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEAEDFF),
                  foregroundColor: HD.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: HD.bodyBold(size: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const Key('phieu-xem-phong-khac'),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Xem phòng khác'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEAEDFF),
                  foregroundColor: HD.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: HD.bodyBold(size: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
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
