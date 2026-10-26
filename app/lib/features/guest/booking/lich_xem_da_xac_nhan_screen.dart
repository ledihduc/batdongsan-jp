// ignore_for_file: unused_element

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:house_booking/features/guest/booking/doi_gio_sheet.dart';
import 'package:house_booking/features/guest/booking/ket_qua_sau_xem_screen.dart';
import 'package:house_booking/features/guest/booking/thue_ngay_action.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// MÀN 4 — "Lịch xem đã được xác nhận" (mockup KHÁCH THUÊ, 20/09/2026).
///
/// Thông tin đi xem: giờ hẹn · địa chỉ (chỉ đường bằng bản đồ) · sale đón ·
/// tình trạng chủ nhà. Sau giờ hẹn, nút dưới cùng mở [KetQuaSauXemScreen] —
/// đúng thứ tự mockup: xem xong mới hỏi kết quả.
///
/// SĐT sale ở phiếu hẹn là SỐ THẬT (server chỉ che ở trang công khai), nên nút
/// gọi / Zalo ở đây gọi được thật.
class LichXemDaXacNhanScreen extends StatefulWidget {
  const LichXemDaXacNhanScreen({
    super.key,
    required this.appointmentId,
    this.api = const LichXemApi(),
    this.moLink,
    this.bayGio,
    this.viewingV2Api = const ViewingV2Api(),
    this.rentalJourneyApi = const RentalJourneyApi(),
  });

  final int appointmentId;
  final LichXemApi api;
  final Future<void> Function(Uri)? moLink;

  /// Test ghim "bây giờ" để nút kết quả hiện/ẩn ổn định.
  final DateTime? bayGio;
  final ViewingV2Api viewingV2Api;
  final RentalJourneyApi rentalJourneyApi;

  @override
  State<LichXemDaXacNhanScreen> createState() => _LichXemDaXacNhanScreenState();
}

class _LichXemDaXacNhanScreenState extends State<LichXemDaXacNhanScreen> {
  PhieuHen? _phieu;
  bool _dangTai = true;
  String? _loi;
  bool _dangGui = false;
  Timer? _henGio;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _henGio?.cancel();
    super.dispose();
  }

  DateTime get _bayGio => widget.bayGio ?? DateTime.now();

  void _lapHenGio(PhieuHen p) {
    _henGio?.cancel();
    final luc = p.luc;
    if (widget.bayGio != null || luc == null || !_bayGio.isBefore(luc)) return;
    _henGio = Timer(
      luc.difference(DateTime.now()) + const Duration(milliseconds: 100),
      () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _nap() async {
    try {
      final p = await widget.api.phieu(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        _phieu = p;
        _dangTai = false;
      });
      _lapHenGio(p);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được lịch xem. Kéo xuống để thử lại.';
      });
    }
  }

  Future<void> _thueNgay(PhieuHen p) async {
    if (_dangGui) return;
    setState(() => _dangGui = true);
    try {
      await moThueNgay(
        context,
        phieu: p,
        viewingApi: widget.viewingV2Api,
        rentalApi: widget.rentalJourneyApi,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa mở được hồ sơ thuê. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  Future<void> _mo(Uri uri) async {
    if (widget.moLink != null) return widget.moLink!(uri);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    if (moi != null && mounted) setState(() => _phieu = moi);
  }

  Future<void> _huyLich(PhieuHen p) async {
    if (_dangGui) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy lịch xem này?'),
        content: const Text('Sale và chủ nhà sẽ được thông báo ngay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lịch'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _dangGui = true);
    try {
      final moi = await widget.api.huy(p.id, lyDo: 'Khách hủy lịch đã chốt');
      if (!mounted) return;
      Navigator.of(context).pop(moi);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _phieu;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Lịch xem đã chốt',
          style: HD.bodyBold(size: 17, color: Colors.white),
        ),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s24),
                children: [
                  if (p != null) ...[
                    const ViewingJourneyProgress(
                      labels: [
                        'Gửi yêu cầu',
                        'Xếp lịch',
                        'Đi xem',
                        'Chốt thuê',
                      ],
                      icons: [
                        Icons.check,
                        Icons.event_available,
                        Icons.directions_walk,
                        Icons.handshake,
                      ],
                      current: 2,
                    ),
                    const SizedBox(height: HD.s16),
                    ViewingStatusBox(
                      icon: Icons.check_circle,
                      title: 'Đã xác nhận lịch',
                      message:
                          'Lịch hẹn đã được xác nhận. Vui lòng đến đúng giờ.',
                      color: HD.positive,
                    ),
                    const SizedBox(height: HD.s12),
                    ViewingPropertyCard(phieu: p),
                    const SizedBox(height: HD.s16),
                    _dongThongTin(
                      icon: Icons.calendar_month_outlined,
                      nhan: 'Thời gian xem',
                      chu:
                          '${_ngayDep(p.ngay)}\n${p.gio.replaceAll('-', ' - ')}',
                    ),
                    _dongThongTin(
                      icon: Icons.location_on_outlined,
                      nhan: 'Địa chỉ',
                      chu: p.diemDon.diaChi,
                      cuoi: TextButton(
                        key: const Key('xac-nhan-chi-duong'),
                        onPressed: p.diemDon.diaChi.isEmpty
                            ? null
                            : () => _mo(
                                Uri.https('www.google.com', '/maps/search/', {
                                  'api': '1',
                                  'query': p.diemDon.coToaDo
                                      ? '${p.diemDon.lat},${p.diemDon.lng}'
                                      : p.diemDon.diaChi,
                                }),
                              ),
                        style: TextButton.styleFrom(
                          side: const BorderSide(color: HD.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(HD.r8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                        ),
                        child: Text(
                          'Chỉ đường',
                          style: HD.bodyBold(size: 12, color: HD.accent),
                        ),
                      ),
                    ),
                    _dongSale(p),
                    const SizedBox(height: HD.s4),
                    _cacNutLich(p),
                    _dongThongTin(
                      icon: Icons.home_outlined,
                      nhan: 'Tình trạng chủ nhà',
                      chuWidget: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 15,
                            color: HD.positive,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Đã xác nhận, sẽ có mặt',
                            style: HD.bodyBold(size: 13, color: HD.positive),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: HD.s8),
                    _hopDoiLich(),
                  ],
                  if (_loi != null) ...[
                    const SizedBox(height: HD.s12),
                    Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _nutKetQua(),
    );
  }

  Widget _cacNutLich(PhieuHen p) {
    final s = p.sale;
    final so = (s?.sdt ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final lienHe = s != null && !s.sdtDaChe && so.isNotEmpty;
    Widget button({
      required String label,
      required IconData icon,
      required VoidCallback? onTap,
    }) => OutlinedButton.icon(
      style: viewingOutlineButton(),
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: button(
                label: 'Nhắn Sale',
                icon: Icons.chat_bubble_outline,
                onTap: lienHe ? () => _mo(Uri.https('zalo.me', '/$so')) : null,
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: button(
                label: 'Gọi Sale',
                icon: Icons.call,
                onTap: lienHe ? () => _mo(Uri(scheme: 'tel', path: so)) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s8),
        Row(
          children: [
            Expanded(
              child: button(
                label: 'Đổi lịch',
                icon: Icons.event_repeat,
                onTap: _dangGui ? null : () => _doiLich(p),
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: button(
                label: 'Hủy lịch',
                icon: Icons.close,
                onTap: _dangGui ? null : () => _huyLich(p),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Nút kết quả chỉ hiện SAU giờ hẹn — hỏi "xem thế nào" trước khi đi xem là
  /// vô nghĩa, và sẽ đẻ ra hồ sơ thuê cho một buổi chưa diễn ra.
  Widget? _nutKetQua() {
    final p = _phieu;
    if (p == null) return null;
    final luc = p.luc;
    if (luc == null) return null;
    if (_bayGio.isBefore(luc)) {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('xac-nhan-thue-ngay'),
            style: viewingPrimaryButton(),
            onPressed: _dangGui ? null : () => _thueNgay(p),
            icon: const Icon(Icons.favorite, size: 19),
            label: const Text('Muốn thuê ngay'),
          ),
        ),
      );
    }
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('xac-nhan-mo-ket-qua'),
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
              icon: const Icon(Icons.check_circle_outline, size: 19),
              label: const Text('Đã xem · Gửi kết quả'),
            ),
          ),
          const SizedBox(height: HD.s8),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton.icon(
              style: viewingOutlineButton(color: const Color(0xFF173B75)),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã lưu. Ứng dụng sẽ nhắc bạn phản hồi sau.'),
                ),
              ),
              icon: const Icon(Icons.schedule, size: 19),
              label: const Text('Chưa xem · Nhắc lại sau'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _theCan(PhieuHen p) => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(HD.r8),
          child: SizedBox(
            width: 64,
            height: 56,
            child: (p.tin.anh == null || p.tin.anh!.isEmpty)
                ? const ColoredBox(
                    color: HD.paperSunken,
                    child: Icon(Icons.apartment, color: HD.inkMuted),
                  )
                : CachedNetworkImage(
                    imageUrl: p.tin.anh!.startsWith('http')
                        ? p.tin.anh!
                        : '${ApiConfig.baseUrl}${p.tin.anh}',
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: HD.paperSunken),
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: HD.paperSunken),
                  ),
          ),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.tin.tieuDe,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(size: 14),
              ),
              const SizedBox(height: 2),
              if ((p.tin.gia ?? 0) > 0)
                Text(
                  '${PriceFormat.full(p.tin.gia!)}/${p.tin.donVi}',
                  style: HD.bodyBold(size: 13, color: HD.accent),
                ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: HD.inkMuted,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      p.tin.diaChi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 12, color: HD.inkMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _dongThongTin({
    required IconData icon,
    required String nhan,
    String? chu,
    Widget? chuWidget,
    Widget? cuoi,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: HD.inkMuted),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nhan, style: HD.body(size: 12, color: HD.inkMuted)),
              const SizedBox(height: 2),
              if (chuWidget != null)
                chuWidget
              else
                Text(chu ?? '', style: HD.bodyBold(size: 13.5)),
            ],
          ),
        ),
        if (cuoi != null) ...[const SizedBox(width: HD.s8), cuoi],
      ],
    ),
  );

  Widget _dongSale(PhieuHen p) {
    final s = p.sale;
    final so = (s?.sdt ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final goiDuoc = s != null && !s.sdtDaChe && so.isNotEmpty;
    return _dongThongTin(
      icon: Icons.person_outline,
      nhan: 'Sale phụ trách',
      chuWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s?.ten ?? 'Đang phân công', style: HD.bodyBold(size: 13.5)),
          if (goiDuoc)
            Text(s.sdt, style: HD.body(size: 12.5, color: HD.inkMuted)),
        ],
      ),
      cuoi: Row(
        children: [
          IconButton(
            key: const Key('xac-nhan-goi-sale'),
            onPressed: goiDuoc ? () => _mo(Uri(scheme: 'tel', path: so)) : null,
            icon: const Icon(Icons.call, size: 18),
            color: HD.accent,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            key: const Key('xac-nhan-zalo-sale'),
            onPressed: goiDuoc ? () => _mo(Uri.https('zalo.me', '/$so')) : null,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            color: HD.accent,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _hopDoiLich() => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.svcBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: HD.svcBlue),
        const SizedBox(width: HD.s8),
        Expanded(
          child: Text(
            'Có thay đổi? Báo cho sale trước ít nhất 2 giờ để được hỗ trợ sắp '
            'xếp lại lịch.',
            style: HD.body(size: 12.5, color: HD.inkSoft),
          ),
        ),
      ],
    ),
  );

  static String _ngayDep(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final thu = d.weekday == DateTime.sunday
        ? 'Chủ nhật'
        : 'Thứ ${d.weekday + 1}';
    return '$thu, ${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
