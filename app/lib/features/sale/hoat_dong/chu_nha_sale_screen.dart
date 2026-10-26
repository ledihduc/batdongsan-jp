import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Màn 7 — "Chủ nhà" (mockup 05/10/2026): ô tìm, chip Tất cả / Đang hợp tác /
/// Mới, mỗi dòng: avatar · tên · "N tòa nhà • N phòng" · nút gọi.
/// API: `GET /api/sale/van-hanh/chu-nha`.
class ChuNhaSaleScreen extends StatelessWidget {
  const ChuNhaSaleScreen({
    super.key,
    this.kenh = kKenhDaiHan,
    this.api = const SaleVanHanhApi(),
  });

  final String kenh;
  final SaleVanHanhApi api;

  @override
  Widget build(BuildContext context) => TrangSale(
    tieuDe: 'Chủ nhà',
    phuDe: '(${nhanKenh(kenh)})',
    body: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DanhSachChuNhaSale(api: api),
    ),
  );
}

/// Thân danh sách chủ nhà — dùng ở màn 7 và tab "Chủ nhà" của màn 6.
class DanhSachChuNhaSale extends StatefulWidget {
  const DanhSachChuNhaSale({super.key, this.api = const SaleVanHanhApi()});

  final SaleVanHanhApi api;

  @override
  State<DanhSachChuNhaSale> createState() => _DanhSachChuNhaSaleState();
}

class _DanhSachChuNhaSaleState extends State<DanhSachChuNhaSale> {
  String _loc = 'tat_ca';
  String _tim = '';

  bool _khop(ChuNhaSale c) {
    final q = _tim.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.ten.toLowerCase().contains(q) || c.sdt.contains(q);
  }

  @override
  Widget build(BuildContext context) => TaiSale<DanhSachSale<ChuNhaSale>>(
    tai: widget.api.chuNha,
    dung: (context, d, taiLai) {
      final ds = [
        for (final c in d.ds)
          if ((_loc == 'tat_ca' || c.trangThai == _loc) && _khop(c)) c,
      ];
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: OTimSale(
              goiY: 'Tìm chủ nhà...',
              onDoi: (v) => setState(() => _tim = v),
            ),
          ),
          DaiChipSale(
            chip: [for (final c in d.chip) (c.khoa, c.nhan, c.so)],
            chon: _loc,
            onChon: (k) => setState(() => _loc = k),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              color: HD.accent,
              onRefresh: taiLai,
              child: ds.isEmpty
                  ? ListView(
                      children: [
                        RongSale(
                          chu: d.ds.isEmpty
                              ? 'Bạn chưa liên kết với chủ nhà nào. Gửi mã sale '
                                    'của bạn cho chủ nhà để bắt đầu hợp tác.'
                              : 'Không tìm thấy chủ nhà phù hợp.',
                          icon: Icons.home_work_outlined,
                        ),
                      ],
                    )
                  : ListView.separated(
                      key: const Key('ds-chu-nha'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: ds.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: SaleMau.vien),
                      itemBuilder: (_, i) => _DongChuNha(c: ds[i]),
                    ),
            ),
          ),
        ],
      );
    },
  );
}

class _DongChuNha extends StatelessWidget {
  const _DongChuNha({required this.c});

  final ChuNhaSale c;

  @override
  Widget build(BuildContext context) => Padding(
    key: Key('chu-nha-${c.id}'),
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        AvatarSale(ten: c.ten, url: c.anh, co: 50),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.ten, style: HD.bodyBold(size: 15.5, color: HD.ink)),
              const SizedBox(height: 3),
              Text(
                '${c.soToa} tòa nhà • ${c.soPhong} phòng',
                style: HD.body(size: 13, color: HD.inkMuted),
              ),
            ],
          ),
        ),
        NutTronSale(
          key: Key('goi-chu-nha-${c.id}'),
          icon: Icons.call_rounded,
          tooltip: 'Gọi ${c.ten}',
          onTap: () => goiSo(context, c.sdt),
        ),
      ],
    ),
  );
}
