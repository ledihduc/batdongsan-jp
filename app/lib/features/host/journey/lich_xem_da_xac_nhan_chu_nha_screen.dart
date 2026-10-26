import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/api_viewing_appointment_repository.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/host/journey/ket_qua_buoi_xem_chu_nha_screen.dart';
import 'package:house_booking/features/host/journey/xac_nhan_lich_xem_screen.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// Chi tiết một lịch xem đã xác nhận ở phía chủ nhà.
class LichXemDaXacNhanChuNhaScreen extends StatefulWidget {
  const LichXemDaXacNhanChuNhaScreen({
    super.key,
    required this.appointmentId,
    this.api = const LichXemApi(),
    this.lichRepo,
    this.bayGio,
  });

  final int appointmentId;
  final LichXemApi api;
  final ApiViewingAppointmentRepository? lichRepo;
  final DateTime? bayGio;

  @override
  State<LichXemDaXacNhanChuNhaScreen> createState() =>
      _LichXemDaXacNhanChuNhaScreenState();
}

class _LichXemDaXacNhanChuNhaScreenState
    extends State<LichXemDaXacNhanChuNhaScreen> {
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
        _loi = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được lịch xem. Kéo xuống để thử lại.';
      });
    }
  }

  Future<void> _huy() async {
    final p = _p;
    if (p == null || _dangGui) return;
    final ghiChu = TextEditingController();
    String lyDo = 'Chủ nhà bận / không có mặt';
    final ketQua = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Hủy lịch xem này?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Khách và Sale sẽ nhận thông báo. Người hủy và lý do được lưu trong lịch sử.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: lyDo,
                  decoration: const InputDecoration(labelText: 'Lý do hủy'),
                  items:
                      const [
                            'Chủ nhà bận / không có mặt',
                            'Phòng không còn sẵn sàng',
                            'Không thống nhất được khung giờ',
                            'Thông tin lịch chưa chính xác',
                            'Khác',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setInner(() => lyDo = value ?? lyDo),
                ),
                if (lyDo == 'Khác') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: ghiChu,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lý do',
                      hintText: 'Mô tả ngắn để các bên nắm thông tin',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Giữ lịch'),
            ),
            FilledButton(
              onPressed: () {
                final value = lyDo == 'Khác' ? ghiChu.text.trim() : lyDo;
                if (value.isNotEmpty) Navigator.pop(ctx, value);
              },
              child: const Text('Xác nhận hủy'),
            ),
          ],
        ),
      ),
    );
    ghiChu.dispose();
    if (ketQua == null || !mounted) return;
    setState(() => _dangGui = true);
    try {
      // Production dùng API phiếu hẹn để gửi cả `ly_do`; backend tự ghi actor
      // hiện tại nên trang Lịch sử hiển thị đúng ai hủy và vì sao.
      if (widget.lichRepo != null) {
        await widget.lichRepo!.updateAppointmentStatus(p.id, 'cancelled');
      } else {
        await widget.api.huy(p.id, lyDo: ketQua);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  Future<void> _nhacKhach() async {
    final so = (_p?.sdtKhach ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (so.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khách chưa cập nhật số điện thoại.')),
      );
      return;
    }
    await launchUrl(
      Uri.https('zalo.me', '/$so'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _goiKhach() async {
    final so = (_p?.sdtKhach ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (so.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khách chưa cập nhật số điện thoại.')),
      );
      return;
    }
    await launchUrl(
      Uri(scheme: 'tel', path: so),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final daQuaGio =
        p?.luc != null && !(widget.bayGio ?? DateTime.now()).isBefore(p!.luc!);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: ViewingDetailAppBar(title: 'Lịch xem đã xác nhận'),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              onRefresh: _nap,
              color: HD.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  HD.s16,
                  HD.s12,
                  HD.s16,
                  HD.s24,
                ),
                children: [
                  if (p != null) ...[
                    ViewingStatusBox(
                      icon: p.choKhachChonGio
                          ? Icons.schedule
                          : daQuaGio
                          ? Icons.rate_review_outlined
                          : Icons.check_circle,
                      title: p.choKhachChonGio
                          ? 'Chờ khách xác nhận giờ mới'
                          : daQuaGio
                          ? 'Đã đến giờ xem · Chờ kết quả'
                          : 'Đã xác nhận lịch',
                      message: p.choKhachChonGio
                          ? 'Đề xuất đã gửi; khách đang chọn lại khung giờ.'
                          : daQuaGio
                          ? 'Ghi nhận buổi xem hoặc chờ khách phản hồi.'
                          : 'Khách đã nhận thông báo.',
                      color: p.choKhachChonGio || daQuaGio
                          ? HD.warning
                          : HD.positive,
                    ),
                    const SizedBox(height: HD.s12),
                    ViewingPropertyCard(phieu: p),
                    const SizedBox(height: HD.s16),
                    ViewingInfoRow(
                      icon: Icons.calendar_month_outlined,
                      text: viewingPrettyDate(p.ngay),
                    ),
                    ViewingInfoRow(
                      icon: Icons.access_time,
                      text: p.gio.replaceAll('-', ' - '),
                    ),
                    ViewingInfoRow(
                      icon: Icons.location_on,
                      text: p.diemDon.diaChi.isEmpty
                          ? p.tin.diaChi
                          : p.diemDon.diaChi,
                    ),
                    const SizedBox(height: HD.s4),
                    Text('Khách hàng', style: HD.bodyBold(size: 14)),
                    const SizedBox(height: HD.s8),
                    ViewingSectionCard(
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 22,
                            backgroundColor: HD.paperSunken,
                            child: Icon(Icons.person, color: HD.inkMuted),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.tenKhach.isEmpty
                                      ? 'Khách thuê'
                                      : p.tenKhach,
                                  style: HD.bodyBold(size: 13.5),
                                ),
                                Text(
                                  p.sdtKhach.isEmpty
                                      ? 'Chưa có số điện thoại'
                                      : p.sdtKhach,
                                  style: HD.body(size: 12, color: HD.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _goiKhach,
                            icon: const Icon(Icons.call, color: HD.positive),
                          ),
                          IconButton(
                            onPressed: _nhacKhach,
                            icon: const Icon(
                              Icons.chat_bubble,
                              color: HD.svcBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_loi != null)
                    Text(_loi!, style: HD.body(color: HD.negative)),
                ],
              ),
            ),
      bottomNavigationBar: p == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    style: viewingPrimaryButton(),
                    onPressed: daQuaGio
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => KetQuaBuoiXemChuNhaScreen(
                                appointmentId: p.id,
                              ),
                            ),
                          )
                        : _nhacKhach,
                    icon: Icon(
                      daQuaGio
                          ? Icons.assignment_turned_in
                          : Icons.notifications_active,
                    ),
                    label: Text(daQuaGio ? 'Ghi nhận kết quả' : 'Nhắc khách'),
                  ),
                  const SizedBox(height: HD.s8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: viewingOutlineButton(),
                          onPressed: _dangGui
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
                                    .then((_) => _nap()),
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: const Text('Đổi lịch'),
                        ),
                      ),
                      const SizedBox(width: HD.s8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: viewingOutlineButton(),
                          onPressed: _dangGui ? null : _huy,
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Hủy lịch'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HD.s8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F7FF),
                      borderRadius: BorderRadius.circular(HD.r8),
                    ),
                    child: Text(
                      'Thông tin sai hoặc khách phản ánh? Gửi báo cáo cho Vua Nhà.',
                      textAlign: TextAlign.center,
                      style: HD.bodyBold(size: 11.5, color: HD.svcBlue),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
