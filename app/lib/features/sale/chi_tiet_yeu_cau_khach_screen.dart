// ignore_for_file: unused_element

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/api_viewing_appointment_repository.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/sale/lam_viec_voi_chu_nha_screen.dart';
import 'package:house_booking/features/sale/sau_buoi_xem_screen.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// MÀN 2 của SALE — "Chi tiết yêu cầu khách" (mockup SALE, 20/09/2026).
///
/// Mọi thứ trên màn đều từ PHIẾU HẸN thật (`GET /viewing-appointments/{id}/phieu`,
/// sale phụ trách xem được): khách là ai, muốn xem gì, giờ nào, nhắn gì.
///
/// "Nhu cầu tìm thuê" suy từ chính tin khách xin xem — app chưa có chỗ để khách
/// khai nhu cầu riêng (loại phòng / khu vực / ngân sách), nên thà nói rõ nguồn
/// còn hơn in ba dòng trống hoặc bịa số.
class ChiTietYeuCauKhachScreen extends StatefulWidget {
  const ChiTietYeuCauKhachScreen({
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
  State<ChiTietYeuCauKhachScreen> createState() =>
      _ChiTietYeuCauKhachScreenState();
}

class _ChiTietYeuCauKhachScreenState extends State<ChiTietYeuCauKhachScreen> {
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

  Future<void> _xacNhan() async {
    final p = _p;
    if (p == null || _dangGui) return;
    setState(() => _dangGui = true);
    try {
      await (widget.lichRepo ?? ApiViewingAppointmentRepository())
          .updateAppointmentStatus(p.id, 'approved');
      await _nap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận lịch với khách và chủ nhà.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa xác nhận được lịch. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
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
          p?.trangThai == 'approved'
              ? 'Lịch xem đã xác nhận'
              : 'Xác nhận lịch xem',
          style: HD.bodyBold(size: 17, color: Colors.white),
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
                    if (p.trangThai == 'approved') ...[
                      const ViewingStatusBox(
                        icon: Icons.check_circle,
                        title: 'Đã xác nhận lịch',
                        message: 'Khách đã nhận thông báo lịch xem.',
                        color: HD.positive,
                      ),
                      const SizedBox(height: HD.s12),
                    ],
                    ViewingPropertyCard(phieu: p),
                    const SizedBox(height: HD.s12),
                    const Divider(height: 1),
                    const SizedBox(height: HD.s12),
                    Text('Thông tin khách hàng', style: HD.bodyBold(size: 14)),
                    const SizedBox(height: HD.s8),
                    _dongKhach(p),
                    const SizedBox(height: 14),
                    Text(
                      'Thời gian khách yêu cầu',
                      style: HD.bodyBold(size: 14),
                    ),
                    const SizedBox(height: HD.s8),
                    ViewingInfoRow(
                      icon: Icons.calendar_month_outlined,
                      text: viewingPrettyDate(p.ngay),
                    ),
                    ViewingInfoRow(
                      icon: Icons.access_time,
                      text: p.gio.replaceAll('-', ' - '),
                    ),
                    if (p.loiNhan.trim().isNotEmpty) ...[
                      Text('Ghi chú của khách', style: HD.bodyBold(size: 14)),
                      const SizedBox(height: HD.s8),
                      _oTrichDan(p.loiNhan.trim()),
                    ],
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

  String _loaiPhong(PhieuHen p) {
    final dt = p.tin.dienTich;
    return dt != null && dt > 0 ? '${dt.toStringAsFixed(0)} m²' : '—';
  }

  /// Khung giờ khách muốn: khung đã đặt + các khung khách ghi kèm trong lời nhắn.
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

  Widget _dongMa(PhieuHen p) => Row(
    children: [
      Text(p.ma, style: HD.bodyBold(size: 15)),
      const SizedBox(width: HD.s8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: HD.svcBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(HD.rPill),
        ),
        child: Text(
          _nhanTrangThai(p.trangThai),
          style: HD.bodyBold(size: 11, color: HD.svcBlue),
        ),
      ),
      const Spacer(),
      Text(
        '${_ngayDep(p.ngay)} · ${p.gio.split('-').first}',
        style: HD.body(size: 11.5, color: HD.inkMuted),
      ),
    ],
  );

  static String _nhanTrangThai(String s) => switch (s) {
    'pending' => 'Yêu cầu mới',
    'approved' => 'Đã xác nhận',
    'doi_gio' => 'Chờ khách chọn giờ',
    'completed' => 'Đã xem xong',
    'cancelled' => 'Đã huỷ',
    'rejected' => 'Đã từ chối',
    'locked' => 'Đã chốt thuê',
    'awaiting_guest' => 'Chờ khách trả lời',
    // Rơi về mã thô còn hơn bịa một nhãn sai; nhưng mọi trạng thái server
    // đang trả đều phải có tên tiếng Việt ở trên.
    _ => s,
  };

  Widget _dongKhach(PhieuHen p) {
    final so = p.sdtKhach.replaceAll(RegExp(r'[^0-9]'), '');
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: HD.paperSunken,
          child: const Icon(Icons.person, color: HD.inkMuted),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.tenKhach.isEmpty ? 'Khách' : p.tenKhach,
                style: HD.bodyBold(size: 15),
              ),
              Row(
                children: [
                  const Icon(Icons.phone, size: 12, color: HD.inkMuted),
                  const SizedBox(width: 4),
                  Text(
                    p.sdtKhach.isEmpty ? 'Chưa có SĐT' : p.sdtKhach,
                    style: HD.body(size: 12.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        _nutTron(
          khoa: 'khach-goi',
          icon: Icons.call,
          bat: so.isNotEmpty,
          onTap: () => _mo(Uri(scheme: 'tel', path: so)),
        ),
        const SizedBox(width: HD.s8),
        _nutTron(
          khoa: 'khach-zalo',
          icon: Icons.chat_bubble,
          bat: so.isNotEmpty,
          onTap: () => _mo(Uri.https('zalo.me', '/$so')),
        ),
      ],
    );
  }

  Widget _nutTron({
    required String khoa,
    required IconData icon,
    required bool bat,
    required VoidCallback onTap,
  }) => InkWell(
    key: Key('sale-$khoa'),
    onTap: bat ? onTap : null,
    borderRadius: BorderRadius.circular(HD.rPill),
    child: Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: HD.accentTint,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 17, color: bat ? HD.accent : HD.inkMuted),
    ),
  );

  Widget _oTrichDan(String chu) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.paperSunken,
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Text('“$chu”', style: HD.body(size: 13, color: HD.ink)),
  );

  Widget _muc(String ten, {String? phu}) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(ten, style: HD.bodyBold(size: 14)),
        if (phu != null) ...[
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '($phu)',
              style: HD.body(size: 11.5, color: HD.inkMuted),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _dongInfo(String nhan, String chu) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(nhan, style: HD.body(size: 12.5, color: HD.inkMuted)),
        ),
        Expanded(child: Text(chu, style: HD.bodyBold(size: 13))),
      ],
    ),
  );

  Widget _oKhung(String chu) => Container(
    padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s8),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r8),
      border: Border.all(color: HD.hairline),
    ),
    child: Text(chu, style: HD.body(size: 12.5, color: HD.ink)),
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
              const SizedBox(height: 2),
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

  Widget _thanhNut() {
    final p = _p;
    final so = (p?.sdtKhach ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final daXacNhan = p?.trangThai == 'approved';
    final daQuaGio = p?.luc != null && !DateTime.now().isBefore(p!.luc!);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (daXacNhan && daQuaGio)
            FilledButton.icon(
              key: const Key('sale-mo-ket-qua'),
              style: viewingPrimaryButton(),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SauBuoiXemScreen(appointmentId: p.id),
                ),
              ),
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: const Text('Ghi kết quả sau khi xem'),
            )
          else if (daXacNhan)
            FilledButton.icon(
              key: const Key('sale-nhan-cho-khach'),
              style: viewingPrimaryButton(),
              onPressed: so.isEmpty
                  ? null
                  : () => _mo(Uri.https('zalo.me', '/$so')),
              icon: const Icon(Icons.notifications_active),
              label: const Text('Nhắc khách'),
            )
          else
            FilledButton.icon(
              key: const Key('sale-xac-nhan-lich'),
              style: viewingPrimaryButton(),
              onPressed: p == null || _dangGui ? null : _xacNhan,
              icon: const Icon(Icons.calendar_month),
              label: const Text('Xác nhận lịch hộ chủ nhà'),
            ),
          const SizedBox(height: HD.s8),
          OutlinedButton.icon(
            key: const Key('sale-lien-he-chu-nha'),
            style: viewingOutlineButton(),
            onPressed: p == null
                ? null
                : () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => LamViecVoiChuNhaScreen(
                            appointmentId: p.id,
                            api: widget.api,
                          ),
                        ),
                      )
                      .then((_) => _nap()),
            icon: Icon(
              daXacNhan ? Icons.event_repeat : Icons.chat_bubble_outline,
            ),
            label: Text(daXacNhan ? 'Đổi lịch / Hủy lịch' : 'Đề xuất giờ khác'),
          ),
          const SizedBox(height: HD.s8),
          Text(
            daXacNhan
                ? 'Khách đã nhận thông báo. Sale không thể tự chốt thuê.'
                : 'Khách sẽ nhận thông báo ngay sau khi lịch được xác nhận.',
            textAlign: TextAlign.center,
            style: HD.body(size: 11.5, color: HD.inkMuted),
          ),
        ],
      ),
    );
  }

  static String _ngayDep(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final thu = d.weekday == DateTime.sunday ? 'CN' : 'T${d.weekday + 1}';
    return '$thu ${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
  }
}
