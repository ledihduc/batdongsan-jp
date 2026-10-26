import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:house_booking/core/config/env.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/chu_nha_api.dart';
import 'package:house_booking/data/services/ho_so_phong_api.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/host/chu_nha/quyet_dinh_sau_xem_screen.dart';
import 'package:house_booking/features/host/chu_nha/widgets/chu_nha_ui.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/screens/room_detail_screen.dart';

/// Màn 3 — Chi tiết phòng phía chủ nhà (mockup "Góc nhìn Chủ nhà", 04/10/2026).
///
/// Ảnh lớn · "Phòng 305 - Tòa A" + nhãn · diện tích · loại · giá → bốn tab:
/// Thông tin · Lịch xem (N) · Hợp đồng · Hóa đơn. Tab Lịch xem: lịch sắp tới
/// (Từ chối / Xác nhận, Xem chi tiết) và lịch đã qua (kết quả, Xem đánh giá).
/// Việc vận hành sâu (lập hoá đơn, công tơ, tài sản…) mở hồ sơ phòng đầy đủ.
///
/// API: `GET /api/host/rooms/{id}/ho-so` + `GET /api/host/chu-nha/phong/{id}/lich-xem`.
class ChiTietPhongChuNhaScreen extends StatefulWidget {
  const ChiTietPhongChuNhaScreen({
    super.key,
    required this.roomId,
    this.api = const ChuNhaApi(),
    this.hoSoApi = const HoSoPhongApi(),
    this.tabDau = 1,
  });

  final int roomId;
  final ChuNhaApi api;
  final HoSoPhongApi hoSoApi;
  final int tabDau;

  @override
  State<ChiTietPhongChuNhaScreen> createState() =>
      _ChiTietPhongChuNhaScreenState();
}

class _ChiTietPhongChuNhaScreenState extends State<ChiTietPhongChuNhaScreen> {
  HoSoPhong? _hs;
  List<LichChuNha> _sapToi = const [];
  List<LichChuNha> _daQua = const [];
  String? _loi;
  late int _tab = widget.tabDau;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final r = await Future.wait([
        widget.hoSoApi.lay(widget.roomId),
        widget.api.lichXemPhong(widget.roomId),
      ]);
      final lx = r[1] as ({List<LichChuNha> sapToi, List<LichChuNha> daQua});
      if (!mounted) return;
      setState(() {
        _hs = r[0] as HoSoPhong;
        _sapToi = lx.sapToi;
        _daQua = lx.daQua;
        _loi = null;
      });
    } catch (_) {
      if (mounted) setState(() => _loi = 'Chưa tải được phòng. Thử lại nhé.');
    }
  }

  Future<void> _mo(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) _nap();
  }

  void _moHoSoDayDu(HoSoPhong hs) => _mo(
    ChangeNotifierProvider(
      create: (_) => RoomProvider()..fetchRooms(hs.toa.id),
      child: RoomDetailScreen(roomId: widget.roomId),
    ),
  );

  String _trangThai(HoSoPhong hs) {
    if (hs.hopDong != null) {
      final con = hs.hopDong!.conLaiNgay;
      return con != null && con <= 30 ? 'sap_tra' : 'dang_thue';
    }
    if (hs.room.status == 'maintenance') return 'bao_tri';
    return _sapToi.isNotEmpty ? 'co_lich_xem' : 'trong';
  }

  String _tenPhong(HoSoPhong hs) => [
    'Phòng ${hs.room.code.replaceFirst(RegExp(r'^[Pp](?=\d)'), '')}',
    if (hs.toa.ten.isNotEmpty) hs.toa.ten,
  ].join(' - ');

  @override
  Widget build(BuildContext context) {
    final hs = _hs;
    if (hs == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: appBarCN(context, 'Chi tiết phòng'),
        body: Center(
          child: _loi == null
              ? const CircularProgressIndicator(color: HD.accent)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    phuCN(_loi!),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _nap,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
        ),
      );
    }
    final r = hs.room;
    final gia = r.giaKenh ?? r.basePrice;
    final tabs = [
      'Thông tin',
      'Lịch xem (${_sapToi.length})',
      'Hợp đồng',
      'Hóa đơn',
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBarCN(context, 'Chi tiết phòng'),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _nap,
        child: ListView(
          key: const Key('chi-tiet-phong-chu-nha'),
          padding: EdgeInsets.zero,
          children: [
            _anh(hs),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tenPhong(hs),
                          style: HD.bodyBold(size: 18, color: HD.ink),
                        ),
                      ),
                      NhanPhong(_trangThai(hs)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (r.areaM2 != null)
                        _Ich(
                          Icons.square_foot_rounded,
                          '${r.areaM2! % 1 == 0 ? r.areaM2!.toInt() : r.areaM2} m²',
                        ),
                      _Ich(
                        Icons.person_outline_rounded,
                        (r.loaiPhong ?? '').isEmpty
                            ? 'Phòng trọ'
                            : r.loaiPhong!,
                      ),
                      if (gia > 0)
                        _Ich(
                          Icons.sell_outlined,
                          '${tienVN(gia)}/${r.donVi ?? 'tháng'}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ThanhTab(
                    tabs: tabs,
                    tab: _tab,
                    onTab: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 14),
                  ...switch (_tab) {
                    0 => _thongTin(hs),
                    1 => _lichXem(),
                    2 => _hopDong(hs),
                    _ => _hoaDon(hs),
                  },
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _anh(HoSoPhong hs) {
    final anh = hs.room.images;
    const nen = ColoredBox(
      color: HD.paperSunken,
      child: Center(
        child: Icon(Icons.bed_outlined, size: 48, color: HD.inkMuted),
      ),
    );
    final houseId = hs.room.marketplaceHouseId;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (anh.isEmpty)
            nen
          else
            CachedNetworkImage(
              imageUrl: duongDanAnh(anh.first),
              fit: BoxFit.cover,
              placeholder: (_, _) => nen,
              errorWidget: (_, _, _) => nen,
            ),
          Positioned(
            right: 10,
            top: 10,
            child: Row(
              children: [
                _NutAnh(
                  key: const Key('mo-ho-so-day-du'),
                  icon: Icons.edit_note_rounded,
                  tooltip: 'Hồ sơ phòng đầy đủ',
                  onTap: () => _moHoSoDayDu(hs),
                ),
                if (houseId != null) ...[
                  const SizedBox(width: 8),
                  _NutAnh(
                    icon: Icons.share_outlined,
                    tooltip: 'Chia sẻ tin',
                    onTap: () =>
                        Share.share(Env.housePublicUrl(houseId, _tenPhong(hs))),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Thông tin ──────────────────────────────────────────────────────────
  List<Widget> _thongTin(HoSoPhong hs) {
    final r = hs.room;
    return [
      for (final (k, v) in [
        ('Tòa nhà', hs.toa.ten),
        ('Địa chỉ', hs.toa.diaChi),
        ('Tầng', (r.tang ?? '').isEmpty ? '—' : r.tang!),
        ('Hướng', (r.huong ?? '').isEmpty ? '—' : r.huong!),
        (
          'Diện tích',
          r.areaM2 == null
              ? '—'
              : '${r.areaM2! % 1 == 0 ? r.areaM2!.toInt() : r.areaM2} m²',
        ),
        ('Sức chứa', '${r.capacity} người'),
        (
          'Đồ trong phòng',
          r.doTrongPhong.isEmpty ? '—' : r.doTrongPhong.join(', '),
        ),
      ])
        _DongTT(k, v.isEmpty ? '—' : v),
    ];
  }

  // ── Tab Lịch xem ───────────────────────────────────────────────────────────
  List<Widget> _lichXem() => [
    Text('Lịch xem sắp tới', style: HD.bodyBold(size: 15)),
    const SizedBox(height: 10),
    if (_sapToi.isEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: phuCN('Chưa có lịch xem nào sắp tới.'),
      )
    else
      for (final m in _sapToi) _TheLich(m: m, sapToi: true, ct: this),
    const SizedBox(height: 6),
    Text('Lịch xem đã qua', style: HD.bodyBold(size: 15)),
    const SizedBox(height: 10),
    if (_daQua.isEmpty)
      phuCN('Chưa có buổi xem nào.')
    else
      for (final m in _daQua) _TheLich(m: m, sapToi: false, ct: this),
  ];

  Future<void> _tuChoi(LichChuNha m) async {
    final lyDo = await hoiLyDoTuChoi(context, tieuDe: 'Từ chối lịch xem');
    if (lyDo == null || !mounted) return;
    if (await chayCN(
      context,
      () => widget.api.tuChoiLich(m.id, lyDo: lyDo),
      xong: 'Đã từ chối · Sale đã được báo',
    )) {
      _nap();
    }
  }

  Future<void> _xacNhan(LichChuNha m) async {
    if (await chayCN(
      context,
      () => widget.api.duyetLich(m.id),
      xong: 'Đã xác nhận lịch xem',
    )) {
      _nap();
    }
  }

  void _xemDanhGia(LichChuNha m) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.ketQua == null ? 'Lịch xem' : 'Kết quả buổi xem',
              style: HD.bodyBold(size: 18),
            ),
            const SizedBox(height: 10),
            nhanLichCN(m),
            const SizedBox(height: 10),
            phuCN(lucHenCN(m)),
            if (m.sale != null) phuCN('Sale: ${m.sale!.ten}'),
            const SizedBox(height: 10),
            phuCN('Khách: $kAnThongTin'),
            const SizedBox(height: 10),
            Text(() {
              final g = m.ketQua == null ? m.ghiChu : m.ghiChuKetQua;
              return g.isEmpty ? 'Không có ghi chú.' : 'Ghi chú: $g';
            }(), style: HD.body(size: 14)),
          ],
        ),
      ),
    ),
  );

  // ── Tab Hợp đồng ───────────────────────────────────────────────────────────
  List<Widget> _hopDong(HoSoPhong hs) {
    final hd = hs.hopDong;
    if (hd == null) {
      return [
        phuCN(
          'Phòng chưa có hợp đồng. Hợp đồng được tạo từ yêu cầu chốt sau '
          'buổi xem, hoặc trong hồ sơ phòng đầy đủ.',
        ),
        const SizedBox(height: 12),
        NutCN('Mở hồ sơ phòng', onPressed: () => _moHoSoDayDu(hs)),
      ];
    }
    return [
      _DongTT('Khách thuê', hd.khach?.ten ?? '—'),
      _DongTT('Thời hạn', '${_dmy(hd.batDau)} – ${_dmy(hd.ketThuc)}'),
      _DongTT('Tiền thuê', '${tienVN(hd.tienThue)}/tháng'),
      _DongTT('Tiền cọc', tienVN(hd.tienCoc)),
      _DongTT(
        'Ngày thanh toán',
        hd.ngayThanhToan == null ? '—' : 'Ngày ${hai(hd.ngayThanhToan!)}',
      ),
      if (hd.conLaiNgay != null)
        _DongTT(
          'Còn lại',
          hd.conLaiNgay! < 0 ? 'Đã quá hạn' : '${hd.conLaiNgay} ngày',
        ),
      const SizedBox(height: 12),
      NutCN(
        'Quản lý hợp đồng',
        key: const Key('quan-ly-hop-dong'),
        onPressed: () => _moHoSoDayDu(hs),
      ),
    ];
  }

  // ── Tab Hóa đơn ────────────────────────────────────────────────────────────
  List<Widget> _hoaDon(HoSoPhong hs) => [
    if (hs.hoaDon.isEmpty)
      phuCN('Chưa có hóa đơn nào.')
    else
      for (final h in hs.hoaDon)
        TheCN(
          child: Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: HD.inkSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hóa đơn tháng ${_kyVN(h.ky)}',
                      style: HD.bodyBold(size: 14, color: HD.ink),
                    ),
                    const SizedBox(height: 2),
                    phuCN(tienVN(h.tong)),
                  ],
                ),
              ),
              h.daTra >= h.tong && h.tong > 0
                  ? const NhanCN(
                      'Đã thanh toán',
                      mau: HD.positive,
                      nen: HD.positiveTint,
                    )
                  : h.trangThai == 'draft'
                  ? const NhanCN(
                      'Nháp',
                      mau: Color(0xFF6B7280),
                      nen: Color(0xFFF1F2F4),
                    )
                  : const NhanCN(
                      'Chưa thanh toán',
                      mau: kCamCN,
                      nen: Color(0xFFFFF4E0),
                    ),
            ],
          ),
        ),
    const SizedBox(height: 8),
    NutCN('Lập hóa đơn', onPressed: () => _moHoSoDayDu(hs)),
  ];
}

String _dmy(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : ngayVN(d);
}

String _kyVN(String ky) {
  final p = ky.split('-');
  return p.length >= 2 ? '${p[1]}/${p[0]}' : ky;
}

class _Ich extends StatelessWidget {
  const _Ich(this.icon, this.chu);

  final IconData icon;
  final String chu;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: HD.inkSoft),
      const SizedBox(width: 4),
      Text(chu, style: HD.body(size: 13, color: HD.inkSoft)),
    ],
  );
}

class _NutAnh extends StatelessWidget {
  const _NutAnh({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: HD.ink),
        ),
      ),
    ),
  );
}

class _ThanhTab extends StatelessWidget {
  const _ThanhTab({required this.tabs, required this.tab, required this.onTab});

  final List<String> tabs;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: kVienCN)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            child: InkWell(
              key: Key('tab-phong-$i'),
              onTap: () => onTab(i),
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == tab ? HD.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tabs[i],
                    style: i == tab
                        ? HD.bodyBold(size: 12.5, color: HD.accent)
                        : HD.body(size: 12.5, color: HD.inkSoft),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _DongTT extends StatelessWidget {
  const _DongTT(this.nhan, this.giaTri);

  final String nhan;
  final String giaTri;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: kVienCN)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: phuCN(nhan)),
        Expanded(
          child: Text(
            giaTri,
            textAlign: TextAlign.right,
            style: HD.body(size: 13.5, color: HD.ink),
          ),
        ),
      ],
    ),
  );
}

/// Một lịch xem trong tab Lịch xem.
class _TheLich extends StatelessWidget {
  const _TheLich({required this.m, required this.sapToi, required this.ct});

  final LichChuNha m;
  final bool sapToi;
  final _ChiTietPhongChuNhaScreenState ct;

  @override
  Widget build(BuildContext context) {
    final d = m.luc;
    final canKetQua =
        !sapToi &&
        m.ketQua == null &&
        m.loai == 'xem' &&
        (m.trangThai == 'approved' || m.trangThai == 'completed');
    return TheCN(
      key: Key('lich-phong-${m.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: HD.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d == null ? m.ngay : ngayVN(d),
                      style: HD.bodyBold(size: 14, color: HD.ink),
                    ),
                    phuCN(khoangGioCN(m.gio)),
                    phuCN('Khách: $kAnThongTin'),
                    if (m.sale != null) phuCN('Sale: ${m.sale!.ten}'),
                  ],
                ),
              ),
              nhanLichCN(m),
            ],
          ),
          if (sapToi && m.trangThai == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: NutCN(
                    'Từ chối',
                    key: Key('tu-choi-${m.id}'),
                    onPressed: () => ct._tuChoi(m),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NutCN(
                    'Xác nhận',
                    key: Key('xac-nhan-${m.id}'),
                    dac: true,
                    onPressed: () => ct._xacNhan(m),
                  ),
                ),
              ],
            ),
          ] else if (canKetQua)
            _Lien(
              'Ghi kết quả',
              () => ct._mo(QuyetDinhSauXemScreen(lich: m, api: ct.widget.api)),
            )
          else if (!sapToi && m.ketQua != null)
            _Lien('Xem đánh giá', () => ct._xemDanhGia(m))
          else if (sapToi && m.trangThai == 'approved')
            _Lien('Xem chi tiết', () => ct._xemDanhGia(m)),
        ],
      ),
    );
  }
}

class _Lien extends StatelessWidget {
  const _Lien(this.chu, this.onTap);

  final String chu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: kXanhDuong,
        visualDensity: VisualDensity.compact,
      ),
      child: Text('$chu ›', style: HD.body(size: 13, color: kXanhDuong)),
    ),
  );
}
