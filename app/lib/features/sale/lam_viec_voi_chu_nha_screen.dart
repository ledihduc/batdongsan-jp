import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/api_viewing_appointment_repository.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';

/// MÀN 3 của SALE — "Làm việc với chủ nhà" (mockup SALE, 20/09/2026).
///
/// Lịch trống lấy từ `GET /viewing-appointments/{id}/gio-trong` — đã trừ khung
/// chủ nhà không mở và khung người khác đặt mất, nên cái sale nhìn thấy đúng là
/// cái đặt được.
///
/// Hai lối ra, đúng hai nút trong mockup:
///   * "Chọn khung trùng"   → duyệt đúng giờ khách xin (`PATCH /status`)
///   * "Đề xuất lịch khác"  → gửi tối đa ba khung (`POST /doi-gio`), khách chọn lại
class LamViecVoiChuNhaScreen extends StatefulWidget {
  const LamViecVoiChuNhaScreen({
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
  State<LamViecVoiChuNhaScreen> createState() => _LamViecVoiChuNhaScreenState();
}

/// Ba khung 2 tiếng của mockup.
const _khung = <({String nhan, int tu, int den})>[
  (nhan: '09:00 - 11:00', tu: 9, den: 11),
  (nhan: '14:00 - 16:00', tu: 14, den: 16),
  (nhan: '18:00 - 20:00', tu: 18, den: 20),
];

class _LamViecVoiChuNhaScreenState extends State<LamViecVoiChuNhaScreen> {
  PhieuHen? _p;
  List<NgayTrong> _ngay = const [];
  int _ngayChon = 0;
  final Set<String> _deXuat = {}; // 'yyyy-MM-dd|HH:00-HH:00'
  bool _dangTai = true;
  bool _dangGui = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() => _loi = null);
    try {
      final p = await widget.api.phieu(widget.appointmentId);
      final ngay = await widget.api.gioTrong(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        _p = p;
        _ngay = ngay;
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được lịch trống. Kéo xuống để thử lại.';
      });
    }
  }

  Future<void> _mo(Uri uri) async {
    if (widget.moLink != null) return widget.moLink!(uri);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Giờ trống đầu tiên trong khung 2 tiếng của ngày đang chọn.
  String? _slotTrong(NgayTrong n, ({String nhan, int tu, int den}) k) {
    for (var h = k.tu; h < k.den; h++) {
      final s =
          '${h.toString().padLeft(2, '0')}:00-'
          '${(h + 1).toString().padLeft(2, '0')}:00';
      if (n.gio.contains(s)) return s;
    }
    return null;
  }

  bool get _khungKhachConTrong {
    final p = _p;
    if (p == null) return false;
    for (final n in _ngay) {
      if (n.ngay == p.ngay && n.gio.contains(p.gio)) return true;
    }
    return false;
  }

  Future<void> _chonKhungTrung() async {
    if (_dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await (widget.lichRepo ?? ApiViewingAppointmentRepository())
          .updateAppointmentStatus(widget.appointmentId, 'approved');
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận lịch xem với khách.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = 'Chưa xác nhận được lịch. Thử lại giúp em.';
      });
    }
  }

  Future<void> _guiDeXuat() async {
    if (_deXuat.isEmpty || _dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await widget.api.doiGio(
        widget.appointmentId,
        deXuat: [
          for (final k in _deXuat)
            GioDeXuat(ngay: k.split('|').first, gio: k.split('|').last),
        ],
        lyDo: 'Chủ nhà bận khung giờ bạn chọn, em đề xuất vài khung khác.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi lịch đề xuất cho khách.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = 'Chưa gửi được đề xuất. Thử lại giúp em.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: HD.ink),
        title: Text('Làm việc với chủ nhà', style: HD.bodyBold(size: 16)),
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
                  _dongChuNha(),
                  const SizedBox(height: HD.s16),
                  if (p != null) _theCan(p),
                  const SizedBox(height: HD.s16),
                  Text('Lịch trống của chủ nhà', style: HD.bodyBold(size: 14)),
                  const SizedBox(height: HD.s8),
                  _chuGiai(),
                  const SizedBox(height: HD.s12),
                  _dayNgay(),
                  const SizedBox(height: HD.s12),
                  if (_ngay.isEmpty)
                    Text(
                      'Chủ nhà chưa mở khung giờ nào trong những ngày tới.',
                      style: HD.body(size: 12.5, color: HD.inkMuted),
                    )
                  else
                    for (final k in _khung) _dongKhung(_ngay[_ngayChon], k),
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

  Widget _dongChuNha() {
    // Chủ nhà lấy từ PHIẾU (suy từ toà/phòng). Trước đây lấy `host_name` của
    // tin — mà tin do chính sale đăng, nên màn này hiện tên và số của CHÍNH
    // SALE dưới nhãn "Chủ nhà".
    final chu = _p?.chuNha;
    final ten = chu?.ten.isNotEmpty == true ? chu!.ten : 'Chưa rõ chủ nhà';
    final so = chu?.sdtDaChe == true
        ? ''
        : (chu?.sdt ?? '').replaceAll(RegExp(r'[^0-9]'), '');
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
              Text(ten, style: HD.bodyBold(size: 15)),
              Text('Chủ nhà', style: HD.body(size: 12, color: HD.inkMuted)),
              if (so.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.phone, size: 12, color: HD.inkMuted),
                    const SizedBox(width: 4),
                    Text(
                      chu!.sdt,
                      style: HD.body(size: 12.5, color: HD.inkMuted),
                    ),
                  ],
                ),
            ],
          ),
        ),
        InkWell(
          key: const Key('sale-goi-chu-nha'),
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

  Widget _chuGiai() => Row(
    children: [
      _cham(HD.positive, 'Có thể xem'),
      const SizedBox(width: HD.s12),
      _cham(HD.inkMuted, 'Không có'),
      const SizedBox(width: HD.s12),
      _cham(HD.warning, 'Khách đang xin'),
    ],
  );

  Widget _cham(Color mau, String chu) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(chu, style: HD.body(size: 11.5, color: HD.inkSoft)),
    ],
  );

  Widget _dayNgay() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < _ngay.length; i++) ...[
          if (i > 0) const SizedBox(width: HD.s8),
          InkWell(
            key: Key('sale-ngay-${_ngay[i].ngay}'),
            onTap: () => setState(() => _ngayChon = i),
            borderRadius: BorderRadius.circular(HD.r8),
            child: Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: HD.s8),
              decoration: BoxDecoration(
                color: i == _ngayChon ? HD.accent : HD.paperRaised,
                borderRadius: BorderRadius.circular(HD.r8),
                border: Border.all(
                  color: i == _ngayChon ? HD.accent : HD.hairline,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _thu(_ngay[i].ngay),
                    style: HD.bodyBold(
                      size: 12,
                      color: i == _ngayChon ? Colors.white : HD.inkSoft,
                    ),
                  ),
                  Text(
                    _ngayThang(_ngay[i].ngay),
                    style: HD.body(
                      size: 11,
                      color: i == _ngayChon ? Colors.white : HD.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _dongKhung(NgayTrong n, ({String nhan, int tu, int den}) k) {
    final slot = _slotTrong(n, k);
    final laKhungKhach =
        _p != null &&
        _p!.ngay == n.ngay &&
        _p!.gio.startsWith(k.tu.toString().padLeft(2, '0'));
    final khoa = slot == null ? null : '${n.ngay}|$slot';
    final chon = khoa != null && _deXuat.contains(khoa);
    final (mauCham, nhanTrang) = slot == null
        ? (HD.inkMuted, 'Không có')
        : laKhungKhach
        ? (HD.warning, 'Khách đang xin')
        : (HD.positive, 'Trống');
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s8),
      child: InkWell(
        key: Key('sale-khung-${n.ngay}-${k.nhan}'),
        onTap: khoa == null
            ? null
            : () => setState(
                () => chon ? _deXuat.remove(khoa) : _deXuat.add(khoa),
              ),
        borderRadius: BorderRadius.circular(HD.r12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HD.s12,
            vertical: HD.s12,
          ),
          decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: chon ? HD.accent : HD.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: mauCham,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Text(
                  k.nhan,
                  style: HD.body(
                    size: 13,
                    color: slot == null ? HD.inkMuted : HD.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mauCham.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HD.rPill),
                ),
                child: Text(
                  nhanTrang,
                  style: HD.bodyBold(size: 11, color: mauCham),
                ),
              ),
              if (chon) ...[
                const SizedBox(width: HD.s8),
                const Icon(Icons.check_circle, size: 16, color: HD.accent),
              ],
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
          height: 48,
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('sale-chon-khung-trung'),
            style: FilledButton.styleFrom(
              backgroundColor: HD.accent,
              disabledBackgroundColor: HD.accent.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HD.r12),
              ),
            ),
            onPressed: !_khungKhachConTrong || _dangGui
                ? null
                : _chonKhungTrung,
            icon: const Icon(
              Icons.event_available,
              size: 18,
              color: Colors.white,
            ),
            label: Text(
              'Chọn khung trùng',
              style: HD.bodyBold(size: 14.5, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: HD.s8),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('sale-de-xuat-lich-khac'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: HD.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HD.r12),
              ),
            ),
            onPressed: _deXuat.isEmpty || _dangGui ? null : _guiDeXuat,
            icon: const Icon(
              Icons.chat_bubble_outline,
              size: 17,
              color: HD.accent,
            ),
            label: Text(
              _deXuat.isEmpty
                  ? 'Đề xuất lịch khác'
                  : 'Đề xuất ${_deXuat.length} khung đã chọn',
              style: HD.bodyBold(size: 14.5, color: HD.accent),
            ),
          ),
        ),
      ],
    ),
  );

  static String _thu(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return d.weekday == DateTime.sunday ? 'CN' : 'T${d.weekday + 1}';
  }

  static String _ngayThang(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}
