import 'package:flutter/material.dart';

import 'package:house_booking/data/services/ho_so_phong_api.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/property/widgets/tai_san_phong_sheet.dart';

/// TÀI SẢN & NỘI THẤT BÀN GIAO của một phòng — "Xem tất cả N tài sản & tình
/// trạng hao mòn" ở hồ sơ phòng: đủ danh sách, đếm theo tình trạng, bấm một món
/// để ghi hãng / thông số / hao mòn. Route: không (push từ `HoSoPhongScreen`).
/// API: [HoSoPhongApi] (đọc lại hồ sơ; thêm / sửa / xoá qua [TaiSanSheet]).
class TaiSanPhongScreen extends StatefulWidget {
  const TaiSanPhongScreen({
    super.key,
    required this.roomId,
    required this.maPhong,
    required this.daGhi,
    required this.doTrongPhong,
    this.suaDuoc = false,
    this.api = const HoSoPhongApi(),
  });

  final int roomId;
  final String maPhong;

  /// Bản đang có ở hồ sơ — hiện ngay, nạp lại sau mỗi lần sửa.
  final List<TaiSan> daGhi;
  final List<String> doTrongPhong;
  final bool suaDuoc;
  final HoSoPhongApi api;

  @override
  State<TaiSanPhongScreen> createState() => _TaiSanPhongScreenState();
}

class _TaiSanPhongScreenState extends State<TaiSanPhongScreen> {
  late List<TaiSan> _daGhi = widget.daGhi;
  late List<String> _doTrongPhong = widget.doTrongPhong;

  Future<void> _nap() async {
    try {
      final hs = await widget.api.lay(widget.roomId);
      if (!mounted) return;
      setState(() {
        _daGhi = hs.taiSan;
        _doTrongPhong = hs.room.doTrongPhong;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải lại được danh sách tài sản')),
        );
      }
    }
  }

  Future<void> _mo([MucTaiSan? muc]) async {
    if (!widget.suaDuoc) return;
    final ok = await moTaiSanSheet(context, roomId: widget.roomId, api: widget.api, muc: muc);
    if (ok) await _nap();
  }

  @override
  Widget build(BuildContext context) {
    final ds = gopTaiSan(_daGhi, _doTrongPhong);
    final dem = <String?, int>{};
    for (final m in ds) {
      dem[m.tinhTrang] = (dem[m.tinhTrang] ?? 0) + 1;
    }
    final tomTat = [
      for (final e in TaiSan.nhanTinhTrang.entries)
        if ((dem[e.key] ?? 0) > 0) (e.key, '${dem[e.key]} ${e.value.toLowerCase()}'),
      if ((dem[null] ?? 0) > 0) (null, '${dem[null]} chưa ghi tình trạng'),
    ];
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        surfaceTintColor: HD.paperRaised,
        title: Text('Tài sản phòng ${widget.maPhong}', style: HD.bodyBold(size: 16)),
        actions: [
          if (widget.suaDuoc)
            TextButton.icon(
              key: const ValueKey('ds-them-tai-san'),
              onPressed: _mo,
              icon: const Icon(Icons.add, size: 16, color: HD.accent),
              label: Text('Thêm', style: HD.bodyBold(size: 13, color: HD.accent)),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _nap,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(HD.s16),
          children: [
            if (ds.isEmpty)
              Padding(
                padding: const EdgeInsets.all(HD.s32),
                child: Text(
                  'Chưa ghi tài sản nào cho phòng này.',
                  textAlign: TextAlign.center,
                  style: HD.body(size: 13, color: HD.inkMuted),
                ),
              )
            else ...[
              Wrap(
                spacing: HD.s12,
                runSpacing: 6,
                children: [
                  for (final (tt, chu) in tomTat)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: mauTinhTrangTaiSan(tt),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(chu, style: HD.body(size: 12, color: HD.inkSoft)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: HD.s12),
              for (final m in ds) ...[
                _DongTaiSan(muc: m, onTap: widget.suaDuoc ? () => _mo(m) : null),
                const SizedBox(height: HD.s8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DongTaiSan extends StatelessWidget {
  const _DongTaiSan({required this.muc, this.onTap});

  final MucTaiSan muc;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, mau) = iconTaiSan(muc.loai);
    final tt = muc.tinhTrang;
    return Material(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(HD.r12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(HD.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.hairline.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: mau.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(HD.r8),
                ),
                child: Icon(icon, size: 18, color: mau),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(muc.ten, style: HD.bodyBold(size: 13)),
                    Text(
                      [
                        muc.thongSo ?? (muc.taiSan == null ? 'Chưa ghi hãng / thông số' : ''),
                        if (muc.taiSan?.ghiChu != null) muc.taiSan!.ghiChu!,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: HD.body(size: 11, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HD.s8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: mauTinhTrangTaiSan(tt), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                TaiSan.nhanTinhTrang[tt] ?? 'Chưa ghi',
                style: HD.bodyBold(size: 11, color: tt == null ? HD.inkMuted : mauTinhTrangTaiSan(tt)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
