import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/api_viewing_appointment_repository.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/host/journey/xac_nhan_lich_xem_screen.dart';

/// MÀN 2 của CHỦ NHÀ — "Chi tiết yêu cầu xem" (mockup CHỦ NHÀ, 20/09/2026).
///
/// Ai xin xem, sale nào giới thiệu, căn nào, giờ nào, khách dặn gì — rồi hai
/// lối ra: TỪ CHỐI (`PATCH /status` → rejected) hoặc XÁC NHẬN LỊCH (mở màn 3
/// để chọn đúng khung giờ trước khi chốt).
class ChiTietYeuCauXemScreen extends StatefulWidget {
  const ChiTietYeuCauXemScreen({
    super.key,
    required this.appointmentId,
    this.api = const LichXemApi(),
    this.lichRepo,
    this.moLink,
  });

  final int appointmentId;
  final LichXemApi api;
  final ApiViewingAppointmentRepository? lichRepo;
  final Future<void> Function(Uri)? moLink;

  @override
  State<ChiTietYeuCauXemScreen> createState() => _ChiTietYeuCauXemScreenState();
}

class _ChiTietYeuCauXemScreenState extends State<ChiTietYeuCauXemScreen> {
  PhieuHen? _p;
  bool _dangTai = true;
  bool _dangGui = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final p = await widget.api.phieu(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        _p = p;
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được yêu cầu. Kéo xuống để thử lại.';
      });
    }
  }

  Future<void> _mo(Uri uri) async {
    if (widget.moLink != null) return widget.moLink!(uri);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _tuChoi() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Từ chối yêu cầu?', style: HD.bodyBold(size: 16)),
        content: Text(
          'Khách sẽ nhận thông báo là bạn không nhận lịch này.',
          style: HD.body(size: 13, color: HD.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            key: const Key('chu-xac-nhan-tu-choi'),
            style: FilledButton.styleFrom(backgroundColor: HD.accent),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await (widget.lichRepo ?? ApiViewingAppointmentRepository())
          .updateAppointmentStatus(widget.appointmentId, 'rejected');
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = 'Chưa từ chối được. Thử lại giúp em.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.accent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Chi tiết yêu cầu xem',
          style: HD.bodyBold(size: 16, color: Colors.white),
        ),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  HD.s16,
                  HD.s12,
                  HD.s16,
                  HD.s24,
                ),
                children: [
                  if (p != null) ...[
                    _dongKhach(p),
                    if (p.loiNhan.trim().isNotEmpty) ...[
                      const SizedBox(height: HD.s12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(HD.s12),
                        decoration: BoxDecoration(
                          color: HD.paperSunken,
                          borderRadius: BorderRadius.circular(HD.r12),
                        ),
                        child: Text(
                          '“${p.loiNhan.trim()}”',
                          style: HD.body(size: 13, color: HD.ink),
                        ),
                      ),
                    ],
                    const SizedBox(height: HD.s16),
                    _muc(Icons.apartment, 'Thông tin bất động sản'),
                    _theCan(p),
                    const SizedBox(height: HD.s16),
                    _muc(
                      Icons.calendar_month_outlined,
                      'Thời gian khách mong muốn',
                    ),
                    for (final k in _cacKhung(p)) _oKhung(k),
                    const SizedBox(height: HD.s16),
                    _muc(Icons.chat_bubble_outline, 'Ghi chú từ khách'),
                    Text(
                      p.loiNhan.trim().isEmpty
                          ? 'Khách không ghi chú gì.'
                          : p.loiNhan,
                      style: HD.body(size: 13, color: HD.inkSoft),
                    ),
                  ],
                  if (_loi != null) ...[
                    const SizedBox(height: HD.s12),
                    Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _dangTai ? null : _thanhNut(),
    );
  }

  List<String> _cacKhung(PhieuHen p) {
    final ra = <String>[
      '${_ngayDep(p.ngay)} · ${p.gio.replaceAll('-', ' - ')}',
    ];
    final m = RegExp(r'Em cũng xem được:\s*(.+)$').firstMatch(p.loiNhan);
    if (m != null) {
      ra.addAll(
        m.group(1)!.split('·').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }
    return ra;
  }

  Widget _dongKhach(PhieuHen p) {
    final so = p.sdtKhach.replaceAll(RegExp(r'[^0-9]'), '');
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: HD.paperSunken,
          child: const Icon(Icons.person, color: HD.inkMuted),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      p.tenKhach.isEmpty ? 'Khách' : p.tenKhach,
                      style: HD.bodyBold(size: 15),
                    ),
                  ),
                  const SizedBox(width: HD.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: HD.accentTint,
                      borderRadius: BorderRadius.circular(HD.rPill),
                    ),
                    child: Text(
                      'Khách thuê',
                      style: HD.bodyBold(size: 10.5, color: HD.accent),
                    ),
                  ),
                ],
              ),
              Text(
                p.sale == null
                    ? 'Chưa có sale phụ trách'
                    : 'Được giới thiệu bởi ${p.sale!.ten} (Sale)',
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            ],
          ),
        ),
        InkWell(
          key: const Key('chu-goi-khach'),
          onTap: so.isEmpty ? null : () => _mo(Uri(scheme: 'tel', path: so)),
          borderRadius: BorderRadius.circular(HD.rPill),
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: HD.accentTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.call,
              size: 17,
              color: so.isEmpty ? HD.inkMuted : HD.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _muc(IconData icon, String ten) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: HD.inkMuted),
        const SizedBox(width: 6),
        Text(ten, style: HD.bodyBold(size: 14)),
      ],
    ),
  );

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
            width: 72,
            height: 60,
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
                style: HD.bodyBold(size: 13.5),
              ),
              Text(
                p.tin.diaChi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
              if ((p.tin.gia ?? 0) > 0)
                Text(
                  '${PriceFormat.full(p.tin.gia!)}/${p.tin.donVi}',
                  style: HD.bodyBold(size: 13, color: HD.accent),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _oKhung(String chu) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 16, color: HD.inkMuted),
          const SizedBox(width: HD.s8),
          Expanded(
            child: Text(chu, style: HD.body(size: 13, color: HD.ink)),
          ),
        ],
      ),
    ),
  );

  Widget _thanhNut() {
    final p = _p;
    final xong =
        p != null && p.trangThai != 'pending' && p.trangThai != 'doi_gio';
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                key: const Key('chu-tu-choi'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: HD.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HD.r12),
                  ),
                ),
                onPressed: xong || _dangGui ? null : _tuChoi,
                child: Text(
                  'Từ chối',
                  style: HD.bodyBold(size: 14, color: HD.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton(
                key: const Key('chu-xac-nhan-lich'),
                style: FilledButton.styleFrom(
                  backgroundColor: HD.accent,
                  disabledBackgroundColor: HD.accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HD.r12),
                  ),
                ),
                onPressed: p == null || xong || _dangGui
                    ? null
                    : () => Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => XacNhanLichXemScreen(
                                appointmentId: p.id,
                                api: widget.api,
                              ),
                            ),
                          )
                          .then((v) {
                            if (v == true && mounted)
                              Navigator.of(context).pop(true);
                          }),
                child: Text(
                  xong ? 'Đã xử lý' : 'Xác nhận lịch',
                  style: HD.bodyBold(size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
