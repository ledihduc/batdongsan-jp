import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/api_viewing_appointment_repository.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// MÀN 3 của CHỦ NHÀ — "Xác nhận lịch xem" (mockup CHỦ NHÀ, 20/09/2026).
///
/// Chọn MỘT khung trong các khung khách xin, hoặc đề xuất giờ khác từ danh sách
/// còn trống thật (`/gio-trong`) rồi để khách chọn lại (`/doi-gio`).
///
/// Ghi chú kèm theo đi vào lý do đổi giờ — chỗ duy nhất server nhận chữ của bên
/// bán trên một lịch hẹn. Chọn đúng khung khách xin thì duyệt thẳng
/// (`PATCH /status` → approved), không cần lý do.
class XacNhanLichXemScreen extends StatefulWidget {
  const XacNhanLichXemScreen({
    super.key,
    required this.appointmentId,
    this.api = const LichXemApi(),
    this.lichRepo,
  });

  final int appointmentId;
  final LichXemApi api;
  final ApiViewingAppointmentRepository? lichRepo;

  @override
  State<XacNhanLichXemScreen> createState() => _XacNhanLichXemScreenState();
}

class _XacNhanLichXemScreenState extends State<XacNhanLichXemScreen> {
  final _ghiChu = TextEditingController();
  PhieuHen? _p;
  List<NgayTrong> _trong = const [];
  String? _chon; // 'yyyy-MM-dd|HH:00-HH:00'
  bool _dangTai = true;
  bool _dangGui = false;
  String? _loi;

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
    try {
      final p = await widget.api.phieu(widget.appointmentId);
      List<NgayTrong> trong = const [];
      try {
        trong = await widget.api.gioTrong(widget.appointmentId);
      } catch (_) {
        trong = const [];
      }
      if (!mounted) return;
      setState(() {
        _p = p;
        _trong = trong;
        _chon = '${p.ngay}|${p.gio}';
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được lịch. Kéo xuống để thử lại.';
      });
    }
  }

  bool get _dungKhungKhach => _p != null && _chon == '${_p!.ngay}|${_p!.gio}';

  Future<void> _xacNhan() async {
    final chon = _chon;
    if (chon == null || _dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      if (_dungKhungKhach) {
        await (widget.lichRepo ?? ApiViewingAppointmentRepository())
            .updateAppointmentStatus(widget.appointmentId, 'approved');
      } else {
        await widget.api.doiGio(
          widget.appointmentId,
          deXuat: [
            GioDeXuat(ngay: chon.split('|').first, gio: chon.split('|').last),
          ],
          lyDo: _ghiChu.text.trim().isEmpty
              ? 'Chủ nhà bận khung giờ bạn chọn, mời bạn chọn khung này.'
              : _ghiChu.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _dungKhungKhach
                ? 'Đã xác nhận lịch xem. Sale và khách đều nhận được thông báo.'
                : 'Đã gửi khung giờ đề xuất cho khách.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = 'Chưa xác nhận được. Thử lại giúp em.';
      });
    }
  }

  /// Khung khách xin + khung còn trống khác của cùng những ngày đó.
  List<({String khoa, String ngay, String gio, bool cuaKhach})> get _luaChon {
    final p = _p;
    if (p == null) return const [];
    final ra = <({String khoa, String ngay, String gio, bool cuaKhach})>[
      (khoa: '${p.ngay}|${p.gio}', ngay: p.ngay, gio: p.gio, cuaKhach: true),
    ];
    for (final n in _trong) {
      for (final g in n.gio) {
        if (n.ngay == p.ngay && g == p.gio) continue;
        ra.add((khoa: '${n.ngay}|$g', ngay: n.ngay, gio: g, cuaKhach: false));
      }
    }
    return ra.take(8).toList();
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
          'Xác nhận lịch xem',
          style: HD.bodyBold(size: 17, color: Colors.white),
        ),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                HD.s16,
                HD.s12,
                HD.s16,
                HD.s24,
              ),
              children: [
                if (p != null) ...[
                  ViewingPropertyCard(phieu: p),
                  const SizedBox(height: HD.s12),
                  const Divider(height: 1),
                  const SizedBox(height: HD.s12),
                  Text('Thông tin khách hàng', style: HD.bodyBold(size: 14)),
                  const SizedBox(height: HD.s8),
                  _dongNguoi(
                    'Khách thuê',
                    p.tenKhach.isEmpty ? 'Khách' : p.tenKhach,
                  ),
                  const SizedBox(height: HD.s16),
                  Text('Thời gian khách yêu cầu', style: HD.bodyBold(size: 14)),
                  const SizedBox(height: HD.s12),
                  for (final l in _luaChon) _oChon(l),
                  if (p.loiNhan.trim().isNotEmpty) ...[
                    const SizedBox(height: HD.s4),
                    ViewingSectionCard(
                      child: Text(
                        '“${p.loiNhan.trim()}”',
                        style: HD.body(size: 12.5, color: HD.inkSoft),
                      ),
                    ),
                  ],
                  const SizedBox(height: HD.s12),
                  ViewingStatusBox(
                    icon: Icons.person_pin_circle,
                    title: 'Bạn trực tiếp xử lý lịch này',
                    message:
                        'Khách sẽ liên hệ với bạn. Sale phụ trách: '
                        '${p.sale?.ten ?? 'đang phân công'}.',
                    color: HD.warning,
                  ),
                  const SizedBox(height: HD.s12),
                  Text('Ghi chú (tuỳ chọn)', style: HD.bodyBold(size: 14)),
                  const SizedBox(height: HD.s8),
                  TextField(
                    key: const Key('chu-ghi-chu-lich'),
                    controller: _ghiChu,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Nhập ghi chú cho sale và khách…',
                      hintStyle: HD.body(size: 12.5, color: HD.inkMuted),
                      filled: true,
                      fillColor: HD.paperRaised,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HD.r12),
                      ),
                    ),
                  ),
                ],
                if (_loi != null) ...[
                  const SizedBox(height: HD.s12),
                  Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                ],
              ],
            ),
      bottomNavigationBar: _dangTai ? null : _thanhNut(),
    );
  }

  Widget _dongNguoi(String vai, String ten) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: HD.paperSunken,
          child: const Icon(Icons.person, size: 16, color: HD.inkMuted),
        ),
        const SizedBox(width: HD.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vai, style: HD.body(size: 11.5, color: HD.inkMuted)),
              Text(ten, style: HD.bodyBold(size: 13)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _oChon(({String khoa, String ngay, String gio, bool cuaKhach}) l) {
    final chon = _chon == l.khoa;
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s8),
      child: InkWell(
        key: Key('chu-lich-${l.khoa}'),
        onTap: () => setState(() => _chon = l.khoa),
        borderRadius: BorderRadius.circular(HD.r12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HD.s12,
            vertical: HD.s12,
          ),
          decoration: BoxDecoration(
            color: chon ? HD.accentTint : HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: chon ? HD.accent : HD.hairline),
          ),
          child: Row(
            children: [
              Icon(
                chon
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: chon ? HD.accent : HD.inkMuted,
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_ngayDep(l.ngay), style: HD.bodyBold(size: 13.5)),
                    Text(
                      l.gio.replaceAll('-', ' - '),
                      style: HD.body(size: 12.5, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              if (l.cuaKhach)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HD.accent,
                    borderRadius: BorderRadius.circular(HD.rPill),
                  ),
                  child: Text(
                    'Khách xin',
                    style: HD.bodyBold(size: 10.5, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thanhNut() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 50,
          width: double.infinity,
          child: FilledButton(
            key: const Key('chu-luu-xac-nhan-lich'),
            style: FilledButton.styleFrom(
              backgroundColor: HD.accent,
              disabledBackgroundColor: HD.accent.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HD.r12),
              ),
            ),
            onPressed: _chon == null || _dangGui ? null : _xacNhan,
            child: _dangGui
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _dungKhungKhach
                        ? 'Xác nhận lịch với khách'
                        : 'Gửi khung giờ này cho khách',
                    style: HD.bodyBold(size: 15, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: HD.s8),
        Text(
          'Sau khi bạn xác nhận, sale và khách sẽ nhận được thông báo.',
          textAlign: TextAlign.center,
          style: HD.body(size: 11.5, color: HD.inkMuted),
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
