import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:house_booking/features/guest/booking/doi_gio_sheet.dart';
import 'package:house_booking/features/guest/booking/schedule_booking_screen.dart';
import 'package:house_booking/features/guest/lich_xem/ket_qua_lich_xem_screen.dart';
import 'package:house_booking/features/guest/lich_xem/trang_thai_xem.dart';
import 'package:house_booking/features/guest/lich_xem/widgets/lich_xem_ui.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';

/// Chi tiết lịch xem phòng — góc nhìn KHÁCH (mockup "Luồng lịch xem phòng sắp
/// tới", 04/10/2026). Một màn, bốn dáng theo [BuocXem]:
///
///   * Đã gửi lịch   — ảnh lớn · sale phụ trách · 5 bước · hộp vàng ·
///                     [Hủy lịch] [Nhắn tin với sale]
///   * Đã xác nhận   — như trên, hộp xanh "Hẹn gặp bạn lúc…" ·
///                     [Đổi lịch] [Nhắn tin với sale]
///   * Đã xem phòng  — thẻ tóm tắt · "Bạn thấy phòng này thế nào?" · Chốt /
///                     Không chốt · ghi chú · [Nhắn tin] [Gửi đánh giá]
///   * Đã chốt / Không chốt / Đã hủy — mở lại từ Lịch sử.
///
/// API: `GET /api/viewing-appointments/{id}/phieu`; huỷ `PATCH …/status`; đổi
/// lịch `POST …/khach-doi-lich`; đánh giá `POST /api/v2/viewings/{id}/result`
/// (luồng cũ `…/viewing-result` khi v2 chưa bật).
class ChiTietLichXemScreen extends StatefulWidget {
  const ChiTietLichXemScreen({
    super.key,
    required this.appointmentId,
    this.api = const LichXemApi(),
    this.v2Api = const ViewingV2Api(),
    this.journeyApi = const RentalJourneyApi(),
    this.onTimNha,
    this.bayGio,
  });

  final int appointmentId;
  final LichXemApi api;
  final ViewingV2Api v2Api;
  final RentalJourneyApi journeyApi;
  final VoidCallback? onTimNha;

  /// Chỉ để test ghim "bây giờ".
  final DateTime? bayGio;

  @override
  State<ChiTietLichXemScreen> createState() => _ChiTietLichXemScreenState();
}

class _ChiTietLichXemScreenState extends State<ChiTietLichXemScreen> {
  PhieuHen? _p;
  String? _loi;
  bool _dangGui = false;

  /// Lựa chọn ở màn "Đã xem phòng": true = chốt, false = không chốt.
  bool? _chot;
  final _ghiChu = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _ghiChu.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    setState(() => _loi = null);
    try {
      final p = await widget.api.phieu(widget.appointmentId);
      if (mounted) setState(() => _p = p);
    } catch (e) {
      if (mounted) {
        setState(
          () => _loi = e is ApiException
              ? e.message
              : 'Chưa tải được lịch xem. Vui lòng thử lại.',
        );
      }
    }
  }

  BuocXem _buoc(PhieuHen p) => buocXemCua(
    p.trangThai,
    ketQua: p.ketQua,
    luc: p.luc,
    bayGio: widget.bayGio,
  );

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  void _nhan(PhieuHen p) {
    final s = p.sale;
    if (s == null) {
      _bao('Phòng này chưa có sale phụ trách.');
      return;
    }
    nhanTinSale(context, s, p.tin);
  }

  void _ketQua(KieuKetQuaXem k, PhieuHen p) =>
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              KetQuaLichXemScreen(kieu: k, phieu: p, onTimNha: widget.onTimNha),
        ),
      );

  // ── Hành động ──────────────────────────────────────────────────────────────
  Future<void> _huy(PhieuHen p) async {
    final lyDo = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _SheetHuyLich(),
    );
    if (lyDo == null || !mounted) return;
    setState(() => _dangGui = true);
    try {
      final moi = await widget.api.huy(p.id, lyDo: lyDo);
      if (!mounted) return;
      _ketQua(KieuKetQuaXem.daHuy, moi);
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Chưa hủy được lịch, thử lại nhé.');
      if (mounted) setState(() => _dangGui = false);
    }
  }

  Future<void> _doiLich(PhieuHen p) async {
    final moi = await moChonGioKhac(
      context,
      appointmentId: p.id,
      api: widget.api,
      khachTuDoi: true,
      ngayHienTai: p.ngay,
      gioHienTai: p.gio,
    );
    if (moi == null || !mounted) return;
    setState(() => _p = moi);
    _bao('Đã đổi lịch · chờ sale xác nhận lại');
  }

  Future<void> _chonDeXuat(PhieuHen p, GioDeXuat g) async {
    setState(() => _dangGui = true);
    try {
      final moi = await widget.api.chonGio(p.id, g);
      if (mounted) setState(() => _p = moi);
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không chọn được giờ này.');
      await _nap();
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  Future<void> _chonGioKhac(PhieuHen p) async {
    final moi = await moChonGioKhac(
      context,
      appointmentId: p.id,
      api: widget.api,
    );
    if (moi != null && mounted) setState(() => _p = moi);
  }

  Future<void> _guiDanhGia(PhieuHen p) async {
    final chot = _chot;
    if (chot == null) {
      _bao('Chọn "Chốt phòng này" hoặc "Không chốt" trước nhé.');
      return;
    }
    final ghiChu = _ghiChu.text.trim();
    setState(() => _dangGui = true);
    try {
      try {
        await widget.v2Api.submitResult(
          p.id,
          status: chot ? 'INTERESTED' : 'DECLINED',
          reasonCode: chot ? null : 'OTHER',
          reasonNote: ghiChu.isEmpty ? null : ghiChu,
        );
      } on ApiException catch (e) {
        // 404 = luồng v2 chưa bật trên server → ghi theo luồng cũ.
        if (e.statusCode != 404) rethrow;
        await widget.journeyApi.submitViewingResult(
          p.id,
          interested: chot,
          reason: ghiChu.isEmpty ? null : ghiChu,
        );
      }
      if (!mounted) return;
      _ketQua(chot ? KieuKetQuaXem.daChot : KieuKetQuaXem.khongChot, p);
    } catch (e) {
      _bao(
        e is ApiException ? e.message : 'Chưa gửi được đánh giá, thử lại nhé.',
      );
      if (mounted) setState(() => _dangGui = false);
    }
  }

  // ── Giao diện ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: _loi == null
              ? const CircularProgressIndicator(color: HD.accent)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loi!,
                        textAlign: TextAlign.center,
                        style: HD.body(color: HD.inkMuted),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _nap,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    final buoc = _buoc(p);
    if (buoc == BuocXem.daXem && p.loai == 'xem') return _manDaXem(p);
    return _manChiTiet(p, buoc);
  }

  Widget _manChiTiet(PhieuHen p, BuocXem buoc) {
    final luc = p.luc;
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _nap,
        child: ListView(
          key: const Key('chi-tiet-lich-xem'),
          padding: EdgeInsets.zero,
          children: [
            SafeArea(bottom: false, child: AnhLichXem(tin: p.tin)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          p.tin.tieuDe,
                          style: HD.bodyBold(size: 19, color: HD.ink),
                        ),
                      ),
                      const SizedBox(width: 8),
                      NhanBuocXem(buoc),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (p.tin.diaChi.isNotEmpty) ...[
                    _Dong(icon: Icons.location_on_outlined, chu: p.tin.diaChi),
                    const SizedBox(height: 6),
                  ],
                  _Dong(
                    icon: Icons.access_time_rounded,
                    chu: luc == null
                        ? khoangGio(p.gio)
                        : '${thuNgay(luc)} • ${khoangGio(p.gio)}',
                  ),
                  const SizedBox(height: 16),
                  if (p.sale != null) ...[
                    TheSalePhuTrach(sale: p.sale!, onNhan: () => _nhan(p)),
                    const SizedBox(height: 18),
                  ],
                  // Lịch đã huỷ không đi tiếp bước nào — bỏ hẳn thanh 5 bước.
                  if (buoc != BuocXem.daHuy && buoc != BuocXem.hetHan) ...[
                    Text(
                      'Trạng thái lịch xem',
                      style: HD.bodyBold(size: 16, color: HD.ink),
                    ),
                    const SizedBox(height: 12),
                    ThanhBuocXem(buoc: buoc),
                    const SizedBox(height: 16),
                  ],
                  ..._hop(p, buoc),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _chan(p, buoc),
    );
  }

  List<Widget> _hop(PhieuHen p, BuocXem buoc) {
    final luc = p.luc;
    final gio = khoangGio(p.gio).split(' - ').first;
    switch (buoc) {
      case BuocXem.daGui:
        return const [
          HopThongBao(
            key: Key('hop-da-gui'),
            icon: Icons.info_outline_rounded,
            mau: Color(0xFFC77C00),
            nen: Color(0xFFFFF7E6),
            chu:
                'Bạn đã gửi yêu cầu xem phòng. Sale sẽ xác nhận lịch trong '
                'thời gian sớm nhất (thường trong 1–2 giờ làm việc).',
          ),
        ];
      case BuocXem.choChonGio:
        final deXuat = [
          for (final g in p.doiGio?.deXuat ?? const <GioDeXuat>[])
            if (g.conTrong) g,
        ];
        return [
          HopThongBao(
            key: const Key('hop-chon-gio'),
            icon: Icons.schedule_rounded,
            mau: const Color(0xFFC77C00),
            nen: const Color(0xFFFFF7E6),
            chu: [
              'Sale báo bận giờ bạn chọn và đề xuất giờ khác.',
              if ((p.doiGio?.lyDo ?? '').isNotEmpty)
                'Lý do: ${p.doiGio!.lyDo}.',
              'Chọn một giờ dưới đây để chốt lịch.',
            ].join(' '),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in deXuat)
                ActionChip(
                  key: Key('de-xuat-${g.ngay}-${g.gio}'),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: HD.accent),
                  label: Text(
                    () {
                      final d = DateTime.tryParse(g.ngay);
                      final h = khoangGio(g.gio).split(' - ').first;
                      return d == null ? h : '${thuNgayNgan(d)} • $h';
                    }(),
                    style: HD.bodyBold(size: 13, color: HD.accent),
                  ),
                  onPressed: _dangGui ? null : () => _chonDeXuat(p, g),
                ),
              ActionChip(
                key: const Key('chon-gio-khac'),
                backgroundColor: const Color(0xFFF1F2F4),
                side: BorderSide.none,
                label: Text(
                  'Chọn giờ khác',
                  style: HD.body(size: 13, color: HD.ink),
                ),
                onPressed: _dangGui ? null : () => _chonGioKhac(p),
              ),
            ],
          ),
        ];
      case BuocXem.daXacNhan:
        return [
          HopThongBao(
            key: const Key('hop-da-xac-nhan'),
            icon: Icons.check_circle_outline_rounded,
            mau: HD.positive,
            nen: HD.positiveTint,
            chu:
                'Sale đã xác nhận lịch với chủ nhà. Hẹn gặp bạn lúc $gio'
                '${luc == null ? '' : ', ${thuNgayNgan(luc)}'}'
                ' tại ${p.tin.tieuDe}.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('huy-lich-nho'),
              style: TextButton.styleFrom(foregroundColor: HD.inkMuted),
              onPressed: _dangGui ? null : () => _huy(p),
              child: Text(
                'Không đi được? Hủy lịch',
                style: HD.body(size: 13.5, color: HD.inkMuted),
              ),
            ),
          ),
        ];
      case BuocXem.daXem:
        // Hẹn chốt (không phải đi xem) không có bước đánh giá.
        return [
          HopThongBao(
            icon: Icons.visibility_outlined,
            mau: BuocXem.daXem.mau,
            nen: BuocXem.daXem.nen,
            chu: 'Buổi hẹn đã diễn ra. Sale sẽ liên hệ bạn cho bước tiếp theo.',
          ),
        ];
      case BuocXem.daChot:
        return [
          HopThongBao(
            key: const Key('hop-da-chot'),
            icon: Icons.verified_outlined,
            mau: BuocXem.daChot.mau,
            nen: BuocXem.daChot.nen,
            chu:
                'Bạn đã chốt phòng này. Xem tiến trình hợp đồng tại mục '
                'Đang thuê.',
          ),
        ];
      case BuocXem.khongChot:
        return const [
          HopThongBao(
            key: Key('hop-khong-chot'),
            icon: Icons.info_outline_rounded,
            mau: Color(0xFF6B7280),
            nen: Color(0xFFF1F2F4),
            chu: 'Bạn đã không chốt phòng này sau buổi xem.',
          ),
        ];
      case BuocXem.hetHan:
        return const [
          HopThongBao(
            key: Key('hop-het-han'),
            icon: Icons.history_toggle_off_rounded,
            mau: Color(0xFF6B7280),
            nen: Color(0xFFF1F2F4),
            chu:
                'Lịch này đã qua giờ hẹn mà chưa được sale xác nhận. '
                'Bạn có thể đặt lịch khác.',
          ),
        ];
      case BuocXem.daHuy:
        return [
          HopThongBao(
            key: const Key('hop-da-huy'),
            icon: Icons.event_busy_rounded,
            mau: HD.accent,
            nen: HD.accentTint,
            chu: p.trangThai == 'rejected'
                ? 'Sale đã từ chối lịch này. Bạn có thể đặt lịch khác.'
                : 'Lịch xem phòng này đã được hủy.',
          ),
        ];
    }
  }

  Widget? _chan(PhieuHen p, BuocXem buoc) {
    final nhan = p.sale == null ? null : () => _nhan(p);
    return switch (buoc) {
      BuocXem.daGui || BuocXem.choChonGio => HaiNutChan(
        trai: 'Hủy lịch',
        khoaTrai: const Key('huy-lich'),
        onTrai: () => _huy(p),
        phai: 'Nhắn tin với sale',
        khoaPhai: const Key('nhan-sale'),
        onPhai: nhan,
        dangChay: _dangGui,
      ),
      BuocXem.daXacNhan => HaiNutChan(
        trai: 'Đổi lịch',
        khoaTrai: const Key('doi-lich'),
        onTrai: () => _doiLich(p),
        phai: 'Nhắn tin với sale',
        khoaPhai: const Key('nhan-sale'),
        onPhai: nhan,
        dangChay: _dangGui,
      ),
      BuocXem.daChot || BuocXem.daXem => HaiNutChan(
        trai: 'Nhắn tin với sale',
        khoaTrai: const Key('nhan-sale'),
        onTrai: nhan,
        phai: 'Về Hoạt động',
        onPhai: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
      BuocXem.khongChot => HaiNutChan(
        trai: 'Nhắn tin với sale',
        khoaTrai: const Key('nhan-sale'),
        onTrai: nhan,
        phai: 'Xem thêm phòng',
        onPhai: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          widget.onTimNha?.call();
        },
      ),
      BuocXem.daHuy || BuocXem.hetHan =>
        p.tin.houseId == null && p.tin.roomId == null
            ? null
            : HaiNutChan(
                trai: 'Về Hoạt động',
                onTrai: () => Navigator.of(context).popUntil((r) => r.isFirst),
                phai: 'Đặt lịch lại',
                khoaPhai: const Key('dat-lai'),
                onPhai: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ScheduleBookingScreen(
                      houseId: p.tin.houseId,
                      roomId: p.tin.roomId,
                      tenPhong: p.tin.tieuDe,
                    ),
                  ),
                ),
              ),
    };
  }

  /// Màn 4 — "Đã xem phòng": khách chốt hoặc không chốt, kèm ghi chú.
  Widget _manDaXem(PhieuHen p) {
    final luc = p.luc;
    final anh = p.tin.anhDs.isNotEmpty ? p.tin.anhDs.first : p.tin.anh;
    const nen = ColoredBox(
      color: HD.paperSunken,
      child: Center(child: Icon(Icons.apartment_rounded, color: HD.inkMuted)),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Chi tiết lịch xem',
          style: HD.bodyBold(size: 17, color: HD.ink),
        ),
      ),
      body: ListView(
        key: const Key('lich-xem-da-xem'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kVienXem),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 84,
                        height: 72,
                        child: anh == null
                            ? nen
                            : CachedNetworkImage(
                                imageUrl: duongDanAnh(anh),
                                fit: BoxFit.cover,
                                placeholder: (_, _) => nen,
                                errorWidget: (_, _, _) => nen,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: NhanBuocXem(BuocXem.daXem),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.tin.tieuDe,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HD.bodyBold(size: 15, color: HD.ink),
                          ),
                          const SizedBox(height: 4),
                          _Dong(
                            icon: Icons.access_time_rounded,
                            chu: luc == null
                                ? khoangGio(p.gio)
                                : '${thuNgayNgan(luc)} • ${khoangGio(p.gio)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (p.sale != null) ...[
                  const Divider(height: 22, color: kVienXem),
                  Row(
                    children: [
                      AnhDaiDien(ten: p.sale!.ten, anh: p.sale!.anh, co: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sale: ${p.sale!.ten}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.body(size: 13.5, color: HD.ink),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kVienXem),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bạn thấy phòng này thế nào?',
                            style: HD.bodyBold(size: 16, color: HD.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cho sale biết quyết định của bạn sau buổi xem.',
                            style: HD.body(size: 13, color: HD.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: HD.accentTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.home_work_outlined,
                        color: HD.accent,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _LuaChon(
                  key: const Key('chon-chot'),
                  chon: _chot == true,
                  icon: Icons.thumb_up_alt_outlined,
                  mau: HD.positive,
                  nen: HD.positiveTint,
                  tieuDe: 'Chốt phòng này',
                  phu: 'Tôi muốn thuê',
                  onTap: () => setState(() => _chot = true),
                ),
                const SizedBox(height: 10),
                _LuaChon(
                  key: const Key('chon-khong-chot'),
                  chon: _chot == false,
                  icon: Icons.thumb_down_alt_outlined,
                  mau: HD.accent,
                  nen: HD.accentTint,
                  tieuDe: 'Không chốt',
                  phu: 'Tôi không thuê',
                  onTap: () => setState(() => _chot = false),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ghi chú (tùy chọn)',
                  style: HD.bodyBold(size: 14, color: HD.ink),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('ghi-chu-danh-gia'),
                  controller: _ghiChu,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Chia sẻ thêm cảm nhận của bạn về phòng…',
                    hintStyle: HD.body(size: 13.5, color: HD.inkMuted),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kVienXem),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kVienXem),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: HaiNutChan(
        trai: 'Nhắn tin với sale',
        khoaTrai: const Key('nhan-sale'),
        onTrai: p.sale == null ? null : () => _nhan(p),
        phai: 'Gửi đánh giá',
        khoaPhai: const Key('gui-danh-gia'),
        onPhai: _chot == null ? null : () => _guiDanhGia(p),
        dangChay: _dangGui,
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  const _Dong({required this.icon, required this.chu});

  final IconData icon;
  final String chu;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: HD.inkMuted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(chu, style: HD.body(size: 13.5, color: HD.inkMuted)),
      ),
    ],
  );
}

/// Ô chọn lớn: icon tròn màu · tiêu đề · dòng phụ · vòng tròn chọn.
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
    color: chon ? nen : Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: chon ? mau : kVienXem, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: nen, shape: BoxShape.circle),
              child: Icon(icon, color: mau, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tieuDe, style: HD.bodyBold(size: 15, color: mau)),
                  const SizedBox(height: 2),
                  Text(phu, style: HD.body(size: 13, color: HD.inkMuted)),
                ],
              ),
            ),
            Icon(
              chon
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: chon ? mau : const Color(0xFFC4C8CE),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Hỏi lý do trước khi huỷ — chọn một dòng, không bắt gõ.
class _SheetHuyLich extends StatefulWidget {
  const _SheetHuyLich();

  @override
  State<_SheetHuyLich> createState() => _SheetHuyLichState();
}

class _SheetHuyLichState extends State<_SheetHuyLich> {
  static const _lyDo = [
    'Tôi bận việc đột xuất',
    'Tôi đã tìm được phòng khác',
    'Tôi muốn xem phòng khác',
    'Lý do khác',
  ];
  String _chon = _lyDo.first;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hủy lịch xem phòng?', style: HD.bodyBold(size: 18)),
          const SizedBox(height: 6),
          Text(
            'Cho sale biết lý do để sắp xếp tốt hơn.',
            style: HD.body(size: 13.5, color: HD.inkMuted),
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _chon,
            onChanged: (v) => setState(() => _chon = v ?? _chon),
            child: Column(
              children: [
                for (final l in _lyDo)
                  RadioListTile<String>(
                    key: Key('ly-do-$l'),
                    value: l,
                    contentPadding: EdgeInsets.zero,
                    activeColor: HD.accent,
                    title: Text(l, style: HD.body(size: 14.5)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('xac-nhan-huy'),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(_chon),
              child: const Text('Xác nhận hủy lịch'),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: HD.inkMuted),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Không hủy'),
          ),
        ],
      ),
    ),
  );
}
