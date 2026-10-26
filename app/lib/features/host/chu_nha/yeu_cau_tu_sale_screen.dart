import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/chu_nha_api.dart';
import 'package:house_booking/features/chat/chat_screen.dart';
import 'package:house_booking/features/guest/lich_xem/widgets/lich_xem_ui.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/host/chu_nha/quyet_dinh_sau_xem_screen.dart';
import 'package:house_booking/features/host/chu_nha/tao_hop_dong_screen.dart';
import 'package:house_booking/features/host/chu_nha/widgets/chu_nha_ui.dart';

/// Màn 4 — Yêu cầu từ Sale (mockup "Góc nhìn Chủ nhà", 04/10/2026). Tab
/// "Hoạt động" của chủ nhà.
///
/// Ba tab: Lịch xem (chờ chủ nhà xác nhận) · Yêu cầu chốt (khách muốn thuê
/// sau buổi xem + đề nghị chốt trên tin) · Khác (buổi xem đã qua chưa ghi
/// kết quả). Mỗi thẻ: sale phụ trách (★, gọi, nhắn) → nội dung yêu cầu →
/// Từ chối / Xác nhận (hoặc Xem chi tiết).
///
/// API: `GET /api/host/chu-nha/yeu-cau`.
class YeuCauTuSaleScreen extends StatefulWidget {
  const YeuCauTuSaleScreen({
    super.key,
    this.api = const ChuNhaApi(),
    this.laTab = true,
    this.tabDau = 0,
  });

  final ChuNhaApi api;

  /// Gốc của tab dưới → không có nút quay lại.
  final bool laTab;
  final int tabDau;

  @override
  State<YeuCauTuSaleScreen> createState() => _YeuCauTuSaleScreenState();
}

class _YeuCauTuSaleScreenState extends State<YeuCauTuSaleScreen> {
  YeuCauChuNha? _yc;
  String? _loi;
  late int _tab = widget.tabDau;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final yc = await widget.api.yeuCau();
      if (mounted) setState(() => (_yc = yc, _loi = null));
    } catch (_) {
      if (mounted) {
        setState(() => _loi = 'Chưa tải được yêu cầu. Kéo để thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final yc = _yc;
    final chot = [...?yc?.chot, ...?yc?.giaoDich];
    final ds = switch (_tab) {
      0 => yc?.lichXem ?? const <LichChuNha>[],
      1 => chot,
      _ => yc?.khac ?? const <LichChuNha>[],
    };
    final tabs = [
      'Lịch xem (${yc?.lichXem.length ?? 0})',
      'Yêu cầu chốt (${chot.length})',
      yc == null || yc.khac.isEmpty ? 'Khác' : 'Khác (${yc.khac.length})',
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBarCN(context, 'Yêu cầu từ Sale', quayLai: !widget.laTab),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _nap,
        child: ListView(
          key: const Key('yeu-cau-tu-sale'),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      color: i == _tab ? HD.accent : const Color(0xFFF2F3F5),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: Key('tab-yeu-cau-$i'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _tab = i),
                        child: SizedBox(
                          height: 36,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tabs[i],
                                style: i == _tab
                                    ? HD.bodyBold(
                                        size: 12.5,
                                        color: Colors.white,
                                      )
                                    : HD.body(size: 12.5, color: HD.inkSoft),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            if (yc == null && _loi == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: HD.accent),
                ),
              )
            else if (_loi != null && yc == null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: phuCN(_loi!)),
              )
            else if (ds.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: phuCN(
                    const [
                      'Chưa có lịch xem nào chờ bạn xác nhận.',
                      'Chưa có yêu cầu chốt phòng nào.',
                      'Không còn việc nào khác.',
                    ][_tab],
                  ),
                ),
              )
            else
              for (final m in ds)
                TheYeuCauSale(m: m, api: widget.api, onXong: _nap),
          ],
        ),
      ),
    );
  }
}

/// Thẻ một yêu cầu: sale phụ trách → nội dung → hai nút.
class TheYeuCauSale extends StatelessWidget {
  const TheYeuCauSale({
    super.key,
    required this.m,
    required this.api,
    required this.onXong,
  });

  final LichChuNha m;
  final ChuNhaApi api;
  final VoidCallback onXong;

  Future<void> _mo(BuildContext context, Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    onXong();
  }

  Future<void> _tuChoi(BuildContext context) async {
    final lyDo = await hoiLyDoTuChoi(
      context,
      tieuDe: m.kieu == 'lich_xem' ? 'Từ chối lịch xem' : 'Từ chối chốt phòng',
    );
    if (lyDo == null || !context.mounted) return;
    final ok = await chayCN(
      context,
      () => switch (m.kieu) {
        'lich_xem' => api.tuChoiLich(m.id, lyDo: lyDo),
        'giao_dich' => api.tuChoiGiaoDich(m.id, lyDo: lyDo),
        _ => api.tuChoiChot(m.id, lyDo: lyDo),
      },
      xong: 'Đã từ chối · Sale đã được báo',
    );
    if (ok) onXong();
  }

  Future<void> _xacNhan(BuildContext context) async {
    final ok = await chayCN(
      context,
      () => api.duyetLich(m.id),
      xong: 'Đã xác nhận lịch xem',
    );
    if (ok) onXong();
  }

  Future<void> _xemGiaoDich(BuildContext context) async {
    final dong = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Xác nhận chốt phòng', style: HD.bodyBold(size: 18)),
              const SizedBox(height: 8),
              Text(m.tenPhong, style: HD.body(size: 14.5)),
              if (m.giaThue != null) ...[
                const SizedBox(height: 4),
                phuCN('Giá thuê: ${tienVN(m.giaThue!)}/tháng'),
              ],
              const SizedBox(height: 4),
              phuCN('Khách: $kAnThongTin'),
              const SizedBox(height: 16),
              NutCN(
                'Đồng ý chốt phòng',
                key: const Key('dong-y-giao-dich'),
                dac: true,
                cao: 46,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (dong != true || !context.mounted) return;
    final ok = await chayCN(
      context,
      () => api.xacNhanGiaoDich(m.id),
      xong: 'Đã chốt phòng · Sale và khách đã được báo',
    );
    if (ok) onXong();
  }

  @override
  Widget build(BuildContext context) {
    final s = m.sale;
    final (icon, tieuDe) = switch (m.kieu) {
      'lich_xem' => (Icons.event_note_outlined, 'Yêu cầu xác nhận lịch xem'),
      'ghi_ket_qua' => (Icons.fact_check_outlined, 'Ghi nhận kết quả buổi xem'),
      _ => (Icons.assignment_turned_in_outlined, 'Yêu cầu xác nhận chốt phòng'),
    };
    return TheCN(
      key: Key('yeu-cau-${m.kieu}-${m.id}'),
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s != null) ...[
            Row(
              children: [
                AnhDaiDien(ten: s.ten, anh: s.anh, co: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.ten,
                        style: HD.bodyBold(size: 14.5, color: HD.ink),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          phuCN('Sale'),
                          if (s.danhGia != null) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF5A524),
                            ),
                            Text(
                              s.danhGia!.toStringAsFixed(1),
                              style: HD.body(size: 12.5, color: HD.ink),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Flexible(
                            child: phuCN(
                              '(${s.soLanXemXong} lượt)',
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _NutTron(
                  icon: Icons.call_rounded,
                  tooltip: s.sdt.isEmpty ? 'Chưa có số' : 'Gọi ${s.sdt}',
                  onTap: s.sdt.isEmpty || s.sdtDaChe
                      ? null
                      : () => launchUrl(Uri(scheme: 'tel', path: s.sdt)),
                ),
                const SizedBox(width: 8),
                _NutTron(
                  icon: Icons.chat_bubble_outline_rounded,
                  tooltip: 'Nhắn tin',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        peerId: s.id,
                        peerName: s.ten,
                        peerAvatar: s.anh ?? '',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22, color: kVienCN),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 19, color: HD.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tieuDe, style: HD.bodyBold(size: 14, color: HD.ink)),
                    const SizedBox(height: 4),
                    phuCN(m.tenPhong),
                    ..._noiDung(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: _nut(context)),
        ],
      ),
    );
  }

  List<Widget> _noiDung() {
    final ghiChu = m.kieu == 'chot' ? m.ghiChuKetQua : m.ghiChu;
    return [
      if (m.kieu == 'lich_xem' || m.kieu == 'ghi_ket_qua') ...[
        const SizedBox(height: 2),
        phuCN(lucHenCN(m)),
        const SizedBox(height: 2),
        phuCN('Khách: $kAnThongTin'),
      ] else ...[
        const SizedBox(height: 2),
        phuCN('Khách đã đồng ý thuê, đề nghị chủ xác nhận'),
        if (m.giaThue != null) ...[
          const SizedBox(height: 2),
          phuCN('Giá thuê: ${tienVN(m.giaThue!)}/tháng'),
        ],
        if (!m.laGiaoDich && m.luc != null) ...[
          const SizedBox(height: 2),
          phuCN('Đã xem ngày: ${ngayVN(m.luc)}'),
        ],
      ],
      if (ghiChu.isNotEmpty) ...[
        const SizedBox(height: 2),
        phuCN('Ghi chú: $ghiChu'),
      ],
    ];
  }

  List<Widget> _nut(BuildContext context) => switch (m.kieu) {
    'lich_xem' => [
      Expanded(
        child: NutCN(
          'Từ chối',
          key: Key('tu-choi-${m.id}'),
          onPressed: () => _tuChoi(context),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: NutCN(
          'Xác nhận',
          key: Key('xac-nhan-${m.id}'),
          dac: true,
          onPressed: () => _xacNhan(context),
        ),
      ),
    ],
    'ghi_ket_qua' => [
      Expanded(
        child: NutCN(
          'Ghi kết quả buổi xem',
          key: Key('ghi-ket-qua-${m.id}'),
          dac: true,
          onPressed: () =>
              _mo(context, QuyetDinhSauXemScreen(lich: m, api: api)),
        ),
      ),
    ],
    _ => [
      Expanded(
        child: NutCN(
          'Từ chối',
          key: Key('tu-choi-${m.kieu}-${m.id}'),
          onPressed: () => _tuChoi(context),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: NutCN(
          'Xem chi tiết',
          key: Key('xem-chi-tiet-${m.kieu}-${m.id}'),
          onPressed: () => m.laGiaoDich
              ? _xemGiaoDich(context)
              : _mo(context, TaoHopDongScreen(lich: m, api: api)),
        ),
      ),
    ],
  };
}

class _NutTron extends StatelessWidget {
  const _NutTron({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: HD.accentTint,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? HD.inkMuted : HD.accent,
          ),
        ),
      ),
    ),
  );
}
