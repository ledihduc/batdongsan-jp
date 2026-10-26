import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/chu_nha_api.dart';
import 'package:house_booking/features/guest/project/building_claim_screen.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/host/chu_nha/chi_tiet_phong_chu_nha_screen.dart';
import 'package:house_booking/features/host/chu_nha/widgets/chu_nha_ui.dart';

/// Màn 2 — Quản lý nhà & phòng (mockup "Góc nhìn Chủ nhà", 04/10/2026). Tab
/// "Nhà & phòng" của chủ nhà.
///
/// Chọn toà (ô xổ xuống) + nút thêm toà → chip lọc trạng thái có đếm → phòng
/// gom theo tầng, mỗi tầng gập/mở được → bấm phòng mở Chi tiết phòng.
///
/// API: `GET /api/host/chu-nha/phong?building_id=`.
class NhaVaPhongScreen extends StatefulWidget {
  const NhaVaPhongScreen({
    super.key,
    this.api = const ChuNhaApi(),
    this.laTab = true,
  });

  final ChuNhaApi api;
  final bool laTab;

  @override
  State<NhaVaPhongScreen> createState() => _NhaVaPhongScreenState();
}

class _NhaVaPhongScreenState extends State<NhaVaPhongScreen> {
  PhongCuaToa? _du;
  int? _toa;
  String _loc = 'tat_ca';
  String? _loi;
  final _dong = <String>{};

  static const _chip = [
    ('tat_ca', 'Tất cả'),
    ('dang_thue', 'Đang thuê'),
    ('trong', 'Trống'),
    ('co_lich_xem', 'Có lịch xem'),
    ('sap_tra', 'Sắp trả'),
    ('bao_tri', 'Bảo trì'),
  ];

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final du = await widget.api.phong(buildingId: _toa);
      if (!mounted) return;
      setState(() {
        _du = du;
        _toa = du.toaChon;
        _loi = null;
      });
    } catch (_) {
      if (mounted) setState(() => _loi = 'Chưa tải được danh sách phòng.');
    }
  }

  Future<void> _mo(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) _nap();
  }

  @override
  Widget build(BuildContext context) {
    final du = _du;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBarCN(context, 'Quản lý nhà & phòng', quayLai: !widget.laTab),
      body: du == null
          ? Center(
              child: _loi == null
                  ? const CircularProgressIndicator(color: HD.accent)
                  : phuCN(_loi!),
            )
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                key: const Key('nha-va-phong'),
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                children: [
                  _chonToa(du),
                  const SizedBox(height: 12),
                  if (du.toa.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: phuCN(
                          'Bạn chưa quản lý toà nào. Bấm + để nhận toà bằng '
                          'mã bàn giao.',
                        ),
                      ),
                    )
                  else ...[
                    _chips(du),
                    const SizedBox(height: 12),
                    ..._tang(du),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _chonToa(PhongCuaToa du) => Row(
    children: [
      Expanded(
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDE0E5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const Key('chon-toa'),
              value: du.toa.any((t) => t.id == _toa) ? _toa : null,
              isExpanded: true,
              hint: phuCN('Chọn toà nhà'),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              style: HD.body(size: 14, color: HD.ink),
              items: [
                for (final t in du.toa)
                  DropdownMenuItem(
                    value: t.id,
                    child: Text(
                      t.diaChi.isEmpty ? t.ten : '${t.ten} - ${t.diaChi}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v == null || v == _toa) return;
                setState(() {
                  _toa = v;
                  _loc = 'tat_ca';
                  _dong.clear();
                });
                _nap();
              },
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Tooltip(
        message: 'Thêm toà nhà',
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFDDE0E5)),
          ),
          child: InkWell(
            key: const Key('them-toa'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => _mo(const BuildingClaimScreen()),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.add_rounded, color: HD.ink),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _chips(PhongCuaToa du) => SizedBox(
    height: 34,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final (k, nhan) in _chip)
          if (k == 'tat_ca' ||
              (du.dem[k] ?? 0) > 0 ||
              k == 'dang_thue' ||
              k == 'trong')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: k == _loc ? HD.accent : const Color(0xFFF2F3F5),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  key: Key('loc-$k'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _loc = k),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        '$nhan (${du.dem[k] ?? 0})',
                        style: k == _loc
                            ? HD.bodyBold(size: 12.5, color: Colors.white)
                            : HD.body(size: 12.5, color: HD.inkSoft),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    ),
  );

  List<Widget> _tang(PhongCuaToa du) {
    final loc = du.phong
        .where((p) => _loc == 'tat_ca' || p.trangThai == _loc)
        .toList();
    if (loc.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(child: phuCN('Không có phòng nào ở mục này.')),
        ),
      ];
    }
    // Gom theo tầng, giữ thứ tự số tầng (Trệt / chữ ở cuối).
    final nhom = <String, List<PhongChuNha>>{};
    for (final p in loc) {
      nhom.putIfAbsent(p.tang, () => []).add(p);
    }
    final tang = nhom.keys.toList()
      ..sort((a, b) {
        final x = int.tryParse(a), y = int.tryParse(b);
        if (x != null && y != null) return x.compareTo(y);
        if (x != null) return -1;
        if (y != null) return 1;
        return a.compareTo(b);
      });
    return [
      for (final t in tang)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kVienCN),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                InkWell(
                  key: Key('tang-$t'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(
                    () => _dong.contains(t) ? _dong.remove(t) : _dong.add(t),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(
                      children: [
                        Text(
                          int.tryParse(t) != null ? 'Tầng $t' : t,
                          style: HD.bodyBold(size: 14.5, color: HD.ink),
                        ),
                        const SizedBox(width: 4),
                        phuCN('(${nhom[t]!.length} phòng)'),
                        const Spacer(),
                        Icon(
                          _dong.contains(t)
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: HD.inkSoft,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_dong.contains(t))
                  for (final p in nhom[t]!) _dongPhong(p),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _dongPhong(PhongChuNha p) => InkWell(
    key: Key('phong-${p.id}'),
    onTap: () => _mo(ChiTietPhongChuNhaScreen(roomId: p.id, api: widget.api)),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kVienCN)),
      ),
      child: Row(
        children: [
          AnhNhoCN(url: p.anh, rong: 58, cao: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.ten, style: HD.bodyBold(size: 14, color: HD.ink)),
                const SizedBox(height: 2),
                phuCN(
                  [
                    if (p.dienTich != null)
                      '${p.dienTich! % 1 == 0 ? p.dienTich!.toInt() : p.dienTich} m²',
                    if (p.gia != null) tienVN(p.gia!),
                  ].join(' • '),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          NhanPhong(p.trangThai),
        ],
      ),
    ),
  );
}
