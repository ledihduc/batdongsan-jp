import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/quan_ly_dai_han_api.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/widgets/quan_ly_chung.dart';

/// MÀN 4/4 "Quản lý cho thuê dài hạn" — **Doanh thu** (mockup 23/09/2026).
///
/// Bốn con số của tháng (doanh thu · đã thu · chưa thu · quá hạn), cột doanh
/// thu 6 tháng gần nhất, cơ cấu tiền phòng/điện nước/dịch vụ, top phòng và
/// công nợ cần chú ý.
///
/// Route: push từ lưới "Quản lý" của màn toà. API:
/// `GET /api/host/buildings/{id}/doanh-thu?thang=`.
///
/// **Doanh thu ≠ tiền đã về**: doanh thu là hoá đơn đã phát hành trong kỳ,
/// `đã thu` mới là tiền mặt. Gộp hai cái là tháng nào cũng đẹp.
class DoanhThuToaScreen extends StatefulWidget {
  const DoanhThuToaScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
    this.api = const QuanLyDaiHanApi(),
    this.thang,
  });

  final int buildingId;
  final String buildingName;
  final QuanLyDaiHanApi api;

  /// `YYYY-MM`; bỏ trống = tháng này.
  final String? thang;

  @override
  State<DoanhThuToaScreen> createState() => _DoanhThuToaScreenState();
}

class _DoanhThuToaScreenState extends State<DoanhThuToaScreen> {
  DoanhThuToa? _du;
  late String? _thang = widget.thang;
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() => _loi = null);
    try {
      final d = await widget.api.doanhThu(widget.buildingId, thang: _thang);
      if (!mounted) return;
      setState(() {
        _du = d;
        _thang = d.thang;
        _dangTai = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được doanh thu. Kéo xuống để thử lại.';
      });
    }
  }

  void _doiThang(int buoc) {
    final t = _thang;
    if (t == null || t.length < 7) return;
    final nam = int.parse(t.substring(0, 4));
    final thang = int.parse(t.substring(5, 7));
    final tong = nam * 12 + (thang - 1) + buoc;
    setState(() {
      _thang = '${tong ~/ 12}-${(tong % 12 + 1).toString().padLeft(2, '0')}';
      _dangTai = true;
    });
    _nap();
  }

  @override
  Widget build(BuildContext context) {
    final d = _du;
    return Scaffold(
      backgroundColor: QL.nen,
      appBar: qlAppBar(context, widget.buildingName),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  _chonThang(),
                  const SizedBox(height: 12),
                  if (_loi != null) ...[
                    QlBaoLoi(chu: _loi!),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: QlOSo(
                          khoa: 'dt-doanh-thu',
                          icon: Icons.bar_chart_rounded,
                          mau: QL.xanh,
                          so: qlTien(d?.doanhThu ?? 0),
                          nhan: 'Doanh thu tháng',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: QlOSo(
                          khoa: 'dt-da-thu',
                          icon: Icons.account_balance_wallet_outlined,
                          mau: QL.lam,
                          so: qlTien(d?.daThu ?? 0),
                          nhan: 'Đã thu (${d?.daThuPhanTram ?? 0}%)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: QlOSo(
                          khoa: 'dt-chua-thu',
                          icon: Icons.schedule,
                          mau: QL.cam,
                          so: qlTien(d?.chuaThu ?? 0),
                          nhan: 'Chưa thu (${d?.chuaThuPhanTram ?? 0}%)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: QlOSo(
                          khoa: 'dt-qua-han',
                          icon: Icons.warning_amber_rounded,
                          mau: HD.accent,
                          so: qlTien(d?.quaHan ?? 0),
                          nhan: 'Quá hạn',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _khungCot(d),
                  const SizedBox(height: 12),
                  _khungCoCau(d),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _bangNho(
                          khoa: 'dt-top-phong',
                          icon: Icons.emoji_events_outlined,
                          mauIcon: QL.cam,
                          tieuDe: 'Top phòng doanh thu cao',
                          dong: d?.topPhong ?? const [],
                          mauTien: HD.ink,
                          rong: 'Chưa có doanh thu',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _bangNho(
                          khoa: 'dt-cong-no',
                          icon: Icons.inbox_outlined,
                          mauIcon: HD.accent,
                          tieuDe: 'Công nợ cần chú ý',
                          dong: d?.congNo ?? const [],
                          mauTien: HD.accent,
                          rong: 'Không có công nợ',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _chonThang() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: QL.the,
    child: Row(
      children: [
        const Icon(Icons.calendar_month_outlined, size: 18, color: HD.inkSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            qlThang(_thang ?? ''),
            style: HD.bodyBold(size: 13.5),
          ),
        ),
        IconButton(
          key: const Key('dt-thang-truoc'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left_rounded, color: HD.inkSoft),
          onPressed: () => _doiThang(-1),
        ),
        IconButton(
          key: const Key('dt-thang-sau'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right_rounded, color: HD.inkSoft),
          onPressed: () => _doiThang(1),
        ),
      ],
    ),
  );

  Widget _khungCot(DoanhThuToa? d) {
    final cot = d?.sauThang ?? const [];
    final dinh = cot.fold<double>(0, (a, b) => b.tien > a ? b.tien : a);
    return Container(
      key: const Key('dt-bieu-do'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: QL.the,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Doanh thu 6 tháng gần nhất',
                  style: HD.bodyBold(size: 13),
                ),
              ),
              Text(
                'Đơn vị: triệu đồng',
                style: HD.body(size: 10, color: HD.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 118,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final c in cot)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            c.tien == 0
                                ? '0'
                                : (c.tien / 1000000)
                                      .toStringAsFixed(1)
                                      .replaceAll('.', ','),
                            maxLines: 1,
                            style: HD.bodyBold(size: 9.5, color: HD.inkSoft),
                          ),
                          const SizedBox(height: 3),
                          // Cột cao theo TỈ LỆ với tháng cao nhất; tháng 0 đồng
                          // vẫn để lại một vạch mỏng để không mất cột.
                          Container(
                            height: dinh <= 0
                                ? 2
                                : (c.tien / dinh * 74).clamp(2, 74),
                            decoration: BoxDecoration(
                              color: c.tien <= 0 ? HD.paperSunken : null,
                              gradient: c.tien <= 0
                                  ? null
                                  : const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [HD.accent, Color(0xffF6828A)],
                                    ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            c.nhan,
                            style: HD.body(size: 10, color: HD.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _khungCoCau(DoanhThuToa? d) {
    final muc = d?.coCau ?? const [];
    const mau = {
      'tien_phong': QL.lam,
      'dien_nuoc': QL.cam,
      'dich_vu': QL.xanh,
    };
    const icon = {
      'tien_phong': Icons.bed_outlined,
      'dien_nuoc': Icons.bolt,
      'dich_vu': Icons.grid_view_rounded,
    };
    return Container(
      key: const Key('dt-co-cau'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: QL.the,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cơ cấu doanh thu ${qlThang(d?.thang ?? '').toLowerCase()}',
            style: HD.bodyBold(size: 13),
          ),
          const SizedBox(height: 4),
          for (final m in muc)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(
                    icon[m.ma] ?? Icons.circle,
                    size: 16,
                    color: mau[m.ma] ?? HD.inkMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m.nhan, style: HD.body(size: 12.5))),
                  Text(qlTien(m.tien), style: HD.bodyBold(size: 12.5)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${m.phanTram}%',
                      textAlign: TextAlign.right,
                      style: HD.body(size: 11.5, color: HD.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bangNho({
    required String khoa,
    required IconData icon,
    required Color mauIcon,
    required String tieuDe,
    required List<({String phong, double tien})> dong,
    required Color mauTien,
    required String rong,
  }) => Container(
    key: Key(khoa),
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
    decoration: QL.the,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: mauIcon),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                tieuDe,
                maxLines: 2,
                style: HD.bodyBold(size: 11.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (dong.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(rong, style: HD.body(size: 11, color: HD.inkMuted)),
          )
        else
          for (var i = 0; i < dong.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 17,
                    height: 17,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: mauIcon.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: HD.bodyBold(size: 9.5, color: mauIcon),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      dong[i].phong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 11.5),
                    ),
                  ),
                  Text(
                    qlTien(dong[i].tien),
                    style: HD.bodyBold(size: 11.5, color: mauTien),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}
