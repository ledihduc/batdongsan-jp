import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// SETUP TẦNG của một toà: tích chọn nhiều phòng → "Chuyển vào tầng…" (tầng
/// có sẵn hoặc gõ tầng mới: số, "Trệt", "Lửng", "Mái").
///
/// Tầng không có bảng riêng — là cột `rooms.tang`; phòng chưa khai và mã không
/// đoán được tầng thì nằm ở "Khác". Lưu ngay mỗi lần chuyển.
/// API: `GET …/toa-nha/{id}/phong`, `PUT …/toa-nha/{id}/tang`.
class SetupTangScreen extends StatefulWidget {
  const SetupTangScreen({super.key, required this.toaId, this.api = const SoChuNhaApi()});

  final int toaId;
  final SoChuNhaApi api;

  @override
  State<SetupTangScreen> createState() => _SetupTangScreenState();
}

class _SetupTangScreenState extends State<SetupTangScreen> {
  PhongCuaToaCN? _d;
  Object? _loi;
  final Set<int> _chon = {};
  bool _dang = false;

  @override
  void initState() {
    super.initState();
    widget.api.phongCuaToa(widget.toaId).then(
      (d) {
        if (mounted) setState(() => _d = d);
      },
      onError: (Object e) {
        if (mounted) setState(() => _loi = e);
      },
    );
  }

  Future<void> _chuyen(PhongCuaToaCN d) async {
    final tang = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MauCN.the,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SheetChonTang(cacTang: d.tang.where((t) => t.ten != 'Khác').toList(), tangMoi: d.tangMoi),
    );
    if (tang == null || !mounted) return;
    setState(() => _dang = true);
    try {
      final moi = await widget.api.datTang(widget.toaId, {for (final id in _chon) id: tang});
      if (!mounted) return;
      final n = _chon.length;
      setState(() {
        _d = moi;
        _chon.clear();
        _dang = false;
      });
      baoCN(context, 'Đã chuyển $n phòng vào ${_nhan(tang)}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dang = false);
      baoCN(context, loiCN(e), loi: true);
    }
  }

  String _nhan(String t) => RegExp(r'^\d+$').hasMatch(t) ? 'Tầng $t' : t;

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return ManCN(
      tieuDe: 'Setup tầng',
      day: d == null
          ? null
          : NutCN(
              _chon.isEmpty ? 'Chọn phòng để xếp tầng' : 'Chuyển ${_chon.length} phòng vào tầng…',
              key: const Key('cn-chuyen-tang'),
              icon: Icons.layers_outlined,
              dangChay: _dang,
              onPressed: _chon.isEmpty ? null : () => _chuyen(d),
            ),
      body: d == null
          ? (_loi != null
                ? RongCN(loiCN(_loi!), icon: Icons.cloud_off_rounded)
                : const Center(child: CircularProgressIndicator(color: HD.accent)))
          : ListView(
              key: const Key('cn-setup-tang'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Text(
                  'Tích chọn các phòng cùng tầng rồi bấm "Chuyển vào tầng". '
                  'Phòng ở mục "Chưa xếp tầng" là phòng chưa có tầng.',
                  style: HD.body(size: 13.5, color: HD.inkMuted),
                ),
                const SizedBox(height: 10),
                for (final t in d.tang) ...[
                  _dauTang(d, t),
                  TheCN(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      children: [
                        for (final p in d.phong.where((p) => p.tang == t.ten))
                          CheckboxListTile(
                            key: Key('cn-chon-phong-${p.id}'),
                            value: _chon.contains(p.id),
                            activeColor: HD.accent,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(p.ten, style: HD.bodyBold(size: 14.5, color: HD.ink)),
                            subtitle: Text(
                              [
                                if (p.dienTich != null) '${soCN(p.dienTich)} m²',
                                nhanLoaiThue(p.loaiThue),
                              ].join(' · '),
                              style: HD.body(size: 12.5, color: HD.inkMuted),
                            ),
                            onChanged: (v) => setState(() => v == true ? _chon.add(p.id) : _chon.remove(p.id)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _dauTang(PhongCuaToaCN d, TangCN t) {
    final cua = d.phong.where((p) => p.tang == t.ten).map((p) => p.id).toList();
    final het = cua.every(_chon.contains);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 0, 6),
      child: Row(
        children: [
          Text(
            t.ten == 'Khác' ? 'Chưa xếp tầng' : t.nhan,
            style: HD.bodyBold(size: 15, color: t.ten == 'Khác' ? HD.accent : HD.ink),
          ),
          const SizedBox(width: 8),
          Text('${t.so} phòng', style: HD.body(size: 13, color: HD.inkMuted)),
          const Spacer(),
          TextButton(
            key: Key('cn-chon-ca-tang-${t.ten}'),
            style: TextButton.styleFrom(foregroundColor: HD.accent),
            onPressed: () => setState(() => het ? _chon.removeAll(cua) : _chon.addAll(cua)),
            child: Text(het ? 'Bỏ chọn' : 'Chọn cả tầng', style: HD.bodyBold(size: 13, color: HD.accent)),
          ),
        ],
      ),
    );
  }
}

/// Sheet chọn tầng đích: các tầng đang có + ô gõ tầng mới. Trả tên tầng.
class _SheetChonTang extends StatefulWidget {
  const _SheetChonTang({required this.cacTang, required this.tangMoi});

  final List<TangCN> cacTang;
  final String tangMoi;

  @override
  State<_SheetChonTang> createState() => _SheetChonTangState();
}

class _SheetChonTangState extends State<_SheetChonTang> {
  late final _moi = TextEditingController(text: widget.tangMoi);

  @override
  void dispose() {
    _moi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chuyển vào tầng', style: HD.bodyBold(size: 18, color: HD.ink)),
          const SizedBox(height: 12),
          if (widget.cacTang.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in widget.cacTang)
                  ActionChip(
                    key: Key('cn-tang-dich-${t.ten}'),
                    label: Text(t.nhan, style: HD.bodyBold(size: 14, color: HD.accent)),
                    backgroundColor: HD.accentTint,
                    side: const BorderSide(color: HD.accent),
                    onPressed: () => Navigator.pop(context, t.ten),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Text('Hoặc tầng mới', style: HD.bodyBold(size: 14, color: HD.ink)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('cn-tang-moi'),
                  controller: _moi,
                  style: HD.body(size: 15, color: HD.ink),
                  decoration: kieuONhapCN(goiY: 'VD: 4, Trệt, Lửng'),
                ),
              ),
              const SizedBox(width: 10),
              NutCN(
                'Chuyển',
                key: const Key('cn-tang-moi-luu'),
                rong: false,
                onPressed: () {
                  final t = _moi.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(context, t.replaceFirst(RegExp(r'^[Tt]ầng\s+'), ''));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
