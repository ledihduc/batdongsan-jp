import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/data/services/giay_to_hop_dong_api.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/dang_thue_api.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/guest/thue_o/khach_bao_su_co_screen.dart';
import 'package:house_booking/features/guest/thue_o/khach_dien_nuoc_screen.dart';
import 'package:house_booking/features/guest/thue_o/khach_hoa_don_screen.dart';
import 'package:house_booking/features/guest/thue_o/khach_hop_dong_screen.dart';
import 'package:house_booking/features/guest/thue_o/widgets/thue_o_ui.dart';

/// Màn 2 — Chi tiết phòng đang thuê (mockup 04/10/2026).
///
/// Ảnh phòng (nhãn "Đang thuê", đếm 1/N) → tên, địa chỉ, thời hạn · còn lại →
/// bốn lối: Hợp đồng · Hóa đơn · Điện nước · Báo sự cố → Thông tin phòng →
/// Thông tin liên hệ.
///
/// API: `GET /api/guest/dang-thue/{contractId}/ho-so` — một lần, các màn con
/// dùng lại đúng hồ sơ này.
class PhongDangThueScreen extends StatefulWidget {
  const PhongDangThueScreen({
    super.key,
    required this.contractId,
    this.api = const DangThueApi(),
    this.dienNuocApi = const DienNuocApi(),
    this.giayToApi = const GiayToHopDongApi(),
  });

  final int contractId;
  final DangThueApi api;
  final DienNuocApi dienNuocApi;
  final GiayToHopDongApi giayToApi;

  @override
  State<PhongDangThueScreen> createState() => _PhongDangThueScreenState();
}

class _PhongDangThueScreenState extends State<PhongDangThueScreen> {
  HoSoThue? _hs;
  String? _loi;
  int _anh = 0;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() => _loi = null);
    try {
      final raw = await widget.api.hoSo(widget.contractId);
      if (mounted) setState(() => _hs = HoSoThue(raw));
    } catch (_) {
      if (mounted) {
        setState(
          () => _loi =
              'Chưa tải được hồ sơ phòng, hoặc hợp đồng này không còn hiệu lực.',
        );
      }
    }
  }

  Future<void> _mo(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) _nap();
  }

  @override
  Widget build(BuildContext context) {
    final hs = _hs;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: hs == null
          ? Center(
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
            )
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                key: const Key('phong-dang-thue'),
                padding: EdgeInsets.zero,
                children: [
                  _anhPhong(hs),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          hs.tieuDe,
                          style: HD.bodyBold(size: 19, color: HD.ink),
                        ),
                        const SizedBox(height: 8),
                        _dong(Icons.location_on_outlined, hs.diaChiNgan),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _dong(
                                Icons.calendar_month_outlined,
                                '${ngayVN(hs.batDau)} – ${ngayVN(hs.ketThuc)}',
                              ),
                            ),
                            Text(
                              conLai(hs.ketThuc),
                              style: HD.body(size: 13, color: HD.inkMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (hs.giayToThieu.isNotEmpty) _canhBaoGiayTo(hs),
                        _bonLoi(hs),
                        const SizedBox(height: 18),
                        _thongTinPhong(hs),
                        const SizedBox(height: 16),
                        _lienHe(hs),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _dong(IconData icon, String chu) => Row(
    children: [
      Icon(icon, size: 17, color: HD.inkMuted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          chu,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 13.5, color: HD.inkMuted),
        ),
      ),
    ],
  );

  Widget _anhPhong(HoSoThue hs) {
    final ds = hs.anh;
    const nen = ColoredBox(
      color: HD.paperSunken,
      child: Center(
        child: Icon(Icons.bed_outlined, size: 48, color: HD.inkMuted),
      ),
    );
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ds.isEmpty)
            nen
          else
            PageView.builder(
              key: const Key('anh-phong'),
              itemCount: ds.length,
              onPageChanged: (i) => setState(() => _anh = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: ds[i],
                fit: BoxFit.cover,
                placeholder: (_, _) => nen,
                errorWidget: (_, _, _) => nen,
              ),
            ),
          Positioned(left: 12, top: 12, child: NhanTron.xanh('Đang thuê')),
          if (ds.length > 1)
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(HD.rPill),
                ),
                child: Text(
                  '${_anh + 1}/${ds.length}',
                  style: HD.bodyBold(size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Thuê trước, bổ sung sau: hợp đồng còn thiếu ảnh / minh chứng cọc → nhắc,
  /// bấm vào là sang màn Hợp đồng (khối Giấy tờ có nút chụp / tải lên).
  Widget _canhBaoGiayTo(HoSoThue hs) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: HD.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('khach-canh-bao-giay-to'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _mo(KhachHopDongScreen(hoSo: hs, giayToApi: widget.giayToApi)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: HD.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hợp đồng còn thiếu '
                  '${hs.giayToThieu.map((x) => x == 'hop_dong' ? 'ảnh hợp đồng' : 'minh chứng cọc').join(' · ')}'
                  ' — chạm để chụp và tải lên.',
                  style: HD.body(size: 13.5, color: HD.ink),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _bonLoi(HoSoThue hs) {
    final o = [
      (
        'Hợp đồng',
        Icons.description_outlined,
        HD.accent,
        const Color(0xFFFDECEC),
        () => _mo(KhachHopDongScreen(hoSo: hs, giayToApi: widget.giayToApi)),
      ),
      (
        'Hóa đơn',
        Icons.receipt_long_outlined,
        const Color(0xFFD97706),
        const Color(0xFFFFF4E0),
        () => _mo(KhachHoaDonScreen(hoSo: hs)),
      ),
      (
        'Điện nước',
        Icons.water_drop_outlined,
        const Color(0xFF2563EB),
        const Color(0xFFE8F0FE),
        () => _mo(KhachDienNuocScreen(hoSo: hs, api: widget.dienNuocApi)),
      ),
      (
        'Báo sự cố',
        Icons.build_outlined,
        HD.positive,
        HD.positiveTint,
        () =>
            _mo(KhachBaoSuCoScreen(contractId: hs.contractId, api: widget.api)),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < o.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: o[i].$4,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: Key('loi-${o[i].$1}'),
                borderRadius: BorderRadius.circular(12),
                onTap: o[i].$5,
                child: SizedBox(
                  height: 76,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(o[i].$2, color: o[i].$3, size: 26),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          o[i].$1,
                          style: HD.body(size: 12, color: o[i].$3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _thongTinPhong(HoSoThue hs) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Thông tin phòng', style: HD.bodyBold(size: 16, color: HD.ink)),
      const SizedBox(height: 4),
      DongThongTin('Loại phòng', hs.loaiPhong),
      DongThongTin('Tầng', hs.tang),
      DongThongTin('Diện tích', hs.dienTich),
      DongThongTin('Nội thất', hs.noiThat, vach: false),
    ],
  );

  Widget _lienHe(HoSoThue hs) {
    final lh = hs.lienHe;
    final sdt = (lh?['sdt'] as String?) ?? '';
    final vai = (lh?['vai'] as String?) ?? 'Chủ nhà / Quản lý';
    final ten = (lh?['ten'] as String?) ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Thông tin liên hệ', style: HD.bodyBold(size: 16, color: HD.ink)),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.person_outline_rounded, color: HD.inkSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ten.isEmpty ? vai : '$vai · $ten',
                style: HD.body(size: 14, color: HD.ink),
              ),
            ),
            IconButton(
              key: const Key('goi-lien-he'),
              tooltip: sdt.isEmpty ? 'Chưa có số điện thoại' : 'Gọi $sdt',
              onPressed: sdt.isEmpty
                  ? null
                  : () => launchUrl(Uri(scheme: 'tel', path: sdt)),
              icon: const Icon(Icons.phone_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
