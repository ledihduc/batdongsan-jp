import 'package:flutter/material.dart';

import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ho_so_phong_api.dart';
import 'package:house_booking/data/services/tien_ich_phong.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Thêm / sửa một món tài sản bàn giao của phòng. Mở bằng [moTaiSanSheet] từ hồ
/// sơ phòng hoặc danh sách tài sản; đóng với `true` khi đã lưu hoặc xoá.
/// API: `POST /api/host/rooms/{id}/tai-san`, `PATCH|DELETE /api/host/tai-san/{id}`.
///
/// Kèm các hàm dùng chung cho hai màn đó: gộp tài sản đã ghi với "đồ trong
/// phòng" chưa ghi chi tiết ([gopTaiSan]), biểu tượng và màu tình trạng.

/// Đặc điểm của CĂN PHÒNG chứ không phải đồ bàn giao — không vào danh sách tài sản.
const _cauTruc = {'ban_cong', 'gac_xep', 'wc_rieng'};

/// Loại chọn được khi ghi tài sản: đồ trong phòng (trừ đặc điểm cấu trúc) +
/// vài món hay có trong biên bản bàn giao mà tờ khai phòng không hỏi.
final Map<String, String> kLoaiTaiSan = {
  for (final e in kDoTrongPhong.entries)
    if (!_cauTruc.contains(e.key)) e.key: e.value,
  'tivi': 'Tivi',
  'quat': 'Quạt',
  'rem_cua': 'Rèm cửa',
};

/// Một dòng trong danh sách tài sản: món đã ghi ([taiSan] khác `null`) hoặc món
/// tờ khai phòng nói là có mà chưa ai ghi hãng / tình trạng.
typedef MucTaiSan = ({
  TaiSan? taiSan,
  String? loai,
  String ten,
  String? thongSo,
  String? tinhTrang,
});

List<MucTaiSan> gopTaiSan(List<TaiSan> daGhi, List<String> doTrongPhong) {
  final coLoai = {for (final t in daGhi) t.loai};
  return [
    for (final t in daGhi)
      (taiSan: t, loai: t.loai, ten: t.ten, thongSo: t.thongSo, tinhTrang: t.tinhTrang),
    for (final k in doTrongPhong)
      if (kLoaiTaiSan.containsKey(k) && !coLoai.contains(k))
        (taiSan: null, loai: k, ten: kLoaiTaiSan[k]!, thongSo: null, tinhTrang: null),
  ];
}

(IconData, Color) iconTaiSan(String? loai) => switch (loai) {
  'giuong' => (Icons.bed_outlined, HD.svcIndigo),
  'tu_quan_ao' => (Icons.checkroom, HD.svcTeal),
  'ban_ghe' => (Icons.chair_alt_outlined, HD.svcAmber),
  'dieu_hoa' => (Icons.ac_unit, HD.svcBlue),
  'nong_lanh' => (Icons.local_fire_department_outlined, HD.svcAmber),
  'may_giat' => (Icons.local_laundry_service_outlined, HD.svcCyan),
  'tu_lanh' => (Icons.kitchen_outlined, HD.svcGreen),
  'bep' => (Icons.soup_kitchen_outlined, HD.accent),
  'tivi' => (Icons.tv_outlined, HD.svcIndigo),
  'quat' => (Icons.air, HD.svcCyan),
  'rem_cua' => (Icons.curtains_outlined, HD.svcTeal),
  _ => (Icons.inventory_2_outlined, HD.inkSoft),
};

/// `null` = chưa ghi tình trạng.
Color mauTinhTrangTaiSan(String? tinhTrang) => switch (tinhTrang) {
  'tot' => HD.positive,
  'hao_mon' => HD.svcAmber,
  'hong' => HD.negative,
  _ => HD.hairlineStrong,
};

Future<bool> moTaiSanSheet(
  BuildContext context, {
  required int roomId,
  HoSoPhongApi api = const HoSoPhongApi(),
  MucTaiSan? muc,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TaiSanSheet(roomId: roomId, api: api, muc: muc),
  );
  return ok == true;
}

class TaiSanSheet extends StatefulWidget {
  const TaiSanSheet({
    super.key,
    required this.roomId,
    this.api = const HoSoPhongApi(),
    this.muc,
  });

  final int roomId;
  final HoSoPhongApi api;

  /// `null` = thêm mới. Món chưa ghi (taiSan == null) = thêm mới, điền sẵn loại.
  final MucTaiSan? muc;

  @override
  State<TaiSanSheet> createState() => _TaiSanSheetState();
}

class _TaiSanSheetState extends State<TaiSanSheet> {
  late final _ten = TextEditingController(text: widget.muc?.ten ?? '');
  late final _thongSo = TextEditingController(text: widget.muc?.thongSo ?? '');
  late final _ghiChu = TextEditingController(text: widget.muc?.taiSan?.ghiChu ?? '');
  late String? _loai = widget.muc?.loai;
  late String _tinhTrang = widget.muc?.tinhTrang ?? 'tot';
  bool _dangLuu = false;
  String? _loi;

  TaiSan? get _daGhi => widget.muc?.taiSan;

  @override
  void dispose() {
    for (final c in [_ten, _thongSo, _ghiChu]) {
      c.dispose();
    }
    super.dispose();
  }

  void _chonLoai(String? k) {
    final nhanCu = kLoaiTaiSan[_loai];
    setState(() {
      _loai = k;
      // Tên đang trống hoặc vẫn là nhãn tự điền của loại trước → đổi theo loại mới.
      final ten = _ten.text.trim();
      if (ten.isEmpty || ten == nhanCu) _ten.text = kLoaiTaiSan[k] ?? '';
    });
  }

  String? _chu(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _luu() async {
    final ten = _ten.text.trim();
    if (ten.isEmpty) {
      setState(() => _loi = 'Ghi tên tài sản (VD: Điều hòa Daikin)');
      return;
    }
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      final ts = _daGhi;
      if (ts == null) {
        await widget.api.themTaiSan(
          widget.roomId,
          ten: ten,
          loai: _loai,
          thongSo: _chu(_thongSo),
          tinhTrang: _tinhTrang,
          ghiChu: _chu(_ghiChu),
        );
      } else {
        await widget.api.suaTaiSan(
          ts.id,
          ten: ten,
          loai: _loai,
          thongSo: _chu(_thongSo),
          tinhTrang: _tinhTrang,
          ghiChu: _chu(_ghiChu),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangLuu = false;
        _loi = e is ApiException ? e.message : 'Không lưu được. Thử lại.';
      });
    }
  }

  Future<void> _xoa() async {
    final ts = _daGhi;
    if (ts == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá "${ts.ten}"?'),
        content: const Text('Món này sẽ mất khỏi danh sách bàn giao của phòng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _dangLuu = true);
    try {
      await widget.api.xoaTaiSan(ts.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangLuu = false;
        _loi = e is ApiException ? e.message : 'Không xoá được. Thử lại.';
      });
    }
  }

  InputDecoration _o(String nhan, {String? goiY}) => InputDecoration(
    labelText: nhan,
    hintText: goiY,
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(HD.r12)),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(HD.s20, HD.s16, HD.s20, HD.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _daGhi == null ? 'Thêm tài sản bàn giao' : 'Sửa tài sản',
              style: HD.bodyBold(size: 16),
            ),
            const SizedBox(height: HD.s12),
            Text('Loại', style: HD.body(size: 12, color: HD.inkMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in [...kLoaiTaiSan.entries, const MapEntry<String, String>('', 'Khác')])
                  ChoiceChip(
                    key: ValueKey('ts-loai-${e.key.isEmpty ? 'khac' : e.key}'),
                    avatar: Icon(
                      iconTaiSan(e.key.isEmpty ? null : e.key).$1,
                      size: 16,
                      color: iconTaiSan(e.key.isEmpty ? null : e.key).$2,
                    ),
                    label: Text(e.value),
                    selected: (_loai ?? '') == e.key,
                    onSelected: (_) => _chonLoai(e.key.isEmpty ? null : e.key),
                  ),
              ],
            ),
            const SizedBox(height: HD.s16),
            TextField(
              key: const ValueKey('ts-ten'),
              controller: _ten,
              textCapitalization: TextCapitalization.sentences,
              decoration: _o('Tên, hãng *', goiY: 'VD: Điều hòa Daikin'),
            ),
            const SizedBox(height: HD.s12),
            TextField(
              key: const ValueKey('ts-thong-so'),
              controller: _thongSo,
              decoration: _o('Thông số', goiY: 'VD: 12000 BTU • Inverter'),
            ),
            const SizedBox(height: HD.s12),
            Text('Tình trạng', style: HD.body(size: 12, color: HD.inkMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final e in TaiSan.nhanTinhTrang.entries)
                  ChoiceChip(
                    key: ValueKey('ts-tt-${e.key}'),
                    avatar: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: mauTinhTrangTaiSan(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: Text(e.value),
                    selected: _tinhTrang == e.key,
                    onSelected: (_) => setState(() => _tinhTrang = e.key),
                  ),
              ],
            ),
            const SizedBox(height: HD.s12),
            TextField(
              key: const ValueKey('ts-ghi-chu'),
              controller: _ghiChu,
              maxLines: 2,
              decoration: _o('Ghi chú', goiY: 'Vết xước, số seri, ngày mua…'),
            ),
            if (_loi != null)
              Padding(
                padding: const EdgeInsets.only(top: HD.s8),
                child: Text(_loi!, style: HD.body(size: 12, color: HD.negative)),
              ),
            const SizedBox(height: HD.s16),
            Row(
              children: [
                if (_daGhi != null) ...[
                  IconButton(
                    key: const ValueKey('xoa-tai-san'),
                    tooltip: 'Xoá tài sản',
                    onPressed: _dangLuu ? null : _xoa,
                    icon: const Icon(Icons.delete_outline, color: HD.negative),
                  ),
                  const SizedBox(width: HD.s4),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: _dangLuu ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Huỷ'),
                  ),
                ),
                const SizedBox(width: HD.s12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('luu-tai-san'),
                    style: FilledButton.styleFrom(backgroundColor: HD.accent),
                    onPressed: _dangLuu ? null : _luu,
                    child: _dangLuu
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Lưu'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
