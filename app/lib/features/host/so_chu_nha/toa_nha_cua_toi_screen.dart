import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/phong_theo_tang_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/them_toa_sheet.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Màn 2 — "Tòa nhà của tôi" (tab Tòa nhà của chủ nhà).
///
/// Nút + đỏ thêm toà; mỗi thẻ: ảnh · tên · địa chỉ · "N phòng" · "N đang
/// thuê" (xanh) · mũi tên → màn phòng theo tầng.
/// API: `GET /api/host/so-chu-nha/toa-nha`.
class ToaNhaCuaToiScreen extends StatefulWidget {
  const ToaNhaCuaToiScreen({super.key, this.api = const SoChuNhaApi(), this.laTab = true});

  final SoChuNhaApi api;
  final bool laTab;

  @override
  State<ToaNhaCuaToiScreen> createState() => _ToaNhaCuaToiScreenState();
}

class _ToaNhaCuaToiScreenState extends State<ToaNhaCuaToiScreen> {
  int _lan = 0;

  Future<void> _them() async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MauCN.the,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ThemToaSheet(api: widget.api),
    );
    if (id != null && mounted) setState(() => _lan++);
  }

  Future<void> _mo(ToaCN t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PhongTheoTangScreen(toaId: t.id, tenToa: t.ten, api: widget.api)),
    );
    if (mounted) setState(() => _lan++);
  }

  @override
  Widget build(BuildContext context) {
    return ManCN(
      tieuDe: 'Tòa nhà của tôi',
      coNutLui: !widget.laTab,
      hanhDong: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: HD.accent,
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('cn-them-toa'),
              customBorder: const CircleBorder(),
              onTap: _them,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.add_rounded, color: HD.paperRaised, size: 24),
              ),
            ),
          ),
        ),
      ],
      body: TaiCN<List<ToaCN>>(
        khoaTai: _lan,
        tai: widget.api.toaNha,
        dung: (context, ds, taiLai) => RefreshIndicator(
          color: HD.accent,
          onRefresh: taiLai,
          child: ListView(
            key: const Key('cn-ds-toa'),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              if (ds.isEmpty)
                const RongCN('Bạn chưa có tòa nhà nào.\nBấm + để thêm tòa nhà đầu tiên.', icon: Icons.apartment_rounded),
              for (final t in ds) _the(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _the(ToaCN t) {
    return TheCN(
      key: Key('cn-toa-${t.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      onTap: () => _mo(t),
      child: Row(
        children: [
          AnhCN(url: t.anh, rong: 84, bo: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.ten, maxLines: 2, overflow: TextOverflow.ellipsis, style: HD.bodyBold(size: 15.5, color: HD.ink)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.location_on_outlined, size: 15, color: HD.inkMuted),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        t.diaChi.isEmpty ? 'Chưa có địa chỉ' : t.diaChi,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 13, color: HD.inkMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (t.soTang > 0) _soLieu(Icons.layers_outlined, '${t.soTang} tầng'),
                    _soLieu(Icons.door_front_door_outlined, '${t.soPhong} phòng'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: MauCN.xanh, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text('${t.dangThue} đang thuê', style: HD.bodyBold(size: 13, color: MauCN.xanh)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
        ],
      ),
    );
  }

  Widget _soLieu(IconData icon, String chu) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: HD.inkSoft),
      const SizedBox(width: 4),
      Text(chu, style: HD.body(size: 13, color: HD.inkSoft)),
    ],
  );
}
